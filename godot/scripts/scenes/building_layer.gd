extends Node2D
## Renders buildings on the hex grid with drawn icons per building type.

var _hex_grid: HexGrid
var _sprite_cache: Dictionary = {}

# Category colors for base hex fill
const CAT_COLORS: Dictionary = {
	"Residential":     Color("c0392b"),
	"Production":      Color("d35400"),
	"Commercial":      Color("f39c12"),
	"Culture":         Color("8e44ad"),
	"Infrastructure":  Color("7f8c8d"),
	"Advanced":        Color("16a085"),
}


func set_hex_grid(grid: HexGrid) -> void:
	_hex_grid = grid
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	var hex_fill := _hex_polygon(HexCoords.HEX_SIZE * 0.82)
	var hex_border := _hex_polygon(HexCoords.HEX_SIZE * 0.85)
	var road_coords: Array[Vector2i] = []
	var building_coords: Array[Vector2i] = []

	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		var type_id: String = bld.get("type", "") as String
		var def: Dictionary = ContentDB.get_building_def(type_id)
		if _is_road_building(type_id, def):
			road_coords.append(coord)
		else:
			building_coords.append(coord)

	for coord: Vector2i in road_coords:
		var road_bld: Dictionary = GameStateStore.get_building(coord)
		_draw_road_tile(coord, road_bld)

	for coord: Vector2i in building_coords:
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
		color = color.lerp(Color.WHITE, level * 0.04)

		var center: Vector2 = HexCoords.axial_to_pixel(coord)

		# Hex fill
		var fill_pts := PackedVector2Array()
		for p: Vector2 in hex_fill:
			fill_pts.append(center + p)
		draw_colored_polygon(fill_pts, color)

		# Border
		var border_pts := PackedVector2Array()
		for p: Vector2 in hex_border:
			border_pts.append(center + p)
		var border_color := Color.RED if damaged else Color(0.1, 0.1, 0.1, 0.7)
		draw_polyline(border_pts, border_color, 2.0)

		# Draw building icon
		_draw_building_icon(center, type_id, level, color)

		# Damage/issue indicator
		if damaged:
			_draw_crack(center)
		elif has_issue:
			_draw_alert(center)

		# Level dots at bottom
		if level > 0:
			_draw_level_dots(center, level)


func _draw_road_tile(coord: Vector2i, bld: Dictionary) -> void:
	var center: Vector2 = HexCoords.axial_to_pixel(coord)
	var damaged: bool = bld.get("damaged", false) as bool
	var has_issue: bool = bld.get("has_issue", false) as bool
	var level: int = bld.get("level", 0) as int

	var dust_fill := Color(0.39, 0.30, 0.18, 0.10)
	var translated_underlay := PackedVector2Array()
	for p: Vector2 in _hex_polygon(HexCoords.HEX_SIZE * 0.66):
		translated_underlay.append(center + p)
	draw_colored_polygon(translated_underlay, dust_fill)

	var style: Dictionary = _road_style_for_level(level)
	var shoulder_color: Color = style["shoulder"] as Color
	var surface_color: Color = style["surface"] as Color
	var rut_color: Color = style["rut"] as Color
	if damaged:
		surface_color = surface_color.lerp(Color("b36c4d"), 0.55)
		rut_color = rut_color.lerp(Color("8e4936"), 0.45)
	elif has_issue:
		surface_color = surface_color.lerp(Color("c79d58"), 0.35)
		rut_color = rut_color.lerp(Color("9f7c3f"), 0.25)

	var endpoints: Array[Vector2] = _road_connection_endpoints(coord)
	for end_point: Vector2 in endpoints:
		_draw_road_segment(center, end_point, shoulder_color, surface_color)
		_draw_road_ruts(center, end_point, rut_color)

	var hub_radius: float = 6.0 if endpoints.size() <= 2 else 7.0
	draw_circle(center, hub_radius + 1.8, shoulder_color)
	draw_circle(center, hub_radius, surface_color)
	_draw_road_gravel(center, hub_radius, rut_color)

	if endpoints.is_empty():
		var stub_end: Vector2 = center + Vector2(HexCoords.HEX_SIZE * 0.28, 0.0)
		var stub_start: Vector2 = center - Vector2(HexCoords.HEX_SIZE * 0.28, 0.0)
		_draw_road_segment(stub_start, stub_end, shoulder_color, surface_color)
		_draw_road_ruts(stub_start, stub_end, rut_color)

	if damaged:
		_draw_crack(center)
	elif has_issue:
		_draw_alert(center)

	if level > 0:
		_draw_level_dots(center, level)


