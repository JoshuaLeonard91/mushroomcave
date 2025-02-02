extends Camera3D

@export var move_speed = 5.0  # Adjust movement speed
@export var edge_scroll_speed = 3.0  # Adjust edge scroll speed
@export var screen_edge_margin = 20  # Pixels from the edge to activate scrolling

func _process(delta):
	var direction = Vector3.ZERO

	# Keyboard movement
	if Input.is_action_pressed("move_forward"):
		direction.z -= 1
	if Input.is_action_pressed("move_backward"):
		direction.z += 1
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_right"):
		direction.x += 1

	# Normalize and apply movement
	if direction.length() > 0:
		direction = direction.normalized()
	global_translate(direction * move_speed * delta)

	# Mouse edge scrolling
	var mouse_pos = get_viewport().get_mouse_position()
	var screen_size = get_viewport().size

	if mouse_pos.x <= screen_edge_margin:
		global_translate(Vector3(-edge_scroll_speed * delta, 0, 0))
	if mouse_pos.x >= screen_size.x - screen_edge_margin:
		global_translate(Vector3(edge_scroll_speed * delta, 0, 0))
	if mouse_pos.y <= screen_edge_margin:
		global_translate(Vector3(0, 0, -edge_scroll_speed * delta))
	if mouse_pos.y >= screen_size.y - screen_edge_margin:
		global_translate(Vector3(0, 0, edge_scroll_speed * delta))
