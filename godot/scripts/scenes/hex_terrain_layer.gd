extends Node2D
## Renders seasonal terrain textures, with colored polygons for missing tiles.
## Draws non-blocking props above terrain; redraws on season and building changes.

var _hex_grid: HexGrid
var _colors: Dictionary = {}  # terrain_id → Color, from terrain.json (Rust Pit palette)
var _tile_cache: Dictionary = {}  # resource path → Texture2D (or null for a missing tile)
var _prop_cache: Dictionary = {}  # prop id → silhouette-trimmed Texture2D (or null)

const PIPE_COLOR := Color("7a4a2e")
const PIPE_JOINT := Color("4e2f1c")


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_resized)
	EventBus.season_changed.connect(_on_season_changed)
	EventBus.building_placed.connect(_on_building_changed)
	EventBus.building_removed.connect(_on_building_changed)


func render_terrain(grid: HexGrid) -> void:
	_hex_grid = grid
	queue_redraw()


func _on_viewport_resized() -> void:
	queue_redraw()


func _on_season_changed(_season_id: String, _day: int, _length: int) -> void:
	queue_redraw()


func _on_building_changed(_coord: Vector2i, _type_id: String) -> void:
	queue_redraw()


func _draw() -> void:
	if _hex_grid == null:
		return

	var hex_points := _hex_polygon()
	var dusty: bool = GameStateStore.climate().get("season_id", "") == "season_dust"
	var half_tile := Vector2(HexCoords.HEX_SIZE, HexCoords.HEX_SIZE * HexCoords.ISO_Y)
	for coord: Vector2i in _hex_grid.all_coords():
		var terrain_id: int = _hex_grid.get_terrain_at(coord)
		var center: Vector2 = HexCoords.axial_to_pixel(coord)
		var translated_pts: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in hex_points:
			translated_pts.append(center + p)
		var tile: Texture2D = _terrain_texture(terrain_id, dusty)
		if tile != null:
			draw_texture_rect(tile, Rect2(center - half_tile, half_tile * 2.0), false)
		else:
			draw_colored_polygon(translated_pts, _terrain_color(terrain_id))
		# Outline — faint, warm, so the grid reads as cracked ground rather than a chessboard.
		draw_polyline(translated_pts, Color(0.25, 0.18, 0.1, 0.22), 1.0)
	_draw_old_pipes()
	_draw_props()


func _draw_props() -> void:
	var decor: Dictionary = GameStateStore.world().get("decor", {}) as Dictionary
	var props: Array = (decor.get("props", []) as Array).duplicate()
	props.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _prop_center(a).y < _prop_center(b).y)
	for prop: Dictionary in props:
		var coord := Vector2i(int(prop["q"]), int(prop["r"]))
		if not _hex_grid.is_valid(coord) or GameStateStore.has_building(coord):
			continue
		var texture: Texture2D = _prop_texture(prop["id"] as String)
		if texture == null:
			continue
		var width: float = HexCoords.HEX_SIZE * 1.6
		var draw_size := Vector2(width, texture.get_height() * width / texture.get_width())
		var anchor := Vector2(width * 0.5, draw_size.y - width * 0.25)
		draw_texture_rect(texture, Rect2(_prop_center(prop) - anchor, draw_size), false)


func _prop_center(prop: Dictionary) -> Vector2:
	return HexCoords.axial_to_pixel(Vector2i(int(prop["q"]), int(prop["r"])))


func _prop_texture(id: String) -> Texture2D:
	if not _prop_cache.has(id):
		var path: String = "res://assets/props/%s.png" % id
		var texture: Texture2D = ResourceLoader.load(path) as Texture2D if ResourceLoader.exists(path) else null
		if texture != null:
			var image: Image = texture.get_image()
			var used: Rect2i = image.get_used_rect()
			texture = ImageTexture.create_from_image(image.get_region(used)) if used.has_area() else null
		_prop_cache[id] = texture
	return _prop_cache[id] as Texture2D


func _terrain_texture(terrain_id: int, dusty: bool) -> Texture2D:
	var def: Dictionary = ContentDB.get_terrain_def(terrain_id)
	var key: String = "tile_dust" if dusty else "tile"
	var path: String = def.get(key, "") as String
	if path.is_empty():
		return null
	if not _tile_cache.has(path):
		# Remember unavailable resources too, so fallback cells do not retry every draw.
		_tile_cache[path] = ResourceLoader.load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _tile_cache[path] as Texture2D


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
