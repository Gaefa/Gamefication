extends Node2D
## Draws selection highlight, build preview overlays, and building range circles.

const PlacementRulesRef := preload("res://scripts/core/buildings/placement_rules.gd")

var _selected: Vector2i = Vector2i(-9999, -9999)
var _build_preview: String = ""
var _show_ranges: bool = false
var _show_logistics: bool = false
var _hex_grid: HexGrid


func set_hex_grid(grid: HexGrid) -> void:
	_hex_grid = grid
	queue_redraw()


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


func set_show_logistics(show: bool) -> void:
	_show_logistics = show
	queue_redraw()


func _draw() -> void:
	if _show_logistics:
		_draw_logistics_lens()
	if _show_ranges:
		_draw_pipe_lens()

	_draw_diagnostic_pins()

	# Selection highlight
	if _selected != Vector2i(-9999, -9999):
		var center: Vector2 = HexCoords.axial_to_pixel(_selected)
		draw_arc(center, HexCoords.HEX_SIZE * 0.9, 0.0, TAU, 32, Color.WHITE, 2.0)

		# Range display for selected building
		if _show_ranges:
			_draw_existing_building_range(center)

	# Build preview cursor (snaps to hex grid)
	if _build_preview != "":
		var mouse_pos: Vector2 = get_global_mouse_position()
		var coord: Vector2i = HexCoords.pixel_to_axial(mouse_pos)
		var snap_center: Vector2 = HexCoords.axial_to_pixel(coord)
		var validation: Dictionary = PlacementRulesRef.validate(coord, _build_preview, _hex_grid)
		var color := Color(0.2, 0.9, 0.25, 0.45) if (validation.get("ok", false) as bool) else Color(1.0, 0.2, 0.12, 0.5)
		_draw_preview_hex(snap_center, color)
		if _show_ranges:
			_draw_type_range(coord, _build_preview, 0)


func _draw_existing_building_range(center: Vector2) -> void:
	if _selected == Vector2i(-9999, -9999):
		return
	var bld: Dictionary = GameStateStore.get_building(_selected)
	if bld.is_empty():
		return
	var type_id: String = bld.get("type", "") as String
	var level: int = bld.get("level", 0) as int
	_draw_type_range(_selected, type_id, level)


func _draw_type_range(coord: Vector2i, type_id: String, level: int) -> void:
	var ldata: Dictionary = _merged_building_data(type_id, level)
	var desc: Dictionary = _get_range_descriptor(type_id, ldata)
	var radius: int = desc.get("radius", 0) as int
	if radius <= 0:
		return
	var range_color: Color = desc.get("color", Color(0.5, 0.8, 0.5, 0.12)) as Color
	var center: Vector2 = HexCoords.axial_to_pixel(coord)

	# Draw hex tiles in range
	var hex_pts := _hex_polygon(HexCoords.HEX_SIZE * 0.8)
	for tile: Vector2i in HexCoords.disk(coord, radius):
		if tile == coord:
			continue
		var tile_center: Vector2 = HexCoords.axial_to_pixel(tile)
		var pts := PackedVector2Array()
		for p: Vector2 in hex_pts:
			pts.append(tile_center + p)
		draw_colored_polygon(pts, range_color)

	# Draw range border circle (account for Y-squish)
	var pixel_radius: float = HexCoords.HEX_SIZE * 1.73 * float(radius) * HexCoords.ISO_Y
	draw_arc(center, pixel_radius, 0.0, TAU, 48, range_color * 3.0, 1.5)


func _draw_logistics_lens() -> void:
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		var type_id: String = bld.get("type", "") as String
		var def: Dictionary = ContentDB.get_building_def(type_id)
		if _is_road_building(type_id, def):
			_draw_hex_fill(coord, Color(0.2, 0.95, 0.35, 0.28), Color(0.55, 1.0, 0.65, 0.8))
		elif _building_needs_road(def):
			var connected := _has_road_neighbor(coord)
			var fill_color := Color(0.25, 0.6, 1.0, 0.22) if connected else Color(1.0, 0.12, 0.08, 0.36)
			var border_color := Color(0.45, 0.85, 1.0, 0.8) if connected else Color(1.0, 0.35, 0.25, 0.95)
			_draw_hex_fill(coord, fill_color, border_color)


func _draw_pipe_lens() -> void:
	if _selected == Vector2i(-9999, -9999):
		return
	var bld: Dictionary = GameStateStore.get_building(_selected)
	if bld.is_empty():
		return
	var type_id: String = bld.get("type", "") as String
	var def: Dictionary = ContentDB.get_building_def(type_id)
	var level: int = bld.get("level", 0) as int
	var radius: int = _water_radius_for(type_id, def, level)
	if radius > 0:
		_draw_pipe_source_network(_selected, radius)
		return
	var data: Dictionary = _merged_building_data(type_id, level)
	if _building_uses_water(data):
		var source_coord: Vector2i = _nearest_covering_water_source(_selected)
		if source_coord != Vector2i(-9999, -9999):
			_draw_pipe_segment(HexCoords.axial_to_pixel(source_coord), HexCoords.axial_to_pixel(_selected), Color(0.42, 0.8, 1.0, 0.75))


