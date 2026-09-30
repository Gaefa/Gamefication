extends Node
## TutorialManager (Autoload)
## A guided first session (playtest: "нужен полноценный тутор"). One step at a time:
## the thing to click is spotlighted (a UI control or map cells), a bubble says what to do
## and why, and the step completes when the player has actually done it. Time stands
## still until the player is told how to start it.
##
## Runs on the first new game (remembered in user://settings.cfg) and whenever the
## "Обучение" box on the start menu is ticked. Skippable at any step.
## Self-contained: owns its CanvasLayer; talks to the scene only through public state.

const SETTINGS_PATH := "user://settings.cfg"
const NO_COORD := Vector2i(-9999, -9999)
const MAX_CELLS := 4

var enabled_for_next_run: bool = true
var active: bool = false
## True once the tutorial has started in this run — the text-only onboarding chain stays quiet.
var ran_this_run: bool = false

var _steps: Array[Dictionary] = []
var _index: int = -1
var _base: Dictionary = {}       # counters captured when a step begins
var _desk_seen: bool = false
var _paused_by_us: bool = false
var _frame: int = 0

var _layer: CanvasLayer
var _shade: Control
var _bubble: PanelContainer
var _title: Label
var _text: RichTextLabel
var _next_btn: Button
var _skip_btn: Button
var _target_rect: Rect2 = Rect2()
var _has_target: bool = false


func _ready() -> void:
	# Dev tools drive the game themselves; a tutorial that pauses time would hang them.
	var tool_run: bool = DisplayServer.get_name() == "headless"
	for arg: String in OS.get_cmdline_args():
		if arg.begins_with("res://tools/"):
			tool_run = true
	enabled_for_next_run = not tool_run and not _load_done()
	_build_ui()
	EventBus.new_game_started.connect(func() -> void:
		ran_this_run = false
		_stop())
	EventBus.game_loaded.connect(func(_slot: int) -> void: _stop())
	EventBus.desk_opened.connect(func(_events: Array) -> void: _desk_seen = true)
	EventBus.ending_triggered.connect(func(_id: String, _kind: String) -> void: _stop())
	Localization.locale_changed.connect(func(_locale: String) -> void:
		if active:
			_steps = _make_steps()
			_show_step())


## Called by the HUD right after a new run has really started (not on Continue).
func on_run_started() -> void:
	if not enabled_for_next_run:
		return
	_steps = _make_steps()
	active = true
	ran_this_run = true
	_desk_seen = false
	SimulationRunner.paused = true
	_paused_by_us = true
	_go(0)


func _process(_delta: float) -> void:
	if not active:
		return
	_frame += 1
	var step: Dictionary = _steps[_index]
	_update_target(step)
	if _frame % 12 == 0:
		_push_cells(step)
	if step.has("done") and (step["done"] as Callable).call():
		_go(_index + 1)


# ------------------------------------------------------------------ steps

