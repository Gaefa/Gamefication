extends Node
## OnboardingManager (Autoload)
## Built-in onboarding (UX_BIBLE §14): no separate tutorial — short contextual hints,
## one new idea at a time, dismissible, never repeating. Each hint fires once on a
## first-time condition; "shown" ids persist in GameStateStore.onboarding().
##
## Hints are queued and flushed only while the game is running (not over the desk /
## a crisis card / the finale), so they never fight a modal for attention.
## Self-contained autoload — owns its own banner, no HUD/main edits.

const HINTS := {
	"welcome": "Здесь всё начинается с воды. Постройте дорогу, колодец-насос и жильё. На паузе (Пробел) строить можно спокойно.",
	"water_days": "Вверху — «Воды на N дней»: сколько город протянет при текущем расходе. Не дайте упасть к нулю, особенно перед Пылью.",
	"building_problem": "Над зданием значок проблемы. Кликните по зданию — игра покажет причину, но чинить решаете вы.",
	"season_dust": "Сезон Пыли: воды уходит больше, урожай падает. Нажмите K — там прогноз и чек-лист готовности. J — дневник прежнего администратора.",
}

var _queue: Array[String] = []
var _active: String = ""

var _layer: CanvasLayer
var _label: Label
var _panel: PanelContainer


func _ready() -> void:
	_build_ui()
	EventBus.new_game_started.connect(func() -> void: _offer("welcome"))
	EventBus.building_issue_added.connect(func(_coord: Vector2i) -> void: _offer("building_problem"))
	EventBus.season_changed.connect(func(season_id: String, _d: int, _l: int) -> void:
		if season_id == "season_dust":
			_offer("season_dust"))
	EventBus.tick_finished.connect(_on_tick_finished)


func _on_tick_finished(_tick: int) -> void:
	# Water-days hint: first time the reserve dips into "watch it" territory.
	if GameStateStore.get_resource("res_water_stockpile") <= 70.0:
		_offer("water_days")
	_flush()


func _offer(hint_id: String) -> void:
	if not HINTS.has(hint_id):
		return
	if _is_shown(hint_id) or _active == hint_id or _queue.has(hint_id):
		return
	_queue.append(hint_id)


func _flush() -> void:
	if _active != "" or _queue.is_empty():
		return
	if SimulationRunner.paused:
		return  # don't pop a hint over the desk / crisis / finale
	_active = _queue.pop_front()
	_label.text = HINTS[_active] as String
	_layer.visible = true


func _dismiss() -> void:
	if _active != "":
		_mark_shown(_active)
		_active = ""
	_layer.visible = false
	_flush()


func _is_shown(hint_id: String) -> bool:
	return (GameStateStore.onboarding().get("shown", []) as Array).has(hint_id)


func _mark_shown(hint_id: String) -> void:
	var shown: Array = GameStateStore.onboarding().get("shown", []) as Array
	if not shown.has(hint_id):
		shown.append(hint_id)


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 120  # above HUD, below diary/season (150) and finale (200)
	_layer.visible = false
	add_child(_layer)

	_panel = PanelContainer.new()
	# Bottom-center, clear of the top resource bar and the right build menu.
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -300
	_panel.offset_right = 300
	_panel.offset_top = -130
	_panel.offset_bottom = -40
	_layer.add_child(_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.11, 0.16, 0.96)
	style.border_color = Color(0.55, 0.5, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	var head := Label.new()
	head.text = "ПОДСКАЗКА"
	head.add_theme_font_size_override("font_size", 11)
	head.add_theme_color_override("font_color", Color(0.7, 0.66, 0.5))
	vbox.add_child(head)

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(572, 0)
	_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_label)

	var btn := Button.new()
	btn.text = "Понятно"
	btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn.pressed.connect(_dismiss)
	vbox.add_child(btn)
