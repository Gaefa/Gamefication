extends Node2D
## Renders buildings on the hex grid with drawn icons per building type.

var _hex_grid: HexGrid

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


# ============================================================
# Building-specific icon drawing
# ============================================================

func _draw_building_icon(c: Vector2, type_id: String, level: int, base_color: Color) -> void:
	match type_id:
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
		pts.append(Vector2(cos(angle), sin(angle)) * hex_size)
	pts.append(pts[0])
	return pts
