## Base class for a single state in a [StateMachine].
##
## Subclass this, attach it to a [Node] child of a [StateMachine], and override
## the callbacks you care about. Every callback is a no-op by default, so a
## state only contains the behaviour that is actually different about it.
class_name State
extends Node

## Emitted when this state wants the machine to switch to another one.
## Prefer calling [method transition_to] instead of emitting this directly.
signal transition_requested(next_state_name: StringName, data: Dictionary)

## The node this state acts on (the Marine, the Player, ...).
## Assigned by the [StateMachine] when it registers its children.
var agent: Node


## Called once when the machine switches into this state.
## [param previous] is the name of the state we came from (empty on startup).
## [param data] carries optional hand-off values from the previous state.
func enter(_previous: StringName, _data: Dictionary = {}) -> void:
	pass


## Called once when the machine switches away from this state.
## Undo anything [method enter] turned on.
func exit() -> void:
	pass


## Called every frame while this state is active, from the machine's _process.
func update(_delta: float) -> void:
	pass


## Called every physics tick while this state is active.
func physics_update(_delta: float) -> void:
	pass


## Ask the machine to switch states. The switch happens immediately, so avoid
## doing more work after calling this.
func transition_to(next_state_name: StringName, data: Dictionary = {}) -> void:
	transition_requested.emit(next_state_name, data)
