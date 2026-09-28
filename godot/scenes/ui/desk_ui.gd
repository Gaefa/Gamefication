extends Control
## DeskUI — полноэкранный интерфейс "Стола Администратора".
## Активируется вечером. Секретарь приносит почту.
## Игрок разбирает карточки событий и ставит резолюции.

var _events: Array = []
var _current_index: int = 0
var _resolved_count: int = 0
## Критический режим: одна срочная карточка посреди дня. По завершении просто
## снимаем паузу и возвращаемся в день, НЕ переходя к новому дню (в отличие от Стола).
var _critical_mode: bool = false

# UI nodes (создаются динамически)
var _bg: ColorRect
var _title_label: Label
var _header_label: Label
var _body_label: RichTextLabel
var _options_container: VBoxContainer
var _counter_label: Label
var _next_btn: Button
var _finish_btn: Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	EventBus.evening_started.connect(_on_evening_started)
	EventBus.critical_event_started.connect(_on_critical_event_started)
	_build_ui()


func _build_ui() -> void:
	# Полноэкранный тёмный фон
	_bg = ColorRect.new()
	_bg.color = Color(0.08, 0.06, 0.12, 0.95)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)
	
	# Центральная панель
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(700, 500)
	panel.position = Vector2(-350, -250)
	_bg.add_child(panel)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	
	# Заголовок: "Стол Администратора"
	_title_label = Label.new()
	_title_label.text = Localization.ru_en("СТОЛ АДМИНИСТРАТОРА", "THE ADMINISTRATOR'S DESK")
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_title_label)
	
	# Счётчик: "Письмо 1 из 3"
	_counter_label = Label.new()
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter_label.add_theme_font_size_override("font_size", 14)
	_counter_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(_counter_label)
	
	# Разделитель
	var sep := HSeparator.new()
	vbox.add_child(sep)
	
	# Заголовок события
	_header_label = Label.new()
	_header_label.add_theme_font_size_override("font_size", 18)
	_header_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_header_label)
	
	# Тело события
	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = true
	_body_label.fit_content = true
	_body_label.custom_minimum_size = Vector2(0, 120)
	_body_label.scroll_active = false
	_body_label.add_theme_font_size_override("normal_font_size", 15)
	vbox.add_child(_body_label)
	
	# Контейнер для кнопок-вариантов
	_options_container = VBoxContainer.new()
	_options_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_options_container)
	
	# Разделитель
	var sep2 := HSeparator.new()
	vbox.add_child(sep2)
	
	# Кнопка "Следующее письмо"
	_next_btn = Button.new()
	_next_btn.text = Localization.ru_en("Следующее письмо →", "Next letter →")
	_next_btn.visible = false
	_next_btn.pressed.connect(_show_next_event)
	vbox.add_child(_next_btn)
	
	# Кнопка "Завершить вечер"
	_finish_btn = Button.new()
	_finish_btn.text = Localization.ru_en("Завершить вечер — начать новый день", "End the evening — start a new day")
	_finish_btn.visible = false
	_finish_btn.pressed.connect(_finish_evening)
	vbox.add_child(_finish_btn)


func _on_critical_event_started(event_data: Dictionary) -> void:
	# Срочная карточка посреди дня. Игра уже на паузе (EventManager).
	_critical_mode = true
	SimulationRunner.card_open = true
	_events = [event_data]
	_current_index = 0
	_resolved_count = 0
	_title_label.text = Localization.ru_en("СРОЧНО", "URGENT")
	_show_event(0)
	visible = true
	EventBus.desk_opened.emit(_events)


func _on_evening_started(events: Array) -> void:
	_critical_mode = false
	_title_label.text = Localization.ru_en("СТОЛ АДМИНИСТРАТОРА", "THE ADMINISTRATOR'S DESK")
	_events = events
	_current_index = 0
	_resolved_count = 0

	if _events.is_empty():
		# Нет почты — тихий вечер
		_show_empty_desk()
	else:
		_show_event(_current_index)
	
	visible = true
	EventBus.desk_opened.emit(_events)