func _make_steps() -> Array[Dictionary]:
	var t := func(ru: String, en: String) -> String: return Localization.ru_en(ru, en)
	return [
		{
			"text": t.call("Вы — администратор [b]Ржавой Норы[/b]. Через 18 дней придёт сезон [b]Пыли[/b], на 20-й день — аудит Лиги. Продержитесь до 30-го дня, не потеряв ни Лигу, ни город.\n\nВремя пока стоит — спокойно осмотримся.",
				"You are the administrator of the [b]Rust Pit[/b]. The [b]Dust[/b] season comes in 18 days, the League audit on day 20. Hold out until day 30 without losing the League or the city.\n\nTime is stopped for now — let's look around."),
		},
		{
			"text": t.call("[b]Камера.[/b] WASD или стрелки — двигать, колесо мыши — приближать. Подвиньте карту или покрутите колесо.",
				"[b]Camera.[/b] WASD or arrows to move, mouse wheel to zoom. Move the map or turn the wheel."),
			"enter": func() -> void:
				var cam: Node2D = _camera()
				_base = { "pos": cam.global_position, "zoom": cam.get("zoom") } if cam != null else {},
			"done": func() -> bool:
				var cam: Node2D = _camera()
				if cam == null or _base.is_empty():
					return true
				return cam.global_position.distance_to(_base["pos"] as Vector2) > 30.0 or (cam.get("zoom") as Vector2) != (_base["zoom"] as Vector2),
		},
		{
			"text": t.call("Это [b]Главная Цистерна[/b] — запас воды всего района. Кликните по ней.",
				"This is the [b]Main Cistern[/b] — the district's water reserve. Click it."),
			"cells": func() -> Array: return _coords_of("bld_main_cistern"),
			"done": func() -> bool: return _coords_of("bld_main_cistern").has(_main().get("_selected_coord")),
		},
		{
			"text": t.call("Слева внизу — [b]карточка[/b] выбранного: что это, чего ему не хватает и что делать. Если над зданием значок — кликните, причина будет здесь.",
				"Bottom left is the [b]card[/b] of whatever you selected: what it is, what it lacks and what to do. If a building shows an icon, click it — the cause is here."),
			"target": func() -> Control: return _hud().get("_info_panel"),
		},
		{
			"text": t.call("Справа — стройка. Всё работает только [b]рядом с дорогой[/b]. Выберите «Дорога».",
				"Construction is on the right. Everything works only [b]next to a road[/b]. Pick \"Road\"."),
			"enter": func() -> void: _hud().call("_set_active_category", "Infrastructure"),
			"target": func() -> Control: return _build_button("bld_road"),
			"done": func() -> bool: return _build_mode() == "bld_road",
		},
		{
			"text": t.call("Поставьте [b]две клетки[/b] дороги от существующей. Подсвеченные клетки подходят. ПКМ или Esc — отменить выбор.",
				"Place [b]two road tiles[/b] extending the existing one. Highlighted cells are fine. RMB or Esc cancels."),
			"enter": func() -> void: _base = { "n": _count("bld_road") },
			"target": func() -> Control: return _build_button("bld_road") if _build_mode() != "bld_road" else null,
			"cells": func() -> Array: return _candidates("bld_road", false),
			"done": func() -> bool: return _count("bld_road") >= (_base.get("n", 0) as int) + 2,
		},
		{
			"text": t.call("Теперь вода. Выберите [b]«Колодец-насос»[/b]: он пополняет запас и даёт воду домам вокруг.",
				"Now water. Pick the [b]Well Pump[/b]: it refills the reserve and supplies the houses around it."),
			"target": func() -> Control: return _build_button("bld_well_pump"),
			"done": func() -> bool: return _build_mode() == "bld_well_pump",
		},
		{
			"text": t.call("Поставьте насос [b]у дороги[/b]. Второй насос — ваш запас на Пыль.",
				"Place the pump [b]next to a road[/b]. A second pump is your reserve for the Dust."),
			"enter": func() -> void: _base = { "n": _count("bld_well_pump") },
			"target": func() -> Control: return _build_button("bld_well_pump") if _build_mode() != "bld_well_pump" else null,
			"cells": func() -> Array: return _candidates("bld_well_pump", false),
			"done": func() -> bool: return _count("bld_well_pump") >= (_base.get("n", 0) as int) + 1,
		},
		{
			"text": t.call("Насос выбран. Нажмите [b]V[/b] — увидите, куда достаёт его вода. Дом за пределами круга останется сухим, сколько бы воды ни было в цистерне.",
				"The pump is selected. Press [b]V[/b] to see how far its water reaches. A house outside the circle stays dry however full the cistern is."),
			"enter": func() -> void:
				EventBus.build_mode_changed.emit("")
				var pumps: Array = _coords_of("bld_well_pump")
				if not pumps.is_empty():
					_select(pumps.back() as Vector2i),
			"done": func() -> bool: return _main().get("_show_ranges") == true,
		},
		{
			"text": t.call("Людям нужно жильё. Откройте раздел [b]«Жильё»[/b].",
				"People need housing. Open the [b]Residential[/b] tab."),
			"target": func() -> Control: return (_hud().get("_category_buttons") as Dictionary).get("Residential"),
			"done": func() -> bool: return _hud().get("_active_category") == "Residential",
		},
		{
			"text": t.call("Выберите [b]«Жилой барак»[/b].", "Pick the [b]Shelter[/b]."),
			"target": func() -> Control: return _build_button("bld_shelter"),
			"done": func() -> bool: return _build_mode() == "bld_shelter",
		},
		{
			"text": t.call("Поставьте барак [b]у дороги и в зоне воды[/b] — подсвеченные клетки подходят. Барак без воды пустует.",
				"Place the shelter [b]by a road and inside water range[/b] — highlighted cells fit. A shelter without water stays empty."),
			"enter": func() -> void: _base = { "n": _count("bld_shelter") },
			"target": func() -> Control: return _build_button("bld_shelter") if _build_mode() != "bld_shelter" else null,
			"cells": func() -> Array: return _candidates("bld_shelter", true),
			"done": func() -> bool: return _count("bld_shelter") >= (_base.get("n", 0) as int) + 1,
		},
		{
			"text": t.call("Вверху — всё, за чем надо следить.\n• [b]Ресурсы[/b]: число и прирост за день.\n• [b]Вода[/b]: держится запас или на сколько дней его хватит.\n• [b]Лига ↕ Город[/b] — два хозяина. Любая шкала в ноль — конец.\n• [b]Давление[/b]: четыре шкалы. Дошла до 100 — кризис.",
				"The top bar is everything you must watch.\n• [b]Resources[/b]: the number and the change per day.\n• [b]Water[/b]: whether the reserve holds or how many days are left.\n• [b]League ↕ City[/b] — two masters. Either at zero ends the run.\n• [b]Pressure[/b]: four gauges. At 100 a crisis lands."),
			"enter": func() -> void: EventBus.build_mode_changed.emit(""),
			"target": func() -> Control: return _hud().get("_resource_bar"),
		},
		{
			"text": t.call("Это [b]часы дня[/b]. Сейчас пауза. [b]Пробел[/b] — пуск и пауза, [b]1 / 2 / 3[/b] — скорость. Строить можно и на паузе.\n\nНажмите Пробел — пусть время пойдёт.",
				"This is the [b]day clock[/b]. It is paused. [b]Space[/b] starts and pauses, [b]1 / 2 / 3[/b] set the speed. You can build while paused.\n\nPress Space to let time run."),
			"target": func() -> Control: return _hud().get("_clock_panel"),
			"done": func() -> bool: return not SimulationRunner.paused,
		},
		{
			"text": t.call("День идёт. Стройте, что считаете нужным, — или нажмите [b]3[/b], чтобы ускорить. Вечером придёт почта.",
				"The day is running. Build what you think is needed — or press [b]3[/b] to speed up. Mail comes in the evening."),
			"enter": func() -> void: _paused_by_us = false,
			"compact": true,
			"done": func() -> bool: return _desk_seen,
		},
		{
			"text": t.call("[b]Вечер — Стол администратора.[/b] Письма покровителя и обращения жителей. [b]Наведите курсор на ответ[/b] — увидите, чем он обернётся. Утром решения вступают в силу.",
				"[b]Evening — the Administrator's Desk.[/b] Patron letters and residents' petitions. [b]Hover an answer[/b] to see what it leads to. Decisions take effect in the morning."),
			"top": true,
		},
		{
			"text": t.call("Дальше сами. [b]H[/b] — справка, [b]C[/b] — вода, [b]K[/b] — сезон и прогноз, [b]N[/b] — журнал ваших ответов. Значок над зданием — кликните по нему.\n\nУдачи, администратор.",
				"You are on your own now. [b]H[/b] — help, [b]C[/b] — water, [b]K[/b] — season and forecast, [b]N[/b] — log of your answers. An icon over a building — click it.\n\nGood luck, administrator."),
			"top": true,
			"last": true,
		},
	]