func _draw_pipe_source_network(source_coord: Vector2i, radius: int) -> void:
	var source_center: Vector2 = HexCoords.axial_to_pixel(source_coord)
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		if coord == source_coord:
			continue
		if HexCoords.distance(source_coord, coord) > radius:
			continue
		var bld: Dictionary = GameStateStore.get_building(coord)
		var type_id: String = bld.get("type", "") as String
		var data: Dictionary = _merged_building_data(type_id, bld.get("level", 0) as int)
		if not _building_uses_water(data):
			continue
		_draw_pipe_segment(source_center, HexCoords.axial_to_pixel(coord), Color(0.42, 0.8, 1.0, 0.75))


func _draw_pipe_segment(start: Vector2, end_point: Vector2, dash_color: Color) -> void:
	draw_line(start, end_point, Color(0.08, 0.28, 0.44, 0.28), 4.0)
	var segment: Vector2 = end_point - start
	var length: float = segment.length()
	if length <= 8.0:
		return
	var dir: Vector2 = segment / length
	var cursor: float = 5.0
	while cursor < length - 3.0:
		var dash_start: Vector2 = start + dir * cursor
		var dash_end: Vector2 = start + dir * minf(cursor + 5.0, length - 2.0)
		draw_line(dash_start, dash_end, dash_color, 2.0)
		cursor += 10.0
	draw_circle(start, 2.5, Color(0.74, 0.94, 1.0, 0.85))
	draw_circle(end_point, 2.0, Color(0.74, 0.94, 1.0, 0.75))


func _draw_diagnostic_pins() -> void:
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		var diag: Dictionary = _primary_diagnostic(coord, bld)
		if diag.is_empty():
			continue
		_draw_diagnostic_pin(coord, diag)


func _draw_hex_fill(coord: Vector2i, fill_color: Color, border_color: Color) -> void:
	var center: Vector2 = HexCoords.axial_to_pixel(coord)
	var pts := PackedVector2Array()
	for p: Vector2 in _hex_polygon(HexCoords.HEX_SIZE * 0.86):
		pts.append(center + p)
	draw_colored_polygon(pts, fill_color)
	draw_polyline(pts, border_color, 2.0)


func _draw_diagnostic_pin(coord: Vector2i, diag: Dictionary) -> void:
	var center: Vector2 = HexCoords.axial_to_pixel(coord) + Vector2(14, -28)
	var color: Color = diag.get("color", Color(1.0, 0.18, 0.12, 1.0)) as Color
	draw_circle(center, 9.0, color)
	draw_arc(center, 9.5, 0.0, TAU, 24, Color.WHITE, 1.2)
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-4, 5),
		diag.get("icon", "!") as String,
		HORIZONTAL_ALIGNMENT_LEFT,
		12,
		12,
		Color.WHITE
	)


func _primary_diagnostic(coord: Vector2i, bld: Dictionary) -> Dictionary:
	var type_id: String = bld.get("type", "") as String
	var def: Dictionary = ContentDB.get_building_def(type_id)
	if bld.get("damaged", false) as bool:
		return {"icon": "!", "label": "repair", "color": Color(1.0, 0.18, 0.12, 1.0)}
	if bld.get("has_issue", false) as bool:
		return {"icon": "!", "label": "issue", "color": Color(1.0, 0.75, 0.15, 1.0)}
	if _building_needs_road(def) and not _has_road_neighbor(coord):
		return {"icon": "R", "label": "road", "color": Color(1.0, 0.2, 0.1, 1.0)}

	var data: Dictionary = _merged_building_data(type_id, bld.get("level", 0) as int)
	var consumes: Dictionary = data.get("consumes", {})
	if consumes.has("res_water_stockpile") or consumes.has("water_res"):
		if not _is_water_covered(coord):
			return {"icon": "W", "label": "water", "color": Color(0.15, 0.55, 1.0, 1.0)}
		var water_stock: float = GameStateStore.get_resource("res_water_stockpile")
		if water_stock <= 0.0:
			return {"icon": "W", "label": "stock", "color": Color(0.05, 0.35, 0.95, 1.0)}
	return {}


func _merged_building_data(type_id: String, level: int) -> Dictionary:
	var def: Dictionary = ContentDB.get_building_def(type_id)
	var merged: Dictionary = def.duplicate(true)
	var ldata: Dictionary = ContentDB.building_level_data(type_id, level)
	for key: String in ldata:
		merged[key] = ldata[key]
	return merged


