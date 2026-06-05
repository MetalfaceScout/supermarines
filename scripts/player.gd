extends CharacterBody3D

#TODO: Should only be able to sprint when overall velocity is forward, no sprinting to the side

@onready var head: Node3D = $head

const SPRINT_SPEED = 7.0
const RUN_SPEED = 5.0
const CROUCH_SPEED = 2.0
const JUMP_VELOCITY = 4.5


@export var current_speed = 5.0
@export var mouse_sensitivity = 0.1

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))

func _physics_process(delta: float) -> void:
	
	if Input.is_action_pressed("Crouch"):
		current_speed = CROUCH_SPEED
	else:
		if Input.is_action_pressed("Sprint"):
			current_speed = SPRINT_SPEED
		else:
			current_speed = RUN_SPEED	
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("Left", "Right", "Forward", "Backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()
