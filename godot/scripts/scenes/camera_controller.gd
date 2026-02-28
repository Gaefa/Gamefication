extends Camera2D
## WASD/Arrow camera panning + mouse wheel zoom + middle-button drag.

const PAN_SPEED := 400.0
const ZOOM_MIN := 0.3
const ZOOM_MAX := 5.0
const ZOOM_STEP := 0.15

var _dragging := false
var _drag_start := Vector2.ZERO


func _process(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_action_pressed("camera_up"):
		move.y -= 1.0
	if Input.is_action_pressed("camera_down"):
		move.y += 1.0
	if Input.is_action_pressed("camera_left"):
		move.x -= 1.0
	if Input.is_action_pressed("camera_right"):
		move.x += 1.0
	if move != Vector2.ZERO:
		global_position += move.normalized() * PAN_SPEED * delta / zoom.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom *= (1.0 + ZOOM_STEP)
			zoom = zoom.clamp(Vector2(ZOOM_MIN, ZOOM_MIN), Vector2(ZOOM_MAX, ZOOM_MAX))
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom *= (1.0 - ZOOM_STEP)
			zoom = zoom.clamp(Vector2(ZOOM_MIN, ZOOM_MIN), Vector2(ZOOM_MAX, ZOOM_MAX))
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
			_drag_start = mb.global_position

	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		global_position -= mm.relative / zoom
