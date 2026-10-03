extends Control
## HUD: wrapping resource bar (two rows), right-anchored build menu with category tabs,
## actionable info panel, event popup, toast, and help.

const UiIcons := preload("res://scripts/scenes/ui_icons.gd")
const PlacementRulesRef := preload("res://scripts/core/buildings/placement_rules.gd")

# --- References ---
var _resource_bar: PanelContainer
var _city_label: Label          # season chip (click → season panel)
var _utility_label: Label       # water chip (click → water panel)
var _res_chips: Dictionary = {}  # res_id → {"value": Label, "delta": Label, "panel": Control}
var _pop_label: Label
var _happy_label: Label
var _level_label: Label
var _power_label: Label
var _trust_bar: ProgressBar
var _patron_label: Label
var _masters_arrow: Label
var _support_bar: ProgressBar
var _trust_value: Label
var _support_value: Label
var _rival_label: RichTextLabel
var _pressure_bars: Dictionary = {}  # category → {"bar": ProgressBar, "value": Label}

var _build_panel: PanelContainer
var _build_title_label: Label
var _build_city_button: Button
var _build_gov_button: Button
var _build_settings_button: Button
var _range_lens_button: Button
var _logistics_lens_button: Button
var _build_scroll: ScrollContainer
var _build_vbox: VBoxContainer
var _category_select: OptionButton
var _category_buttons: Dictionary = {}
var _active_category: String = ""
var _active_build_type: String = ""

var _info_panel: PanelContainer
var _info_label: RichTextLabel
var _info_actions: HBoxContainer
var _upgrade_button: Button
var _repair_button: Button
var _bulldoze_button: Button
const INFO_W := 380.0

var _toast_label: Label
var _toast_panel: PanelContainer
var _toast_timer: float = 0.0

var _start_panel: PanelContainer
var _start_visible: bool = true
var _help_panel: PanelContainer
var _help_label: Label
var _help_visible: bool = false
var _governance_panel: PanelContainer
var _governance_visible: bool = false
var _governance_tabs: TabContainer
var _city_panel: PanelContainer
var _city_visible: bool = false
var _settings_panel: PanelContainer
var _settings_visible: bool = false
var _settings_language_select: OptionButton

var _selected_coord: Vector2i = Vector2i(-9999, -9999)

var _build_entries: Array[Dictionary] = []  # {type_id, card, cost_labels: {res_id: Label}, locked}
var _hover_build_type: String = ""
var _category_rows: VBoxContainer

# --- Minimap ---
var _minimap_panel: PanelContainer
var _minimap_viewport: SubViewport
var _minimap_camera: Camera2D

# --- Menu State ---
var _start_menu_mode: String = "main" # "main", "campaign", "sandbox"
var _start_dim: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_resource_bar()
	_build_day_clock()
	_build_build_panel()
	_build_info_panel()
	_build_toast()
	_build_start_panel()
	_build_minimap()
	_build_left_column()
	_build_help_panel()
	_build_city_panel()
	_build_governance_panel()
	_build_settings_panel()
	_connect_signals()
	_set_active_category("Infrastructure")
	_position_below_resource_bar.call_deferred()
	move_child(_info_panel, _left_column.get_index())  # above the left column, below the pop-ups
	_start_dim.move_to_front()
	_start_panel.move_to_front()


func _process(delta: float) -> void:
	_update_day_clock()  # also reflects pause and speed, which emit no signal
	_update_minimap_camera()
	_update_toast_fade(delta)


func _update_minimap_camera() -> void:
	if _minimap_camera == null: return
	var main_node = get_tree().current_scene
	var main_cam = main_node.get_node_or_null("Camera")
	if main_cam:
		_minimap_camera.global_position = main_cam.global_position


## Texts set once when the HUD is built. They are re-applied when the language changes,
## so a switch on the menu or in Options leaves nothing in the old language.
var _static_texts: Array = []  # [control, property, text_fn]


func _loc(control: Control, text_fn: Callable, property: String = "text") -> void:
	_static_texts.append([control, property, text_fn])
	control.set(property, text_fn.call())


func _connect_signals() -> void:
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.toast_requested.connect(_on_toast)
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.new_game_started.connect(_on_new_game_started)
	EventBus.tick_finished.connect(_on_tick_finished)
	EventBus.coverage_recalculated.connect(_on_coverage_recalculated)
	EventBus.city_level_changed.connect(func(_lv: int) -> void:
		_rebuild_building_list()
		if _city_visible:
			_rebuild_city_panel()
	)
	EventBus.build_mode_changed.connect(_on_build_mode_changed)
	EventBus.ranges_changed.connect(_on_ranges_changed)
	EventBus.logistics_lens_changed.connect(_on_logistics_lens_changed)
	Localization.locale_changed.connect(_on_locale_changed)
	EventBus.day_timer_updated.connect(func(_left: float) -> void: _update_day_clock())
	EventBus.phase_changed.connect(func(_phase: String) -> void: _update_day_clock())


# ===========================================================
# RESOURCE BAR (top) — compact blocks: Core | City | Utilities | Risk
# ===========================================================

func _build_resource_bar() -> void:
	## Readable at a glance: every figure is its own chip (icon, number, trend), the two
	## masters and the four pressures are bars, not digits in a sentence.
	_resource_bar = PanelContainer.new()
	_resource_bar.set_anchors_preset(PRESET_TOP_WIDE)
	_resource_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_resource_bar.resized.connect(_position_below_resource_bar)
	var bar_style: StyleBoxFlat = UiStyle.box(Color("0f0d0bfa"), UiStyle.LINE, 0, 8, 0)
	bar_style.border_width_bottom = 1
	bar_style.content_margin_top = 6
	bar_style.content_margin_bottom = 6
	_resource_bar.add_theme_stylebox_override("panel", bar_style)
	add_child(_resource_bar)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	_resource_bar.add_child(rows)
	var top := HFlowContainer.new()
	top.add_theme_constant_override("h_separation", 6)
	top.add_theme_constant_override("v_separation", 4)
	rows.add_child(top)
	var bottom := HFlowContainer.new()
	bottom.add_theme_constant_override("h_separation", 6)
	bottom.add_theme_constant_override("v_separation", 4)
	rows.add_child(bottom)

	# --- Row 1: what you have ---
	_res_chips.clear()
	for res_id: String in _top_resource_ids():
		var box: HBoxContainer = _chip(top)
		_chip_icon(box, UiIcons.RESOURCES.get(res_id, "") as String)
		var value: Label = _chip_text(box, 15, Color(0.97, 0.95, 0.88))
		var delta: Label = _chip_text(box, 11, Color(0.6, 0.6, 0.6))
		_res_chips[res_id] = { "value": value, "delta": delta, "panel": box.get_parent() }
	var pop_box: HBoxContainer = _chip(top)
	_chip_icon(pop_box, "people")
	_pop_label = _chip_text(pop_box, 14, Color(0.97, 0.95, 0.88))
	_happy_label = _chip_text(_chip(top, func() -> String: return Localization.ru_en(
		"Счастье жителей: вода, еда, жильё. Аудит требует не ниже %d%%.",
		"Residents' happiness: water, food, housing. The audit requires at least %d%%.") % int(MandateManager.HAPPINESS_OK)), 14, Color(0.97, 0.95, 0.88))
	_level_label = _chip_text(_chip(top, func() -> String: return Localization.ru_en(
		"Уровень поселения. Условия следующего уровня — кнопка «Город».",
		"Settlement level. The next level's requirements are under the City button.")), 12, Color(0.9, 0.85, 0.6))
	var power_box: HBoxContainer = _chip(top)
	_chip_icon(power_box, "power")
	_power_label = _chip_text(power_box, 12, Color(0.95, 0.85, 0.5))

	# --- Row 2: what threatens you ---
	var water_box: HBoxContainer = _chip(bottom)
	_chip_icon(water_box, "water")
	_utility_label = _chip_text(water_box, 14, Color(0.65, 0.85, 1.0))
	_utility_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_utility_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_utility_label.gui_input.connect(_on_utility_gui_input)

	_city_label = _chip_text(_chip(bottom), 13, Color(0.9, 0.85, 0.6))
	_city_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_city_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_city_label.gui_input.connect(_on_city_gui_input)

	# The two masters: a bar each, so "who is about to end me" reads without digits.
	var masters: HBoxContainer = _chip(bottom, func() -> String: return Localization.ru_en(
		"Доверие покровителя и поддержка города. Упадёт до нуля первое — вас отзовут, второе — бунт.",
		"Patron trust and city support. If the first hits zero you are recalled; the second — a riot."))
	_patron_label = _chip_text(masters, 12, Color(0.8, 0.8, 0.85))
	_trust_bar = _chip_bar(masters, 54)
	_trust_value = _chip_text(masters, 13, Color.WHITE)
	_masters_arrow = _chip_text(masters, 12, Color(0.6, 0.6, 0.6))
	_masters_arrow.text = "↕"
	_loc(_chip_text(masters, 12, Color(0.8, 0.8, 0.85)), func() -> String: return Localization.ru_en("Город", "City"))
	_support_bar = _chip_bar(masters, 54)
	_support_value = _chip_text(masters, 13, Color.WHITE)
	_rival_label = RichTextLabel.new()
	_rival_label.bbcode_enabled = true
	_rival_label.fit_content = true
	_rival_label.scroll_active = false
	_rival_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_rival_label.add_theme_font_size_override("normal_font_size", 12)
	_rival_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rival_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chip(bottom, func() -> String: return Localization.ru_en(
		"Сводный показатель района Мары Восс и ваш. По нему делят грант на %d-й день.",
		"The combined score of Mara Voss's district and yours. It decides the grant on day %d.") % ContentDB.get_grant_day()).add_child(_rival_label)

	# Pressure director: four gauges filling toward a crisis at 100.
	var pressure: HBoxContainer = _chip(bottom, func() -> String: return Localization.ru_en(
		"Давление: еда, вода, люди, мандат. Шкала дошла до 100 — на Стол приходит срочное письмо.",
		"Pressure: food, water, people, mandate. When a gauge reaches 100, an urgent letter lands on the Desk."))
	_loc(_chip_text(pressure, 12, Color(0.8, 0.8, 0.85)), func() -> String: return Localization.ru_en("Давление", "Pressure"))
	_pressure_bars.clear()
	for pair: Array in [["food", "food"], ["water", "water"], ["happiness", "people"], ["mandate", "mandate"]]:
		_chip_icon(pressure, pair[1] as String)
		var bar: ProgressBar = _chip_bar(pressure, 28)
		var num: Label = _chip_text(pressure, 11, Color(0.7, 0.7, 0.75))
		_pressure_bars[pair[0]] = { "bar": bar, "value": num }


func _chip(parent: Control, tip: Callable = Callable()) -> HBoxContainer:
	var panel := PanelContainer.new()
	var style: StyleBoxFlat = UiStyle.box(UiStyle.BG_RAISED, UiStyle.LINE, 5, 3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	if tip.is_valid():
		_loc(panel, tip, "tooltip_text")
	parent.add_child(panel)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	return box


func _chip_icon(box: HBoxContainer, icon: String, px: int = 18) -> void:
	var texture: Texture2D = UiIcons.texture(icon) if icon != "" else null
	if texture == null:
		return
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(px, px)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.modulate = UiIcons.color(icon)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rect)


func _chip_text(box: HBoxContainer, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	return label


func _chip_bar(box: HBoxContainer, width: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(width, 9)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", UiStyle.box(Color("0b0a08"), UiStyle.LINE_SOFT, 3, 0))
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.5, 0.75, 0.5)
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	box.add_child(bar)
	return bar


func _set_bar(bar: ProgressBar, value: float, color: Color) -> void:
	bar.value = clampf(value, 0.0, 100.0)
	(bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = color


# ===========================================================
# DAY CLOCK (top centre) — which day it is and how long until the evening Desk
# ===========================================================

var _clock_panel: PanelContainer
var _clock_day: Label
var _clock_bar: ProgressBar
var _clock_left: Label


func _build_day_clock() -> void:
	_clock_panel = PanelContainer.new()
	_clock_panel.anchor_left = 0.5
	_clock_panel.anchor_right = 0.5
	_clock_panel.offset_left = -190
	_clock_panel.offset_right = 190
	_clock_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_loc(_clock_panel, func() -> String: return Localization.ru_en("Пробел — пауза · 1 / 2 / 3 — скорость", "Space — pause · 1 / 2 / 3 — speed"), "tooltip_text")
	var style: StyleBoxFlat = UiStyle.panel_box(6)
	style.border_color = UiStyle.ACCENT_DIM
	style.content_margin_left = 12
	style.content_margin_right = 12
	_clock_panel.add_theme_stylebox_override("panel", style)
	add_child(_clock_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock_panel.add_child(row)

	_clock_day = Label.new()
	UiStyle.title(_clock_day, 15, UiStyle.ACCENT)
	_clock_day.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_clock_day)

	_clock_bar = ProgressBar.new()
	_clock_bar.min_value = 0.0
	_clock_bar.max_value = 1.0
	_clock_bar.show_percentage = false
	_clock_bar.custom_minimum_size = Vector2(110, 10)
	_clock_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clock_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_clock_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_clock_bar)

	_clock_left = Label.new()
	_clock_left.add_theme_font_size_override("font_size", 12)
	_clock_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_clock_left)
	_update_day_clock()


