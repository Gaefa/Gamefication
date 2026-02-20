## hex_terrain_layer.gd -- Renders the hex terrain using Godot's _draw().
## Draws flat-top hexagons colored by terrain type.
## Only redraws visible hexes (viewport culling).
extends Node2D


var _orchestrator: GameOrchestrator = null
var _hex_size: float = 32.0

## Pre-computed hex corner offsets for flat-top hexagons.
var _hex_corners: PackedVector2Array = PackedVector2Array()

## Terrain color palette (indexed by terrain type ID).
const TERRAIN_COLORS: Dictionary = {
	0: Color(0.42, 0.75, 0.33),    # grass - green
	1: Color(0.20, 0.45, 0.80),    # water - blue
	2: Color(0.85, 0.78, 0.55),    # sand - tan
	3: Color(0.20, 0.55, 0.20),    # forest - dark green
	4: Color(0.55, 0.50, 0.45),    # mountain - grey
	5: Color(0.45, 0.55, 0.35),    # swamp - murky green
}

## Grid line color.
const GRID_COLOR: Color = Color(0.0, 0.0, 0.0, 0.12)

## Whether the terrain needs a full redraw.
var _needs_redraw: bool = true


# ------------------------------------------------------------------
# Setup
# ------------------------------------------------------------------

func setup(orchestrator: GameOrchestrator, hex_size: float) -> void:
	_orchestrator = orchestrator
	_hex_size = hex_size
	_precompute_hex_corners()
	_needs_redraw = true
	queue_redraw()


## Pre-compute the 6 corner offsets for a flat-top hexagon.
func _precompute_hex_corners() -> void:
	_hex_corners.clear()
	for i in 6:
		var angle_deg: float = 60.0 * i
		var angle_rad: float = deg_to_rad(angle_deg)
		_hex_corners.append(Vector2(
			_hex_size * cos(angle_rad),
			_hex_size * sin(angle_rad)
		))


# ------------------------------------------------------------------
# Refresh
# ------------------------------------------------------------------

func refresh() -> void:
	# Terrain doesn't change per tick, but refresh on demand
	if _needs_redraw:
		queue_redraw()


# ------------------------------------------------------------------
# Drawing
# ------------------------------------------------------------------

func _draw() -> void:
	if not _orchestrator or not _orchestrator.hex_grid:
		return

	var hex_grid: HexGrid = _orchestrator.hex_grid
	var grid_size: int = hex_grid.grid_size

	# Get visible area from the viewport for culling
	var canvas_transform: Transform2D = get_canvas_transform()
	var viewport_size: Vector2 = get_viewport_rect().size
	var visible_rect: Rect2 = Rect2(
		-canvas_transform.origin / canvas_transform.x.x,
		viewport_size / canvas_transform.x.x
	)

	# Expand by hex_size to catch hexes at the edges
	visible_rect = visible_rect.grow(_hex_size * 2.0)

	for r in range(grid_size):
		for q in range(grid_size):
			var pixel: Vector2 = HexCoords.axial_to_pixel(q, r, _hex_size)

			# Viewport culling
			if not visible_rect.has_point(pixel):
				continue

			var terrain_type: int = hex_grid.get_terrain(q, r)
			var color: Color = TERRAIN_COLORS.get(terrain_type, TERRAIN_COLORS[0])

			_draw_hex(pixel, color)

	_needs_redraw = false


## Draw a single filled hexagon at the given center position.
func _draw_hex(center: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	points.resize(6)
	for i in 6:
		points[i] = center + _hex_corners[i]

	# Filled hex
	draw_colored_polygon(points, color)

	# Grid outline
	for i in 6:
		var next_i: int = (i + 1) % 6
		draw_line(points[i], points[next_i], GRID_COLOR, 1.0)
