## A single IR sensor on a marine's gear.
##
## Live sensors sit on a physics layer that incoming shots scan for. Disabling a
## sensor moves it to layer 0 so shots pass straight through it -- that is what
## makes a deactivated or dead pack untaggable.
class_name IREmitter3D
extends Node3D

## This sensor was hit by [param source].
signal tagged(source: Node)

@onready var _area: Area3D = $Area3D
## Whatever layer the scene configured; restored whenever the sensor is enabled.
@onready var _active_layer: int = _area.collision_layer

var _enabled := true


## Turn the sensor on or off. A disabled sensor cannot be tagged.
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	_area.collision_layer = _active_layer if enabled else 0
	_area.monitoring = enabled


func is_enabled() -> bool:
	return _enabled


## Move the sensor to a different physics layer. Used to hide a player's own
## sensors from their own phaser so they cannot tag themselves.
func set_active_layer(layer: int) -> void:
	_active_layer = layer
	if _enabled:
		_area.collision_layer = layer


## Report an incoming tag. Called by whatever resolves a shot.
func tag(source: Node) -> void:
	if not _enabled:
		return
	tagged.emit(source)
