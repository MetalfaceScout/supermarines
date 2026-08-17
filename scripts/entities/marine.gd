## A marine's laser-tag gear: the pack, the phaser, and the IR sensors.
##
## This script deliberately holds *no* rules about when you may shoot or take a
## hit. It owns the data (shots, lives, sensors) and forwards every verb to the
## current [MarineState], which decides what -- if anything -- happens.
class_name Marine3D
extends Node3D

## Lost a life. Fires on every hit, including the fatal one.
signal tagged(source: Node, lives_remaining: int)
## A shot left the phaser.
signal shot_fired(shots_remaining: int)
## Trigger pulled with an empty magazine.
signal out_of_shots
## Lives hit zero.
signal died
## Re-emitted from the state machine, for HUDs and pack lights.
signal state_changed(from: StringName, to: StringName)
## A hit was soaked by armor instead of costing a life.
signal hit_absorbed(source: Node, armor_remaining: int)
## This marine's position was assigned or changed.
signal position_changed(new_position: MarinePosition)

## Which side this marine is on. NONE is a marine that has not been assigned yet --
## it has no enemies and cannot be nuked, which keeps a half-built test scene from
## behaving like a one-man team.
enum Team { NONE, RED, BLUE }

## The position this marine is playing. Every gear stat comes from here.
## Named `marine_position` rather than `position` because Node3D already owns
## that name -- shadowing it is a parse error.
@export var marine_position: MarinePosition

## Red or blue. Setting this re-registers the marine in the matching group, so a
## round manager can shuffle sides between rounds without rebuilding anything.
@export var team: Team = Team.NONE:
	set(value):
		if team == value:
			return
		_leave_team_group()
		team = value
		# Node groups need a tree. During scene load this setter runs before the
		# node is in one, so _ready() joins again to cover that case.
		if is_inside_tree():
			_join_team_group()

## Current gear, refilled to the position's maxima by [method reset_gear].
var shots := 0
var lives := 0

## Current special points
var special_points := 0

## Copied from the position on ready, so a buff can raise them at runtime
## without editing the shared resource.
var shots_max := 0
var lives_max := 0
var special_points_max := 0

## -- Runtime gear modifiers -----------------------------------------------------
##
## Written by a running [SpecialAbility] and restored when it ends. They live here
## rather than on the [MarinePosition] because the position resource is shared by
## every marine playing it -- buffing one Scout must not buff the others.

## Multiplier on this position's shot cooldown. 1.0 is the position's own rate;
## [RapidFire] drops it below 1 to fire faster.
var shot_cooldown_scale := 1.0

## While true, holding the trigger keeps firing instead of one shot per click.
## The shot cooldown still sets the rate -- this only changes what the player has
## to do with their finger.
var full_auto := false

## Every IR sensor on this marine, found automatically at load.
var sensors: Array[IREmitter3D] = []

var _sensors_enabled := false

@onready var state_machine: StateMachine = $StateMachine

@onready var special_runner: SpecialAbilityRunner = $SpecialAbilityRunner

## The pack's warning lights, or null in a scene that has none. Found by type so a
## marine rig without lights still loads.
@onready var pack_lights: PackLights = find_children("*", "PackLights", true, false).pop_front()

func _ready() -> void:
	_join_team_group()

	sensors = _collect_sensors()
	for sensor in sensors:
		sensor.tagged.connect(_on_sensor_tagged)

	apply_position()

	state_machine.state_changed.connect(state_changed.emit)
	state_machine.start()


# -- Verbs: forwarded to whatever state is running -----------------------------

## Pull the trigger. Returns true if a shot actually went out.
func shoot() -> bool:
	return _state().shoot()


## Register an incoming tag from [param source].
func take_hit(source: Node) -> void:
	_state().take_hit(source)

## Use special
func use_special() -> void:
	_state().use_special()
	

# -- Control: called from outside, e.g. a round manager ------------------------

## Power the pack up.
func activate() -> void:
	state_machine.transition_to(&"Activated")


## Power the pack down. With [param duration] > 0 it comes back up by itself.
##
## Re-entrant on purpose: calling this on a marine who is already down restarts
## their timer rather than being ignored, so a nuke landing on someone mid-respawn
## extends their downtime instead of doing nothing.
func deactivate(duration := 0.0) -> void:
	state_machine.transition_to(&"Deactivated", {"duration": duration}, true)


## Knock the marine out regardless of lives remaining.
func kill() -> void:
	state_machine.transition_to(&"Dead")


## Take [param amount] lives straight off the counter and, if that empties it, go
## down for good.
##
## This is the one verb that deliberately does *not* forward to the current state.
## Everywhere else the state decides whether something is allowed -- but nuke damage
## is unconditional by design: it ignores armor, and it lands on marines who are
## deactivated or mid-respawn, both of which [method take_hit] would swallow.
## Reach for [method take_hit] for anything a phaser did; reach for this only for
## effects that are supposed to be un-dodgeable.
##
## Already-dead marines are skipped -- there is nothing left to take.
func take_lives(amount: int, source: Node = null) -> void:
	if amount <= 0 or not is_alive():
		return
	lives = maxi(lives - amount, 0)
	tagged.emit(source, lives)
	if lives <= 0:
		state_machine.transition_to(&"Dead")


