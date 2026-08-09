class_name IREmitter3D

extends Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#Set the scale of the CollisionShape3D to the IR Radius.
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func setCollisonMask(mask):
	$Area3D.collision_layer = 4
