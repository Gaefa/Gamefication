## camera_controller.gd -- Camera2D controller with WASD panning and scroll zoom.
## Attached to the Camera2D node in main.tscn.
extends Camera2D


## Pan speed in pixels per second.
@export var pan_speed: float = 400.0

## Zoom speed per scroll step.
@export var zoom_speed: float = 0.1

## Zoom limits.
@export var min_zoom: float = 0.3
@export var max_zoom: float = 5.0

## Map bounds (in world pixels) -- set during setup.
var _map_min: Vector2 = Vector2(-200, -200)
var _map_max: Vector2 = Vector2(4000, 4000)

## Smooth zoom target.
var _target_zoom: float = 1.5


# ------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------

func _ready() -> void:
	_target_zoom = zoom.x
	# Compute map bounds from grid size (will be updated by main.gd if needed)
	_update_map_bounds(64, 32.0)


## Update the camera bounds based on grid size and hex size.
func _update_map_bounds(grid_size: int, hex_size: float) -> void:
	var margin: float = hex_size * 4.0
	_map_min = Vector2(-margin, -margin)
	# Approximate max pixel from axial_to_pixel for max q,r
	var max_pixel: Vector2 = HexCoords.axial_to_pixel(grid_size, grid_size, hex_size)
	_map_max = max_pixel + Vector2(margin, margin)


# ------------------------------------------------------------------
# Process
# ------------------------------------------------------------------

func _process(delta: float) -> void:
	_handle_pan(delta)
	_handle_zoom_smooth(delta)
	_clamp_position()


func _handle_pan(delta: float) -> void:
	var direction := Vector2.ZERO

	if Input.is_action_pressed("camera_up"):
		direction.y -= 1.0
	if Input.is_action_pressed("camera_down"):
		direction.y += 1.0
	if Input.is_action_pressed("camera_left"):
		direction.x -= 1.0
	if Input.is_action_pressed("camera_right"):
		direction.x += 1.0

	if direction != Vector2.ZERO:
		direction = direction.normalized()
		# Pan speed is scaled inversely with zoom so it feels consistent
		var effective_speed: float = pan_speed / zoom.x
		global_position += direction * effective_speed * delta


func _handle_zoom_smooth(delta: float) -> void:
	# Lerp toward target zoom
	var current: float = zoom.x
	if absf(current - _target_zoom) > 0.001:
		var new_zoom: float = lerp(current, _target_zoom, 8.0 * delta)
		zoom = Vector2(new_zoom, new_zoom)


func _clamp_position() -> void:
	global_position.x = clampf(global_position.x, _map_min.x, _map_max.x)
	global_position.y = clampf(global_position.y, _map_min.y, _map_max.y)


# ------------------------------------------------------------------
# Input
# ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_target_zoom = clampf(_target_zoom + zoom_speed, min_zoom, max_zoom)
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_target_zoom = clampf(_target_zoom - zoom_speed, min_zoom, max_zoom)
				get_viewport().set_input_as_handled()

	# Middle mouse button drag for panning
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			global_position -= event.relative / zoom.x
			get_viewport().set_input_as_handled()