func _show_event(index: int) -> void:
	if index >= _events.size():
		_show_all_resolved()
		return
	
	var evt: Dictionary = _events[index]
	_counter_label.text = Localization.ru_en("Письмо %d из %d", "Letter %d of %d") % [index + 1, _events.size()]
	_header_label.text = Localization.content_text(evt, "title", evt.get("runtime_id", Localization.ru_en("Событие", "Event")) as String)
	_body_label.text = Localization.content_text(evt, "body", Localization.content_text(evt, "text", ""))
	_next_btn.text = Localization.ru_en("Следующее письмо →", "Next letter →")
	
	# Очищаем старые кнопки
	for child: Node in _options_container.get_children():
		child.queue_free()
	
	_next_btn.visible = false
	_finish_btn.visible = false
	
	# Создаём кнопки вариантов
	var options: Array = evt.get("options", [])
	if options.is_empty():
		# Старый формат (accept/decline)
		_create_legacy_buttons(evt)
	else:
		# Новый TDD-формат (массив options с text/effects)
		for i: int in options.size():
			var opt: Dictionary = options[i] as Dictionary
			var btn := Button.new()
			btn.text = Localization.content_text(opt, "text", Localization.ru_en("Вариант %d", "Option %d") % (i + 1))
			var event_id: String = evt.get("runtime_id", "") as String
			var effects: Dictionary = opt.get("effects", {})
			var cost: Dictionary = opt.get("cost", {})
			btn.tooltip_text = _consequences_text(effects, cost)
			if not cost.is_empty() and not GameStateStore.can_afford(cost):
				btn.disabled = true
				btn.text += Localization.ru_en(" (не хватает ресурсов)", " (not enough resources)")
			var opt_idx: int = i
			btn.pressed.connect(func() -> void: _select_option(event_id, opt_idx, effects, cost))
			_options_container.add_child(btn)


func _create_legacy_buttons(evt: Dictionary) -> void:
	var event_id: String = evt.get("runtime_id", evt.get("id", "")) as String
	
	# Accept
	var accept_btn := Button.new()
	accept_btn.text = Localization.content_text(evt, "accept_label", Localization.ru_en("Принять", "Accept"))
	var accept_effects: Dictionary = evt.get("accept_effects", {})
	var accept_cost: Variant = evt.get("accept_cost", null)
	if accept_cost is Dictionary and not (accept_cost as Dictionary).is_empty():
		if not GameStateStore.can_afford(accept_cost as Dictionary):
			accept_btn.disabled = true
			accept_btn.text += Localization.ru_en(" (не хватает ресурсов)", " (not enough resources)")
	var accept_cost_dict: Dictionary = accept_cost as Dictionary if accept_cost is Dictionary else {}
	accept_btn.tooltip_text = _consequences_text(accept_effects, accept_cost_dict)
	accept_btn.pressed.connect(func() -> void: _select_option(event_id, 0, accept_effects, accept_cost_dict))
	_options_container.add_child(accept_btn)
	
	# Decline
	var decline_btn := Button.new()
	decline_btn.text = Localization.content_text(evt, "decline_label", Localization.ru_en("Отклонить", "Decline"))
	var decline_effects: Dictionary = evt.get("decline_effects", {})
	decline_btn.tooltip_text = _consequences_text(decline_effects, {})
	decline_btn.pressed.connect(func() -> void: _select_option(event_id, 1, decline_effects, {}))
	_options_container.add_child(decline_btn)


const RES_LABELS := {
	"res_water_stockpile": "вода", "res_food": "еда", "res_wood": "дерево",
	"res_stone": "камень", "res_tools": "инструменты", "res_money": "деньги",
}
const RES_LABELS_EN := {
	"res_water_stockpile": "water", "res_food": "food", "res_wood": "wood",
	"res_stone": "stone", "res_tools": "tools", "res_money": "money",
}


func _res_label(res_id: String) -> String:
	return Localization.ru_en(RES_LABELS.get(res_id, res_id) as String, RES_LABELS_EN.get(res_id, res_id) as String)


## Hover preview of an answer (UX_BIBLE §7.1): the player shouldn't guess what a stamp does.
## Style and flags stay hidden — naming them would spoil the finale.
func _consequences_text(effects: Dictionary, cost: Dictionary) -> String:
	var parts: Array[String] = []
	for key: String in effects:
		var value: Variant = effects[key]
		match key:
			"stat_league_trust":
				parts.append(Localization.ru_en("доверие покровителя %s", "patron trust %s") % _signed(value as float))
			"stat_city_trust":
				parts.append(Localization.ru_en("поддержка города %s", "city support %s") % _signed(value as float))
			"stat_unrest_pressure":
				parts.append(Localization.ru_en("давление «люди» %s", "\"people\" pressure %s") % _signed(value as float))
			"add_resources", "remove_resources":
				var mult: float = 1.0 if key == "add_resources" else -1.0
				for res_id: String in value as Dictionary:
					parts.append("%s %s" % [_res_label(res_id), _signed(mult * ((value as Dictionary)[res_id] as float))])
			"demolish_building":
				parts.append(Localization.ru_en("снос: %s", "demolition: %s") % _building_name(value as String))
			"replace_building":
				parts.append(Localization.ru_en("перестройка: %s", "rebuild: %s") % _building_name((value as Dictionary).get("to", "") as String))
			"force_issues":
				parts.append(Localization.ru_en("поломки: %d", "breakdowns: %d") % (value as int))
			"damage_buildings":
				parts.append(Localization.ru_en("повреждённых зданий: %d", "buildings damaged: %d") % (value as int))
			_:
				if key.begins_with("res_"):
					parts.append("%s %s" % [_res_label(key), _signed(value as float)])
	var lines: Array[String] = []
	if not parts.is_empty():
		lines.append(Localization.ru_en("Следствие: ", "Effect: ") + ", ".join(parts))
	if not cost.is_empty():
		var costs: Array[String] = []
		for res_id: String in cost:
			costs.append("%s %d" % [_res_label(res_id), int(cost[res_id] as float)])
		lines.append(Localization.ru_en("Цена: ", "Cost: ") + ", ".join(costs))
	return "\n".join(lines)