# ============================================================
# Building-specific icon drawing
# ============================================================

func _draw_building_icon(c: Vector2, type_id: String, level: int, base_color: Color) -> void:
	if _draw_building_sprite(c, type_id, level):
		return

	match type_id:
		"bld_admin_post":
			_draw_bank(c)
		"bld_main_cistern":
			_draw_water(c)
		"bld_road":
			_draw_road(c)
		"bld_warehouse":
			_draw_warehouse(c)
		"bld_shelter":
			_draw_house(c, level)
		"bld_well_pump":
			_draw_water(c)
		"bld_field_strip":
			_draw_farm(c)
		"bld_lumber_yard":
			_draw_tree(c)
		"bld_quarry_pit":
			_draw_pickaxe(c)
		"bld_tool_workshop":
			_draw_gear(c)
		"hut":
			_draw_house(c, level)
		"apartment":
			_draw_apartment(c, level)
		"farm":
			_draw_farm(c)
		"lumber":
			_draw_tree(c)
		"quarry":
			_draw_pickaxe(c)
		"workshop":
			_draw_gear(c)
		"foundry":
			_draw_foundry(c)
		"market":
			_draw_market(c)
		"bank":
			_draw_bank(c)
		"park":
			_draw_park(c)
		"library":
			_draw_book(c)
		"theater":
			_draw_theater(c)
		"power":
			_draw_lightning(c)
		"water_tower":
			_draw_water(c)
		"road":
			_draw_road(c)
		"warehouse":
			_draw_warehouse(c)
		"research":
			_draw_flask(c)
		"wonder":
			_draw_star(c)
		_:
			# Fallback: draw letter
			draw_string(ThemeDB.fallback_font, c + Vector2(-6, 5),
				type_id.left(1).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 20, 14, Color.WHITE)


func _draw_building_sprite(c: Vector2, type_id: String, level: int) -> bool:
	var texture: Texture2D = _get_building_sprite(type_id, level)
	if texture == null:
		return false
	var tex_size: Vector2 = texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return false

	var max_width: float = HexCoords.HEX_SIZE * 1.85
	var scale_x: float = max_width / tex_size.x
	var scale_y: float = scale_x * HexCoords.ISO_Y
	var draw_size := Vector2(tex_size.x * scale_x, tex_size.y * scale_y)
	var rect := Rect2(c - draw_size * 0.5, draw_size)
	draw_texture_rect(texture, rect, false)
	return true


func _get_building_sprite(type_id: String, level: int) -> Texture2D:
	var def: Dictionary = ContentDB.get_building_def(type_id)
	var sprites: Array = def.get("sprites_by_level", []) as Array
	if sprites.is_empty():
		return null
	var idx: int = clampi(level, 0, sprites.size() - 1)
	var sprite_path: String = sprites[idx] as String
	if sprite_path == "":
		return null
	if _sprite_cache.has(sprite_path):
		return _sprite_cache[sprite_path] as Texture2D
	var texture: Texture2D = null
	if sprite_path.ends_with(".svg") and FileAccess.file_exists(sprite_path):
		var svg_text: String = FileAccess.get_file_as_string(sprite_path)
		if svg_text != "":
			var image := Image.new()
			var err: Error = image.load_svg_from_string(svg_text, 1.0)
			if err == OK:
				texture = ImageTexture.create_from_image(image)
	elif ResourceLoader.exists(sprite_path):
		texture = ResourceLoader.load(sprite_path) as Texture2D
	if texture == null:
		return null
	_sprite_cache[sprite_path] = texture
	return texture


## House: triangle roof + square body
func _draw_house(c: Vector2, level: int) -> void:
	var s := 10.0 + level * 1.5
	# Body
	draw_rect(Rect2(c.x - s * 0.6, c.y - s * 0.2, s * 1.2, s * 0.9), Color(0.85, 0.75, 0.6))
	# Roof (triangle)
	var roof := PackedVector2Array([
		c + Vector2(-s * 0.8, -s * 0.2),
		c + Vector2(0, -s * 1.0),
		c + Vector2(s * 0.8, -s * 0.2),
	])
	draw_colored_polygon(roof, Color(0.7, 0.2, 0.15))
	# Door
	draw_rect(Rect2(c.x - 2, c.y + s * 0.2, 4, s * 0.5), Color(0.4, 0.25, 0.1))
	# Window
	draw_rect(Rect2(c.x + s * 0.2, c.y - s * 0.1, 4, 4), Color(0.6, 0.85, 1.0))