# -- Teams ---------------------------------------------------------------------

## The side this marine shoots at. NONE for an unassigned marine.
func enemy_team() -> Team:
	match team:
		Team.RED: return Team.BLUE
		Team.BLUE: return Team.RED
		_: return Team.NONE


## Every marine on the opposing side, dead ones included -- callers filter.
##
## Backed by node groups today, and funnelled through this one method on purpose:
## when a round manager takes over the roster, this body changes and nothing that
## calls it has to.
func get_enemy_marines() -> Array[Marine3D]:
	return get_marines_on(enemy_team())


## Every marine on [param which_team], excluding this one. Empty for Team.NONE.
func get_marines_on(which_team: Team) -> Array[Marine3D]:
	var found: Array[Marine3D] = []
	var group := group_for(which_team)
	if group == &"" or not is_inside_tree():
		return found
	for node in get_tree().get_nodes_in_group(group):
		var other := node as Marine3D
		if other != null and other != self:
			found.append(other)
	return found


## The node group backing [param which_team], or &"" for Team.NONE.
static func group_for(which_team: Team) -> StringName:
	match which_team:
		Team.RED: return &"team_red"
		Team.BLUE: return &"team_blue"
		_: return &""
	


## Adopt a position and refill to its gear. Pass nothing to re-apply the one
## already assigned in the inspector. Safe to call between rounds.
func apply_position(new_position: MarinePosition = null) -> void:
	if new_position != null:
		marine_position = new_position

	if marine_position == null:
		push_error("Marine3D '%s' has no position assigned." % name)
		return

	shots_max = marine_position.shots_max
	lives_max = marine_position.lives_max
	special_points = marine_position.special_points
	special_points_max = marine_position.special_points_max
	# A special belongs to the position that granted it, so changing position drops
	# whatever was running rather than carrying a Scout's Rapid Fire onto a Heavy.
	if special_runner != null:
		special_runner.end()
	reset_gear()
	position_changed.emit(marine_position)


## Restore gear to this position's starting supply -- not to the maxima. The
## gap between the two is what a Medic or Ammo will eventually fill.
## Does not change state -- follow with [method activate].
func reset_gear() -> void:
	if marine_position == null:
		return
	# mini() guards against a .tres that was authored with a start above its max.
	shots = mini(marine_position.starting_shots, shots_max)
	lives = mini(marine_position.starting_lives, lives_max)


## Hits this marine can soak before one costs a life.
func get_armor() -> int:
	return marine_position.armor if marine_position != null else 0


## Seconds this marine must wait between shots, after any running special has had
## its say. Read this rather than the position's raw `shot_cooldown` -- that one
## does not know about buffs.
func get_shot_cooldown() -> float:
	if marine_position == null:
		return 0.0
	return marine_position.shot_cooldown * shot_cooldown_scale


func is_active() -> bool:
	return state_machine.current_state != null \
		and state_machine.current_state.name == &"Activated"


## Still in the round. False only in Dead -- a marine sitting out a respawn is
## down, not out, which is why a nuke can still reach them.
func is_alive() -> bool:
	return state_machine.current_state == null \
		or state_machine.current_state.name != &"Dead"


# -- Internals -----------------------------------------------------------------

func _join_team_group() -> void:
	var group := group_for(team)
	if group != &"" and not is_in_group(group):
		add_to_group(group)


func _leave_team_group() -> void:
	var group := group_for(team)
	if group != &"" and is_in_group(group):
		remove_from_group(group)

## Blink the pack's warning lights, if this marine's rig has any. A charging nuke
## is the first caller; a low-lives warning will be the second.
func set_pack_flashing(flashing: bool) -> void:
	if pack_lights == null:
		return
	if flashing:
		pack_lights.start_flashing()
	else:
		pack_lights.stop_flashing()


func set_sensors_enabled(enabled: bool) -> void:
	_sensors_enabled = enabled
	for sensor in sensors:
		sensor.set_enabled(enabled)

func register_sensor(sensor: IREmitter3D) -> void:
	if sensor in sensors:
		return
	sensor.tagged.connect(_on_sensor_tagged)
	sensor.set_enabled(_sensors_enabled)
	sensors.append(sensor)
	
func unregister_sensor(sensor: IREmitter3D) -> void:
	if not sensor in sensors:
		return
	sensor.tagged.disconnect(_on_sensor_tagged)
	sensor.set_enabled(false)
	sensors.erase(sensor)


func _state() -> MarineState:
	return state_machine.current_state as MarineState


func _on_sensor_tagged(source: Node) -> void:
	take_hit(source)


## Finds sensors by type rather than by hardcoded node path, so moving or
## renaming one in the editor -- or adding a sixth -- needs no code change.
func _collect_sensors() -> Array[IREmitter3D]:
	var found: Array[IREmitter3D] = []
	for node in find_children("*", "IREmitter3D", true, false):
		found.append(node)
	return found