func _update_day_clock() -> void:
	if _clock_day == null:
		return
	_clock_panel.visible = SimulationRunner.run_active
	_clock_day.text = "%s %d" % [Localization.ru_en("День", "Day"), SimulationRunner.day_count]
	var duration: float = maxf(SimulationRunner.day_duration, 1.0)
	_clock_bar.value = clampf(1.0 - SimulationRunner.day_timer / duration, 0.0, 1.0)
	var text: String
	var color := Color(0.85, 0.85, 0.8)
	if SimulationRunner.current_phase == SimulationRunner.Phase.EVENING:
		text = Localization.ru_en("Вечер — Стол администратора", "Evening — the Administrator's Desk")
		_clock_bar.value = 1.0
	elif SimulationRunner.paused:
		text = Localization.ru_en("⏸ Пауза (Пробел)", "⏸ Paused (Space)")
		color = Color(0.95, 0.8, 0.3)
	else:
		# Real seconds until the evening Desk at the current speed.
		var left: int = int(ceil(maxf(SimulationRunner.day_timer, 0.0) / maxf(SimulationRunner.speed_scale, 0.1)))
		text = "%s %d:%02d · ×%d" % [Localization.ru_en("до вечера", "evening in"), left / 60, left % 60, int(SimulationRunner.speed_scale)]
		if left <= 30:
			color = Color(0.95, 0.65, 0.35)
	_clock_left.text = text
	_clock_left.add_theme_color_override("font_color", color)


func _position_below_resource_bar() -> void:
	var bottom: float = _resource_bar.position.y + _resource_bar.size.y
	if _clock_panel:
		_clock_panel.offset_top = bottom + 6.0
		_clock_panel.offset_bottom = bottom + 6.0
	if _build_panel:
		_build_panel.offset_top = bottom + 4.0
	if _minimap_panel:
		_minimap_panel.position.y = bottom + 8.0
	if _left_column:
		_left_column.position = Vector2(10.0, bottom + 8.0 + _minimap_panel.size.y + 6.0)


# ===========================================================
# LEFT COLUMN (under the minimap) — current goals + panel buttons
# ===========================================================

var _left_column: VBoxContainer
var _goal_rows: Dictionary = {}  # id → {"row": Control, "mark": Label, "name": Label, "value": Label}
const LEFT_W := 236.0
const GOAL_ROWS := ["dust", "audit", "water", "food", "mood", "spoilage", "grant", "finish"]

## Panels in the order of their keys: Q E T Y sit in one row next to WASD (W and R are taken).
const PANEL_BUTTONS := [
	["water", "Вода", "Water", "Q"],
	["season", "Сезон", "Season", "E"],
	["log", "Журнал", "Log", "T"],
	["diary", "Дневник", "Diary", "Y"],
	["help", "Справка", "Help", "H"],
]


func _build_left_column() -> void:
	_left_column = VBoxContainer.new()
	_left_column.add_theme_constant_override("separation", 6)
	_left_column.custom_minimum_size.x = LEFT_W
	add_child(_left_column)

	var goals := PanelContainer.new()
	goals.add_theme_stylebox_override("panel", UiStyle.panel_box(10))
	goals.mouse_filter = Control.MOUSE_FILTER_STOP
	_left_column.add_child(goals)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	goals.add_child(box)
	var head := Label.new()
	_loc(head, func() -> String: return Localization.ru_en("Цели", "Goals"))
	UiStyle.caption(head)
	box.add_child(head)
	_goal_rows.clear()
	for id: String in GOAL_ROWS:
		_goal_rows[id] = _goal_row(box)

	var row: HBoxContainer = null
	for entry: Array in PANEL_BUTTONS:
		if row == null or row.get_child_count() >= 3:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			_left_column.add_child(row)
		var btn := Button.new()
		_loc(btn, func() -> String: return "%s  %s" % [Localization.ru_en(entry[1] as String, entry[2] as String), entry[3]])
		btn.add_theme_font_size_override("font_size", 12)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_open_panel.bind(entry[0] as String))
		row.add_child(btn)
	_update_goals()


func _goal_row(parent: Control) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var mark := Label.new()
	mark.custom_minimum_size.x = 12
	mark.add_theme_font_size_override("font_size", 12)
	row.add_child(mark)
	var title := Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 12)
	row.add_child(title)
	var value := Label.new()
	value.add_theme_font_size_override("font_size", 12)
	row.add_child(value)
	return { "row": row, "mark": mark, "name": title, "value": value }


## One line of the goals list. `done` picks the mark; a heading row has no mark and no value.
func _set_goal(id: String, shown: bool, done: bool = false, title: String = "", value: String = "", heading: bool = false) -> void:
	var row: Dictionary = _goal_rows[id] as Dictionary
	(row["row"] as Control).visible = shown
	if not shown:
		return
	var mark: Label = row["mark"] as Label
	mark.text = "" if heading else ("✔" if done else "○")
	mark.add_theme_color_override("font_color", UiStyle.GOOD if done else UiStyle.WARN)
	(row["name"] as Label).text = title
	(row["name"] as Label).add_theme_color_override("font_color", UiStyle.TEXT_DIM if heading else UiStyle.TEXT)
	(row["value"] as Label).text = value
	(row["value"] as Label).add_theme_color_override("font_color", UiStyle.GOOD if done else UiStyle.WARN)


func _open_panel(panel_id: String) -> void:
	match panel_id:
		"water": WaterPanel.call("_toggle")
		"season": SeasonPanel.call("_toggle")
		"log": EventLogPanel.call("_toggle")
		"diary": DiaryManager.call("_toggle")
		"help": toggle_help()


## What the player should be working on right now (playtest: "нужен список целей").
func _update_goals() -> void:
	if _goal_rows.is_empty():
		return
	_left_column.visible = SimulationRunner.run_active
	var day: int = GameStateStore.climate().get("total_day", 1) as int

	# 1. The season ahead.
	var sid: String = GameStateStore.climate().get("season_id", "") as String
	var order: Array = ContentDB.get_season_order()
	var idx: int = order.find(sid)
	var next_def: Dictionary = ContentDB.get_season_def(order[(idx + 1) % order.size()] as String) if not order.is_empty() else {}
	var length: int = ContentDB.get_season_def(sid).get("length_days", 1) as int
	var remaining: int = length - (GameStateStore.climate().get("day_in_season", 1) as int) + 1
	_set_goal("dust", not next_def.is_empty(), false,
		Localization.content_text(next_def, "label", "?"), Localization.ru_en("через %d дн.", "in %d days") % remaining)

	# 2. The audit checklist, live — the same three checks the inspector runs.
	var mandate: Dictionary = GameStateStore.mandate()
	var has_patron: bool = (mandate.get("patron_id", "") as String) != ""  # a founder faces no audit and no grant contest
	var audit_done: bool = MandateManager.next_audit_day() == 0
	var checking: bool = has_patron and not audit_done
	_set_goal("audit", has_patron, audit_done,
		Localization.ru_en("Аудиты пройдены", "Audits done") if audit_done else Localization.ru_en("Аудит · день %d", "Audit · day %d") % MandateManager.next_audit_day(),
		"", not audit_done)
	var water: float = GameStateStore.get_resource("res_water_stockpile")
	var food: float = GameStateStore.get_resource("res_food")
	var mood: float = GameStateStore.population().get("happiness", 50.0) as float
	_set_goal("water", checking, water >= MandateManager.WATER_OK, Localization.ru_en("Вода", "Water"), "%d / %d" % [int(water), int(MandateManager.WATER_OK)])
	_set_goal("food", checking, food >= MandateManager.FOOD_OK, Localization.ru_en("Еда", "Food"), "%d / %d" % [int(food), int(MandateManager.FOOD_OK)])
	_set_goal("mood", checking, mood >= MandateManager.HAPPINESS_OK, Localization.ru_en("Счастье", "Mood"), "%d%% / %d%%" % [int(mood), int(MandateManager.HAPPINESS_OK)])

	var climate: Dictionary = GameStateStore.climate()
	var incoming: float = climate.get("heat_food_start", 0.0) as float
	var spoiled: float = climate.get("heat_food_spoiled", 0.0) as float
	var loss_percent: float = 100.0 * spoiled / incoming if incoming > 0.0 else 0.0
	_set_goal("spoilage", checking and climate.has("heat_food_start"), MandateManager.food_preserved(),
		Localization.ru_en("Порча еды", "Food spoiled"), "%.1f%% / <25%%" % loss_percent)

	# 3. The grant contest with the neighbour.
	var ours: int = int(RivalManager.player_score())
	var theirs: int = int(RivalManager.rival_score())
	_set_goal("grant", has_patron and not (GameStateStore.rival().get("grant_decided", false) as bool), ours >= theirs,
		Localization.ru_en("Грант · день %d", "Grant · day %d") % ContentDB.get_grant_day(),
		Localization.ru_en("вы %d : %d Восс", "you %d : %d Voss") % [ours, theirs])

	# 4. The finish line.
	_set_goal("finish", true, false, Localization.ru_en("Дожить до дня %d", "Reach day %d") % ContentDB.get_win_day(),
		Localization.ru_en("день %d", "day %d") % day)


func _top_resource_ids() -> Array[String]:
	var ids: Array[String] = []
	for pair: Array in [
		["res_money", "coins"],
		["res_food", "food"],
		["res_water_stockpile", "water_res"],
		["res_wood", "wood"],
		["res_stone", "stone"],
		["res_tools", "tools"],
	]:
		var preferred: String = pair[0] as String
		var fallback: String = pair[1] as String
		ids.append(preferred if not ContentDB.get_resource_def(preferred).is_empty() else fallback)
	return ids


func _resource_value(preferred_id: String, fallback_id: String) -> float:
	if not ContentDB.get_resource_def(preferred_id).is_empty():
		return GameStateStore.get_resource(preferred_id)
	return GameStateStore.get_resource(fallback_id)


func _on_resources_changed(_resources: Dictionary) -> void:
	_update_resource_bar()
	_update_build_list_affordability()