## Apartment: tall rectangle with many windows
func _draw_apartment(c: Vector2, level: int) -> void:
	var h := 14.0 + level * 2.0
	var w := 10.0
	# Body
	draw_rect(Rect2(c.x - w * 0.5, c.y - h * 0.6, w, h), Color(0.75, 0.75, 0.8))
	# Windows (grid)
	for row: int in range(0, mini(3 + level, 5)):
		for col: int in 2:
			var wx := c.x - 3 + col * 5
			var wy := c.y - h * 0.5 + row * 4 + 2
			draw_rect(Rect2(wx, wy, 3, 3), Color(0.9, 0.9, 0.5, 0.8))


## Farm: green field with wheat lines
func _draw_farm(c: Vector2) -> void:
	# Field
	draw_rect(Rect2(c.x - 10, c.y - 6, 20, 14), Color(0.55, 0.75, 0.3))
	# Wheat rows
	for i: int in 5:
		var x := c.x - 8 + i * 4
		draw_line(Vector2(x, c.y - 4), Vector2(x, c.y + 5), Color(0.85, 0.8, 0.2), 1.5)
		# Wheat top
		draw_circle(Vector2(x, c.y - 5), 1.5, Color(0.85, 0.8, 0.2))


## Lumber mill: pine tree shape
func _draw_tree(c: Vector2) -> void:
	# Trunk
	draw_rect(Rect2(c.x - 2, c.y + 2, 4, 8), Color(0.5, 0.3, 0.15))
	# Three triangles for foliage
	for i: int in 3:
		var y_off := -3.0 - i * 5.0
		var w := 10.0 - i * 2.0
		var tri := PackedVector2Array([
			c + Vector2(-w, y_off + 6),
			c + Vector2(0, y_off),
			c + Vector2(w, y_off + 6),
		])
		draw_colored_polygon(tri, Color(0.15, 0.5 + i * 0.07, 0.15))


## Quarry: pickaxe symbol
func _draw_pickaxe(c: Vector2) -> void:
	# Rock base
	var rock := PackedVector2Array([
		c + Vector2(-10, 5), c + Vector2(-6, -3), c + Vector2(0, -6),
		c + Vector2(8, -2), c + Vector2(10, 5),
	])
	draw_colored_polygon(rock, Color(0.6, 0.58, 0.55))
	# Pickaxe handle
	draw_line(c + Vector2(-5, 8), c + Vector2(5, -5), Color(0.5, 0.3, 0.15), 2.0)
	# Pickaxe head
	draw_line(c + Vector2(3, -6), c + Vector2(8, -3), Color(0.5, 0.5, 0.55), 2.5)


## Workshop: gear/cog
func _draw_gear(c: Vector2) -> void:
	# Outer gear (approximated with circles and rectangles)
	draw_circle(c, 9.0, Color(0.55, 0.55, 0.6))
	draw_circle(c, 5.0, Color(0.4, 0.4, 0.45))
	draw_circle(c, 3.0, Color(0.55, 0.55, 0.6))
	# Teeth
	for i: int in 6:
		var angle := TAU / 6.0 * float(i)
		var p1 := c + Vector2(cos(angle), sin(angle)) * 8.0
		var p2 := c + Vector2(cos(angle), sin(angle)) * 12.0
		draw_line(p1, p2, Color(0.55, 0.55, 0.6), 3.0)


## Foundry: chimney with smoke
func _draw_foundry(c: Vector2) -> void:
	# Building body
	draw_rect(Rect2(c.x - 10, c.y - 4, 20, 14), Color(0.5, 0.4, 0.35))
	# Chimney
	draw_rect(Rect2(c.x + 4, c.y - 12, 5, 10), Color(0.45, 0.35, 0.3))
	# Fire glow
	draw_circle(c + Vector2(0, 4), 4.0, Color(1.0, 0.5, 0.1, 0.7))
	# Smoke puffs
	draw_circle(c + Vector2(6, -14), 2.5, Color(0.7, 0.7, 0.7, 0.4))
	draw_circle(c + Vector2(8, -17), 3.0, Color(0.7, 0.7, 0.7, 0.3))