# ------------------------------------------------------------------ flow

func _go(index: int) -> void:
	if index >= _steps.size():
		_finish(true)
		return
	_index = index
	_base = {}
	var step: Dictionary = _steps[_index]
	if step.has("enter"):
		(step["enter"] as Callable).call()
	_show_step()
	_push_cells(step)


func _show_step() -> void:
	var step: Dictionary = _steps[_index]
	_layer.visible = true
	_title.text = "%s · %d / %d" % [Localization.ru_en("Обучение", "Tutorial"), _index + 1, _steps.size()]
	_text.text = step.get("text", "") as String
	_next_btn.visible = not step.has("done")
	_next_btn.text = Localization.ru_en("Играть", "Play") if (step.get("last", false) as bool) else Localization.ru_en("Дальше", "Next")
	_skip_btn.text = Localization.ru_en("Пропустить обучение", "Skip tutorial")
	_skip_btn.visible = not (step.get("last", false) as bool)
	_update_target(step)


func _finish(completed: bool) -> void:
	if completed or active:
		_save_done()
		enabled_for_next_run = false
	if _paused_by_us and SimulationRunner.current_phase == SimulationRunner.Phase.DAY and not SimulationRunner.card_open:
		SimulationRunner.paused = false
	_stop()


func _stop() -> void:
	active = false
	_paused_by_us = false
	_index = -1
	if _layer != null:
		_layer.visible = false
	_set_cells([])


