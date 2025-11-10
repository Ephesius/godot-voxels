class_name FlyingCamera
extends Camera3D

# Movement settings
var base_speed: float = 10.0  # Normal movement speed
var sprint_speed: float = 30.0  # Speed when holding Shift
var slow_speed: float = 3.0  # Speed when holding Ctrl

# Mouse look settings
var mouse_sensitivity: float = 0.003  # How fast the camera rotates with mouse movement
var pitch: float = 0.0  # Up/down rotation (stored separately to clamp it)

# Internal state
var mouse_captured: bool = false

func _ready() -> void:
	# Make this the active camera
	current = true

	# Capture the mouse cursor
	_capture_mouse()

func _input(event: InputEvent) -> void:
	# Handle mouse look
	if event is InputEventMouseMotion and mouse_captured:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion

		# Rotate camera based on mouse movement
		# Horizontal rotation (yaw) - rotate around Y axis
		rotate_y(-mouse_motion.relative.x * mouse_sensitivity)

		# Vertical rotation (pitch) - rotate around local X axis
		pitch -= mouse_motion.relative.y * mouse_sensitivity
		# Clamp pitch to prevent camera flipping upside down
		pitch = clamp(pitch, -PI / 2, PI / 2)
		rotation.x = pitch

	# Toggle mouse capture with Escape
	if event.is_action_pressed("ui_cancel"):
		if mouse_captured:
			_release_mouse()
		else:
			_capture_mouse()

func _process(delta: float) -> void:
	# Don't move if mouse isn't captured (player is in menu/paused)
	if not mouse_captured:
		return

	# Determine current speed based on modifiers
	var current_speed: float = base_speed
	if Input.is_key_pressed(KEY_SHIFT):
		current_speed = sprint_speed
	elif Input.is_key_pressed(KEY_CTRL):
		current_speed = slow_speed

	# Get input direction (WASD)
	var input_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# Calculate movement direction relative to camera orientation
	# Forward/backward movement (W/S)
	var forward: Vector3 = -global_transform.basis.z * input_dir.y
	# Left/right movement (A/D)
	var right: Vector3 = global_transform.basis.x * input_dir.x

	# Vertical movement (Space/Shift for up, Ctrl for down)
	var vertical: Vector3 = Vector3.ZERO
	if Input.is_key_pressed(KEY_SPACE):
		vertical = Vector3.UP
	# Note: We already use Ctrl for slow mode, so let's use E for down
	if Input.is_key_pressed(KEY_E):
		vertical = Vector3.DOWN

	# Combine all movement directions
	var movement: Vector3 = (forward + right + vertical).normalized()

	# Apply movement
	global_position += movement * current_speed * delta

func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_captured = true

func _release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_captured = false
