## Drives every light on a marine's pack as one group.
##
## Like [MaterialFlash] and the phaser's barrel light, this knows nothing about
## nukes, marines, or specials -- something else calls [method start_flashing]. That
## keeps it usable for a low-lives warning, a medic beacon, or a round-start pulse.
##
## It finds its lights by type rather than by path, so adding a fifth light to the
## pack in the editor needs no code change. With no lights under it at all this is a
## harmless no-op, which is what lets the script be attached before the pack has
## been lit.
class_name PackLights
extends Node3D

## Colour the pack blinks. Set per use -- a charging nuke is not the same signal as
## a medic beacon.
@export var flash_color := Color(1.0, 0.15, 0.05)

## Peak brightness of a blink. Above 1 blooms, since glow is on in the world
## environment.
@export var flash_energy := 5.0

## Blinks per second.
@export_range(0.5, 20.0, 0.5) var flash_hz := 4.0

## Lights found under this node, captured once at load.
var _lights: Array[OmniLight3D] = []

## What each light looked like before we took it over, so [method stop_flashing]
## restores rather than guessing at black.
var _rest_energy: Array[float] = []
var _rest_color: Array[Color] = []

var _flashing := false
var _phase := 0.0


func _ready() -> void:
	_lights = _collect_lights()
	for light in _lights:
		_rest_energy.append(light.light_energy)
		_rest_color.append(light.light_color)
	set_process(false)


## Start blinking, and keep going until [method stop_flashing]. Calling this while
## already flashing restarts the cycle rather than stacking.
func start_flashing() -> void:
	_flashing = true
	_phase = 0.0
	for light in _lights:
		light.light_color = flash_color
	set_process(true)


## Stop, and put every light back exactly as it was found.
func stop_flashing() -> void:
	_flashing = false
	set_process(false)
	for i in _lights.size():
		_lights[i].light_energy = _rest_energy[i]
		_lights[i].light_color = _rest_color[i]


func is_flashing() -> bool:
	return _flashing


func _process(delta: float) -> void:
	_phase += delta * flash_hz
	# A square wave rather than a sine: a pack that is obviously blinking reads
	# across a dark arena, where a smooth pulse just looks like a light.
	var lit := fmod(_phase, 1.0) < 0.5
	for light in _lights:
		light.light_energy = flash_energy if lit else 0.0


## Finds lights by type rather than by hardcoded path, matching how [Marine3D]
## collects its sensors.
func _collect_lights() -> Array[OmniLight3D]:
	var found: Array[OmniLight3D] = []
	for node in find_children("*", "OmniLight3D", true, false):
		found.append(node)
	return found
