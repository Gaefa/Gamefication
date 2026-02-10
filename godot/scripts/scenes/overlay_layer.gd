## overlay_layer.gd -- Renders debug/informational overlays on top of the map.
## Supports toggleable range indicators, road network visualization,
## water/power coverage highlights, and hover tooltip.
extends Node2D


var _orchestrator: GameOrchestrator = null
var _hex_size: float = 32.0

## Which overlay is currently active.
enum OverlayMode { NONE, ROAD_NETWORK, WATER_COVERAGE, POWER_COVERAGE, HAPPINESS }
var current_mode: int = OverlayMode.NONE

## Hex the mouse is currently over.
var hovered_hex: Vector2i = Vector2i(-1, -1)

## Overlay colors.
const ROAD_COLOR: Color = Color(0.7, 0.5, 0.2, 0.35)
const WATER_COLOR: Color = Color(0.2, 0.5, 0.9, 0.35)
const POWER_COLOR: Color = Color(1.0, 0.9, 0.2, 0.35)
const HAPPINESS_HIGH_COLOR: Color = Color(0.3, 0.9, 0.3, 0.35)
const HAPPINESS_LOW_COLOR: Color = Color(0.9, 0.3, 0.3, 0.35)
const HOVER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.25)

## Pre-computed hex corners.
var _hex_corners: PackedVector2Array = PackedVector2Array()


# ------------------------------------------------------------------
# Setup
# ------------------------------------------------------------------

func setup(orchestrator: GameOrchestrator, hex_size: float) -> void:
	_orchestrator = orchestrator
	_hex_size = hex_size
	_precompute_corners()


func _precompute_corners() -> void:
	_hex_corners.clear()
	for i in 6:
		var angle_rad: float = deg_to_rad(60.0 * i)
		_hex_corners.append(Vector2(
			_hex_size * cos(angle_rad),
			_hex_size * sin(angle_rad)
		))


# ------------------------------------------------------------------
# Input
# ------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if Input.is_action_just_pressed("toggle_ranges"):
			# Cycle through overlay modes
			current_mode = (current_mode + 1) % 5
			queue_redraw()

	if event is InputEventMouseMotion:
		var camera: Camera2D = get_viewport().get_camera_2d()
		if camera:
			var world_pos: Vector2 = camera.get_global_mouse_position()
			var new_hex: Vector2i = HexCoords.pixel_to_axial(world_pos.x, world_pos.y, _hex_size)
			if new_hex != hovered_hex:
				hovered_hex = new_hex
				queue_redraw()


# ------------------------------------------------------------------
# Refresh
# ------------------------------------------------------------------

func refresh() -> void:
	if current_mode != OverlayMode.NONE:
		queue_redraw()


# ------------------------------------------------------------------
# Drawing
# ------------------------------------------------------------------

func _draw() -> void:
	# Always draw hover highlight
	if hovered_hex != Vector2i(-1, -1):
		_draw_hex_overlay(hovered_hex, HOVER_COLOR)

	if not _orchestrator or not _orchestrator.hex_grid:
		return

	match current_mode:
		OverlayMode.ROAD_NETWORK:
			_draw_road_overlay()
		OverlayMode.WATER_COVERAGE:
			_draw_water_overlay()
		OverlayMode.POWER_COVERAGE:
			_draw_power_overlay()
		OverlayMode.HAPPINESS:
			_draw_happiness_overlay()


func _draw_road_overlay() -> void:
	if not _orchestrator.transport_graph:
		return
	var hex_grid: HexGrid = _orchestrator.hex_grid
	for coord: Vector2i in hex_grid.get_all_buildings():
		var bld: Dictionary = hex_grid.get_building(coord.x, coord.y)
		if bld != null and bld.get("type", "") == "road":
			_draw_hex_overlay(coord, ROAD_COLOR)


func _draw_water_overlay() -> void:
	if not _orchestrator.hex_grid:
		return
	var hex_grid: HexGrid = _orchestrator.hex_grid
	for coord: Vector2i in hex_grid.get_all_buildings():
		if _orchestrator.aura_cache:
			var covered: bool = _orchestrator.aura_cache.get_water_coverage(
				coord.x, coord.y, hex_grid, _orchestrator.spatial_index)
			if covered:
				_draw_hex_overlay(coord, WATER_COLOR)


func _draw_power_overlay() -> void:
	if not _orchestrator.hex_grid:
		return
	var hex_grid: HexGrid = _orchestrator.hex_grid
	for coord: Vector2i in hex_grid.get_all_buildings():
		if _orchestrator.aura_cache:
			var power: float = _orchestrator.aura_cache.get_power_aura(
				coord.x, coord.y, hex_grid, _orchestrator.spatial_index)
			if power > 0.0:
				var c: Color = POWER_COLOR
				c.a = clampf(0.15 + power * 0.4, 0.0, 0.5)
				_draw_hex_overlay(coord, c)


func _draw_happiness_overlay() -> void:
	# Visual happiness heat map based on park aura
	if not _orchestrator.hex_grid:
		return
	var hex_grid: HexGrid = _orchestrator.hex_grid
	for coord: Vector2i in hex_grid.get_all_buildings():
		if _orchestrator.aura_cache:
			var happiness: float = _orchestrator.aura_cache.get_park_happiness(
				coord.x, coord.y, hex_grid, _orchestrator.spatial_index)
			var t: float = clampf(happiness / 20.0, 0.0, 1.0)
			var c: Color = HAPPINESS_LOW_COLOR.lerp(HAPPINESS_HIGH_COLOR, t)
			_draw_hex_overlay(coord, c)


func _draw_hex_overlay(coord: Vector2i, color: Color) -> void:
	var pixel: Vector2 = HexCoords.axial_to_pixel(coord.x, coord.y, _hex_size)
	var points: PackedVector2Array = PackedVector2Array()
	points.resize(6)
	for i in 6:
		points[i] = pixel + _hex_corners[i]
	draw_colored_polygon(points, color)
