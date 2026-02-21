extends Node2D
## Renders buildings on the hex grid as simple colored shapes with labels.

var _hex_grid: HexGrid

# Category colors for buildings
const CAT_COLORS: Dictionary = {
	"Residential": Color("e74c3c"),
	"Production":  Color("e67e22"),
	"Commercial":  Color("f1c40f"),
	"Culture":     Color("9b59b6"),
	"Infrastructure": Color("95a5a6"),
	"Advanced":    Color("1abc9c"),
}

const BUILDING_RADIUS := 20.0


func set_hex_grid(grid: HexGrid) -> void:
	_hex_grid = grid
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
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
			color = color.lerp(Color.RED, 0.5)
		elif has_issue:
			color = color.lerp(Color.YELLOW, 0.3)

		var center: Vector2 = HexCoords.axial_to_pixel(coord)

		# Draw building as a circle
		var radius: float = BUILDING_RADIUS * (1.0 + level * 0.1)
		draw_circle(center, radius, color)
		draw_arc(center, radius, 0.0, TAU, 32, Color(0.1, 0.1, 0.1, 0.6), 1.5)

		# Label: first letter + level
		var ldata: Dictionary = ContentDB.building_level_data(type_id, level)
		var stage: String = ldata.get("stage", type_id.left(3)) as String
		var label: String = stage.left(2) + str(level)
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(-10, 5),
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			30,
			10,
			Color.WHITE,
		)
