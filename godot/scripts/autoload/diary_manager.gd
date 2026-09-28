extends Node
## DiaryManager (Autoload)
## Прежний администратор оставил дневник (CONTENT_BIBLE §5). Фрагменты находятся
## ПО ПОРЯДКУ (цепочка): следующий открывается, только когда выполнено его условие
## (день / наступление сезона / порог состояния). Найденные фрагменты хранятся в
## GameStateStore.diary().discovered и читаются в панели (клавиша J).
##
## Self-contained: владеет своей панелью (CanvasLayer), не трогает HUD/main.

var _panel_visible: bool = false

# UI
var _layer: CanvasLayer
var _root: Control
var _list: VBoxContainer
var _empty_label: Label
var _title: Label
var _close_btn: Button


func _ready() -> void:
	_build_ui()
	EventBus.tick_finished.connect(_on_tick_finished)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and (ke.keycode == KEY_J or ke.physical_keycode == KEY_J):
			# Не открываем поверх Стола/кризиса/финала (они ставят паузу).
			if SimulationRunner.paused and not _panel_visible:
				return
			_toggle()
			get_viewport().set_input_as_handled()


func _on_tick_finished(_tick: int) -> void:
	_evaluate_next()


func _evaluate_next() -> void:
	var fragments: Array = ContentDB.get_diary_fragments()
	var discovered: Array = GameStateStore.diary().get("discovered", []) as Array
	var idx: int = discovered.size()
	if idx >= fragments.size():
		return
	var frag: Dictionary = fragments[idx] as Dictionary
	if _unlock_met(frag.get("unlock", {}) as Dictionary):
		_discover(frag)


func _unlock_met(cond: Dictionary) -> bool:
	if cond.is_empty():
		return false
	if cond.has("day"):
		return (GameStateStore.climate().get("total_day", 1) as int) >= (cond.get("day", 1) as int)
	if cond.has("season"):
		return (GameStateStore.climate().get("season_id", "") as String) == (cond.get("season", "") as String)
	if cond.has("metric"):
		var val: float = _metric_value(cond.get("metric", "") as String)
		var threshold: float = cond.get("value", 0.0) as float
		match cond.get("op", "<=") as String:
			"<=": return val <= threshold
			">=": return val >= threshold
			"<": return val < threshold
			">": return val > threshold
			"==": return is_equal_approx(val, threshold)
	return false


func _metric_value(metric: String) -> float:
	if metric.begins_with("res_"):
		return GameStateStore.get_resource(metric)
	match metric:
		"stat_league_trust":
			return GameStateStore.mandate().get("patron_trust", 50) as float
		"stat_city_trust":
			return GameStateStore.mandate().get("support", 50) as float
		"stat_unrest_pressure":
			return GameStateStore.pressure().get("index", 0.0) as float
		"stat_happiness":
			return GameStateStore.population().get("happiness", 50.0) as float
	return 0.0


func _discover(frag: Dictionary) -> void:
	var fid: String = frag.get("id", "") as String
	var discovered: Array = GameStateStore.diary().get("discovered", []) as Array
	if discovered.has(fid):
		return
	discovered.append(fid)
	EventBus.diary_fragment_found.emit(fid)
	EventBus.toast_requested.emit(Localization.ru_en("Найден фрагмент дневника прежнего администратора (J)", "Found a fragment of the previous administrator's diary (J)"), 5.0)
	if _panel_visible:
		_rebuild_list()


# --- UI ---

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 150  # above HUD, below finale (200)
	_layer.visible = false
	add_child(_layer)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(_root)

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.04, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(680, 520)
	panel.position = Vector2(-340, -260)
	bg.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(_title)

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(620, 380)
	vbox.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 16)
	scroll.add_child(_list)

	_empty_label = Label.new()
	_empty_label.text = _empty_text()
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.add_theme_color_override("font_color", Color(0.7, 0.68, 0.6))
	_list.add_child(_empty_label)

	_close_btn = Button.new()
	_close_btn.pressed.connect(_toggle)
	vbox.add_child(_close_btn)


func _toggle() -> void:
	_panel_visible = not _panel_visible
	if _panel_visible:
		_rebuild_list()
	_layer.visible = _panel_visible


func _rebuild_list() -> void:
	for child: Node in _list.get_children():
		child.queue_free()
	_title.text = Localization.ru_en("ДНЕВНИК ПРЕЖНЕГО АДМИНИСТРАТОРА", "THE PREVIOUS ADMINISTRATOR'S DIARY")
	_close_btn.text = Localization.ru_en("Закрыть (J)", "Close (J)")
	var discovered: Array = GameStateStore.diary().get("discovered", []) as Array
	if discovered.is_empty():
		var empty := Label.new()
		empty.text = _empty_text()
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", Color(0.7, 0.68, 0.6))
		_list.add_child(empty)
		return
	for fid_var: Variant in discovered:
		var def: Dictionary = ContentDB.get_diary_fragment_def(fid_var as String)
		if def.is_empty():
			continue
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 4)
		var head := Label.new()
		head.text = Localization.content_text(def, "title", Localization.ru_en("Фрагмент", "Fragment"))
		head.add_theme_font_size_override("font_size", 15)
		head.add_theme_color_override("font_color", Color(0.92, 0.86, 0.62))
		entry.add_child(head)
		var body := Label.new()
		body.text = Localization.content_text(def, "body", "")
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_font_size_override("font_size", 13)
		entry.add_child(body)
		_list.add_child(entry)


func _empty_text() -> String:
	return Localization.ru_en("Пока ничего не найдено. Следы прежнего администратора всплывают по ходу дел района.", "Nothing found yet. Traces of the previous administrator surface as you run the district.")
