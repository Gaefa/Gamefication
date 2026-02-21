extends Node2D
## Renders buildings on the hex grid as hex-shaped tiles with icons.

var _hex_grid: HexGrid

# Category colors
const CAT_COLORS: Dictionary = {
	"Residential":     Color("c0392b"),
	"Production":      Color("d35400"),
	"Commercial":      Color("f39c12"),
	"Culture":         Color("8e44ad"),
	"Infrastructure":  Color("7f8c8d"),
	"Advanced":        Color("16a085"),
}

# Type-specific short icons
const TYPE_ICONS: Dictionary = {
	"hut": "H", "apartment": "A",
	"farm": "F", "lumber": "L", "quarry": "Q", "workshop": "W", "foundry": "S",
	"market": "$", "bank": "B",
	"park": "P", "library": "Li", "theater": "T",
	"power": "E", "water_tower": "~", "road": "=", "warehouse": "W",
	"research": "R", "wonder": "!",
}


func set_hex_grid(grid: HexGrid) -> void:
	_hex_grid = grid
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	var hex_fill := _hex_polygon(HexCoords.HEX_SIZE * 0.82)
	var hex_border := _hex_polygon(HexCoords.HEX_SIZE * 0.85)

	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		var type_id: String = bld.get("type", "") as String
		var level: int = bld.get("level", 0) as int
		var damaged: bool = bld.get("damaged", false) as bool
		var has_issue: bool = bld.get("has_issue", false) as bool

		var def: Dictionary = ContentDB.get_building_def(type_id)
		var cat: String = def.get("category", "Infrastructure") as String
		var color: Color = CAT_COLORS.get(cat, Color.WHITE)

		if damaged:
			color = color.lerp(Color.RED, 0.6)
		elif has_issue:
			color = color.lerp(Color.YELLOW, 0.4)
		# Lighten slightly per level
		color = color.lerp(Color.WHITE, level * 0.05)

		var center: Vector2 = HexCoords.axial_to_pixel(coord)

		# Hex fill
		var fill_pts: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in hex_fill:
			fill_pts.append(center + p)
		draw_colored_polygon(fill_pts, color)

		# Border
		var border_pts: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in hex_border:
			border_pts.append(center + p)
		var border_color := Color.RED if damaged else Color(0.1, 0.1, 0.1, 0.7)
		draw_polyline(border_pts, border_color, 2.0)

		# Icon letter
		var icon: String = TYPE_ICONS.get(type_id, "?")
		draw_string(
			ThemeDB.fallback_font, center + Vector2(-6, -1),
			icon, HORIZONTAL_ALIGNMENT_CENTER, 20, 14, Color.WHITE
		)

		# Stage name (small, below icon)
		var ldata: Dictionary = ContentDB.building_level_data(type_id, level)
		var stage: String = ldata.get("stage", "") as String
		if stage != "":
			draw_string(
				ThemeDB.fallback_font, center + Vector2(-14, 12),
				stage.left(5), HORIZONTAL_ALIGNMENT_CENTER, 30, 8,
				Color(1, 1, 1, 0.7)
			)

		# Damage/issue indicator
		if damaged:
			draw_string(ThemeDB.fallback_font, center + Vector2(8, -10), "X", HORIZONTAL_ALIGNMENT_CENTER, 12, 10, Color.RED)
		elif has_issue:
			draw_string(ThemeDB.fallback_font, center + Vector2(8, -10), "!", HORIZONTAL_ALIGNMENT_CENTER, 12, 10, Color.YELLOW)


func _hex_polygon(hex_size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in 6:
		var angle := TAU / 6.0 * float(i)
		pts.append(Vector2(cos(angle), sin(angle)) * hex_size)
	pts.append(pts[0])
	return pts
