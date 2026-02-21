extends Node2D
## Visual effects: damage flashes, build particles, event indicators.

var _effects: Array = []  # Array[{coord, color, remaining}]


func _ready() -> void:
	EventBus.building_placed.connect(_on_building_placed)
	EventBus.building_damaged.connect(_on_building_damaged)


func _on_building_placed(coord: Vector2i, _type_id: String) -> void:
	_effects.append({"coord": coord, "color": Color(0.3, 1.0, 0.3, 0.8), "remaining": 0.5})
	queue_redraw()


func _on_building_damaged(coord: Vector2i, _severity: float) -> void:
	_effects.append({"coord": coord, "color": Color(1.0, 0.2, 0.2, 0.8), "remaining": 1.0})
	queue_redraw()


func _process(delta: float) -> void:
	var alive: Array = []
	for fx: Dictionary in _effects:
		fx["remaining"] = (fx.remaining as float) - delta
		if (fx.remaining as float) > 0.0:
			alive.append(fx)
	if _effects.size() != alive.size():
		_effects = alive
		queue_redraw()


func _draw() -> void:
	for fx: Dictionary in _effects:
		var coord: Vector2i = fx.coord as Vector2i
		var center: Vector2 = HexCoords.axial_to_pixel(coord)
		var alpha: float = clampf(fx.remaining as float, 0.0, 1.0)
		var color: Color = (fx.color as Color)
		color.a = alpha * 0.6
		draw_circle(center, HexCoords.HEX_SIZE * (1.5 - alpha * 0.5), color)
