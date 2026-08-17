## Runs the one special ability a marine's position grants them.
##
## The runner owns the *bookkeeping* -- points, whether something is already
## running, the optional clock -- and the [SpecialAbility] resource owns what the
## ability actually does. Adding a new special means writing a resource, not
## touching this file.
##
## An ability may be one-shot (does its work in `activate()` and never ends, e.g.
## a nuke) or sustained (changes something and waits to be told to stop, e.g.
## [RapidFire]). A sustained ability can either hand this node a duration via
## [method run_for] or, like Rapid Fire, run indefinitely until something calls
## [method end].
class_name SpecialAbilityRunner
extends Node

signal points_changed(points: int, points_max: int)
signal special_activated(ability: SpecialAbility)
signal special_ended(ability: SpecialAbility)

@export var marine: Marine3D

## The ability currently running, or null. Read from the position on activation
## rather than cached at load, so swapping position between rounds swaps the
## special along with it.
var _active: SpecialAbility

## Seconds left on a timed ability. Zero means "indefinite" -- the same convention
## marine_deactivated.gd uses for its respawn delay.
var _time_left := 0.0


## The ability this marine's position grants, or null if it has none.
func get_ability() -> SpecialAbility:
	if marine == null or marine.marine_position == null:
		return null
	return marine.marine_position.special_ability


func is_running() -> bool:
	return _active != null


## Spend the points and start the special. Returns false -- having changed
## nothing -- if there is no ability, one is already running, the marine cannot
## afford it, or the ability itself declines.
func try_activate() -> bool:
	var ability := get_ability()
	if ability == null:
		return false
	if _active != null:
		return false
	if marine.special_points < ability.special_points_cost:
		return false
	if not ability.can_activate(self):
		return false

	marine.special_points -= ability.special_points_cost
	points_changed.emit(marine.special_points, marine.special_points_max)

	# Assigned before activate() so the ability can see itself as running, and so a
	# run_for() call from inside activate() has something to attach its clock to.
	_active = ability
	ability.activate(self)
	special_activated.emit(ability)
	return true


## Give the running ability a lifetime, in seconds. Called from inside an
## ability's `activate()`. An ability that never calls this runs until [method end].
func run_for(seconds: float) -> void:
	_time_left = maxf(seconds, 0.0)


## Stop the running ability *without* its payoff. This is a cancel: a resupply
## ending Rapid Fire, a position change, a commander tagged mid-charge. The points
## stay spent -- [method try_activate] already took them, and not refunding them is
## what makes a cancel hurt. Safe to call when nothing is running.
func end() -> void:
	_finish(true)


## The pack stopped being live. Ends the running ability only if it said it cannot
## survive that, so a Nuke dies with its commander while Rapid Fire rides through a
## respawn.
func on_pack_down() -> void:
	if _active != null and _active.cancel_on_deactivate:
		end()


func _process(delta: float) -> void:
	if _active == null or _time_left <= 0.0:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_finish(false)


## The single teardown path. [param cancelled] is the whole difference between a
## nuke going off and a nuke being cancelled: only an uncancelled run gets its
## [method SpecialAbility.complete]. The restore in `deactivate()` runs either way,
## so gear can never be left buffed.
func _finish(cancelled: bool) -> void:
	if _active == null:
		return
	# Cleared before the callbacks so an ability that re-enters here -- via a signal
	# it fires on the way out, or a nuke that kills its own owner -- cannot recurse.
	var ability := _active
	_active = null
	_time_left = 0.0
	if not cancelled:
		ability.complete(self)
	ability.deactivate(self)
	special_ended.emit(ability)
