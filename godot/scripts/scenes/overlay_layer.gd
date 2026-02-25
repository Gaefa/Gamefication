extends Node2D
## Draws selection highlight, build preview overlays, and building range circles.

var _selected: Vector2i = Vector2i(-9999, -9999)
var _build_preview: String = ""
var _show_ranges: bool = false


func _ready() -> void:
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.build_mode_changed.connect(_on_build_mode_changed)


func _on_selection_changed(coord: Vector2i) -> void:
	_selected = coord
	queue_redraw()


func _on_build_mode_changed(type_id: String) -> void:
	_build_preview = type_id
	queue_redraw()


func set_show_ranges(show: bool, coord: Vector2i) -> void:
	_show_ranges = show
	_selected = coord
	queue_redraw()


func _draw() -> void:
	# Selection highlight
	if _selected != Vector2i(-9999, -9999):
		var center: Vector2 = HexCoords.axial_to_pixel(_selected)
		draw_arc(center, HexCoords.HEX_SIZE * 0.9, 0.0, TAU, 32, Color.WHITE, 2.0)

		# Range display for selected building
		if _show_ranges:
			_draw_building_range(center)

	# Build preview cursor (snaps to hex grid)
	if _build_preview != "":
		var mouse_pos: Vector2 = get_global_mouse_position()
		# Account for parent (World) scale
		var parent_node: Node2D = get_parent() as Node2D
		if parent_node:
			mouse_pos /= parent_node.scale
		var coord: Vector2i = HexCoords.pixel_to_axial(mouse_pos)
		var snap_center: Vector2 = HexCoords.axial_to_pixel(coord)
		var color := Color(0.2, 0.8, 0.2, 0.4)
		draw_circle(snap_center, HexCoords.HEX_SIZE * 0.7, color)


func _draw_building_range(center: Vector2) -> void:
	if _selected == Vector2i(-9999, -9999):
		return
	var bld: Dictionary = GameStateStore.get_building(_selected)
	if bld.is_empty():
		return
	var type_id: String = bld.get("type", "") as String
	var level: int = bld.get("level", 0) as int
	var ldata: Dictionary = ContentDB.building_level_data(type_id, level)

	var radius: int = 0
	var range_color := Color(0.5, 0.8, 1.0, 0.15)

	match type_id:
		"water_tower":
			var water_radii: Array[int] = [4, 6, 8, 10, 14]
			radius = water_radii[mini(level, water_radii.size() - 1)]
			range_color = Color(0.3, 0.5, 1.0, 0.12)
		"power":
			var power_radii: Array[int] = [6, 7, 8, 9, 10]
			radius = power_radii[mini(level, power_radii.size() - 1)]
			range_color = Color(1.0, 0.9, 0.2, 0.12)
		"park":
			var park_radii: Array[int] = [0, 0, 4, 5, 6]
			radius = park_radii[mini(level, park_radii.size() - 1)]
			range_color = Color(0.3, 0.9, 0.3, 0.12)
		"workshop":
			if level >= 1:
				radius = 3
				range_color = Color(0.8, 0.6, 0.2, 0.12)

	# Also check synergy data for radius
	var synergy: Dictionary = ldata.get("synergy", {})
	if synergy.has("radius") and radius == 0:
		radius = synergy.get("radius", 0) as int
		range_color = Color(0.5, 0.8, 0.5, 0.12)

	if radius <= 0:
		return

	# Draw hex tiles in range
	var hex_pts := _hex_polygon(HexCoords.HEX_SIZE * 0.8)
	for tile: Vector2i in HexCoords.disk(_selected, radius):
		if tile == _selected:
			continue
		var tile_center: Vector2 = HexCoords.axial_to_pixel(tile)
		var pts := PackedVector2Array()
		for p: Vector2 in hex_pts:
			pts.append(tile_center + p)
		draw_colored_polygon(pts, range_color)

	# Draw range border circle
	var pixel_radius: float = HexCoords.HEX_SIZE * 1.73 * float(radius)
	draw_arc(center, pixel_radius, 0.0, TAU, 48, range_color * 3.0, 1.5)


func _hex_polygon(hex_size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in 6:
		var angle := TAU / 6.0 * float(i)
		pts.append(Vector2(cos(angle), sin(angle)) * hex_size)
	pts.append(pts[0])
	return pts


func _process(_delta: float) -> void:
	if _build_preview != "" or _show_ranges:
		queue_redraw()