func _building_needs_road(def: Dictionary) -> bool:
	if def.get("requires_road", false) as bool:
		return true
	if def.get("requiresRoad", false) as bool:
		return true
	var tags: Array = def.get("tags", []) as Array
	return tags.has("needs_road")


func _is_road_building(type_id: String, def: Dictionary) -> bool:
	if type_id == "road" or type_id == "bld_road":
		return true
	var tags: Array = def.get("tags", []) as Array
	return tags.has("road")


func _has_road_neighbor(coord: Vector2i) -> bool:
	for nb: Vector2i in HexCoords.neighbors_of(coord):
		var bld: Dictionary = GameStateStore.get_building(nb)
		if bld.is_empty():
			continue
		var type_id: String = bld.get("type", "") as String
		if _is_road_building(type_id, ContentDB.get_building_def(type_id)):
			return true
	return false


func _is_water_covered(coord: Vector2i) -> bool:
	for source_coord: Vector2i in GameStateStore.get_all_building_coords():
		var source: Dictionary = GameStateStore.get_building(source_coord)
		var type_id: String = source.get("type", "") as String
		var def: Dictionary = ContentDB.get_building_def(type_id)
		var radius: int = _water_radius_for(type_id, def, source.get("level", 0) as int)
		if radius > 0 and HexCoords.distance(source_coord, coord) <= radius:
			return true
	return false


func _nearest_covering_water_source(coord: Vector2i) -> Vector2i:
	var best_coord := Vector2i(-9999, -9999)
	var best_distance: int = 1_000_000
	for source_coord: Vector2i in GameStateStore.get_all_building_coords():
		var source: Dictionary = GameStateStore.get_building(source_coord)
		var type_id: String = source.get("type", "") as String
		var def: Dictionary = ContentDB.get_building_def(type_id)
		var radius: int = _water_radius_for(type_id, def, source.get("level", 0) as int)
		if radius <= 0:
			continue
		var dist: int = HexCoords.distance(source_coord, coord)
		if dist > radius:
			continue
		if dist < best_distance:
			best_distance = dist
			best_coord = source_coord
	return best_coord


func _building_uses_water(data: Dictionary) -> bool:
	var consumes: Dictionary = data.get("consumes", {})
	return consumes.has("res_water_stockpile") or consumes.has("water_res")


func _water_radius_for(type_id: String, def: Dictionary, level: int) -> int:
	var data: Dictionary = _merged_building_data(type_id, level)
	var synergy: Dictionary = data.get("synergy", {})
	if synergy.has("water_radius"):
		return synergy["water_radius"] as int
	if data.has("water_radius"):
		return data["water_radius"] as int
	var tags: Array = def.get("tags", []) as Array
	if tags.has("water_source") or type_id == "water_tower" or type_id == "bld_well_pump":
		return 4
	return 0


## Read range data exclusively from synergy — no hardcoded radius arrays.
static func _get_range_descriptor(_type_id: String, ldata: Dictionary) -> Dictionary:
	var synergy: Dictionary = ldata.get("synergy", {})
	if synergy.has("water_radius"):
		return {"radius": synergy["water_radius"] as int, "color": Color(0.3, 0.5, 1.0, 0.12)}
	if synergy.has("powered_boost") and synergy.has("radius"):
		return {"radius": synergy["radius"] as int, "color": Color(1.0, 0.9, 0.2, 0.12)}
	if synergy.has("happiness_aura") and synergy.has("radius"):
		return {"radius": synergy["radius"] as int, "color": Color(0.3, 0.9, 0.3, 0.12)}
	if synergy.has("upgrade_discount") and synergy.has("radius"):
		return {"radius": synergy["radius"] as int, "color": Color(0.8, 0.6, 0.2, 0.12)}
	if synergy.has("radius"):
		return {"radius": synergy["radius"] as int, "color": Color(0.5, 0.8, 0.5, 0.12)}
	var tags: Array = ldata.get("tags", []) as Array
	if tags.has("water_source"):
		return {"radius": 4, "color": Color(0.3, 0.5, 1.0, 0.12)}
	return {"radius": 0, "color": Color.TRANSPARENT}


func _hex_polygon(hex_size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in 6:
		var angle := TAU / 6.0 * float(i)
		pts.append(Vector2(cos(angle), sin(angle) * HexCoords.ISO_Y) * hex_size)
	pts.append(pts[0])
	return pts


func _draw_preview_hex(center: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for p: Vector2 in _hex_polygon(HexCoords.HEX_SIZE * 0.84):
		pts.append(center + p)
	draw_colored_polygon(pts, color)
	draw_polyline(pts, color.lerp(Color.WHITE, 0.35), 2.0)


func _process(_delta: float) -> void:
	if _build_preview != "" or _show_ranges or _show_logistics:
		queue_redraw()
