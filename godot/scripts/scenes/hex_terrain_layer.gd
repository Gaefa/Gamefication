extends Node2D
## Renders hex terrain as colored polygons.
## Redraws when viewport resizes or camera moves.

var _hex_grid: HexGrid
var _colors: Dictionary = {}  # terrain_id → Color, from terrain.json (Rust Pit palette)

const PIPE_COLOR := Color("7a4a2e")
const PIPE_JOINT := Color("4e2f1c")


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_resized)


func render_terrain(grid: HexGrid) -> void:
	_hex_grid = grid
	queue_redraw()


func _on_viewport_resized() -> void:
	queue_redraw()


func _draw() -> void:
	if _hex_grid == null:
		return

	var hex_points := _hex_polygon()
	for coord: Vector2i in _hex_grid.all_coords():
		var terrain_id: int = _hex_grid.get_terrain_at(coord)
		var color: Color = _terrain_color(terrain_id)
		var center: Vector2 = HexCoords.axial_to_pixel(coord)
		var translated_pts: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in hex_points:
			translated_pts.append(center + p)
		draw_colored_polygon(translated_pts, color)
		# Outline — faint, warm, so the grid reads as cracked ground rather than a chessboard.
		draw_polyline(translated_pts, Color(0.25, 0.18, 0.1, 0.22), 1.0)
	_draw_old_pipes()


func _terrain_color(terrain_id: int) -> Color:
	if not _colors.has(terrain_id):
		var def: Dictionary = ContentDB.get_terrain_def(terrain_id)
		_colors[terrain_id] = Color(def.get("color", "7c7c7c") as String) if not def.is_empty() else Color.GRAY
	return _colors[terrain_id] as Color


## Traces of the old water operator (GDD §3.1 «ржавые трубы»): the Company's dead pipeline,
## laid out once at bootstrap in world().decor.pipes and drawn as a rusty segmented line.
func _draw_old_pipes() -> void:
	var decor: Dictionary = GameStateStore.world().get("decor", {}) as Dictionary
	var pipes: Array = decor.get("pipes", []) as Array
	for run: Variant in pipes:
		var pts: PackedVector2Array = PackedVector2Array()
		for cell: Variant in run as Array:
			var arr: Array = cell as Array
			pts.append(HexCoords.axial_to_pixel(Vector2i(int(arr[0]), int(arr[1]))))
		if pts.size() < 2:
			continue
		draw_polyline(pts, PIPE_JOINT, 6.0)
		draw_polyline(pts, PIPE_COLOR, 3.5)
		for p: Vector2 in pts:
			draw_circle(p, 3.5, PIPE_JOINT)


func _hex_polygon() -> PackedVector2Array:
	## Flat-top hex vertices with isometric Y-squish.
	var pts := PackedVector2Array()
	for i: int in 6:
		var angle := TAU / 6.0 * float(i)
		pts.append(Vector2(cos(angle), sin(angle) * HexCoords.ISO_Y) * HexCoords.HEX_SIZE)
	pts.append(pts[0])  # close the polygon for polyline
	return pts