# ------------------------------------------------------------------ scene access

func _main() -> Node:
	return get_tree().current_scene


func _hud() -> Node:
	return _main().get("_hud") as Node


func _camera() -> Node2D:
	return _main().get_node_or_null("Camera") as Node2D


func _build_mode() -> String:
	return _main().get("_build_mode") as String


func _select(coord: Vector2i) -> void:
	_main().set("_selected_coord", coord)
	EventBus.selection_changed.emit(coord)


func _build_button(type_id: String) -> Control:
	var list: Node = _hud().get("_build_vbox") as Node
	if list == null:
		return null
	for child: Node in list.get_children():
		if child is Button and child.has_meta("type_id") and (child.get_meta("type_id") as String) == type_id:
			return child as Control
	return null


func _coords_of(type_id: String) -> Array:
	var out: Array = []
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		if (GameStateStore.get_building(coord).get("type", "") as String) == type_id:
			out.append(coord)
	return out


func _count(type_id: String) -> int:
	return _coords_of(type_id).size()


## Buildable cells next to a road (optionally inside water range), nearest to the hub first.
func _candidates(type_id: String, need_water: bool) -> Array:
	var orch: GameOrchestrator = _main().call("get_orchestrator") as GameOrchestrator
	if orch == null:
		return []
	var seen: Dictionary = {}
	var out: Array = []
	for road: Vector2i in _coords_of("bld_road"):
		for cell: Vector2i in HexCoords.neighbors_of(road):
			if seen.has(cell):
				continue
			seen[cell] = true
			if not (PlacementRules.validate(cell, type_id, orch.hex_grid).get("ok", false) as bool):
				continue
			if need_water and not orch.coverage.is_water_covered(cell):
				continue
			out.append(cell)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return HexCoords.distance(Vector2i.ZERO, a) < HexCoords.distance(Vector2i.ZERO, b))
	return out.slice(0, MAX_CELLS)


func _push_cells(step: Dictionary) -> void:
	var cells: Array = []
	if step.has("cells"):
		cells = (step["cells"] as Callable).call() as Array
	_set_cells(cells)


func _set_cells(cells: Array) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var overlay: Node = scene.get_node_or_null("World/OverlayLayer")
	if overlay != null and overlay.has_method("set_tutorial_cells"):
		overlay.call("set_tutorial_cells", cells)


# ------------------------------------------------------------------ UI

func _update_target(step: Dictionary) -> void:
	var control: Control = null
	if step.has("target"):
		control = (step["target"] as Callable).call() as Control
	_has_target = control != null and control.is_visible_in_tree()
	if _has_target:
		_target_rect = control.get_global_rect().grow(4.0)
	_shade.queue_redraw()
	_place_bubble(step)


