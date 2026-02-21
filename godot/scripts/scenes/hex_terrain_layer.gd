extends Node2D
## Renders hex terrain as colored polygons.

var _hex_grid: HexGrid
var _drawn: bool = false

# Terrain colors (matching terrain.json)
const COLORS: Dictionary = {
	0: Color("6ab04c"),  # grass
	1: Color("4a90d9"),  # water
	2: Color("d4b545"),  # sand
	3: Color("8b7355"),  # hill
	4: Color("2d8a4e"),  # forest
	5: Color("7c7c7c"),  # rock
}


func render_terrain(grid: HexGrid) -> void:
	_hex_grid = grid
	_drawn = false
	queue_redraw()


func _draw() -> void:
	if _hex_grid == null or _drawn:
		return
	_drawn = true

	var hex_points := _hex_polygon()
	for coord: Vector2i in _hex_grid.all_coords():
		var terrain_id: int = _hex_grid.get_terrain_at(coord)
		var color: Color = COLORS.get(terrain_id, Color.GRAY)
		var center: Vector2 = HexCoords.axial_to_pixel(coord)
		var translated_pts: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in hex_points:
			translated_pts.append(center + p)
		draw_colored_polygon(translated_pts, color)
		# Outline
		draw_polyline(translated_pts, Color(0.2, 0.2, 0.2, 0.3), 1.0)


func _hex_polygon() -> PackedVector2Array:
	## Flat-top hex vertices.
	var pts := PackedVector2Array()
	for i: int in 6:
		var angle := TAU / 6.0 * float(i)
		pts.append(Vector2(cos(angle), sin(angle)) * HexCoords.HEX_SIZE)
	pts.append(pts[0])  # close the polygon for polyline
	return pts