func _update_resource_bar() -> void:
	_update_goals()
	# --- Resources: number + trend per day ---
	var production: Dictionary = GameStateStore.economy().get("production", {}) as Dictionary
	for res_id: String in _res_chips:
		var chip: Dictionary = _res_chips[res_id] as Dictionary
		var val: float = GameStateStore.get_resource(res_id)
		var per_day: float = (production.get(res_id, 0.0) as float) * float(WaterPanel.TICKS_PER_DAY)
		var value_label: Label = chip["value"] as Label
		value_label.text = str(int(val))
		value_label.add_theme_color_override("font_color", Color(0.95, 0.4, 0.35) if val <= 0.0 else Color(0.97, 0.95, 0.88))
		var delta_label: Label = chip["delta"] as Label
		if per_day > 0.0 and val >= GameStateStore.get_cap(res_id) - 0.5:
			# Full store: the surplus is lost, so a big "+N" would be a lie.
			delta_label.text = Localization.ru_en("макс", "max")
			delta_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		elif absf(per_day) < 0.5:
			delta_label.text = ""
		else:
			delta_label.text = "%+d" % int(round(per_day))
			delta_label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55) if per_day > 0.0 else Color(0.95, 0.5, 0.4))
		var res_name: String = Localization.content_text(ContentDB.get_resource_def(res_id), "label", res_id)
		(chip["panel"] as Control).tooltip_text = "%s: %d · %s %+d" % [
			res_name, int(val), Localization.ru_en("в день", "per day"), int(round(per_day))]

	# --- People and level ---
	var pop: int = GameStateStore.population().total as int
	var happiness: float = GameStateStore.population().happiness as float
	_pop_label.text = "%s %d" % [Localization.t("ui.resource.population", "Pop"), pop]
	_happy_label.text = "%s %d%%" % [Localization.t("ui.resource.happiness", "Happy"), int(happiness)]
	_happy_label.add_theme_color_override("font_color", _level_color(happiness, 40.0, 55.0))
	var city_lv: int = GameStateStore.progression().city_level as int
	var lv_name: String = Localization.content_text(ContentDB.get_level_def(city_lv), "name", "?")
	var level_text: String = "%s%d %s" % [Localization.t("ui.resource.level", "Lv"), city_lv, lv_name]
	var next_def: Dictionary = ContentDB.get_level_def(city_lv + 1)
	if not next_def.is_empty() and next_def.get("requirements", null) is Dictionary:
		var reqs: Dictionary = next_def.get("requirements", {}) as Dictionary
		var met: int = 0
		for res_id: String in reqs:
			if GameStateStore.get_resource(res_id) >= (reqs[res_id] as float):
				met += 1
		level_text += " · %s %d/%d" % [Localization.t("ui.resource.next", "Next"), met, reqs.size()]
	_level_label.text = level_text

	# --- Water in days: the headline survival figure (GDD §5): green > 5, yellow 2–5, red < 2 ---
	var utility_stats: Dictionary = _collect_utility_stats()
	var water_total: int = utility_stats.get("residential", 0) as int
	var water_ok: int = utility_stats.get("residential_watered", 0) as int
	# The chip answers "when does the water run out at today's balance": while the reserve
	# grows it says so; once it drains it counts the days left.
	var reserve: float = _resource_value("res_water_stockpile", "water_res")
	var water_per_day: float = (production.get("res_water_stockpile", 0.0) as float) * float(WaterPanel.TICKS_PER_DAY)
	var days_color := Color(0.65, 0.85, 1.0)
	if water_per_day >= -0.5:
		_utility_label.text = Localization.ru_en("Вода: запас держится", "Water: reserve holds")
		if reserve <= 0.0:
			_utility_label.text = Localization.ru_en("Воды нет", "No water")
			days_color = Color(0.95, 0.35, 0.3)
	else:
		var days: float = reserve / absf(water_per_day)
		_utility_label.text = "%s %.1f %s" % [
			Localization.ru_en("Воды на", "Water for"), days, Localization.ru_en("дн.", "days")]
		if days < 2.0:
			days_color = Color(0.95, 0.35, 0.3)
		elif days < 5.0:
			days_color = Color(0.95, 0.8, 0.3)
	_utility_label.add_theme_color_override("font_color", days_color)
	_utility_label.tooltip_text = "%s · %s · %s" % [
		_coverage_ratio_text(Localization.t("ui.flow.water", "Water"), water_ok, water_total),
		"%s %d" % [Localization.t("ui.city.water_reserve_short", "Reserve"), int(_resource_value("res_water_stockpile", "water_res"))],
		Localization.ru_en("клик — панель воды (Q)", "click: water panel (Q)"),
	]
	_power_label.text = _power_readout().strip_edges()
	(_power_label.get_parent().get_parent() as Control).visible = _power_label.text != ""

	# --- Season ---
	_city_label.text = _season_bar_text()
	_city_label.tooltip_text = Localization.ru_en("Клик — сезон и прогноз (E)", "Click: season and forecast (E)")

	# --- The two masters (League ↕ City): trust at zero → recall, support at zero → riot ---
	var trust: float = GameStateStore.mandate().get("patron_trust", 50) as float
	var support: float = GameStateStore.mandate().get("support", 50) as float
	# The patron half names the actual patron and disappears for a founder, who has none.
	var patron_id: String = GameStateStore.mandate().get("patron_id", "") as String
	var has_patron: bool = patron_id != ""
	_patron_label.text = Localization.ru_en("Директорат", "Directorate") if patron_id == "civic_directorate" else Localization.ru_en("Лига", "League")
	for part: Control in [_patron_label, _trust_bar, _trust_value, _masters_arrow]:
		part.visible = has_patron
	(_rival_label.get_parent().get_parent() as Control).visible = has_patron
	_set_bar(_trust_bar, trust, _level_color(trust, 25.0, 45.0))
	_set_bar(_support_bar, support, _level_color(support, 25.0, 45.0))
	_trust_value.text = str(int(trust))
	_support_value.text = str(int(support))
	_rival_label.text = _rival_bb()

	# --- Pressure director (GDD §15): each gauge fills toward a crisis at 100 ---
	var cats: Dictionary = GameStateStore.pressure().get("categories", {}) as Dictionary
	for cat: String in _pressure_bars:
		var gauge: Dictionary = _pressure_bars[cat] as Dictionary
		var value: float = cats.get(cat, 0.0) as float
		var color := Color(0.45, 0.45, 0.5)
		if value >= 70.0:
			color = Color(0.9, 0.21, 0.21)
		elif value >= 40.0:
			color = Color(0.9, 0.56, 0.17)
		_set_bar(gauge["bar"] as ProgressBar, value, color)
		(gauge["value"] as Label).text = str(int(value))
		(gauge["value"] as Label).add_theme_color_override("font_color", color.lightened(0.25))


func _level_color(value: float, danger: float, warn: float) -> Color:
	if value < danger:
		return Color(0.9, 0.21, 0.21)
	if value < warn:
		return Color(0.9, 0.56, 0.17)
	return Color(0.5, 0.75, 0.5)


func _rival_bb() -> String:
	# The neighbour the patron measures you against (RivalManager): orange when behind, green when ahead.
	var theirs: float = RivalManager.rival_score()
	var ours: float = RivalManager.player_score()
	var color: String = "#8a8a99"
	if ours <= theirs - RivalManager.AUDIT_EDGE:
		color = "#e6902b"
	elif ours >= theirs + RivalManager.AUDIT_EDGE:
		color = "#7fbf7f"
	return "%s %.0f · [color=%s]%s %.0f[/color]" % [
		Localization.ru_en("Восс", "Voss"), theirs, color, Localization.ru_en("вы", "you"), ours]


func _on_utility_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			WaterPanel.open()


func _on_city_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			SeasonPanel.open()


func _power_readout() -> String:
	var pw: Dictionary = GameStateStore.power()
	if not (pw.get("enabled", true) as bool):
		return ""
	var gen: float = pw.get("generation", 0.0) as float
	var dem: float = pw.get("demand", 0.0) as float
	if gen <= 0.0 and dem <= 0.0:
		return ""
	var text: String = "  %s %.0f/%.0f" % [Localization.t("ui.flow.power", "Power"), gen, dem]
	var tp: Dictionary = pw.get("tier_powered", {}) as Dictionary
	var shed: Array[String] = []
	if not (tp.get("priority", true) as bool):
		shed.append(Localization.t("ui.flow.water", "Water"))
	if not (tp.get("secondary", true) as bool):
		shed.append(Localization.ru_en("цеха", "workshops"))
	if not (tp.get("tertiary", true) as bool):
		shed.append(Localization.ru_en("жильё", "housing"))
	if not shed.is_empty():
		text += " %s %s" % [Localization.ru_en("⚠ без света:", "⚠ no power:"), ", ".join(shed)]
	return text


func _coverage_ratio_text(label: String, covered: int, total: int) -> String:
	if total <= 0:
		return "%s:-" % label
	return "%s:%d/%d" % [label, covered, total]


func _season_bar_text() -> String:
	var climate: Dictionary = GameStateStore.climate()
	var sid: String = climate.get("season_id", "") as String
	if sid == "":
		return ""
	var sdef: Dictionary = ContentDB.get_season_def(sid)
	var sname: String = Localization.content_text(sdef, "label", sid)
	var din: int = climate.get("day_in_season", 1) as int
	var slen: int = sdef.get("length_days", 0) as int
	var text: String = "%s:%s %d/%d" % [Localization.ru_en("Сезон", "Season"), sname, din, slen]
	# Inexact forecast of the next season (GDD: точный прогноз даёт только Прогнозист).
	var order: Array = ContentDB.get_season_order()
	if order.size() > 1 and slen > 0:
		var idx: int = climate.get("season_index", 0) as int
		var next_id: String = order[(idx + 1) % order.size()] as String
		var next_name: String = Localization.content_text(ContentDB.get_season_def(next_id), "label", next_id)
		var days_left: int = maxi(slen - din + 1, 0)
		text += " %s %s ~%d%s" % [
			"→",
			next_name,
			days_left,
			Localization.ru_en("д", "d"),
		]
	return text


func _collect_utility_stats() -> Dictionary:
	var stats: Dictionary = {
		"residential": 0,
		"residential_watered": 0,
		"power_users": 0,
		"power_covered": 0,
	}
	var orch := _get_orchestrator()
	if orch == null or orch.coverage == null:
		return stats

	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		var type_id: String = bld.get("type", "") as String
		var def: Dictionary = ContentDB.get_building_def(type_id)
		var level: int = bld.get("level", 0) as int
		var ldata: Dictionary = ContentDB.building_level_data(type_id, level)
		var consumes: Dictionary = ldata.get("consumes", {})

		if (def.get("category", "") as String) == "Residential":
			stats["residential"] = (stats.get("residential", 0) as int) + 1
			if orch.coverage.is_water_covered(coord):
				stats["residential_watered"] = (stats.get("residential_watered", 0) as int) + 1
		if consumes.has("energy") and type_id != "power":
			stats["power_users"] = (stats.get("power_users", 0) as int) + 1
			if orch.coverage.is_power_covered(coord):
				stats["power_covered"] = (stats.get("power_covered", 0) as int) + 1
	return stats


# ===========================================================
# BUILD PANEL (right side, expands left)
# ===========================================================

const CATEGORY_ORDER: Array[String] = ["Infrastructure", "Residential", "Production", "Commercial", "Culture", "Advanced"]
const CATEGORY_KEYS := {
	"Infrastructure": "ui.category.infrastructure",
	"Residential": "ui.category.residential",
	"Production": "ui.category.production",
	"Commercial": "ui.category.commercial",
	"Culture": "ui.category.culture",
	"Advanced": "ui.category.advanced",
}
const BUILD_PANEL_W := 300.0

func _build_build_panel() -> void:
	_build_panel = PanelContainer.new()
	_build_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# Anchor to top-right, expand downward
	_build_panel.anchor_left = 1.0
	_build_panel.anchor_right = 1.0
	_build_panel.anchor_top = 0.0
	_build_panel.anchor_bottom = 1.0
	_build_panel.offset_left = -BUILD_PANEL_W
	_build_panel.offset_top = 52
	_build_panel.offset_bottom = 0
	var style: StyleBoxFlat = UiStyle.box(UiStyle.BG, UiStyle.LINE, 0, 10, 0)
	style.border_width_left = 1
	_build_panel.add_theme_stylebox_override("panel", style)
	add_child(_build_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_build_panel.add_child(vbox)

	# District screens: level, governance, options.
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 4)
	vbox.add_child(nav)
	_build_city_button = _nav_button(nav, toggle_city_panel)
	_build_gov_button = _nav_button(nav, toggle_governance)
	_build_settings_button = _nav_button(nav, toggle_settings)

	_build_title_label = Label.new()
	UiStyle.caption(_build_title_label)
	_build_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_build_title_label)

	_category_select = OptionButton.new()
	_category_select.item_selected.connect(_on_category_selected)
	_category_select.visible = false
	vbox.add_child(_category_select)

	# Categories two to a row; an odd last one takes the whole row.
	_category_rows = VBoxContainer.new()
	_category_rows.add_theme_constant_override("separation", 4)
	vbox.add_child(_category_rows)
	_category_buttons.clear()
	var row: HBoxContainer = null
	for cat: String in CATEGORY_ORDER:
		var cat_btn := Button.new()
		cat_btn.toggle_mode = true
		cat_btn.text = _category_label(cat)
		cat_btn.icon = UiIcons.texture(UiIcons.CATEGORIES[cat])
		cat_btn.expand_icon = true
		cat_btn.add_theme_constant_override("icon_max_width", 16)
		cat_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		cat_btn.clip_text = true  # no minimum width of its own, so a row splits evenly
		cat_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cat_btn.add_theme_font_size_override("font_size", 12)
		cat_btn.focus_mode = Control.FOCUS_NONE
		cat_btn.pressed.connect(_set_active_category.bind(cat))
		_category_buttons[cat] = cat_btn
		# A category with nothing to build in this chapter stays out of the menu.
		if not _category_has_buildings(cat):
			cat_btn.visible = false
			_category_rows.add_child(cat_btn)
			continue
		if row == null or row.get_child_count() >= 2:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			_category_rows.add_child(row)
		row.add_child(cat_btn)

	# Scrollable building list
	_build_scroll = ScrollContainer.new()
	_build_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_build_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_build_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_build_scroll)

	_build_vbox = VBoxContainer.new()
	_build_vbox.add_theme_constant_override("separation", 6)
	_build_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_build_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_scroll.add_child(_build_vbox)

	# Map layers: what the overlay shows on top of the district.
	var lens_title := Label.new()
	_loc(lens_title, func() -> String: return Localization.ru_en("Слои карты", "Map layers"))
	UiStyle.caption(lens_title)
	vbox.add_child(lens_title)
	var lens_row := HBoxContainer.new()
	lens_row.add_theme_constant_override("separation", 4)
	vbox.add_child(lens_row)
	_range_lens_button = _lens_button(lens_row, _toggle_ranges_from_button)
	_logistics_lens_button = _lens_button(lens_row, _toggle_logistics_lens_from_button)
	_refresh_lens_buttons(false, false)
	_refresh_build_panel_labels()


func _nav_button(parent: Control, action: Callable) -> Button:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 12)
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_text = true
	btn.pressed.connect(action)
	parent.add_child(btn)
	return btn


func _lens_button(parent: Control, action: Callable) -> Button:
	var btn: Button = _nav_button(parent, action)
	btn.toggle_mode = true
	return btn


