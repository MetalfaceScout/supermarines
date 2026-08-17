## Drives one active [State] at a time.
##
## Add this as a child node, then add a [State] node per state underneath it.
## The state's *node name* is its identifier, so [code]&"Activated"[/code] refers
## to the child named "Activated".
##
## The owner must call [method start] once it is ready. Nothing happens before
## that -- this is deliberate, so states can safely touch the owner's fields
## instead of racing Godot's child-before-parent _ready() order.
class_name StateMachine
extends Node

## Emitted after every successful switch. Handy for driving UI and sounds
## without the states having to know those things exist.
signal state_changed(from: StringName, to: StringName)

## The state to enter when [method start] is called.
@export var initial_state: State

## The node the states act on. Defaults to the scene root this machine
## belongs to, which is almost always what you want.
@export var agent: Node

## The state currently running, or null before [method start].
var current_state: State

var _states: Dictionary[StringName, State] = {}


func _ready() -> void:
	if agent == null:
		agent = owner

	for child in get_children():
		var state := child as State
		if state == null:
			push_warning("StateMachine: child '%s' is not a State, skipping." % child.name)
			continue
		_states[state.name] = state
		state.agent = agent
		state.transition_requested.connect(_on_transition_requested)


## Enter [member initial_state]. Call this from the owner's _ready().
func start() -> void:
	if current_state != null:
		push_warning("StateMachine: already started.")
		return
	if initial_state == null:
		push_error("StateMachine: initial_state is not set.")
		return
	_switch_to(initial_state, &"", {})


## Force a switch from outside -- e.g. a game manager activating every pack at
## the start of a round.
##
## [param allow_reenter] re-runs exit() and enter() even when the machine is already
## in that state, which is how a timer gets restarted -- a nuke extending the
## downtime of someone already sitting out a respawn. It is off by default because
## most re-entries are accidental and destructive: re-entering Activated would hand
## the marine a fresh set of armor.
func transition_to(next_state_name: StringName, data: Dictionary = {}, allow_reenter := false) -> void:
	var next: State = _states.get(next_state_name)
	if next == null:
		push_error("StateMachine: no state named '%s'." % next_state_name)
		return
	if next == current_state and not allow_reenter:
		return
	_switch_to(next, current_state.name if current_state else &"", data)


func _switch_to(next: State, previous_name: StringName, data: Dictionary) -> void:
	if current_state != null:
		current_state.exit()
	current_state = next
	current_state.enter(previous_name, data)
	state_changed.emit(previous_name, current_state.name)


func _on_transition_requested(next_state_name: StringName, data: Dictionary) -> void:
	transition_to(next_state_name, data)


func _process(delta: float) -> void:
	if current_state != null:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)
