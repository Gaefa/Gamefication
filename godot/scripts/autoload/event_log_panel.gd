extends Node
## EventLogPanel (Autoload)
## Журнал Событий (UX_BIBLE §7.2): письма покровителя, петиции и кризисы, на которые
## игрок уже ответил, — чтобы можно было вспомнить, что обещал и кому.
## Записи кладёт Стол (DeskUI → record) в GameStateStore.events().log; панель — клавиша N.
##
## Self-contained: владеет своей панелью (CanvasLayer), не трогает HUD/main.

var _panel_visible: bool = false

# UI
var _layer: CanvasLayer
var _list: VBoxContainer


func _ready() -> void:
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and (ke.keycode == KEY_N or ke.physical_keycode == KEY_N):
			# Не открываем поверх Стола/кризиса/финала (они ставят паузу).
			if SimulationRunner.paused and not _panel_visible:
				return
			_toggle()
			get_viewport().set_input_as_handled()


## Called by the Desk when an answer is stamped.
func record(title: String, choice: String, reply: String) -> void:
	var ev_state: Dictionary = GameStateStore.events()
	if not ev_state.has("log"):
		ev_state["log"] = []
	(ev_state["log"] as Array).append({
		"day": GameStateStore.climate().get("total_day", 1) as int,
		"title": title,
		"choice": choice,
		"reply": reply,
	})


# --- UI ---

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 150  # above HUD, below finale (200)
	_layer.visible = false
	add_child(_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(root)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.07, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bg)

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

	var title := Label.new()
	title.text = "ЖУРНАЛ СОБЫТИЙ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(620, 380)
	vbox.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 14)
	scroll.add_child(_list)

	var close_btn := Button.new()
	close_btn.text = "Закрыть (N)"
	close_btn.pressed.connect(_toggle)
	vbox.add_child(close_btn)


func _toggle() -> void:
	_panel_visible = not _panel_visible
	if _panel_visible:
		_rebuild_list()
	_layer.visible = _panel_visible


func _rebuild_list() -> void:
	for child: Node in _list.get_children():
		child.queue_free()
	var entries: Array = GameStateStore.events().get("log", []) as Array
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "Пока пусто. Сюда ложатся письма и петиции, на которые вы уже ответили."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		_list.add_child(empty)
		return
	# Newest first — the latest promise is the one the player is most likely looking for.
	for i: int in range(entries.size() - 1, -1, -1):
		var e: Dictionary = entries[i] as Dictionary
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 3)
		var head := Label.new()
		head.text = "День %d — %s" % [e.get("day", 0) as int, e.get("title", "") as String]
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		head.add_theme_font_size_override("font_size", 15)
		head.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
		entry.add_child(head)
		var choice := Label.new()
		choice.text = "→ " + (e.get("choice", "") as String)
		choice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice.add_theme_font_size_override("font_size", 13)
		entry.add_child(choice)
		var reply: String = e.get("reply", "") as String
		if reply != "":
			var reply_label := Label.new()
			reply_label.text = reply
			reply_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			reply_label.add_theme_font_size_override("font_size", 12)
			reply_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
			entry.add_child(reply_label)
		_list.add_child(entry)