func _category_has_buildings(cat: String) -> bool:
	for type_id: String in ContentDB.get_building_ids():
		var def: Dictionary = ContentDB.get_building_def(type_id)
		if (def.get("player_buildable", true) as bool) and (def.get("category", "") as String) == cat:
			return true
	return false


func _toggle_ranges_from_button() -> void:
	var main_node: Node = get_tree().current_scene
	if main_node and main_node.has_method("toggle_ranges"):
		main_node.call("toggle_ranges")


func _toggle_logistics_lens_from_button() -> void:
	var main_node: Node = get_tree().current_scene
	if main_node and main_node.has_method("toggle_logistics_lens"):
		main_node.call("toggle_logistics_lens")


func _on_ranges_changed(enabled: bool) -> void:
	_refresh_lens_buttons(enabled, _logistics_lens_button.button_pressed if _logistics_lens_button else false)


func _on_logistics_lens_changed(enabled: bool) -> void:
	_refresh_lens_buttons(_range_lens_button.button_pressed if _range_lens_button else false, enabled)


func _refresh_lens_buttons(ranges_enabled: bool, logistics_enabled: bool) -> void:
	if _range_lens_button:
		_range_lens_button.set_pressed_no_signal(ranges_enabled)
	if _logistics_lens_button:
		_logistics_lens_button.set_pressed_no_signal(logistics_enabled)


func _on_category_selected(index: int) -> void:
	if index < 0 or index >= CATEGORY_ORDER.size():
		return
	_set_active_category(CATEGORY_ORDER[index] as String)


func _set_active_category(cat: String) -> void:
	_active_category = cat
	if _category_select:
		var idx: int = CATEGORY_ORDER.find(cat)
		if idx >= 0 and _category_select.selected != idx:
			_category_select.select(idx)
	_update_category_buttons()
	_rebuild_building_list()


func _refresh_build_panel_labels() -> void:
	if _build_title_label:
		_build_title_label.text = Localization.t("ui.build.title", "Build")
	if _build_city_button:
		_build_city_button.text = Localization.ru_en("Город", "City")
		_build_city_button.tooltip_text = Localization.t("ui.city.tooltip", "City level requirements and upgrade")
	if _build_gov_button:
		_build_gov_button.text = Localization.ru_en("Управление", "Governance")
		_build_gov_button.tooltip_text = Localization.t("ui.governance.tooltip", "Governance (G): tech tree and policies")
	if _build_settings_button:
		_build_settings_button.text = Localization.ru_en("Настройки", "Options")
		_build_settings_button.tooltip_text = Localization.t("ui.settings.tooltip", "Options (O): language and settings")
	if _range_lens_button:
		_range_lens_button.text = Localization.t("ui.lens.ranges", "Радиусы V")
		_range_lens_button.tooltip_text = Localization.t("ui.lens.ranges_tooltip", "Показать радиус выбранного здания")
	if _logistics_lens_button:
		_logistics_lens_button.text = Localization.t("ui.lens.logistics", "Логистика L")
		_logistics_lens_button.tooltip_text = Localization.t("ui.lens.logistics_tooltip", "Подсветить дороги и здания без дорожного доступа")
	if _category_select:
		var selected_category := _active_category
		_category_select.clear()
		for cat: String in CATEGORY_ORDER:
			_category_select.add_item(_category_label(cat))
		var idx: int = CATEGORY_ORDER.find(selected_category)
		if idx >= 0:
			_category_select.select(idx)
	for cat: String in _category_buttons:
		var btn: Button = _category_buttons[cat] as Button
		btn.text = _category_label(cat)
	_update_category_buttons()


func _update_category_buttons() -> void:
	for cat: String in _category_buttons:
		(_category_buttons[cat] as Button).set_pressed_no_signal(cat == _active_category)


func _category_label(category: String) -> String:
	return Localization.t(CATEGORY_KEYS.get(category, ""), category)


func _rebuild_building_list() -> void:
	for c: Node in _build_vbox.get_children():
		c.queue_free()
	_build_entries.clear()
	_hover_build_type = ""

	var city_lv: int = GameStateStore.progression().city_level as int

	for type_id: String in ContentDB.get_building_ids():
		var def: Dictionary = ContentDB.get_building_def(type_id)
		if not (def.get("player_buildable", true) as bool):
			continue
		if (def.get("category", "") as String) != _active_category:
			continue

		var unlock_lv: int = def.get("unlock_level", 1) as int
		var is_locked: bool = city_lv < unlock_lv
		var ldata: Dictionary = ContentDB.building_level_data(type_id, 0)

		# One card per building: picture, name, what it gives, what it costs.
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.tooltip_text = Localization.content_text(def, "description", "")
		card.set_meta("type_id", type_id)  # lets the tutorial point at this card
		_build_vbox.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)

		var thumb := TextureRect.new()
		var sprites: Array = def.get("sprites_by_level", []) as Array
		if not sprites.is_empty():
			thumb.texture = _thumbnail(sprites[0] as String)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.custom_minimum_size = Vector2(46, 46)
		thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_locked:
			thumb.modulate = Color(0.45, 0.45, 0.45)
		row.add_child(thumb)

		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(col)

		var name_lbl := Label.new()
		name_lbl.text = Localization.content_text(def, "label", type_id)
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", UiStyle.TEXT_MUTE if is_locked else UiStyle.TEXT)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(name_lbl)

		var cost_labels: Dictionary = {}
		if is_locked:
			var lock_lbl := Label.new()
			lock_lbl.text = Localization.ru_en("Откроется на уровне %d", "Unlocks at level %d") % unlock_lv
			lock_lbl.add_theme_font_size_override("font_size", 12)
			lock_lbl.add_theme_color_override("font_color", UiStyle.TEXT_MUTE)
			lock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(lock_lbl)
		else:
			var effect_bb: String = _effects_bb(ldata)
			if effect_bb != "":
				col.add_child(_bb_line(effect_bb, UiStyle.TEXT_DIM))
			var build_cost: Dictionary = PlacementRulesRef.build_cost_for(def)
			if not build_cost.is_empty():
				var cost_row := HBoxContainer.new()
				cost_row.add_theme_constant_override("separation", 3)
				cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
				col.add_child(cost_row)
				for res_id: String in build_cost:
					_chip_icon(cost_row, UiIcons.RESOURCES.get(res_id, "") as String, 14)
					var amount := Label.new()
					amount.text = _num(build_cost[res_id] as float) + "  "
					amount.add_theme_font_size_override("font_size", 12)
					amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
					cost_row.add_child(amount)
					cost_labels[res_id] = amount
			card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			card.gui_input.connect(_on_build_card_input.bind(type_id))
			card.mouse_entered.connect(_on_build_card_hover.bind(type_id))
			card.mouse_exited.connect(_on_build_card_hover.bind(""))

		_build_entries.append({"type_id": type_id, "card": card, "cost_labels": cost_labels, "locked": is_locked})
	_refresh_build_cards()
	_update_build_list_affordability()


## A building's picture without the empty margin around it, so it fills the card's slot.
var _thumb_cache: Dictionary = {}


func _thumbnail(path: String) -> Texture2D:
	if not _thumb_cache.has(path):
		var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
		var image: Image = texture.get_image() if texture != null else null
		var used: Rect2i = image.get_used_rect() if image != null else Rect2i()
		if used.has_area():
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(used)
			texture = atlas
		_thumb_cache[path] = texture
	return _thumb_cache[path] as Texture2D


func _on_build_card_input(event: InputEvent, type_id: String) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_on_build_button(type_id)


func _on_build_card_hover(type_id: String) -> void:
	_hover_build_type = type_id
	_refresh_build_cards()


func _refresh_build_cards() -> void:
	for entry: Dictionary in _build_entries:
		var state: String = "normal"
		if entry.locked as bool:
			state = "locked"
		elif (entry.type_id as String) == _active_build_type:
			state = "active"
		elif (entry.type_id as String) == _hover_build_type:
			state = "hover"
		(entry.card as PanelContainer).add_theme_stylebox_override("panel", UiStyle.card_box(state))


## A wrapping line of rich text (icons inline) that takes only the height it needs.
func _bb_line(bb: String, color: Color, font_size: int = 12) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = bb
	return label


## Whole numbers stay whole; fractions keep their digits ("0.05", never "-0").
func _num(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return ("%.2f" % value).rstrip("0").rstrip(".")


func _icon_bb(icon: String, px: int = 14) -> String:
	if icon == "" or UiIcons.texture(icon) == null:
		return ""
	return "[img=%dx%d color=%s]res://assets/ui/icons/%s.svg[/img]" % [px, px, UiStyle.hex(UiIcons.color(icon)), icon]


## "icon amount" for a resource; falls back to the resource's name when it has no icon.
func _res_bb(res_id: String, amount: String) -> String:
	var icon: String = _icon_bb(UiIcons.RESOURCES.get(res_id, "") as String)
	if icon != "":
		return "%s\u00a0%s" % [icon, amount]
	return "%s %s" % [amount, Localization.content_text(ContentDB.get_resource_def(res_id), "label", res_id)]


## What a building does, with resource icons: income green, upkeep amber.
func _effects_bb(ldata: Dictionary) -> String:
	var parts: Array[String] = []
	var produces: Dictionary = ldata.get("produces", {})
	for r: String in produces:
		parts.append("[color=%s]%s[/color]" % [UiStyle.hex(UiStyle.GOOD), _res_bb(r, "+" + _num(produces[r] as float))])
	var consumes: Dictionary = ldata.get("consumes", {})
	for r: String in consumes:
		parts.append("[color=%s]%s[/color]" % [UiStyle.hex(UiStyle.WARN), _res_bb(r, "−" + _num(consumes[r] as float))])
	var bld_pop: int = ldata.get("population", 0) as int
	if bld_pop > 0:
		parts.append("%s\u00a0+%d" % [_icon_bb("people"), bld_pop])
	var storage_value: Variant = ldata.get("storage", 0)
	if storage_value is Dictionary:
		var stores: Array[String] = []
		for r: String in storage_value as Dictionary:
			stores.append(_res_bb(r, "+" + _num((storage_value as Dictionary)[r] as float)))
		parts.append("%s: %s" % [Localization.t("ui.effect.storage", "storage").capitalize(), "  ".join(stores)])
	elif (storage_value as float) > 0.0:
		parts.append("+%d %s" % [int(storage_value as float), Localization.t("ui.effect.storage", "storage")])
	var synergy: Dictionary = ldata.get("synergy", {})
	if synergy.has("water_radius"):
		parts.append("%s\u00a0%s %d" % [_icon_bb("water"), Localization.ru_en("радиус", "radius"), synergy["water_radius"] as int])
	return "   ".join(parts)


func _update_build_list_affordability() -> void:
	# Each price turns red on its own: the player sees exactly which resource is short.
	for entry: Dictionary in _build_entries:
		var cost: Dictionary = PlacementRulesRef.build_cost_for(ContentDB.get_building_def(entry.type_id as String))
		var labels: Dictionary = entry.cost_labels as Dictionary
		for res_id: String in labels:
			var enough: bool = GameStateStore.get_resource(res_id) >= (cost.get(res_id, 0.0) as float)
			(labels[res_id] as Label).add_theme_color_override("font_color", UiStyle.TEXT if enough else UiStyle.BAD)


func _on_build_button(type_id: String) -> void:
	_active_build_type = type_id
	EventBus.build_mode_changed.emit(type_id)
	_show_info(_build_build_mode_info_text(type_id))
	_refresh_build_cards()


func _on_build_mode_changed(type_id: String) -> void:
	_active_build_type = type_id
	if _info_label and type_id != "":
		_show_info(_build_build_mode_info_text(type_id))
	# Update the highlight when build mode changes externally (e.g. RMB cancel)
	_refresh_build_cards()


func _build_build_mode_info_text(type_id: String) -> String:
	var def: Dictionary = ContentDB.get_building_def(type_id)
	if def.is_empty():
		return Localization.t("ui.command.unknown_building", "Unknown building: %s") % type_id

	var ldata: Dictionary = ContentDB.building_level_data(type_id, 0)
	var cost: Dictionary = PlacementRulesRef.build_cost_for(def)
	var lines: Array[String] = [_heading_bb(Localization.content_text(def, "label", type_id))]
	lines.append("%s  %s" % [_dim_bb(Localization.t("ui.meta.cost", "Cost") + ":"), _cost_bb(cost)])
	var effect: String = _effects_bb(ldata)
	if effect != "":
		lines.append(effect)
	# What to put it next to (or keep it away from).
	var has_rules: bool = false
	var orch_adj := _get_orchestrator()
	if orch_adj != null:
		for rule: Dictionary in orch_adj.adjacency.rules_for_type(type_id):
			has_rules = true
			lines.append("[color=%s]•[/color] %s" % [UiStyle.hex(UiStyle.ACCENT), _rule_text(rule)])

	var req_level: int = def.get("unlock_level", 1) as int
	if (GameStateStore.progression().city_level as int) < req_level:
		lines.append("[color=%s]%s[/color]" % [UiStyle.hex(UiStyle.WARN), Localization.t("ui.command.requires_city_level", "Requires city level %d") % req_level])
	elif not GameStateStore.can_afford(cost):
		lines.append("[color=%s]%s: %s[/color]" % [UiStyle.hex(UiStyle.BAD),
			Localization.t("ui.command.not_enough_resources", "Not enough resources"),
			PlacementRulesRef.missing_cost_text(cost)])
	var desc: String = Localization.content_text(def, "description", "")
	if desc != "" and not has_rules:
		lines.append(_dim_bb(desc))
	return "\n".join(lines)


func _on_locale_changed(_locale: String) -> void:
	for entry: Array in _static_texts:
		if is_instance_valid(entry[0]):
			(entry[0] as Control).set(entry[1] as String, (entry[2] as Callable).call())
	_refresh_build_panel_labels()
	_update_resource_bar()
	_rebuild_building_list()
	if _selected_coord == Vector2i(-9999, -9999):
		_show_info(_get_welcome_text())
	else:
		_update_info()
	if _help_label:
		_help_label.text = _get_help_text()
	if _governance_visible:
		_rebuild_governance_panel()
	if _city_visible:
		_rebuild_city_panel()
	if _settings_visible:
		_rebuild_settings_panel()
	if _start_visible:
		_rebuild_start_panel()


# ===========================================================
# INFO PANEL (bottom-left) — Status / Problem / Next Action
# ===========================================================

func _build_info_panel() -> void:
	# Grows upward from the bottom-left corner to fit whatever is selected.
	_info_panel = PanelContainer.new()
	_info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_info_panel.anchor_left = 0.0
	_info_panel.anchor_right = 0.0
	_info_panel.anchor_top = 1.0
	_info_panel.anchor_bottom = 1.0
	_info_panel.offset_left = 10
	_info_panel.offset_right = 10 + INFO_W
	_info_panel.offset_top = -10
	_info_panel.offset_bottom = -10
	_info_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_info_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_panel.add_child(box)

	_info_label = RichTextLabel.new()
	_info_label.bbcode_enabled = true
	_info_label.fit_content = true
	_info_label.scroll_active = false
	_info_label.custom_minimum_size.x = INFO_W - 24
	_info_label.add_theme_font_size_override("normal_font_size", 13)
	_info_label.add_theme_constant_override("line_separation", 4)
	_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_info_label)

	# The same actions as the U / R / B keys, for players who use the mouse.
	_info_actions = HBoxContainer.new()
	_info_actions.add_theme_constant_override("separation", 6)
	box.add_child(_info_actions)
	_upgrade_button = _action_button("Улучшить", "Upgrade", KEY_U)
	_repair_button = _action_button("Починить", "Repair", KEY_R)
	_bulldoze_button = _action_button("Снести", "Demolish", KEY_B)
	_show_info(_get_welcome_text())