## Market: tent/awning
func _draw_market(c: Vector2) -> void:
	# Counter
	draw_rect(Rect2(c.x - 10, c.y, 20, 8), Color(0.6, 0.45, 0.25))
	# Awning (zigzag)
	var awning := PackedVector2Array([
		c + Vector2(-12, -2), c + Vector2(-6, -8), c + Vector2(0, -2),
		c + Vector2(6, -8), c + Vector2(12, -2),
	])
	draw_polyline(awning, Color(0.9, 0.3, 0.2), 2.5)
	# Awning fill
	var awning_l := PackedVector2Array([
		c + Vector2(-12, -2), c + Vector2(-6, -8), c + Vector2(0, -2),
	])
	draw_colored_polygon(awning_l, Color(0.9, 0.3, 0.2, 0.5))
	var awning_r := PackedVector2Array([
		c + Vector2(0, -2), c + Vector2(6, -8), c + Vector2(12, -2),
	])
	draw_colored_polygon(awning_r, Color(0.85, 0.25, 0.15, 0.5))
	# Coin symbol
	draw_circle(c + Vector2(0, 3), 3, Color(1.0, 0.85, 0.2))


## Bank: pillared building
func _draw_bank(c: Vector2) -> void:
	# Base
	draw_rect(Rect2(c.x - 10, c.y - 2, 20, 12), Color(0.85, 0.85, 0.8))
	# Roof (triangle)
	var roof := PackedVector2Array([
		c + Vector2(-12, -2), c + Vector2(0, -12), c + Vector2(12, -2),
	])
	draw_colored_polygon(roof, Color(0.8, 0.8, 0.75))
	# Pillars
	for i: int in 3:
		var px := c.x - 7 + i * 7
		draw_rect(Rect2(px - 1.5, c.y - 1, 3, 10), Color(0.9, 0.9, 0.85))
	# $ symbol
	draw_string(ThemeDB.fallback_font, c + Vector2(-4, -3),
		"$", HORIZONTAL_ALIGNMENT_LEFT, 12, 10, Color(0.8, 0.7, 0.1))


## Park: tree and bench
func _draw_park(c: Vector2) -> void:
	# Grass circle
	draw_circle(c, 12.0, Color(0.45, 0.75, 0.35))
	# Tree crown
	draw_circle(c + Vector2(-4, -5), 6.0, Color(0.2, 0.6, 0.2))
	# Tree trunk
	draw_rect(Rect2(c.x - 5, c.y - 1, 2, 7), Color(0.5, 0.3, 0.15))
	# Bench
	draw_rect(Rect2(c.x + 2, c.y + 3, 8, 2), Color(0.55, 0.35, 0.15))
	# Flowers
	draw_circle(c + Vector2(6, -2), 2.0, Color(1.0, 0.4, 0.5))
	draw_circle(c + Vector2(8, 1), 1.5, Color(1.0, 0.8, 0.3))


## Book: open book shape
func _draw_book(c: Vector2) -> void:
	# Building
	draw_rect(Rect2(c.x - 10, c.y - 6, 20, 14), Color(0.7, 0.6, 0.5))
	# Book body
	draw_rect(Rect2(c.x - 7, c.y - 4, 14, 10), Color(0.3, 0.2, 0.5))
	# Pages
	draw_rect(Rect2(c.x - 6, c.y - 3, 5.5, 8), Color(0.95, 0.93, 0.85))
	draw_rect(Rect2(c.x + 0.5, c.y - 3, 5.5, 8), Color(0.92, 0.9, 0.82))
	# Spine
	draw_line(Vector2(c.x, c.y - 4), Vector2(c.x, c.y + 6), Color(0.3, 0.2, 0.5), 1.5)


## Theater: comedy/tragedy masks (simplified)
func _draw_theater(c: Vector2) -> void:
	# Stage
	draw_rect(Rect2(c.x - 11, c.y + 2, 22, 8), Color(0.6, 0.2, 0.2))
	# Curtain left
	var curtain_l := PackedVector2Array([
		c + Vector2(-12, -10), c + Vector2(-12, 2), c + Vector2(-4, 2), c + Vector2(-2, -6),
	])
	draw_colored_polygon(curtain_l, Color(0.7, 0.15, 0.15))
	# Curtain right
	var curtain_r := PackedVector2Array([
		c + Vector2(12, -10), c + Vector2(12, 2), c + Vector2(4, 2), c + Vector2(2, -6),
	])
	draw_colored_polygon(curtain_r, Color(0.7, 0.15, 0.15))
	# Smile face (comedy)
	draw_circle(c + Vector2(0, -3), 5.0, Color(1.0, 0.9, 0.6))
	draw_arc(c + Vector2(0, -2), 3.0, 0.0, PI, 8, Color.BLACK, 1.0)


