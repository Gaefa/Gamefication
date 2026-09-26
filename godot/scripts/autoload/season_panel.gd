extends Node
## SeasonPanel (Autoload)
## Климат — ось игры (UX_BIBLE §7). Панель (клавиша K) показывает: текущий сезон и
## день, что сезон меняет (модификаторы словами), НЕТОЧНЫЙ прогноз следующего сезона
## (диапазон — точный даёт только Прогнозист) и короткий чек-лист готовности.
##
## Self-contained: владеет своей панелью, не трогает HUD/main. Содержимое
## пересобирается при каждом открытии (читает актуальное состояние).

var _visible: bool = false

var _layer: CanvasLayer
var _root: Control
var _body: RichTextLabel
var _title: Label
var _close_btn: Button


func _ready() -> void:
	_build_ui()
	Localization.locale_changed.connect(_on_locale_changed)


func _on_locale_changed(_locale: String) -> void:
	_apply_static_text()
	if _visible:
		_body.text = _compose()


func _apply_static_text() -> void:
	_title.text = Localization.ru_en("СЕЗОН И ПРОГНОЗ", "SEASON AND FORECAST")
	_close_btn.text = Localization.ru_en("Закрыть (K)", "Close (K)")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and (ke.keycode == KEY_K or ke.physical_keycode == KEY_K):
			if SimulationRunner.paused and not _visible:
				return
			_toggle()
			get_viewport().set_input_as_handled()


func _toggle() -> void:
	_visible = not _visible
	if _visible:
		_body.text = _compose()
	_layer.visible = _visible


## Public entry point (e.g. clicking the season block in the HUD).
func open() -> void:
	_visible = true
	_body.text = _compose()
	_layer.visible = true


func _compose() -> String:
	var climate: Dictionary = GameStateStore.climate()
	var sid: String = climate.get("season_id", "") as String
	if sid == "":
		return Localization.ru_en("Сезон ещё не определён.", "Season not determined yet.")
	var def: Dictionary = ContentDB.get_season_def(sid)
	var name: String = Localization.content_text(def, "label", sid)
	var din: int = climate.get("day_in_season", 1) as int
	var slen: int = def.get("length_days", 0) as int
	var lines: Array[String] = []

	lines.append(Localization.ru_en("[b]Сезон: %s[/b]  (день %d из %d)", "[b]Season: %s[/b]  (day %d of %d)") % [name, din, slen])
	var desc: String = Localization.content_text(def, "description", "")
	if desc != "":
		lines.append(desc)
	lines.append("")

	# Что меняет сезон — модификаторы словами.
	lines.append(Localization.ru_en("[b]Что меняет сезон[/b]", "[b]What the season changes[/b]"))
	var mods: Dictionary = def.get("modifiers", {})
	var mod_lines: Array[String] = _modifier_lines(mods)
	if mod_lines.is_empty():
		lines.append(Localization.ru_en("— спокойно, без штрафов. Время копить и строить.", "— calm, no penalties. Time to stockpile and build."))
	else:
		for m: String in mod_lines:
			lines.append("— " + m)
	lines.append("")

	# Неточный прогноз следующего сезона.
	var order: Array = ContentDB.get_season_order()
	if order.size() > 1 and slen > 0:
		var idx: int = climate.get("season_index", 0) as int
		var next_def: Dictionary = ContentDB.get_season_def(order[(idx + 1) % order.size()] as String)
		var next_name: String = Localization.content_text(next_def, "label", "?")
		var days_left: int = maxi(slen - din, 0)
		lines.append(Localization.ru_en("[b]Прогноз[/b]", "[b]Forecast[/b]"))
		var forecaster: bool = (GameStateStore.mandate().get("flags", {}) as Dictionary).get("forecaster_active", false) as bool
		if forecaster:
			# Прогнозист оживлён — точный прогноз (GDD §14.3).
			lines.append(Localization.ru_en("— %s наступит через [b]%d дн.[/b] (точно — Прогнозист), сила: %s", "— %s arrives in [b]%d days[/b] (exact, per the Forecaster), severity: %s") % [next_name, days_left, _intensity_word(next_def.get("forecast_intensity", "") as String)])
		else:
			var lo: int = maxi(days_left - 2, 0)
			var hi: int = days_left + 2
			lines.append(Localization.ru_en("— %s ожидается через ~%d–%d дн. (прогноз приблизительный)", "— %s expected in ~%d–%d days (rough forecast)") % [next_name, lo, hi])
			lines.append(Localization.ru_en("— Точный прогноз мог бы дать старый ИИ Компании в опечатанном офисе, если его оживить.", "— The Company's old AI in the sealed office could give an exact forecast, if revived."))
		lines.append("")

	# Готовность.
	lines.append(Localization.ru_en("[b]Готовность[/b]", "[b]Readiness[/b]"))
	var water: int = int(GameStateStore.get_resource("res_water_stockpile"))
	var food: int = int(GameStateStore.get_resource("res_food"))
	var production: Dictionary = GameStateStore.economy().get("production", {})
	var water_net: float = production.get("res_water_stockpile", 0.0) as float
	var food_net: float = production.get("res_food", 0.0) as float
	lines.append(Localization.ru_en("— Запас воды: %d  (%s)", "— Water reserve: %d  (%s)") % [water, _net_text(water_net)])
	lines.append(Localization.ru_en("— Запас еды: %d  (%s)", "— Food reserve: %d  (%s)") % [food, _net_text(food_net)])
	if water_net < 0.0 or food_net < 0.0:
		lines.append(Localization.ru_en("[color=#d98c66]Запас тает — в Пыль расход растёт. Готовьтесь в Окно.[/color]", "[color=#d98c66]Reserves are shrinking; use rises in the Dust. Prepare during the Window.[/color]"))

	return "\n".join(lines)


