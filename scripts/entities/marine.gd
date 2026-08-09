class_name Marine3D

extends Node3D

@export var phaser: Node3D

enum PACK_STATE {
	UP,
	DOWN
}



var shots_max = 60
var shots = 30
var lives_max = 30
var lives = 15

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

#Show the laser, more?
func shoot():
	pass
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func getAllSensors():
	return [$sensorback, $sensorfront, $sensorleftshoulder, $sensorrightshoulder, $phaser/sensorphaser]
