extends Node2D
## Visual effects: a short flash on a cell when something is built, breaks or develops a
## fault. The flash has the cell's own hex outline, like the selection frame, so it reads
## as "this cell" and never spills onto the neighbours.

var _effects: Array = []  # Array[{coord, color, duration, remaining, settle}]


func _ready() -> void:
	EventBus.building_placed.connect(_on_building_placed)
	EventBus.building_damaged.connect(_on_building_damaged)
	EventBus.building_issue_added.connect(_on_building_issue_added)


func _on_building_placed(coord: Vector2i, _type_id: String) -> void:
	_flash(coord, UiStyle.GOOD, 0.6, true)


func _on_building_damaged(coord: Vector2i, _severity: float) -> void:
	_flash(coord, UiStyle.BAD, 1.2, false)


func _on_building_issue_added(coord: Vector2i) -> void:
	_flash(coord, UiStyle.WARN, 1.0, false)


## `settle`: the frame drops onto the cell (a new building). Otherwise it blinks as it fades.
func _flash(coord: Vector2i, color: Color, duration: float, settle: bool) -> void:
	_effects.append({"coord": coord, "color": color, "duration": duration, "remaining": duration, "settle": settle})
	queue_redraw()


func _process(delta: float) -> void:
	if _effects.is_empty():
		return
	var alive: Array = []
	for fx: Dictionary in _effects:
		fx["remaining"] = (fx.remaining as float) - delta
		if (fx.remaining as float) > 0.0:
			alive.append(fx)
	_effects = alive
	queue_redraw()


func _draw() -> void:
	for fx: Dictionary in _effects:
		var center: Vector2 = HexCoords.axial_to_pixel(fx.coord as Vector2i)
		var t: float = 1.0 - clampf((fx.remaining as float) / (fx.duration as float), 0.0, 1.0)  # 0 → 1 over its life
		var strength: float = 1.0 - t
		var size: float = HexCoords.HEX_SIZE * 0.97
		if fx.settle as bool:
			size *= lerpf(1.25, 1.0, 1.0 - pow(1.0 - t, 3.0))
		else:
			strength *= 0.55 + 0.45 * absf(cos(t * TAU * 1.5))
		var pts := PackedVector2Array()
		for i: int in 6:
			var angle: float = TAU / 6.0 * float(i)
			pts.append(center + Vector2(cos(angle), sin(angle) * HexCoords.ISO_Y) * size)
		var color: Color = fx.color as Color
		draw_colored_polygon(pts, Color(color, strength * 0.25))
		pts.append(pts[0])
		draw_polyline(pts, Color(0.1, 0.08, 0.06, strength * 0.5), 5.0)
		draw_polyline(pts, Color(color, strength), 3.0)
