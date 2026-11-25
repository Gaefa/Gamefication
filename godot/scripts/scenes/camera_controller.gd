extends Camera2D
## WASD/Arrow camera panning + mouse wheel zoom + middle-button drag.
## On touch (the Android build) one finger drags the map and two fingers pinch to zoom.

const PAN_SPEED := 400.0
const ZOOM_MIN := 0.3
const ZOOM_MAX := 5.0
const ZOOM_STEP := 0.15

var _dragging := false
var _drag_start := Vector2.ZERO
var _fingers: Dictionary = {}  # finger index → where it is on the screen


## Every finger event, the ones a panel takes too: a release lost to a panel would leave a
## ghost finger, and the next one-finger drag would zoom.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_fingers[st.index] = st.position
		else:
			_fingers.erase(st.index)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _fingers.has(sd.index):
			_fingers[sd.index] = sd.position


func _process(delta: float) -> void:
	# A release over a UI panel or outside the window never reaches _unhandled_input.
	if _dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		_dragging = false
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

	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _fingers.size() >= 2:
			_pinch(sd)
		elif sd.index == 0:
			global_position -= sd.relative / zoom
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		zoom = (zoom * mg.factor).clamp(Vector2(ZOOM_MIN, ZOOM_MIN), Vector2(ZOOM_MAX, ZOOM_MAX))


## Android sends no magnify gesture unless a project setting asks for it, so the pinch is
## read off the fingers: the zoom follows the distance between the moved one and the other.
func _pinch(sd: InputEventScreenDrag) -> void:
	for index: int in _fingers:
		if index == sd.index:
			continue
		var other: Vector2 = _fingers[index]
		var before: float = (sd.position - sd.relative - other).length()
		if before > 8.0:
			zoom = (zoom * ((sd.position - other).length() / before)).clamp(Vector2(ZOOM_MIN, ZOOM_MIN), Vector2(ZOOM_MAX, ZOOM_MAX))
		return
