extends Camera3D

@export var move_speed: float = 10.0
@export var edge_scroll_speed: float = 5.0
@export var edge_threshold: int = 10  # Pixels from edge for scrolling
@export var zoom_speed: float = 2.0
@export var min_zoom: float = 20.0  # Closest zoom-in limit
@export var max_zoom: float = 90.0  # Furthest zoom-out limit
@export var zoom_smoothness: float = 5.0  # Smoother zooming effect

@export var default_fov: float = 75.0  # Default field of view
@export var fullscreen_fov: float = 90.0  # Wider FOV for fullscreen

# Define cave boundaries (adjust these to fit your level size)
@export var min_x: float = -100.0
@export var max_x: float = 100.0
@export var min_z: float = -100.0
@export var max_z: float = 100.0

var screen_size: Vector2  # Window size
var target_fov: float  # For smooth zooming

func _ready():
	update_screen_size()
	set_fov_based_on_mode()
	get_window().connect("size_changed", Callable(self, "_on_window_resized"))
	target_fov = fov  # Set initial FOV

func _on_window_resized():
	update_screen_size()
	set_fov_based_on_mode()

func update_screen_size():
	screen_size = get_viewport().get_visible_rect().size  # Get new window size

func set_fov_based_on_mode():
	if get_window().mode == Window.MODE_FULLSCREEN:
		target_fov = fullscreen_fov  # Wider view in fullscreen
	else:
		target_fov = default_fov  # Normal FOV in windowed mode

func _process(delta):
	var velocity = Vector3.ZERO
	var mouse_pos = get_viewport().get_mouse_position()

	# Ensure the window is focused to allow movement
	if not get_window().has_focus():
		return

	# WASD Movement
	if Input.is_action_pressed("move_forward"):  # W
		velocity.z -= move_speed * delta
	if Input.is_action_pressed("move_backward"):  # S
		velocity.z += move_speed * delta
	if Input.is_action_pressed("move_left"):  # A
		velocity.x -= move_speed * delta
	if Input.is_action_pressed("move_right"):  # D
		velocity.x += move_speed * delta

	# Mouse Edge Scrolling (adjusts dynamically)
	if mouse_pos.x <= edge_threshold:
		velocity.x -= edge_scroll_speed * delta
	elif mouse_pos.x >= screen_size.x - edge_threshold:
		velocity.x += edge_scroll_speed * delta

	if mouse_pos.y <= edge_threshold:
		velocity.z -= edge_scroll_speed * delta
	elif mouse_pos.y >= screen_size.y - edge_threshold:
		velocity.z += edge_scroll_speed * delta

	# Zoom In & Out
	if Input.is_action_just_pressed("zoom_in"):
		target_fov = max(min_zoom, target_fov - zoom_speed)
	elif Input.is_action_just_pressed("zoom_out"):
		target_fov = min(max_zoom, target_fov + zoom_speed)

	# Smooth Zoom Transition
	fov = lerp(fov, target_fov, zoom_smoothness * delta)

	# Apply movement
	position += velocity

	# Clamp position to stay inside cave boundaries
	position.x = clamp(position.x, min_x, max_x)
	position.z = clamp(position.z, min_z, max_z)