func _place_bubble(step: Dictionary) -> void:
	var view: Vector2 = _shade.get_viewport_rect().size
	_bubble.custom_minimum_size.x = 300.0 if (step.get("compact", false) as bool) else 440.0
	_bubble.reset_size()
	var size: Vector2 = _bubble.size
	var pos := Vector2((view.x - size.x) * 0.5, view.y - size.y - 24.0)
	if step.get("top", false) as bool:
		pos.y = 110.0
	elif _has_target:
		var r: Rect2 = _target_rect
		var gap := 14.0
		# A target in the right-hand panel gets the bubble on its left, so the list stays readable.
		var prefer_left: bool = r.position.x > view.x * 0.6 and r.position.x - gap - size.x >= 0.0
		if prefer_left:
			pos = Vector2(r.position.x - gap - size.x, r.position.y)
		elif r.end.y + gap + size.y <= view.y:                  # below
			pos = Vector2(r.get_center().x - size.x * 0.5, r.end.y + gap)
		elif r.position.x - gap - size.x >= 0.0:                 # left
			pos = Vector2(r.position.x - gap - size.x, r.position.y)
		elif r.position.y - gap - size.y >= 0.0:                 # above
			pos = Vector2(r.position.x, r.position.y - gap - size.y)
		else:                                                    # right
			pos = Vector2(r.end.x + gap, r.position.y)
	pos.x = clampf(pos.x, 8.0, maxf(view.x - size.x - 8.0, 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(view.y - size.y - 8.0, 8.0))
	_bubble.position = pos


func _draw_shade() -> void:
	if not _has_target:
		return
	var view: Rect2 = _shade.get_viewport_rect()
	var r: Rect2 = _target_rect.intersection(view)
	var dim := Color(0.0, 0.0, 0.0, 0.5)
	_shade.draw_rect(Rect2(0, 0, view.size.x, r.position.y), dim)
	_shade.draw_rect(Rect2(0, r.end.y, view.size.x, view.size.y - r.end.y), dim)
	_shade.draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), dim)
	_shade.draw_rect(Rect2(r.end.x, r.position.y, view.size.x - r.end.x, r.size.y), dim)
	var pulse: float = 0.6 + 0.4 * absf(sin(float(Time.get_ticks_msec()) / 300.0))
	_shade.draw_rect(r, Color(1.0, 0.85, 0.35, pulse), false, 3.0)


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 130  # above the HUD and the Desk, below the C/K/J/N panels and the finale
	_layer.visible = false
	add_child(_layer)

	_shade = Control.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE  # the player must be able to click the target
	_shade.draw.connect(_draw_shade)
	_layer.add_child(_shade)

	_bubble = PanelContainer.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.10, 0.15, 0.97)
	style.border_color = Color(1.0, 0.85, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	_bubble.add_theme_stylebox_override("panel", style)
	_layer.add_child(_bubble)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_bubble.add_child(box)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 11)
	_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	box.add_child(_title)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.custom_minimum_size = Vector2(280, 0)
	_text.add_theme_font_size_override("normal_font_size", 14)
	_text.add_theme_font_size_override("bold_font_size", 14)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_text)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_skip_btn = Button.new()
	_skip_btn.flat = true
	_skip_btn.add_theme_font_size_override("font_size", 11)
	_skip_btn.pressed.connect(func() -> void: _finish(false))
	row.add_child(_skip_btn)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_next_btn = Button.new()
	_next_btn.custom_minimum_size = Vector2(110, 32)
	_next_btn.pressed.connect(func() -> void: _go(_index + 1))
	row.add_child(_next_btn)


# ------------------------------------------------------------------ settings

func _load_done() -> bool:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return false
	return config.get_value("tutorial", "done", false) as bool


func _save_done() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("tutorial", "done", true)
	config.save(SETTINGS_PATH)
