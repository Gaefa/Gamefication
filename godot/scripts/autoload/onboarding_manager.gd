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
	# --- First-session chain: one step at a time, the next unlocks when the previous is done ---
	"welcome": ["Вы — администратор Ржавой Норы. Цель: пережить Пыль (дни 19–29), Жару (30–38) и аудиты на 20-й и 36-й. Продержитесь до дня 40 со счастьем не ниже 40. Первый шаг — вода: дорога → колодец-насос → барак. Пробел — пауза, H — справка.",
		"You are the administrator of the Rust Pit. Goal: survive Dust (days 19–29), Heat (30–38), and audits on days 20 and 36. Reach day 40 with mood at least 40. First step is water: road → well pump → shelter. Space pauses, H opens help."],
	"build_road": ["Справа «Инфраструктура» → «Дорога». Кликайте по клеткам от поста администрации. Здания работают только рядом с дорогой.",
		"On the right, \"Infrastructure\" → \"Road\". Click tiles outward from the administration post. Buildings only work next to a road."],
	"build_pump": ["Теперь «Колодец-насос» у дороги — он даёт воду в радиусе 4 клеток (V покажет радиус). Второй насос — второй запас на Пыль.",
		"Now a \"Well Pump\" by the road: it gives water within 4 tiles (V shows the range). A second pump is a second reserve for the Dust."],
	"build_shelter": ["«Жильё» → «Барак» в зоне воды — приедут жители. Барак без воды пустует. Кликните по зданию — увидите, чего ему не хватает.",
		"\"Residential\" → \"Shelter\" inside the water zone, and residents will arrive. A shelter without water stays empty. Click a building to see what it lacks."],
	"first_desk": ["Так будет каждый вечер: письма и обращения на Столе, последствия написаны под каждым ответом. Всё, что вы ответили, хранится в журнале (T).",
		"This happens every evening: letters and petitions on the Desk, with the consequences written under each answer. Everything you answered is kept in the log (T)."],
	# --- Contextual: fire on the first occurrence of the situation ---
	"water_days": ["Вверху — «Воды на N дней»: сколько город протянет при текущем расходе. Не дайте упасть к нулю, особенно перед Пылью.",
		"At the top, \"Water for N days\": how long the city lasts at current use. Don't let it hit zero, especially before the Dust."],
	"building_problem": ["Над зданием значок проблемы. Кликните по зданию — игра покажет причину, но чинить решаете вы.",
		"A problem icon over a building. Click it and the game shows the cause; the fix is up to you."],
	"season_heat": ["Жара: еда портится, воды нужно больше. Склад ур. 2 снижает потери. Держите цистерну выше 30% и проверьте напор у жилья. E — прогноз.",
		"Heat: food spoils and water use rises. A level 2 warehouse cuts losses. Keep the cistern above 30% and check housing pressure. E opens the forecast."],
	"season_dust": ["Сезон Пыли: воды уходит больше, урожай падает. Нажмите E — там прогноз и чек-лист готовности. Y — дневник прежнего администратора.",
		"Dust season: water goes faster, harvests drop. Press E for the forecast and readiness checklist. Y opens the previous administrator's diary."],
}

## The first-session chain in order, with the building count that completes each step
## (the starter hub already has 3 roads, 1 pump, 1 shelter).
const CHAIN := [
	{ "id": "welcome" },
	{ "id": "build_road", "type": "bld_road", "min": 5 },
	{ "id": "build_pump", "type": "bld_well_pump", "min": 2 },
	{ "id": "build_shelter", "type": "bld_shelter", "min": 2 },
]

var _queue: Array[String] = []
var _active: String = ""
## Set by the HUD while the start menu is open, so the first hint waits for the game proper.
var suppressed: bool = false

var _layer: CanvasLayer
var _label: Label
var _panel: PanelContainer
var _head: Label
var _btn: Button


