## Root of the phaser scene.
##
## This is the phaser's public interface: the owning rig (player.tscn, later a
## bot) wires up `marine` here, and this script hooks the internals to it. Nodes
## inside an instanced scene cannot be configured from the parent scene, so the
## root is the only place this connection can be made.
extends Node3D

## The marine whose trigger fires this phaser. Wire this from the scene that
## instances the phaser -- in player.tscn that is `../../Marine`.
@export var marine: Marine3D

@onready var barrel_light: OmniLight3D = $phaserlights/barrellight

## Lights the gun's white casing from within on each shot.
@onready var barrel_glow: MaterialFlash = $barrelglow

@onready var sensor: IREmitter3D = $sensorphaser

func _ready() -> void:
	if marine == null:
		return
	marine.register_sensor(sensor)

	# `shot_fired` passes the remaining shot count, but flash() takes no
	# arguments -- unbind(1) drops it. Connecting a 1-arg signal straight to a
	# 0-arg method is an error in Godot 4.
	marine.shot_fired.connect(barrel_light.flash.unbind(1))
	marine.shot_fired.connect(barrel_glow.flash.unbind(1))
