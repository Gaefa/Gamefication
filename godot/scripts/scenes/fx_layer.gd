## fx_layer.gd -- Visual effects layer for particles, build flash, etc.
## Manages temporary visual effects that play over the map.
extends Node2D


var _orchestrator: GameOrchestrator = null
var _hex_size: float = 32.0

## Active effects -- each is { position: Vector2, timer: float, type: String, color: Color }
var _effects: Array = []

## Effect duration in seconds.
const EFFECT_DURATION: float = 0.5


# ------------------------------------------------------------------
# Setup
# ------------------------------------------------------------------

func setup(orchestrator: GameOrchestrator, hex_size: float) -> void:
	_orchestrator = orchestrator
	_hex_size = hex_size

	# Connect signals
	EventBus.building_placed.connect(_on_building_placed)
	EventBus.building_removed.connect(_on_building_removed)
	EventBus.building_upgraded.connect(_on_building_upgraded)


# ------------------------------------------------------------------
# Process -- update and expire effects
# ------------------------------------------------------------------

func _process(delta: float) -> void:
	if _effects.is_empty():
		return

	var any_expired: bool = false
	for effect: Dictionary in _effects:
		effect["timer"] = float(effect.get("timer", 0.0)) - delta
		if effect["timer"] <= 0.0:
			any_expired = true

	if any_expired:
		_effects = _effects.filter(func(e: Dictionary) -> bool: return e.get("timer", 0.0) > 0.0)

	queue_redraw()


# ------------------------------------------------------------------
# Drawing
# ------------------------------------------------------------------

func _draw() -> void:
	for effect: Dictionary in _effects:
		var pos: Vector2 = effect.get("position", Vector2.ZERO)
		var t: float = float(effect.get("timer", 0.0)) / EFFECT_DURATION
		t = clampf(t, 0.0, 1.0)

		var etype: String = effect.get("type", "build")
		var base_color: Color = effect.get("color", Color.WHITE)

		match etype:
			"build":
				# Expanding ring
				var radius: float = _hex_size * (1.0 - t) * 1.5
				var alpha: float = t * 0.6
				draw_arc(pos, radius, 0, TAU, 24, Color(base_color, alpha), 2.0)

			"bulldoze":
				# Shrinking circle
				var radius: float = _hex_size * t * 0.8
				var alpha: float = t * 0.5
				draw_circle(pos, radius, Color(1.0, 0.3, 0.1, alpha))

			"upgrade":
				# Upward moving arrow particles
				var offset_y: float = -_hex_size * (1.0 - t) * 0.5
				var alpha: float = t * 0.7
				draw_circle(pos + Vector2(0, offset_y), 3.0, Color(0.3, 0.9, 0.3, alpha))
				draw_circle(pos + Vector2(-5, offset_y + 5), 2.0, Color(0.3, 0.9, 0.3, alpha * 0.5))
				draw_circle(pos + Vector2(5, offset_y + 5), 2.0, Color(0.3, 0.9, 0.3, alpha * 0.5))


# ------------------------------------------------------------------
# Effect spawners
# ------------------------------------------------------------------

func _spawn_effect(coord: Vector2i, type: String, color: Color) -> void:
	var pixel: Vector2 = HexCoords.axial_to_pixel(coord.x, coord.y, _hex_size)
	_effects.append({
		"position": pixel,
		"timer": EFFECT_DURATION,
		"type": type,
		"color": color,
	})


# ------------------------------------------------------------------
# Signal handlers
# ------------------------------------------------------------------

func _on_building_placed(coord: Vector2i, _type_id: String) -> void:
	_spawn_effect(coord, "build", Color(0.3, 0.8, 1.0))


func _on_building_removed(coord: Vector2i) -> void:
	_spawn_effect(coord, "bulldoze", Color(1.0, 0.3, 0.1))


func _on_building_upgraded(coord: Vector2i, _new_level: int) -> void:
	_spawn_effect(coord, "upgrade", Color(0.3, 0.9, 0.3))