func _action_button(ru: String, en: String, key: Key) -> Button:
	var btn := Button.new()
	_loc(btn, func() -> String: return "%s  %s" % [Localization.ru_en(ru, en), OS.get_keycode_string(key)])
	btn.add_theme_font_size_override("font_size", 12)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_press_world_key.bind(key))
	_info_actions.add_child(btn)
	return btn


## A panel button does exactly what its key does, rules and confirmations included.
func _press_world_key(key: Key) -> void:
	var main_node: Node = get_tree().current_scene
	if main_node == null or not main_node.has_method("_handle_key"):
		return
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	main_node.call("_handle_key", event)
	_update_info()


func _show_info(bb: String, with_actions: bool = false) -> void:
	_info_label.text = bb
	_info_actions.visible = with_actions


func _heading_bb(text: String) -> String:
	return "[font=%sIBMPlexSerif-Bold.ttf][font_size=17]%s[/font_size][/font]" % [UiStyle.FONT_DIR, text]


func _dim_bb(text: String) -> String:
	return "[color=%s]%s[/color]" % [UiStyle.hex(UiStyle.TEXT_DIM), text]


func _mark_bb(ok: bool, text: String) -> String:
	if ok:
		return "[color=%s]✔[/color]\u00a0%s" % [UiStyle.hex(UiStyle.GOOD), text]
	return "[color=%s]✘\u00a0%s[/color]" % [UiStyle.hex(UiStyle.BAD), text]


## A neighbour rule in the card's one-line form; the full sentence lives in the help.
func _rule_text(rule: Dictionary) -> String:
	return Localization.content_text(rule, "short", Localization.content_text(rule, "description", ""))


## A price with resource icons; what the district cannot pay yet turns red.
func _cost_bb(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for res_id: String in cost:
		var need: float = cost[res_id] as float
		var part: String = _res_bb(res_id, _num(need))
		if GameStateStore.get_resource(res_id) < need:
			part = "[color=%s]%s[/color]" % [UiStyle.hex(UiStyle.BAD), part]
		parts.append(part)
	return "   ".join(parts)


func _get_welcome_text() -> String:
	return "%s\n%s" % [
		_heading_bb(Localization.ru_en("Управление", "Controls")),
		_dim_bb(Localization.t("ui.welcome.text", "Осмотр: клик по клетке\nКамера: WASD · Зум: колесо\nПауза: Пробел · H — справка")),
	]


func _on_selection_changed(coord: Vector2i) -> void:
	_selected_coord = coord
	_update_info()


func _update_info() -> void:
	if _selected_coord == Vector2i(-9999, -9999):
		return

	var bld: Dictionary = GameStateStore.get_building(_selected_coord)
	if bld.is_empty():
		_show_info(_build_tile_info_text(_selected_coord))
		return

	_show_info(_build_building_info_text(_selected_coord, bld), true)
	var type_id: String = bld.get("type", "") as String
	var level: int = bld.get("level", 0) as int
	var broken: bool = (bld.get("damaged", false) as bool) or (bld.get("has_issue", false) as bool)
	var has_next: bool = level + 1 < ContentDB.max_building_level(type_id)
	var next_cost: Variant = ContentDB.building_level_data(type_id, level + 1).get("cost", null) if has_next else null
	_upgrade_button.visible = has_next
	_upgrade_button.disabled = not (next_cost is Dictionary) or not GameStateStore.can_afford(next_cost as Dictionary)
	_repair_button.visible = broken
	_bulldoze_button.visible = not BulldozeCommand.is_protected(ContentDB.get_building_def(type_id))
	_info_actions.visible = _upgrade_button.visible or _repair_button.visible or _bulldoze_button.visible


func _build_tile_info_text(coord: Vector2i) -> String:
	var terrain_id: int = GameStateStore.get_terrain(coord)
	var tdef: Dictionary = ContentDB.get_terrain_def(terrain_id)
	var lines: Array[String] = [_heading_bb(Localization.content_text(tdef, "label", Localization.t("ui.common.unknown", "Unknown")))]
	if not (tdef.get("buildable", true) as bool):
		lines.append("[color=%s]%s[/color]" % [UiStyle.hex(UiStyle.WARN), Localization.t("ui.tile.cannot_build", "Cannot build here")])
	else:
		# Show terrain bonuses compactly
		var bonuses: Array[String] = []
		for btype_id: String in ContentDB.get_building_ids():
			var bdef: Dictionary = ContentDB.get_building_def(btype_id)
			var tb: Dictionary = bdef.get("terrain_bonus", {})
			if tb.has(str(terrain_id)):
				var bonus: float = tb[str(terrain_id)] as float
				if bonus > 0:
					bonuses.append("[color=%s]+%d%%[/color] %s" % [UiStyle.hex(UiStyle.GOOD), int(bonus * 100), Localization.content_text(bdef, "label", btype_id)])
		if bonuses.is_empty():
			lines.append(_dim_bb(Localization.ru_en("Обычная земля: можно строить.", "Plain ground: you can build here.")))
		else:
			lines.append("%s: %s" % [_dim_bb(Localization.t("ui.tile.bonus", "Bonus")), ", ".join(bonuses)])
	return "\n".join(lines)


func _build_building_info_text(coord: Vector2i, bld: Dictionary) -> String:
	var type_id: String = bld.get("type", "") as String
	var level: int = bld.get("level", 0) as int
	var def: Dictionary = ContentDB.get_building_def(type_id)
	var ldata: Dictionary = ContentDB.building_level_data(type_id, level)
	var max_level: int = ContentDB.max_building_level(type_id)

	# --- What it is ---
	var lines: Array[String] = [_heading_bb(Localization.content_text(def, "label", type_id))]
	var stage: String = Localization.content_text(ldata, "stage", "")
	var level_text: String = Localization.ru_en("уровень %d из %d", "level %d of %d") % [level + 1, max_level]
	lines.append(_dim_bb(level_text if stage == "" or max_level <= 1 else "%s · %s" % [stage, level_text]))
	var effect: String = _effects_bb(ldata)
	if effect != "":
		lines.append(effect)

	# Landmarks (material traces of the old owner) carry flavor, not production —
	# show their description so clicking them tells the district's story.
	if (def.get("tags", []) as Array).has("landmark"):
		var flavor: String = Localization.content_text(def, "description", "")
		if flavor != "":
			lines.append(_dim_bb(flavor))

	# --- How it is doing ---
	var status: String = _status_bb(coord, type_id, def, ldata, bld)
	if status != "":
		lines.append(status)
	var orch_adj := _get_orchestrator()
	if orch_adj != null:
		for entry: Dictionary in orch_adj.adjacency.active_rules(coord, type_id):
			lines.append("%s %s" % [_dim_bb(Localization.ru_en("Соседство:", "Neighbours:")), _rule_text(entry.rule as Dictionary)])
	if bld.get("damaged", false) as bool:
		lines.append("[color=%s]%s[/color]" % [UiStyle.hex(UiStyle.BAD), Localization.ru_en("Повреждено: не работает, пока не починят.", "Damaged: out of action until repaired.")])
	elif bld.get("has_issue", false) as bool:
		lines.append("[color=%s]%s[/color]" % [UiStyle.hex(UiStyle.WARN), Localization.ru_en("Неполадка: работает вполсилы.", "Fault: running at half strength.")])

	# --- What comes next ---
	if level + 1 < max_level:
		var next_ldata: Dictionary = ContentDB.building_level_data(type_id, level + 1)
		var cost_raw: Variant = next_ldata.get("cost", null)
		if cost_raw is Dictionary and not (cost_raw as Dictionary).is_empty():
			lines.append("%s «%s»:  %s" % [_dim_bb(Localization.ru_en("Улучшение до", "Upgrade to")), Localization.content_text(next_ldata, "stage", "?"), _cost_bb(cost_raw as Dictionary)])
	elif max_level > 1:
		lines.append(_dim_bb(Localization.t("ui.building.max_level", "MAX LEVEL")))
	return "\n".join(lines)


## Supply marks in one line: road, water, power, inputs, outputs — and the resulting efficiency.
func _status_bb(coord: Vector2i, type_id: String, def: Dictionary, ldata: Dictionary, bld: Dictionary) -> String:
	var orch := _get_orchestrator()
	if orch == null or orch.coverage == null or orch.resource_flow == null:
		return ""
	var consumes: Dictionary = ldata.get("consumes", {})
	var produces: Dictionary = ldata.get("produces", {})
	var marks: Array[String] = []
	if _uses_road_flow(def, produces, consumes):
		marks.append(_mark_bb(orch.coverage.is_road_connected(coord), Localization.t("ui.flow.road", "Road")))
	if _uses_water_flow(def, type_id, produces, consumes):
		marks.append(_mark_bb(orch.coverage.is_water_covered(coord), Localization.t("ui.flow.water", "Water")))
	if _uses_power_flow(type_id, produces, consumes):
		marks.append(_mark_bb(orch.coverage.is_power_covered(coord), Localization.t("ui.flow.power", "Power")))
	if not consumes.is_empty():
		var missing_inputs: Array[String] = _missing_inputs(coord, consumes, orch.resource_flow)
		if missing_inputs.is_empty():
			marks.append(_mark_bb(true, Localization.t("ui.flow.inputs", "Inputs")))
		else:
			marks.append(_mark_bb(false, "%s: %s" % [Localization.t("ui.flow.inputs", "Inputs"), ", ".join(missing_inputs)]))
	if not produces.is_empty():
		var blocked_outputs: Array[String] = _blocked_outputs(coord, type_id, produces, orch.resource_flow)
		if not blocked_outputs.is_empty():
			marks.append(_mark_bb(false, "%s: %s" % [Localization.t("ui.flow.outputs", "Outputs"), ", ".join(blocked_outputs)]))
	var efficiency: float = orch.resource_flow.input_efficiency_for(coord, consumes) * (0.5 if (bld.get("has_issue", false) as bool) else 1.0)
	if efficiency < 1.0:
		marks.append("[color=%s]%s %d%%[/color]" % [UiStyle.hex(UiStyle.WARN), Localization.t("ui.flow.efficiency", "Efficiency"), int(efficiency * 100.0)])
	return "   ".join(marks)


func _get_orchestrator() -> GameOrchestrator:
	var main_node: Node = get_tree().current_scene
	if main_node and main_node.has_method("get_orchestrator"):
		return main_node.call("get_orchestrator") as GameOrchestrator
	return null


func _uses_road_flow(def: Dictionary, produces: Dictionary, consumes: Dictionary) -> bool:
	if def.get("requires_road", false) as bool:
		return true
	return _has_transport(produces, "road") or _has_transport(consumes, "road")


func _uses_water_flow(def: Dictionary, type_id: String, produces: Dictionary, consumes: Dictionary) -> bool:
	if (def.get("category", "") as String) == "Residential":
		return true
	if type_id == "water_tower":
		return true
	return produces.has("water_res") or consumes.has("water_res") or produces.has("res_water_stockpile") or consumes.has("res_water_stockpile")


func _uses_power_flow(type_id: String, produces: Dictionary, consumes: Dictionary) -> bool:
	if type_id == "power":
		return true
	return produces.has("energy") or consumes.has("energy")


func _has_transport(resources: Dictionary, transport: String) -> bool:
	for res_id: String in resources:
		var rdef: Dictionary = ContentDB.get_resource_def(res_id)
		if (rdef.get("transport", "global") as String) == transport:
			return true
	return false


func _missing_inputs(coord: Vector2i, consumes: Dictionary, flow: ResourceFlow) -> Array[String]:
	var missing: Array[String] = []
	for res_id: String in consumes:
		var rdef: Dictionary = ContentDB.get_resource_def(res_id)
		var label: String = Localization.content_text(rdef, "label", res_id)
		if flow.delivery_efficiency(res_id, coord) < 1.0:
			missing.append("%s (%s)" % [label, Localization.t("ui.flow.delivery", "delivery")])
			continue
		var required: float = consumes[res_id] as float
		if GameStateStore.get_resource(res_id) < required:
			missing.append("%s (%s)" % [label, Localization.t("ui.flow.stock", "stock")])
	return missing


func _blocked_outputs(coord: Vector2i, type_id: String, produces: Dictionary, flow: ResourceFlow) -> Array[String]:
	var blocked: Array[String] = []
	for res_id: String in produces:
		if flow.output_efficiency_for(res_id, coord, type_id) >= 1.0:
			continue
		var rdef: Dictionary = ContentDB.get_resource_def(res_id)
		blocked.append(Localization.content_text(rdef, "label", res_id))
	return blocked


# ===========================================================
# HELP PANEL (center, toggled with H)
# ===========================================================

func _build_help_panel() -> void:
	_help_panel = PanelContainer.new()
	_help_panel.set_anchors_preset(PRESET_CENTER)
	_help_panel.size = Vector2(560, 420)
	_help_panel.position = Vector2(-280, -210)
	_help_panel.visible = false
	_help_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_help_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_help_panel.add_child(margin)

	var help_box := VBoxContainer.new()
	help_box.add_theme_constant_override("separation", 8)
	margin.add_child(help_box)
	var help_head := HBoxContainer.new()
	help_box.add_child(help_head)
	var help_title := Label.new()
	_loc(help_title, func() -> String: return Localization.ru_en("Справка", "Help"))
	UiStyle.title(help_title, 22, UiStyle.ACCENT)
	help_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help_head.add_child(help_title)
	var help_close := Button.new()
	help_close.text = "✕"
	_loc(help_close, func() -> String: return Localization.ru_en("Закрыть (H)", "Close (H)"), "tooltip_text")
	help_close.custom_minimum_size = Vector2(34, 30)
	help_close.pressed.connect(toggle_help)
	help_head.add_child(help_close)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(530, 350)
	help_box.add_child(scroll)

	_help_label = Label.new()
	_help_label.custom_minimum_size.x = 510
	_help_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_label.add_theme_font_size_override("font_size", 13)
	_help_label.add_theme_constant_override("line_spacing", 4)
	_help_label.add_theme_color_override("font_color", UiStyle.TEXT)
	_help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help_label.text = _get_help_text()
	scroll.add_child(_help_label)


func _get_help_text() -> String:
	return Localization.t("ui.help.text", "H — справка. Q вода · E сезон · T журнал · Y дневник · Пробел пауза · 1/2/3 скорость.")


func toggle_help() -> void:
	_help_visible = not _help_visible
	_help_panel.visible = _help_visible


# ===========================================================
# START PANEL (center) — start profile / faction background
# ===========================================================

func _build_start_panel() -> void:
	# Dim the (already booted) map behind the menu so the menu reads as a menu, not a popup.
	_start_dim = ColorRect.new()
	_start_dim.color = Color(0.03, 0.025, 0.02, 0.88)
	_start_dim.set_anchors_preset(PRESET_FULL_RECT)
	_start_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_start_dim)
	OnboardingManager.suppressed = true

	_start_panel = PanelContainer.new()
	_start_panel.set_anchors_preset(PRESET_CENTER)
	_start_panel.size = Vector2(640, 520)
	_start_panel.position = Vector2(-320, -260)
	_start_panel.visible = true
	_start_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = UiStyle.panel_box(28)
	style.border_color = UiStyle.ACCENT_DIM
	_start_panel.add_theme_stylebox_override("panel", style)
	add_child(_start_panel)
	_rebuild_start_panel()


