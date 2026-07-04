extends Node
## WaterPanel (Autoload)
## Вода в MVP — сердце района, и её надо читать как три разные величины (UX_BIBLE §6).
## Панель (клавиша C) показывает:
##   • Запас — сколько воды в цистернах и на сколько дней хватит при текущем расходе;
##   • Покрытие — доля жилья, реально подключённого к воде (из CoverageMap);
##   • Давление — в MVP отдельно не моделируется (честная пометка на будущее).
##
## Self-contained: владеет своей панелью, читает состояние при каждом открытии.

const TICKS_PER_DAY := 300  # matches SimulationRunner (day_duration 300s @ 1 tick/s)

var _visible: bool = false
var _layer: CanvasLayer
var _root: Control
var _body: RichTextLabel


func _ready() -> void:
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and (ke.keycode == KEY_C or ke.physical_keycode == KEY_C):
			if SimulationRunner.paused and not _visible:
				return
			_toggle()
			get_viewport().set_input_as_handled()


func _toggle() -> void:
	_visible = not _visible
	if _visible:
		_body.text = _compose()
	_layer.visible = _visible


func _compose() -> String:
	var lines: Array[String] = []
	var reserve: float = GameStateStore.get_resource("res_water_stockpile")
	var production: Dictionary = GameStateStore.economy().get("production", {})
	var net: float = production.get("res_water_stockpile", 0.0) as float

	# --- Запас (сколько есть) ---
	lines.append("[b]Запас — сколько есть[/b]")
	lines.append("— В цистернах: %d" % int(reserve))
	var gross_day: float = _gross_daily_consumption()
	if gross_day > 0.0:
		var days: float = reserve / gross_day
		var color: String = "#d98c66" if days < 3.0 else "#7fbf7f"
		lines.append("— Хватит примерно на [color=%s]%.1f дн.[/color] при текущем расходе (%.0f/день)" % [color, days, gross_day])
	lines.append("— Баланс: %s" % _net_text(net))
	lines.append("")

	# --- Покрытие (доходит ли) ---
	lines.append("[b]Покрытие — доходит ли[/b]")
	var cov: Dictionary = _coverage()
	if (cov.get("total", 0) as int) <= 0:
		lines.append("— Жилья с потребностью в воде пока нет.")
	else:
		var covered: int = cov.get("covered", 0) as int
		var total: int = cov.get("total", 0) as int
		var pct: int = int(round(100.0 * float(covered) / float(total)))
		var color: String = "#7fbf7f" if pct >= 90 else "#d98c66"
		lines.append("— Подключено жилья: [color=%s]%d из %d (%d%%)[/color]" % [color, covered, total, pct])
		if covered < total:
			lines.append("— Часть домов вне радиуса насоса/башни. Запас может быть большим, а до дальних не доходит.")
	lines.append("")

	# --- Давление (хватает ли напора) ---
	lines.append("[b]Давление — хватает ли напора[/b]")
	lines.append("[color=#8a8a99]В MVP напор отдельно не считается: вода доходит, если есть покрытие. Падение давления на дальних ветках — после MVP.[/color]")

	return "\n".join(lines)


func _gross_daily_consumption() -> float:
	var water_mult: float = (GameStateStore.climate().get("modifiers", {}) as Dictionary).get("water_mult", 1.0) as float
	var per_tick: float = 0.0
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		if bld.get("damaged", false) as bool:
			continue
		var ldata: Dictionary = ContentDB.building_level_data(bld.get("type", "") as String, bld.get("level", 0) as int)
		var consumes: Dictionary = ldata.get("consumes", {})
		per_tick += consumes.get("res_water_stockpile", 0.0) as float
	return per_tick * water_mult * float(TICKS_PER_DAY)


func _coverage() -> Dictionary:
	var result := { "covered": 0, "total": 0 }
	var orch: Object = _orchestrator()
	if orch == null or orch.get("coverage") == null:
		return result
	var coverage: Object = orch.get("coverage")
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		var def: Dictionary = ContentDB.get_building_def(bld.get("type", "") as String)
		var needs_water: bool = (def.get("category", "") as String) == "Residential" \
			or (def.get("tags", []) as Array).has("housing")
		if not needs_water:
			continue
		result.total = (result.total as int) + 1
		if coverage.is_water_covered(coord):
			result.covered = (result.covered as int) + 1
	return result


func _orchestrator() -> Object:
	var main: Node = get_tree().current_scene
	if main != null and main.has_method("get_orchestrator"):
		return main.call("get_orchestrator")
	return null


func _net_text(net: float) -> String:
	if net > 0.05:
		return "[color=#7fbf7f]пополняется (+%.1f/день)[/color]" % net
	if net < -0.05:
		return "[color=#d98c66]тает (%.1f/день)[/color]" % net
	return "ровно"


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 150
	_layer.visible = false
	add_child(_layer)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(_root)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.08, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(640, 480)
	panel.position = Vector2(-320, -240)
	bg.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "ВОДА — ЗАПАС · ПОКРЫТИЕ · ДАВЛЕНИЕ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.custom_minimum_size = Vector2(580, 340)
	_body.add_theme_font_size_override("normal_font_size", 14)
	vbox.add_child(_body)

	var close_btn := Button.new()
	close_btn.text = "Закрыть (C)"
	close_btn.pressed.connect(_toggle)
	vbox.add_child(close_btn)
