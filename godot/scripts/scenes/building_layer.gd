## building_layer.gd -- Renders buildings on the hex grid.
## Each building is drawn as a colored shape at its hex center with a label.
## Will be replaced with proper sprites/atlases later.
extends Node2D


var _orchestrator: GameOrchestrator = null
var _hex_size: float = 32.0

## Building color palette by type.
const BUILDING_COLORS: Dictionary = {
	"hut":          Color(0.85, 0.65, 0.40),
	"apartment":    Color(0.75, 0.55, 0.30),
	"farm":         Color(0.50, 0.80, 0.30),
	"lumber":       Color(0.60, 0.45, 0.25),
	"quarry":       Color(0.65, 0.60, 0.55),
	"workshop":     Color(0.70, 0.55, 0.40),
	"foundry":      Color(0.80, 0.40, 0.20),
	"market":       Color(0.90, 0.75, 0.20),
	"warehouse":    Color(0.55, 0.50, 0.45),
	"road":         Color(0.50, 0.50, 0.50),
	"research":     Color(0.40, 0.60, 0.90),
	"library":      Color(0.50, 0.50, 0.80),
	"power":        Color(0.90, 0.85, 0.20),
	"water_tower":  Color(0.30, 0.65, 0.90),
	"park":         Color(0.35, 0.80, 0.45),
	"monument":     Color(0.80, 0.70, 0.90),
	"trading_post": Color(0.85, 0.65, 0.50),
	"bank":         Color(0.75, 0.75, 0.30),
}

## Default color for unknown building types.
const DEFAULT_BUILDING_COLOR: Color = Color(0.6, 0.6, 0.6)

## Issue indicator color.
const ISSUE_COLOR: Color = Color(1.0, 0.25, 0.25, 0.8)

## Pre-computed hex corners for building outline.
var _hex_corners_small: PackedVector2Array = PackedVector2Array()


# ------------------------------------------------------------------
# Setup
# ------------------------------------------------------------------

func setup(orchestrator: GameOrchestrator, hex_size: float) -> void:
	_orchestrator = orchestrator
	_hex_size = hex_size
	_precompute_corners()
	queue_redraw()


func _precompute_corners() -> void:
	_hex_corners_small.clear()
	var inner_size: float = _hex_size * 0.75
	for i in 6:
		var angle_deg: float = 60.0 * i
		var angle_rad: float = deg_to_rad(angle_deg)
		_hex_corners_small.append(Vector2(
			inner_size * cos(angle_rad),
			inner_size * sin(angle_rad)
		))


# ------------------------------------------------------------------
# Refresh
# ------------------------------------------------------------------

func refresh() -> void:
	queue_redraw()


# ------------------------------------------------------------------
# Drawing
# ------------------------------------------------------------------

func _draw() -> void:
	if not _orchestrator or not _orchestrator.hex_grid:
		return

	var hex_grid: HexGrid = _orchestrator.hex_grid
	var all_buildings: Dictionary = hex_grid.get_all_buildings()

	# Get visible area for culling
	var canvas_transform: Transform2D = get_canvas_transform()
	var viewport_size: Vector2 = get_viewport_rect().size
	var visible_rect: Rect2 = Rect2(
		-canvas_transform.origin / canvas_transform.x.x,
		viewport_size / canvas_transform.x.x
	)
	visible_rect = visible_rect.grow(_hex_size * 2.0)

	var font: Font = ThemeDB.fallback_font
	var font_size: int = 10

	for coord: Vector2i in all_buildings:
		var pixel: Vector2 = HexCoords.axial_to_pixel(coord.x, coord.y, _hex_size)

		# Viewport culling
		if not visible_rect.has_point(pixel):
			continue

		var bld: Dictionary = all_buildings[coord]
		var btype: String = bld.get("type", "")
		var level: int = int(bld.get("level", 1))
		var has_issue: bool = bld.get("issue") != null

		# Building color
		var color: Color = BUILDING_COLORS.get(btype, DEFAULT_BUILDING_COLOR)

		# Draw filled smaller hex
		var points: PackedVector2Array = PackedVector2Array()
		points.resize(6)
		for i in 6:
			points[i] = pixel + _hex_corners_small[i]
		draw_colored_polygon(points, color)

		# Draw border
		var border_color: Color = color.darkened(0.3)
		for i in 6:
			var next_i: int = (i + 1) % 6
			draw_line(points[i], points[next_i], border_color, 1.5)

		# Issue indicator (red dot in corner)
		if has_issue:
			draw_circle(pixel + Vector2(_hex_size * 0.4, -_hex_size * 0.4), 4.0, ISSUE_COLOR)

		# Level indicator
		var label: String = btype.substr(0, 1).to_upper()
		if level > 1:
			label += str(level)
		if font:
			var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			draw_string(font, pixel - text_size * 0.5 + Vector2(0, text_size.y * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
