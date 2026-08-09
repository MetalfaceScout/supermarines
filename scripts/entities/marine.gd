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

@export var shots_max := 60
@export var shots := 30
@export var lives_max := 30
@export var lives := 15

## Every IR sensor on this marine, found automatically at load.
var sensors: Array[IREmitter3D] = []

var _sensors_enabled := false

@onready var state_machine: StateMachine = $StateMachine


func _ready() -> void:
	sensors = _collect_sensors()
	for sensor in sensors:
		sensor.tagged.connect(_on_sensor_tagged)

	state_machine.state_changed.connect(state_changed.emit)
	state_machine.start()


# -- Verbs: forwarded to whatever state is running -----------------------------

## Pull the trigger. Returns true if a shot actually went out.
func shoot() -> bool:
	return _state().shoot()


## Register an incoming tag from [param source].
func take_hit(source: Node) -> void:
	_state().take_hit(source)


# -- Control: called from outside, e.g. a round manager ------------------------

## Power the pack up.
func activate() -> void:
	state_machine.transition_to(&"Activated")


## Power the pack down. With [param duration] > 0 it comes back up by itself.
func deactivate(duration := 0.0) -> void:
	state_machine.transition_to(&"Deactivated", {"duration": duration})


## Knock the marine out regardless of lives remaining.
func kill() -> void:
	state_machine.transition_to(&"Dead")


## Refill shots and lives. Does not change state -- follow with [method activate].
func reset_gear() -> void:
	shots = shots_max
	lives = lives_max


func is_active() -> bool:
	return state_machine.current_state != null \
		and state_machine.current_state.name == &"Activated"


# -- Internals -----------------------------------------------------------------

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