## Lightning bolt for power
func _draw_lightning(c: Vector2) -> void:
	# Pole
	draw_rect(Rect2(c.x - 1.5, c.y - 8, 3, 18), Color(0.55, 0.55, 0.6))
	# Cross-arm
	draw_rect(Rect2(c.x - 8, c.y - 6, 16, 2), Color(0.55, 0.55, 0.6))
	# Lightning bolt
	var bolt := PackedVector2Array([
		c + Vector2(-3, -12), c + Vector2(1, -4), c + Vector2(-1, -4),
		c + Vector2(3, 4), c + Vector2(-1, -1), c + Vector2(1, -1),
	])
	draw_polyline(bolt, Color(1.0, 0.9, 0.2), 2.0)


## Water tower: tank on stilts
func _draw_water(c: Vector2) -> void:
	# Stilts
	draw_line(c + Vector2(-6, 0), c + Vector2(-4, 10), Color(0.5, 0.5, 0.55), 2.0)
	draw_line(c + Vector2(6, 0), c + Vector2(4, 10), Color(0.5, 0.5, 0.55), 2.0)
	# Cross-brace
	draw_line(c + Vector2(-5, 5), c + Vector2(5, 5), Color(0.5, 0.5, 0.55), 1.5)
	# Tank body
	draw_rect(Rect2(c.x - 8, c.y - 8, 16, 10), Color(0.4, 0.6, 0.85))
	# Water highlight
	draw_rect(Rect2(c.x - 6, c.y - 6, 12, 3), Color(0.5, 0.7, 0.95, 0.6))
	# Droplet
	draw_circle(c + Vector2(0, -11), 2.0, Color(0.3, 0.55, 0.9))


## Road: dashed line pattern
func _draw_road(c: Vector2) -> void:
	# Road surface
	draw_circle(c, 10.0, Color(0.45, 0.45, 0.45))
	# Center line (dashed)
	for i: int in 3:
		var x := c.x - 6 + i * 5
		draw_rect(Rect2(x, c.y - 1, 3, 2), Color(1.0, 0.9, 0.3))


## Warehouse: box/crate
func _draw_warehouse(c: Vector2) -> void:
	# Building
	draw_rect(Rect2(c.x - 10, c.y - 6, 20, 14), Color(0.6, 0.55, 0.45))
	# Roof
	draw_rect(Rect2(c.x - 11, c.y - 8, 22, 3), Color(0.5, 0.4, 0.35))
	# Door
	draw_rect(Rect2(c.x - 6, c.y, 12, 8), Color(0.4, 0.35, 0.25))
	# Crates inside
	draw_rect(Rect2(c.x - 4, c.y + 1, 4, 4), Color(0.7, 0.6, 0.35))
	draw_rect(Rect2(c.x + 1, c.y + 2, 3, 3), Color(0.65, 0.55, 0.3))


## Flask / beaker for research lab
func _draw_flask(c: Vector2) -> void:
	# Flask neck
	draw_rect(Rect2(c.x - 2, c.y - 10, 4, 8), Color(0.8, 0.85, 0.9, 0.7))
	# Flask body (triangle)
	var body := PackedVector2Array([
		c + Vector2(-9, 6), c + Vector2(-3, -3), c + Vector2(3, -3), c + Vector2(9, 6),
	])
	draw_colored_polygon(body, Color(0.8, 0.85, 0.9, 0.7))
	# Liquid
	var liquid := PackedVector2Array([
		c + Vector2(-7, 6), c + Vector2(-4, 0), c + Vector2(4, 0), c + Vector2(7, 6),
	])
	draw_colored_polygon(liquid, Color(0.3, 0.9, 0.4, 0.7))
	# Bubbles
	draw_circle(c + Vector2(-2, 3), 1.5, Color(0.5, 1.0, 0.6, 0.5))
	draw_circle(c + Vector2(2, 1), 1.0, Color(0.5, 1.0, 0.6, 0.5))


