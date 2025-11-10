class_name Player
extends CharacterBody3D

## First-person player controller with ground and flying modes
##
## Controls:
## - WASD: Movement
## - Space: Jump (ground mode) / Move up (flying mode)
## - C: Move down (flying mode only)
## - Shift: Sprint
## - Ctrl: Slow movement
## - F: Toggle flying mode
## - Escape: Toggle mouse capture
## - Mouse: Look around

# Player dimensions (in meters/blocks)
const PLAYER_HEIGHT: float = 2.0  # 2 blocks tall
const PLAYER_WIDTH: float = 0.75  # 0.75 blocks wide (radius = 0.375)

# Ground mode parameters
@export var walk_speed: float = 5.0  # Blocks per second
@export var sprint_multiplier: float = 2.0
@export var slow_multiplier: float = 0.5
@export var jump_height: float = 1.5  # Blocks
@export var gravity: float = 20.0  # Blocks per second squared

# Flying mode parameters
@export var fly_speed: float = 10.0  # Blocks per second
@export var fly_sprint_multiplier: float = 3.0

# Mouse look parameters
@export var mouse_sensitivity: float = 0.002
@export var max_pitch: float = 89.0  # Degrees

# State
var is_flying: bool = false
var camera: Camera3D
var pitch: float = 0.0  # Up/down rotation (in radians)

func _ready() -> void:
	# Create and setup camera
	camera = Camera3D.new()
	camera.position = Vector3(0, PLAYER_HEIGHT * 0.85, 0)  # Eye level (85% of height)
	add_child(camera)

	# Create collision shape (capsule)
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.height = PLAYER_HEIGHT
	capsule.radius = PLAYER_WIDTH / 2.0  # Radius is half the width
	collision_shape.shape = capsule
	collision_shape.position = Vector3(0, PLAYER_HEIGHT / 2.0, 0)  # Center the capsule
	add_child(collision_shape)

	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Yaw (left/right) - rotate the entire player body
		rotate_y(-event.relative.x * mouse_sensitivity)

		# Pitch (up/down) - rotate only the camera
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, -deg_to_rad(max_pitch), deg_to_rad(max_pitch))
		camera.rotation.x = pitch

	# Toggle mouse capture
	if event.is_action_pressed("ui_cancel"):  # Escape key
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Toggle flying mode
	if event.is_action_pressed("toggle_fly"):  # F key
		is_flying = !is_flying
		# Reset vertical velocity when switching modes
		if is_flying:
			velocity.y = 0

func _physics_process(delta: float) -> void:
	if is_flying:
		_process_flying_movement(delta)
	else:
		_process_ground_movement(delta)

## Ground mode: Walking with gravity and collision
func _process_ground_movement(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():  # Space key
		# Calculate jump velocity from desired height: v = sqrt(2 * g * h)
		velocity.y = sqrt(2.0 * gravity * jump_height)

	# Get input direction
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	# Calculate movement speed
	var speed: float = walk_speed
	if Input.is_action_pressed("sprint"):  # Shift
		speed *= sprint_multiplier
	elif Input.is_action_pressed("slow"):  # Ctrl
		speed *= slow_multiplier

	# Calculate movement direction relative to player rotation
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Apply horizontal movement
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		# Apply friction when no input
		velocity.x = move_toward(velocity.x, 0, speed * delta * 5)
		velocity.z = move_toward(velocity.z, 0, speed * delta * 5)

	# Move with collision
	move_and_slide()

## Flying mode: Free movement with no collision
func _process_flying_movement(delta: float) -> void:
	# Get input direction (including vertical)
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var vertical_input: float = 0.0

	if Input.is_action_pressed("ui_accept"):  # Space - move up
		vertical_input += 1.0
	if Input.is_action_pressed("fly_down"):  # C - move down
		vertical_input -= 1.0

	# Calculate movement speed
	var speed: float = fly_speed
	if Input.is_action_pressed("sprint"):  # Shift
		speed *= fly_sprint_multiplier
	elif Input.is_action_pressed("slow"):  # Ctrl
		speed *= slow_multiplier

	# Calculate movement direction relative to player rotation (horizontal) and world space (vertical)
	var direction: Vector3 = Vector3.ZERO
	if input_dir.length() > 0:
		direction += transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	direction.y += vertical_input
	direction = direction.normalized()

	# Apply movement (direct velocity control, no physics)
	if direction.length() > 0:
		velocity = direction * speed
	else:
		velocity = Vector3.ZERO

	# Move without collision in flying mode
	position += velocity * delta

## Get the camera for external access
func get_camera() -> Camera3D:
	return camera