func _build_minimap() -> void:
	_minimap_panel = PanelContainer.new()
	_minimap_panel.custom_minimum_size = Vector2(LEFT_W, 124)
	_minimap_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Position: Top-left, under resource bar
	_minimap_panel.anchor_left = 0.0
	_minimap_panel.anchor_right = 0.0
	_minimap_panel.anchor_top = 0.0
	_minimap_panel.anchor_bottom = 0.0
	_minimap_panel.offset_left = 10
	_minimap_panel.offset_top = 55
	# Add some styling to the panel
	_minimap_panel.add_theme_stylebox_override("panel", UiStyle.panel_box(6))
	add_child(_minimap_panel)

	var v_box := VBoxContainer.new()
	_minimap_panel.add_child(v_box)

	var label := Label.new()
	_loc(label, func() -> String: return Localization.ru_en("Карта", "Map"))
	UiStyle.caption(label)
	v_box.add_child(label)

	var sub_v_cont := SubViewportContainer.new()
	sub_v_cont.stretch = true
	sub_v_cont.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sub_v_cont.gui_input.connect(_on_minimap_gui_input)
	v_box.add_child(sub_v_cont)

	_minimap_viewport = SubViewport.new()
	_minimap_viewport.handle_input_locally = false
	_minimap_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Share the world with main viewport
	_minimap_viewport.world_2d = get_viewport().world_2d
	sub_v_cont.add_child(_minimap_viewport)

	_minimap_camera = Camera2D.new()
	_minimap_camera.zoom = Vector2(0.15, 0.15) # Show broad area
	_minimap_viewport.add_child(_minimap_camera)


func _on_minimap_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_teleport_camera_to_minimap_pos(mb.position)


func _teleport_camera_to_minimap_pos(click_pos: Vector2) -> void:
	if _minimap_viewport == null or _minimap_camera == null: return
	
	# Calculate world position from click
	# Viewport is 180x100 approx. Camera is at global_position with 0.15 zoom.
	# WorldPos = CameraPos + (ClickPos - ViewportCenter) / Zoom
	var vp_size = _minimap_viewport.size
	var world_pos = _minimap_camera.global_position + (click_pos - vp_size / 2.0) / _minimap_camera.zoom
	
	var main_node = get_tree().current_scene
	var main_cam = main_node.get_node_or_null("Camera")
	if main_cam:
		# Use global_position as target
		main_cam.global_position = world_pos
		EventBus.toast_requested.emit("Jump to position", 0.5)


func _rebuild_start_panel() -> void:
	if _start_panel == null:
		return
	for c: Node in _start_panel.get_children():
		c.queue_free()

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	_start_panel.add_child(root)

	if _start_menu_mode == "main":
		# The title screen: the game's name, not a form heading.
		var title := Label.new()
		title.text = "MANDATE CITIES"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiStyle.title(title, 38, UiStyle.ACCENT)
		root.add_child(title)
		var chapter := Label.new()
		chapter.text = Localization.ru_en("Ржавая Нора", "The Rust Pit")
		chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiStyle.caption(chapter)
		chapter.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
		root.add_child(chapter)
	else:
		var header := HBoxContainer.new()
		root.add_child(header)
		var title := Label.new()
		title.text = Localization.t("ui.start.title", "Choose Your Mandate")
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiStyle.title(title, 24)
		header.add_child(title)
		var back_btn := Button.new()
		back_btn.text = "‹  " + Localization.ru_en("Назад", "Back")
		back_btn.pressed.connect(func(): _start_menu_mode = "main"; _rebuild_start_panel())
		header.add_child(back_btn)

	root.add_child(HSeparator.new())

	if _start_menu_mode == "main":
		_build_main_menu_options(root)
	elif _start_menu_mode == "campaign":
		_build_campaign_list(root)
	elif _start_menu_mode == "sandbox":
		_build_sandbox_options(root)


func _build_main_menu_options(container: Control) -> void:
	# What the game is, in the player's first ten seconds (UX_BIBLE §1).
	var desc := Label.new()
	desc.text = Localization.t("ui.start.pitch", "Mandate Cities — градостроитель о власти взаймы.")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_constant_override("line_spacing", 4)
	container.add_child(desc)

	var btn_campaign := Button.new()
	btn_campaign.text = Localization.t("ui.menu.campaign", "НОВАЯ ИГРА")
	btn_campaign.custom_minimum_size.y = 52
	btn_campaign.add_theme_font_size_override("font_size", 17)
	UiStyle.primary(btn_campaign)
	btn_campaign.pressed.connect(func(): _start_menu_mode = "campaign"; _rebuild_start_panel())
	container.add_child(btn_campaign)

	# Sandbox is hidden: it only started the default profile and confused testers.

	var btn_continue := Button.new()
	btn_continue.text = Localization.t("ui.menu.continue", "ПРОДОЛЖИТЬ")
	btn_continue.custom_minimum_size.y = 44
	btn_continue.disabled = not SaveService.has_save(0)
	btn_continue.pressed.connect(_on_continue_pressed)
	container.add_child(btn_continue)

	var tutorial_text: String = Localization.ru_en("Обучение: первые пять минут под руководством", "Tutorial: a guided first five minutes")
	var tutorial_box := Button.new()
	tutorial_box.toggle_mode = true
	tutorial_box.flat = true
	tutorial_box.button_pressed = TutorialManager.enabled_for_next_run
	tutorial_box.text = ("✔  " if tutorial_box.button_pressed else "○  ") + tutorial_text
	tutorial_box.add_theme_font_size_override("font_size", 13)
	tutorial_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tutorial_box.toggled.connect(func(on: bool) -> void:
		TutorialManager.enabled_for_next_run = on
		tutorial_box.text = ("✔  " if on else "○  ") + tutorial_text)
	container.add_child(tutorial_box)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(spacer)

	# Language right on the menu: testers pick it before the first letter arrives.
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	container.add_child(footer)
	for locale: String in ["en", "ru"]:
		var btn_lang := Button.new()
		btn_lang.text = "English" if locale == "en" else "Русский"
		btn_lang.toggle_mode = true
		btn_lang.button_pressed = Localization.current_locale == locale
		btn_lang.custom_minimum_size = Vector2(110, 34)
		btn_lang.add_theme_font_size_override("font_size", 13)
		btn_lang.pressed.connect(Localization.set_locale.bind(locale))
		footer.add_child(btn_lang)
	var version := Label.new()
	version.text = "%s %s" % [Localization.ru_en("тестовая сборка", "playtest build"), ProjectSettings.get_setting("application/config/version", "")]
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	version.add_theme_font_size_override("font_size", 12)
	version.add_theme_color_override("font_color", UiStyle.TEXT_MUTE)
	footer.add_child(version)


func _on_continue_pressed() -> void:
	if SaveService.load_game(0):
		_close_start_panel()
		_update_resource_bar()
		_rebuild_building_list()


func _build_campaign_list(container: Control) -> void:
	var intro := Label.new()
	intro.text = Localization.t("ui.start.campaign_intro", "Выберите, кто вас назначил. Для первой игры берите мандат Лиги.")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 13)
	intro.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	container.add_child(intro)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	# Appointed (patron) starts first — that is the chapter; founder starts are experimental.
	var ids: Array = ContentDB.get_start_profile_ids()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return _profile_rank(a) < _profile_rank(b))
	var experimental: Array = []
	for profile_id: String in ids:
		if _profile_rank(profile_id) >= 2:
			experimental.append(profile_id)
		else:
			list.add_child(_build_start_profile_row(profile_id))
	if not experimental.is_empty():
		# Founder starts sit outside the current chapter: keep them out of a first-timer's way.
		var more := Button.new()
		more.flat = true
		more.text = Localization.ru_en("Показать экспериментальные старты (%d)", "Show experimental starts (%d)") % experimental.size()
		more.add_theme_font_size_override("font_size", 12)
		list.add_child(more)
		more.pressed.connect(func() -> void:
			more.queue_free()
			for profile_id: String in experimental:
				list.add_child(_build_start_profile_row(profile_id)))


