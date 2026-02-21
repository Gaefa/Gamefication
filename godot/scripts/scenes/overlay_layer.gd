extends Node2D
## Draws selection highlight and build preview overlays.

var _selected: Vector2i = Vector2i(-9999, -9999)
var _build_preview: String = ""


func _ready() -> void:
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.build_mode_changed.connect(_on_build_mode_changed)


func _on_selection_changed(coord: Vector2i) -> void:
	_selected = coord
	queue_redraw()


func _on_build_mode_changed(type_id: String) -> void:
	_build_preview = type_id
	queue_redraw()


func _draw() -> void:
	# Selection highlight
	if _selected != Vector2i(-9999, -9999):
		var center: Vector2 = HexCoords.axial_to_pixel(_selected)
		draw_arc(center, HexCoords.HEX_SIZE * 0.9, 0.0, TAU, 32, Color.WHITE, 2.0)

	# Build preview cursor
	if _build_preview != "":
		var mouse_pos: Vector2 = get_global_mouse_position()
		var coord: Vector2i = HexCoords.pixel_to_axial(mouse_pos)
		var center: Vector2 = HexCoords.axial_to_pixel(coord)
		var color := Color(0.2, 0.8, 0.2, 0.4)
		draw_circle(center, HexCoords.HEX_SIZE * 0.7, color)


func _process(_delta: float) -> void:
	if _build_preview != "":
		queue_redraw()