func _signed(v: float) -> String:
	return "%+d" % int(v)


func _building_name(type_id: String) -> String:
	return Localization.content_text(ContentDB.get_building_def(type_id), "name", type_id)


func _select_option(event_id: String, option_index: int, effects: Dictionary, cost: Dictionary = {}) -> void:
	# Guard: disable all option buttons immediately to prevent double-click
	for child: Node in _options_container.get_children():
		if child is Button:
			(child as Button).disabled = true
	
	EventBus.desk_option_selected.emit(event_id, option_index, effects, cost)
	_log_answer(option_index, effects)
	_resolved_count += 1

	if _current_index < _events.size() - 1:
		_next_btn.visible = true
	else:
		_show_all_resolved()


## Journal entry (UX_BIBLE §7.2) from the card's own text, so dynamic cards (the audit) read right too.
func _log_answer(option_index: int, effects: Dictionary) -> void:
	if _current_index >= _events.size():
		return
	var evt: Dictionary = _events[_current_index] as Dictionary
	var options: Array = evt.get("options", []) as Array
	# Keep both languages (and any localization keys) so the journal follows a later language switch.
	var entry: Dictionary = {}
	_copy_text(entry, "title", evt, "title")
	if (entry.get("title", "") as String) == "":
		entry["title"] = evt.get("runtime_id", "") as String
	if option_index < options.size():
		_copy_text(entry, "choice", options[option_index] as Dictionary, "text")
	else:
		_copy_text(entry, "choice", evt, "accept_label" if option_index == 0 else "decline_label")
	_copy_text(entry, "reply", effects, "message")
	EventLogPanel.record(entry)


func _copy_text(dst: Dictionary, dst_field: String, src: Dictionary, field: String) -> void:
	dst[dst_field] = src.get(field, "") as String
	for suffix: String in ["_en", "_key"]:
		if src.has(field + suffix):
			dst[dst_field + suffix] = src[field + suffix] as String


func _show_next_event() -> void:
	_current_index += 1
	_show_event(_current_index)


func _show_all_resolved() -> void:
	_counter_label.text = ""
	for child: Node in _options_container.get_children():
		child.queue_free()
	_next_btn.visible = false
	if _critical_mode:
		_header_label.text = Localization.ru_en("Решение принято", "Decision made")
		_body_label.text = Localization.ru_en("Последствия уже в силе. Возвращаемся к делам района.", "The consequences are already in effect. Back to district business.")
		_finish_btn.text = Localization.ru_en("Вернуться к городу", "Return to the city")
	else:
		_header_label.text = Localization.ru_en("Вся почта разобрана", "All mail handled")
		_body_label.text = Localization.ru_en("Вы обработали %d писем. Готовы начать новый день?", "You handled %d letters. Ready to start a new day?") % _resolved_count
		_finish_btn.text = Localization.ru_en("Завершить вечер — начать новый день", "End the evening — start a new day")
	_finish_btn.visible = true


func _show_empty_desk() -> void:
	_header_label.text = Localization.ru_en("Тихий вечер", "A quiet evening")
	_body_label.text = Localization.ru_en("Сегодня почты нет. Секретарь говорит, что жители довольны... пока что.", "No mail today. The secretary says the residents are content... for now.")
	_finish_btn.text = Localization.ru_en("Завершить вечер — начать новый день", "End the evening — start a new day")
	_counter_label.text = ""
	for child: Node in _options_container.get_children():
		child.queue_free()
	_next_btn.visible = false
	_finish_btn.visible = true


func _finish_evening() -> void:
	visible = false
	EventBus.desk_closed.emit()
	if _critical_mode:
		# Срочная карточка: просто снимаем паузу и продолжаем тот же день.
		_critical_mode = false
		SimulationRunner.card_open = false
		SimulationRunner.paused = false
	else:
		SimulationRunner.transition_to_morning()