func _profile_rank(profile_id: String) -> int:
	if profile_id == "appointed_administrator":
		return 0
	var path: String = ContentDB.get_start_profile_def(profile_id).get("start_path", "appointed") as String
	return 1 if path == "appointed" else 2


func _build_sandbox_options(container: Control) -> void:
	var intro := Label.new()
	intro.text = "Sandbox mode: unlimited potential, no pressure."
	intro.add_theme_font_size_override("font_size", 12)
	container.add_child(intro)
	
	# For now, just use the first profile as default sandbox
	var profiles = ContentDB.get_start_profile_ids()
	if not profiles.is_empty():
		var btn := Button.new()
		btn.text = "Start Default Sandbox"
		btn.custom_minimum_size.y = 60
		btn.pressed.connect(_start_new_run.bind(profiles[0]))
		container.add_child(btn)


func _build_start_profile_row(profile_id: String) -> Control:
	var def: Dictionary = ContentDB.get_start_profile_def(profile_id)
	var recommended: bool = profile_id == "appointed_administrator"
	var panel := PanelContainer.new()
	var card: StyleBoxFlat = UiStyle.card_box("active" if recommended else "normal")
	card.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 5)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)

	if recommended:
		var badge := Label.new()
		badge.text = Localization.t("ui.start.recommended", "Рекомендуется для первой игры")
		UiStyle.caption(badge)
		text_box.add_child(badge)

	var title := Label.new()
	title.text = Localization.content_text(def, "label", profile_id)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyle.title(title, 17)
	text_box.add_child(title)

	# One line on how it plays, instead of a paragraph of terms.
	var style_text: String = _profile_playstyle(profile_id)
	if style_text == "":
		style_text = Localization.content_text(def, "description", "")
	var desc := Label.new()
	desc.text = style_text
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	text_box.add_child(desc)

	# The two meters the whole game is about — each explains itself on hover.
	var mandate_data: Dictionary = def.get("mandate", {})
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 14)
	text_box.add_child(stats)
	_profile_stat(stats, Localization.ru_en("Доверие покровителя", "Patron trust"), mandate_data.get("patron_trust", 0) as int,
		Localization.ru_en("Как к вам относится тот, кто вас назначил. Растёт, когда вы выполняете его просьбы и проходите аудит. Упадёт до нуля — вас отзовут.",
			"How the one who appointed you sees you. It grows when you do what they ask and pass the audit. At zero you are recalled."))
	_profile_stat(stats, Localization.ru_en("Поддержка города", "City support"), mandate_data.get("support", 0) as int,
		Localization.ru_en("Как к вам относятся жители. Растёт, когда вы встаёте на их сторону. Упадёт до нуля — бунт.",
			"How the residents see you. It grows when you take their side. At zero they riot."))

	var btn := Button.new()
	btn.text = Localization.t("ui.start.begin", "Begin")
	btn.custom_minimum_size = Vector2(104, 42)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if recommended:
		UiStyle.primary(btn)
	btn.pressed.connect(_start_new_run.bind(profile_id))
	row.add_child(btn)

	return panel


func _profile_playstyle(profile_id: String) -> String:
	match profile_id:
		"appointed_administrator":
			return Localization.ru_en("Мандат Лиги Восстановления. Покровитель мягкий, требует беречь людей. Игра о балансе между его просьбами и жителями.",
				"A Restoration League mandate. A soft patron who wants the people kept safe. A game of balancing its requests against the residents.")
		"directorate_administrator":
			return Localization.ru_en("Мандат Гражданского Директората. Больше денег, но жители холоднее, а проверки жёстче. Игра о порядке и отчётности.",
				"A Civic Directorate mandate. More money, but colder residents and harsher inspections. A game of order and reporting.")
	return ""


func _profile_stat(parent: Control, label: String, value: int, hint: String) -> void:
	var stat := Label.new()
	stat.text = "%s  %d" % [label, value]
	stat.tooltip_text = hint
	stat.mouse_filter = Control.MOUSE_FILTER_STOP
	stat.mouse_default_cursor_shape = Control.CURSOR_HELP
	stat.add_theme_font_size_override("font_size", 12)
	stat.add_theme_color_override("font_color", UiStyle.ACCENT)
	parent.add_child(stat)


func _start_new_run(profile_id: String) -> void:
	var main_node: Node = get_tree().current_scene
	if main_node and main_node.has_method("start_new_run"):
		main_node.call("start_new_run", profile_id)
	_close_start_panel()
	TutorialManager.on_run_started()
	_update_resource_bar()
	_rebuild_building_list()
	_show_info(_get_welcome_text())
	var profile_def: Dictionary = ContentDB.get_start_profile_def(profile_id)
	EventBus.toast_requested.emit(
		Localization.t("ui.start.started", "Started: %s") % Localization.content_text(profile_def, "label", profile_id),
		3.0
	)


func _close_start_panel() -> void:
	_start_visible = false
	_start_panel.visible = false
	_start_dim.visible = false
	OnboardingManager.suppressed = false


func _on_new_game_started() -> void:
	_update_resource_bar()
	_rebuild_building_list()
	if _city_visible:
		_rebuild_city_panel()


# ===========================================================
# CITY PANEL (center) — Level requirements / manual upgrade
# ===========================================================

func _build_city_panel() -> void:
	_city_panel = PanelContainer.new()
	_city_panel.set_anchors_preset(PRESET_CENTER)
	_city_panel.size = Vector2(560, 500)
	_city_panel.position = Vector2(-280, -240)
	_city_panel.visible = false
	_city_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_city_panel)
	_rebuild_city_panel()


func toggle_city_panel() -> void:
	_city_visible = not _city_visible
	_city_panel.visible = _city_visible
	if _city_visible:
		_rebuild_city_panel()


func _rebuild_city_panel() -> void:
	if _city_panel == null:
		return
	for c: Node in _city_panel.get_children():
		c.queue_free()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_city_panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(532, 512)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var root := VBoxContainer.new()
	root.custom_minimum_size.x = 520
	root.add_theme_constant_override("separation", 10)
	scroll.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)

	var title := Label.new()
	title.text = Localization.t("ui.city.title", "City Level")
	UiStyle.title(title, 22, UiStyle.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = Localization.t("ui.common.close", "Close")
	close_btn.pressed.connect(toggle_city_panel)
	header.add_child(close_btn)

	var current_level: int = GameStateStore.progression().city_level as int
	var current_def: Dictionary = ContentDB.get_level_def(current_level)
	var current_name: String = Localization.content_text(current_def, "name", "?")
	var current_lbl := Label.new()
	current_lbl.text = "%s: %s %d - %s" % [
		Localization.t("ui.city.current", "Current"),
		Localization.t("ui.resource.level", "Lv"),
		current_level,
		current_name,
	]
	current_lbl.add_theme_font_size_override("font_size", 13)
	current_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	root.add_child(current_lbl)

	var next_def: Dictionary = ContentDB.get_level_def(current_level + 1)
	if next_def.is_empty():
		var max_lbl := Label.new()
		max_lbl.text = Localization.t("ui.city.max_level", "Max city level reached.")
		max_lbl.add_theme_font_size_override("font_size", 13)
		root.add_child(max_lbl)
		return

	var next_name: String = Localization.content_text(next_def, "name", "?")
	var next_lbl := Label.new()
	next_lbl.text = "%s: %s %d - %s" % [
		Localization.t("ui.city.next", "Next"),
		Localization.t("ui.resource.level", "Lv"),
		current_level + 1,
		next_name,
	]
	next_lbl.add_theme_font_size_override("font_size", 14)
	root.add_child(next_lbl)

	var reqs: Dictionary = next_def.get("requirements", {}) as Dictionary
	var req_title := Label.new()
	req_title.text = Localization.t("ui.city.requirements", "Requirements")
	req_title.add_theme_font_size_override("font_size", 13)
	root.add_child(req_title)

	var can_upgrade := true
	for res_id: String in reqs:
		var needed: float = reqs[res_id] as float
		var have: float = GameStateStore.get_resource(res_id)
		var rdef: Dictionary = ContentDB.get_resource_def(res_id)
		var line := Label.new()
		line.text = "%s: %d/%d" % [Localization.content_text(rdef, "label", res_id), int(have), int(needed)]
		line.add_theme_font_size_override("font_size", 12)
		line.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55) if have >= needed else Color(1.0, 0.55, 0.45))
		root.add_child(line)
		if have < needed:
			can_upgrade = false

	var reward: Dictionary = next_def.get("reward", {}) as Dictionary
	var reward_lbl := Label.new()
	reward_lbl.text = "%s: %s" % [Localization.t("ui.city.reward", "Reward"), _format_cost(reward)]
	reward_lbl.add_theme_font_size_override("font_size", 12)
	reward_lbl.add_theme_color_override("font_color", UiStyle.ACCENT)
	root.add_child(reward_lbl)

	var upgrade_btn := Button.new()
	upgrade_btn.text = Localization.t("ui.city.upgrade", "Upgrade City")
	upgrade_btn.disabled = not can_upgrade
	upgrade_btn.pressed.connect(_upgrade_city_level)
	root.add_child(upgrade_btn)

	var note := Label.new()
	note.text = Localization.t("ui.city.spend_note", "Upgrade spends the required resources and unlocks the next building tier.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	root.add_child(note)

	var sep := HSeparator.new()
	root.add_child(sep)

	var diag_title := Label.new()
	diag_title.text = Localization.t("ui.city.diagnostics", "City Diagnostics")
	diag_title.add_theme_font_size_override("font_size", 14)
	root.add_child(diag_title)

	var diag := Label.new()
	diag.text = _build_city_diagnostics_text()
	diag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	diag.custom_minimum_size.x = 520
	diag.add_theme_font_size_override("font_size", 12)
	diag.add_theme_constant_override("line_spacing", 3)
	diag.add_theme_color_override("font_color", Color(0.9, 0.95, 0.85))
	root.add_child(diag)


func _upgrade_city_level() -> void:
	var orch: GameOrchestrator = _get_orchestrator()
	if orch == null:
		return
	var cmd: CommandBase = load("res://scripts/core/commands/level_up_command.gd").new()
	orch.command_bus.execute(cmd)
	_update_resource_bar()
	_rebuild_building_list()
	_rebuild_city_panel()


func _build_city_diagnostics_text() -> String:
	var orch: GameOrchestrator = _get_orchestrator()
	if orch == null or orch.coverage == null:
		return Localization.t("ui.city.diagnostics_unavailable", "Diagnostics unavailable")

	var total_buildings := 0
	var road_required := 0
	var road_missing := 0
	var issues := 0
	var damaged := 0
	var utility_stats: Dictionary = _collect_utility_stats()

	for coord: Vector2i in GameStateStore.get_all_building_coords():
		total_buildings += 1
		var bld: Dictionary = GameStateStore.get_building(coord)
		var type_id: String = bld.get("type", "") as String
		var def: Dictionary = ContentDB.get_building_def(type_id)

		if def.get("requires_road", false) as bool:
			road_required += 1
			if not orch.coverage.is_road_connected(coord):
				road_missing += 1
		if bld.get("has_issue", false) as bool:
			issues += 1
		if bld.get("damaged", false) as bool:
			damaged += 1

	var lines: Array[String] = []
	var residential: int = utility_stats.get("residential", 0) as int
	var residential_watered: int = utility_stats.get("residential_watered", 0) as int
	var power_users: int = utility_stats.get("power_users", 0) as int
	var power_covered: int = utility_stats.get("power_covered", 0) as int
	lines.append("%s: %d" % [Localization.t("ui.city.buildings", "Buildings"), total_buildings])
	lines.append("%s: %s" % [
		Localization.t("ui.city.local_utilities", "Local utilities"),
		"%s | %s" % [
			_coverage_ratio_text(Localization.t("ui.flow.water", "Water"), residential_watered, residential),
			_coverage_ratio_text(Localization.t("ui.flow.power", "Power"), power_covered, power_users),
		],
	])
	lines.append("%s: %d/%d %s" % [
		Localization.t("ui.city.road_connected", "Road connected"),
		maxi(road_required - road_missing, 0),
		road_required,
		_status_word(road_missing == 0),
	])
	lines.append("%s: %d | %s: %d" % [
		Localization.t("ui.city.issues", "Issues"),
		issues,
		Localization.t("ui.city.damaged", "Damaged"),
		damaged,
	])
	lines.append("%s: %d | %s: %d" % [
		Localization.t("ui.city.water_reserve", "Water Reserve"),
		int(GameStateStore.get_resource("res_water_stockpile")),
		Localization.t("ui.resource.energy", "Energy"),
		int(GameStateStore.get_resource("energy")),
	])
	lines.append(Localization.t("ui.city.coverage_note", "Reserve/Energy are stockpiles. Water/Power are local coverage."))
	return "\n".join(lines)


func _status_word(ok: bool) -> String:
	return Localization.t("ui.flow.ok", "OK") if ok else Localization.t("ui.flow.missing_caps", "MISSING")


# ===========================================================
# SETTINGS PANEL (center) — Language / options
# ===========================================================

func _build_settings_panel() -> void:
	_settings_panel = PanelContainer.new()
	_settings_panel.set_anchors_preset(PRESET_CENTER)
	_settings_panel.size = Vector2(420, 220)
	_settings_panel.position = Vector2(-210, -110)
	_settings_panel.visible = false
	_settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_settings_panel)
	_rebuild_settings_panel()