func _modifier_lines(mods: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var water_mult: float = mods.get("water_mult", 1.0) as float
	if not is_equal_approx(water_mult, 1.0):
		out.append(Localization.ru_en("расход воды %+d%%", "water use %+d%%") % int(round((water_mult - 1.0) * 100.0)))
	var crop_mult: float = mods.get("crop_mult", 1.0) as float
	if not is_equal_approx(crop_mult, 1.0):
		out.append(Localization.ru_en("урожай %+d%%", "harvest %+d%%") % int(round((crop_mult - 1.0) * 100.0)))
	var solar_mult: float = mods.get("solar_mult", 1.0) as float
	if not is_equal_approx(solar_mult, 1.0):
		out.append(Localization.ru_en("солнечные панели %+d%%", "solar panels %+d%%") % int(round((solar_mult - 1.0) * 100.0)))
	var build_mult: float = mods.get("build_cost_mult", 1.0) as float
	if not is_equal_approx(build_mult, 1.0):
		out.append(Localization.ru_en("стоимость стройки %+d%%", "build cost %+d%%") % int(round((build_mult - 1.0) * 100.0)))
	var wear_mult: float = mods.get("wear_mult", 1.0) as float
	if not is_equal_approx(wear_mult, 1.0):
		out.append(Localization.ru_en("износ техники %+d%%", "equipment wear %+d%%") % int(round((wear_mult - 1.0) * 100.0)))
	return out


func _intensity_word(intensity: String) -> String:
	match intensity:
		"calm": return Localization.ru_en("слабая", "low")
		"harsh": return Localization.ru_en("высокая", "high")
	return Localization.ru_en("средняя", "moderate")


func _net_text(net: float) -> String:
	if net > 0.05:
		return Localization.ru_en("[color=#7fbf7f]+%.1f/день[/color]", "[color=#7fbf7f]+%.1f/day[/color]") % net
	if net < -0.05:
		return Localization.ru_en("[color=#d98c66]%.1f/день[/color]", "[color=#d98c66]%.1f/day[/color]") % net
	return Localization.ru_en("ровно", "steady")


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
	bg.color = Color(0.05, 0.06, 0.08, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(640, 500)
	panel.position = Vector2(-320, -250)
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

	_title = Label.new()
	var title := _title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.custom_minimum_size = Vector2(580, 360)
	_body.add_theme_font_size_override("normal_font_size", 14)
	vbox.add_child(_body)

	_close_btn = Button.new()
	_close_btn.pressed.connect(_toggle)
	vbox.add_child(_close_btn)
	_apply_static_text()