func _ready() -> void:
	_build_ui()
	EventBus.run_reset.connect(_reset)
	EventBus.new_game_started.connect(func() -> void: _offer("welcome"))
	EventBus.building_issue_added.connect(func(_coord: Vector2i) -> void: _offer("building_problem"))
	EventBus.season_changed.connect(func(season_id: String, _d: int, _l: int) -> void:
		if HINTS.has(season_id):
			_offer(season_id))
	EventBus.tick_finished.connect(_on_tick_finished)
	Localization.locale_changed.connect(func(_locale: String) -> void: _apply_text())
	EventBus.desk_closed.connect(func() -> void:
		if _is_shown("welcome") and not TutorialManager.ran_this_run:
			_offer("first_desk"))


## Hints queued for the menu map or the previous run must not pop up in this one.
func _reset() -> void:
	_queue.clear()
	_active = ""
	_layer.visible = false


func _on_tick_finished(_tick: int) -> void:
	_advance_chain()
	# Water-days hint: first time the reserve dips into "watch it" territory.
	if GameStateStore.get_resource("res_water_stockpile") <= 70.0:
		_offer("water_days")
	_flush()


## Offers the next chain step whose predecessor is done. A step with a building goal
## waits until the player has actually built it, so the hints follow the player's hands.
func _advance_chain() -> void:
	if TutorialManager.ran_this_run:
		# The guided tutorial teaches the same steps hands-on. Mark them in the run state, so
		# a Continue of this run (where ran_this_run is false again) doesn't start the chain.
		for step: Dictionary in CHAIN:
			_mark_shown(step.get("id", "") as String)
		_mark_shown("first_desk")
		return
	for i: int in CHAIN.size():
		var step: Dictionary = CHAIN[i] as Dictionary
		var hint_id: String = step.get("id", "") as String
		if _is_shown(hint_id):
			continue
		if i > 0 and not _is_shown((CHAIN[i - 1] as Dictionary).get("id", "") as String):
			return
		if step.has("type") and _count_type(step.get("type", "") as String) < (step.get("min", 1) as int):
			return
		_offer(hint_id)
		return


func _count_type(type_id: String) -> int:
	var n: int = 0
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		if (GameStateStore.get_building(coord).get("type", "") as String) == type_id:
			n += 1
	return n


func _offer(hint_id: String) -> void:
	if not HINTS.has(hint_id):
		return
	if _is_shown(hint_id) or _active == hint_id or _queue.has(hint_id):
		return
	_queue.append(hint_id)


func _flush() -> void:
	if _active != "" or _queue.is_empty():
		return
	# The guided tutorial already taught the chain steps hands-on: drop them unseen.
	if TutorialManager.ran_this_run:
		for step: Dictionary in CHAIN:
			var chain_id: String = step.get("id", "") as String
			if _queue.has(chain_id):
				_queue.erase(chain_id)
				_mark_shown(chain_id)
		if _queue.is_empty():
			return
	if SimulationRunner.paused or suppressed or TutorialManager.active:
		return  # don't pop a hint over the desk / crisis / finale / start menu
	_queue.assign(_queue.filter(func(id: String) -> bool: return not _is_shown(id)))
	if _queue.is_empty():
		return
	_active = _queue.pop_front()
	_apply_text()
	_layer.visible = true


## Hint entries are [ru, en]; re-applied on a language switch while the banner is up.
func _apply_text() -> void:
	_head.text = Localization.ru_en("ПОДСКАЗКА", "HINT")
	_btn.text = Localization.ru_en("Понятно", "Got it")
	if _active != "":
		var pair: Array = HINTS[_active] as Array
		_label.text = Localization.ru_en(pair[0] as String, pair[1] as String)


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
	_panel.offset_top = -165
	_panel.offset_bottom = -40
	_layer.add_child(_panel)

	var style: StyleBoxFlat = UiStyle.panel_box(14)
	style.border_color = UiStyle.ACCENT_DIM
	_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	_head = Label.new()
	var head := _head
	UiStyle.caption(head)
	vbox.add_child(head)

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(572, 0)
	_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_label)

	_btn = Button.new()
	var btn := _btn
	btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn.pressed.connect(_dismiss)
	vbox.add_child(btn)
	_apply_text()