func toggle_settings() -> void:
	_settings_visible = not _settings_visible
	_settings_panel.visible = _settings_visible
	if _settings_visible:
		_rebuild_settings_panel()


func _rebuild_settings_panel() -> void:
	if _settings_panel == null:
		return
	for c: Node in _settings_panel.get_children():
		c.queue_free()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_settings_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)

	var title := Label.new()
	title.text = Localization.t("ui.settings.title", "Options")
	UiStyle.title(title, 22, UiStyle.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = Localization.t("ui.common.close", "Close")
	close_btn.pressed.connect(toggle_settings)
	header.add_child(close_btn)

	var language_row := HBoxContainer.new()
	language_row.add_theme_constant_override("separation", 10)
	root.add_child(language_row)

	var language_label := Label.new()
	language_label.text = Localization.t("ui.settings.language", "Language")
	language_label.custom_minimum_size.x = 120
	language_row.add_child(language_label)

	_settings_language_select = OptionButton.new()
	_settings_language_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_language_select.add_item(Localization.t("ui.language.english", "English"))
	_settings_language_select.set_item_metadata(0, "en")
	_settings_language_select.add_item(Localization.t("ui.language.russian", "Russian"))
	_settings_language_select.set_item_metadata(1, "ru")
	_settings_language_select.select(0 if Localization.current_locale == "en" else 1)
	_settings_language_select.item_selected.connect(_on_settings_language_selected)
	language_row.add_child(_settings_language_select)

	var note := Label.new()
	note.text = Localization.t("ui.settings.language_note", "Language is saved automatically.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	root.add_child(note)

	# Play logs (RunLog): testers attach this folder to their feedback.
	var logs_row := HBoxContainer.new()
	logs_row.add_theme_constant_override("separation", 10)
	root.add_child(logs_row)
	var logs_note := Label.new()
	logs_note.text = Localization.ru_en("Журнал партий хранится только на этом компьютере. Приложите папку к отзыву.",
		"Play logs stay on this computer. Attach the folder to your feedback.")
	logs_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	logs_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	logs_note.add_theme_font_size_override("font_size", 12)
	logs_note.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	logs_row.add_child(logs_note)
	var logs_btn := Button.new()
	logs_btn.text = Localization.ru_en("Открыть папку", "Open folder")
	logs_btn.pressed.connect(func() -> void: OS.shell_open(RunLog.folder()))
	logs_row.add_child(logs_btn)


func _on_settings_language_selected(index: int) -> void:
	if _settings_language_select == null:
		return
	var locale := _settings_language_select.get_item_metadata(index) as String
	Localization.set_locale(locale)


# ===========================================================
# GOVERNANCE PANEL (center) — Tech / Policies
# ===========================================================

func _build_governance_panel() -> void:
	_governance_panel = PanelContainer.new()
	_governance_panel.set_anchors_preset(PRESET_CENTER)
	_governance_panel.size = Vector2(620, 500)
	_governance_panel.position = Vector2(-310, -250)
	_governance_panel.visible = false
	_governance_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_governance_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_governance_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)

	var title := Label.new()
	_loc(title, func() -> String: return Localization.t("ui.governance.title", "Governance"))
	UiStyle.title(title, 22, UiStyle.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	_loc(close_btn, func() -> String: return Localization.t("ui.common.close", "Close"))
	close_btn.pressed.connect(toggle_governance)
	header.add_child(close_btn)

	_governance_tabs = TabContainer.new()
	_governance_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_governance_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_governance_tabs)

	_rebuild_governance_panel()


func toggle_governance() -> void:
	_governance_visible = not _governance_visible
	_governance_panel.visible = _governance_visible
	if _governance_visible:
		_rebuild_governance_panel()


func _rebuild_governance_panel() -> void:
	if _governance_tabs == null:
		return
	for c: Node in _governance_tabs.get_children():
		_governance_tabs.remove_child(c)
		c.queue_free()
	_governance_tabs.add_child(_build_tech_tab())
	_governance_tabs.add_child(_build_policy_tab())
	_governance_tabs.set_tab_title(0, Localization.t("ui.tech.tab", "Tech"))
	_governance_tabs.set_tab_title(1, Localization.t("ui.policy.tab", "Policies"))


func _build_tech_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = Localization.t("ui.tech.tab", "Tech")
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for tech_id: String in ContentDB.get_technology_ids():
		list.add_child(_build_tech_row(tech_id))

	return scroll


func _build_tech_row(tech_id: String) -> Control:
	var def: Dictionary = ContentDB.get_technology_def(tech_id)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.card_box())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)

	var researched: bool = GameStateStore.has_technology(tech_id)
	var title := Label.new()
	title.text = "%s%s" % [Localization.content_text(def, "label", tech_id), Localization.t("ui.tech.done_suffix", " [DONE]") if researched else ""]
	title.add_theme_font_size_override("font_size", 13)
	text_box.add_child(title)

	var desc := Label.new()
	desc.text = Localization.content_text(def, "description", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	text_box.add_child(desc)

	text_box.add_child(_bb_line("%s  %s      [color=%s]%s[/color]" % [
		_dim_bb(Localization.t("ui.meta.cost", "Cost") + ":"),
		_cost_bb(def.get("cost", {})),
		UiStyle.hex(UiStyle.GOOD),
		_format_effects(def.get("effects", {})),
	], UiStyle.TEXT))

	var btn := Button.new()
	btn.text = Localization.t("ui.tech.researched", "Researched") if researched else Localization.t("ui.tech.research", "Research")
	btn.disabled = researched or not _can_research_tech(def)
	btn.pressed.connect(_research_technology.bind(tech_id))
	row.add_child(btn)

	return panel


func _build_policy_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = Localization.t("ui.policy.tab", "Policies")
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var active_summary := Label.new()
	active_summary.text = Localization.t("ui.policy.active_prefix", "Active: ") + _format_active_policies()
	active_summary.add_theme_font_size_override("font_size", 12)
	active_summary.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	list.add_child(active_summary)

	for policy_id: String in ContentDB.get_policy_ids():
		list.add_child(_build_policy_row(policy_id))

	return scroll


func _build_policy_row(policy_id: String) -> Control:
	var def: Dictionary = ContentDB.get_policy_def(policy_id)
	var category: String = def.get("category", "general") as String
	var active: bool = GameStateStore.get_active_policy(category) == policy_id
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.card_box())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)

	var title := Label.new()
	title.text = "[%s] %s%s" % [
		category.capitalize(),
		Localization.content_text(def, "label", policy_id),
		Localization.t("ui.policy.active_suffix", " [ACTIVE]") if active else "",
	]
	title.add_theme_font_size_override("font_size", 13)
	text_box.add_child(title)

	var desc := Label.new()
	desc.text = Localization.content_text(def, "description", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	text_box.add_child(desc)

	text_box.add_child(_bb_line("%s  %s      [color=%s]%s[/color]" % [
		_dim_bb(Localization.t("ui.meta.switch", "Switch") + ":"),
		_cost_bb(def.get("switch_cost", {})) if not (def.get("switch_cost", {}) as Dictionary).is_empty() else Localization.t("ui.common.free", "free"),
		UiStyle.hex(UiStyle.GOOD),
		_format_effects(def.get("effects", {})),
	], UiStyle.TEXT))

	var btn := Button.new()
	btn.text = Localization.t("ui.policy.active", "Active") if active else Localization.t("ui.policy.set", "Set")
	btn.disabled = active or not _can_set_policy(def)
	btn.pressed.connect(_set_policy.bind(policy_id))
	row.add_child(btn)

	return panel


func _research_technology(tech_id: String) -> void:
	var orch: GameOrchestrator = _get_orchestrator()
	if orch == null:
		return
	var cmd: CommandBase = load("res://scripts/core/commands/research_technology_command.gd").new(tech_id)
	orch.command_bus.execute(cmd)
	_update_resource_bar()
	_rebuild_governance_panel()


func _set_policy(policy_id: String) -> void:
	var orch: GameOrchestrator = _get_orchestrator()
	if orch == null:
		return
	orch.command_bus.execute(SetPolicyCommand.new(policy_id))
	_update_resource_bar()
	_rebuild_governance_panel()

func _can_research_tech(def: Dictionary) -> bool:
	if not GameStateStore.can_afford(def.get("cost", {})):
		return false
	var requires: Array = def.get("requires", [])
	for req_var: Variant in requires:
		if not GameStateStore.has_technology(req_var as String):
			return false
	return true


func _can_set_policy(def: Dictionary) -> bool:
	if not GameStateStore.can_afford(def.get("switch_cost", {})):
		return false
	var requirements: Dictionary = def.get("requirements", {})
	var city_level: int = requirements.get("city_level", 1) as int
	if (GameStateStore.progression().city_level as int) < city_level:
		return false
	var techs: Array = requirements.get("tech", [])
	for tech_var: Variant in techs:
		if not GameStateStore.has_technology(tech_var as String):
			return false
	return true


func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return Localization.t("ui.common.free", "free")
	var parts: Array[String] = []
	for res_id: String in cost:
		var rdef: Dictionary = ContentDB.get_resource_def(res_id)
		parts.append("%s:%d" % [Localization.content_text(rdef, "label", res_id), int(cost[res_id] as float)])
	return ", ".join(parts)


func _format_effects(effects: Dictionary) -> String:
	if effects.is_empty():
		return Localization.t("ui.common.none", "none")
	var parts: Array[String] = []
	if effects.has("production_mult"):
		var prod: Dictionary = effects.production_mult
		for res_id: String in prod:
			var rdef: Dictionary = ContentDB.get_resource_def(res_id)
			parts.append("%s %+d%%" % [Localization.content_text(rdef, "label", res_id), int((prod[res_id] as float) * 100.0)])
	if effects.has("happiness_add"):
		parts.append("%s %+d" % [Localization.t("ui.effect.happiness", "Happy"), int(effects.happiness_add as float)])
	if effects.has("pressure_delta"):
		parts.append("%s %+d" % [Localization.t("ui.effect.pressure", "Pressure"), int(effects.pressure_delta as float)])
	if effects.has("pressure_mult"):
		parts.append("%s x%.2f" % [Localization.t("ui.effect.pressure", "Pressure"), effects.pressure_mult as float])
	return ", ".join(parts)


func _format_active_policies() -> String:
	var active: Dictionary = GameStateStore.get_active_policies()
	if active.is_empty():
		return Localization.t("ui.common.none", "none")
	var parts: Array[String] = []
	for category: String in active:
		var policy_id: String = active[category] as String
		var def: Dictionary = ContentDB.get_policy_def(policy_id)
		parts.append("%s=%s" % [category, Localization.content_text(def, "label", policy_id)])
	return ", ".join(parts)


# ===========================================================
# TOAST (bottom center)
# ===========================================================

func _build_toast() -> void:
	# A short notice in a pill at the bottom centre, clear of both side panels.
	var holder := CenterContainer.new()
	holder.set_anchors_preset(PRESET_BOTTOM_WIDE)
	holder.offset_top = -74
	holder.offset_bottom = -30
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_toast_panel = PanelContainer.new()
	var style: StyleBoxFlat = UiStyle.panel_box(8)
	style.border_color = UiStyle.ACCENT_DIM
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.set_corner_radius_all(16)
	_toast_panel.add_theme_stylebox_override("panel", style)
	_toast_panel.modulate.a = 0.0
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_toast_panel)
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 14)
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_child(_toast_label)


func _on_toast(text: String, duration: float) -> void:
	_toast_label.text = text
	_toast_panel.modulate.a = 1.0
	_toast_timer = duration


func _update_toast_fade(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast_panel.modulate.a = 0.0
		elif _toast_timer < 1.0:
			_toast_panel.modulate.a = _toast_timer


func _on_tick_finished(_tick: int) -> void:
	_update_resource_bar()
	_update_info()
	if _city_visible:
		_rebuild_city_panel()


func _on_coverage_recalculated() -> void:
	_update_resource_bar()
	if _selected_coord != Vector2i(-9999, -9999):
		_update_info()
	if _city_visible:
		_rebuild_city_panel()