## Star for wonder
func _draw_star(c: Vector2) -> void:
	var pts := PackedVector2Array()
	for i: int in 10:
		var angle := TAU / 10.0 * float(i) - PI / 2.0
		var radius := 12.0 if i % 2 == 0 else 5.5
		pts.append(c + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(pts, Color(1.0, 0.85, 0.2))
	# Inner glow
	draw_circle(c, 4.0, Color(1.0, 0.95, 0.7, 0.6))


# ============================================================
# Indicators
# ============================================================

func _draw_crack(c: Vector2) -> void:
	## Red X for damaged buildings
	draw_line(c + Vector2(-8, -8), c + Vector2(8, 8), Color.RED, 2.5)
	draw_line(c + Vector2(8, -8), c + Vector2(-8, 8), Color.RED, 2.5)


func _draw_alert(c: Vector2) -> void:
	## Yellow ! for issues
	draw_circle(c + Vector2(10, -10), 5.0, Color(1.0, 0.8, 0.0, 0.8))
	draw_string(ThemeDB.fallback_font, c + Vector2(7, -6),
		"!", HORIZONTAL_ALIGNMENT_LEFT, 8, 10, Color.BLACK)


func _draw_level_dots(c: Vector2, level: int) -> void:
	## Small dots below center to show upgrade level
	var total := mini(level, 5)
	var start_x := c.x - float(total - 1) * 2.5
	for i: int in total:
		draw_circle(Vector2(start_x + float(i) * 5.0, c.y + 14), 1.8, Color(1.0, 1.0, 1.0, 0.8))


# ============================================================
# Helpers
# ============================================================

func _hex_polygon(hex_size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in 6:
		var angle := TAU / 6.0 * float(i)
		pts.append(Vector2(cos(angle), sin(angle) * HexCoords.ISO_Y) * hex_size)
	pts.append(pts[0])
	return pts


func _is_road_building(type_id: String, def: Dictionary) -> bool:
	if type_id == "road" or type_id == "bld_road":
		return true
	var tags: Array = def.get("tags", []) as Array
	return tags.has("road")


func _road_connection_endpoints(coord: Vector2i) -> Array[Vector2]:
	var center: Vector2 = HexCoords.axial_to_pixel(coord)
	var endpoints: Array[Vector2] = []
	for nb: Vector2i in HexCoords.neighbors_of(coord):
		var bld: Dictionary = GameStateStore.get_building(nb)
		if bld.is_empty():
			continue
		var type_id: String = bld.get("type", "") as String
		if not _is_road_building(type_id, ContentDB.get_building_def(type_id)):
			continue
		var neighbor_center: Vector2 = HexCoords.axial_to_pixel(nb)
		endpoints.append(center.lerp(neighbor_center, 0.5))
	return endpoints


func _draw_road_segment(start: Vector2, end_point: Vector2, shoulder_color: Color, surface_color: Color) -> void:
	draw_line(start, end_point, shoulder_color, 10.0)
	draw_line(start, end_point, surface_color, 7.2)


func _draw_road_ruts(start: Vector2, end_point: Vector2, rut_color: Color) -> void:
	var segment: Vector2 = end_point - start
	var length: float = segment.length()
	if length <= 10.0:
		return
	var dir: Vector2 = segment / length
	var normal := Vector2(-dir.y, dir.x) * 1.5
	var inner_start := start + dir * 2.5
	var inner_end := end_point - dir * 1.5
	draw_line(inner_start + normal, inner_end + normal, rut_color, 1.2)
	draw_line(inner_start - normal, inner_end - normal, rut_color, 1.2)


func _draw_road_gravel(center: Vector2, radius: float, pebble_color: Color) -> void:
	var pebble_offsets: Array[Vector2] = [
		Vector2(-radius * 0.45, -1.0),
		Vector2(radius * 0.35, -radius * 0.2),
		Vector2(-radius * 0.15, radius * 0.42),
		Vector2(radius * 0.28, radius * 0.32),
	]
	for offset: Vector2 in pebble_offsets:
		draw_circle(center + offset, 0.9, pebble_color)


func _road_style_for_level(level: int) -> Dictionary:
	if level <= 0:
		return {
			"shoulder": Color("5b442d"),
			"surface": Color("8c6a42"),
			"rut": Color("4d3925"),
		}
	if level == 1:
		return {
			"shoulder": Color("6b6252"),
			"surface": Color("a99d86"),
			"rut": Color("72654c"),
		}
	return {
		"shoulder": Color("756f63"),
		"surface": Color("b9b0a0"),
		"rut": Color("807663"),
	}
