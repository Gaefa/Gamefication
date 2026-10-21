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
var _root: Control
var _list: VBoxContainer
var _title: Label
var _close_btn: Button


func _ready() -> void:
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and (ke.keycode == KEY_T or ke.physical_keycode == KEY_T or ke.keycode == KEY_N or ke.physical_keycode == KEY_N):
			# Не открываем поверх Стола/кризиса/финала (они ставят паузу).
			if SimulationRunner.blocks_panels() and not _panel_visible:
				return
			_toggle()
			get_viewport().set_input_as_handled()


## Called by the Desk when an answer is stamped. `texts` holds title/choice/reply
## plus optional `_en` / `_key` siblings, read back through Localization.content_text.
func record(texts: Dictionary) -> void:
	var ev_state: Dictionary = GameStateStore.events()
	if not ev_state.has("log"):
		ev_state["log"] = []
	var entry: Dictionary = texts.duplicate()
	entry["day"] = GameStateStore.climate().get("total_day", 1) as int
	(ev_state["log"] as Array).append(entry)


# --- UI ---

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 150  # above HUD, below finale (200)
	_layer.visible = false
	add_child(_layer)

	_root = Control.new()
	var root: Control = _root
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(root)

	var frame: Dictionary = UiStyle.modal(root)
	(frame["dim"] as Control).visible = true
	_title = frame["title"] as Label
	_close_btn = frame["close"] as Button
	_close_btn.pressed.connect(_toggle)
	var vbox: VBoxContainer = frame["body"] as VBoxContainer

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(592, 320)
	vbox.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 14)
	scroll.add_child(_list)



func _toggle() -> void:
	_panel_visible = not _panel_visible
	if _panel_visible:
		_rebuild_list()
	_layer.visible = _panel_visible
	if _panel_visible:
		UiModals.opened("log", _toggle)
		UiModals.reveal(_root)
	else:
		UiModals.closed("log")


func _rebuild_list() -> void:
	for child: Node in _list.get_children():
		child.queue_free()
	_title.text = Localization.ru_en("Журнал событий", "Event log")
	_close_btn.tooltip_text = Localization.ru_en("Закрыть (T или Esc)", "Close (T or Esc)")
	# What the district says about you, once a style has shown itself.
	var style: String = GameStateStore.dominant_style("")
	if style != "" and (GameStateStore.style_flags().get(style, 0) as int) >= 3:
		var names := {
			"loyal": Localization.ru_en("человек Лиги", "the patron's man"), "protector": Localization.ru_en("защитник города", "the city's protector"),
			"pragmatist": Localization.ru_en("прагматик", "a pragmatist"), "autonomist": Localization.ru_en("будущий автономист", "a future autonomist"),
		}
		var said := Label.new()
		said.text = Localization.ru_en("О вас говорят: %s.", "They say of you: %s.") % (names.get(style, style) as String)
		said.add_theme_font_size_override("font_size", 13)
		said.add_theme_color_override("font_color", UiStyle.ACCENT)
		_list.add_child(said)
	var entries: Array = GameStateStore.events().get("log", []) as Array
	if entries.is_empty():
		var empty := Label.new()
		empty.text = Localization.ru_en("Пока пусто. Сюда ложатся письма и петиции, на которые вы уже ответили.", "Empty so far. Letters and petitions you have answered end up here.")
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
		head.text = Localization.ru_en("День %d — %s", "Day %d — %s") % [e.get("day", 0) as int, Localization.content_text(e, "title", "")]
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		head.add_theme_font_size_override("font_size", 15)
		head.add_theme_color_override("font_color", UiStyle.TEXT)
		entry.add_child(head)
		var choice := Label.new()
		choice.text = "→ " + Localization.content_text(e, "choice", "")
		choice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice.add_theme_font_size_override("font_size", 13)
		entry.add_child(choice)
		var reply: String = Localization.content_text(e, "reply", "")
		if reply != "":
			var reply_label := Label.new()
			reply_label.text = reply
			reply_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			reply_label.add_theme_font_size_override("font_size", 12)
			reply_label.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
			entry.add_child(reply_label)
		_list.add_child(entry)
