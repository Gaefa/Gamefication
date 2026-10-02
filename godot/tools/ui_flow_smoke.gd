extends Node
## Dev tool: drives the interface the way a player does and checks what screenshots cannot —
## real clicks on build cards and action buttons, every tutorial step, a language switch in
## the middle of a run, save/load with an active effect, a new run after another, a founder
## start, and small windows. Run WITHOUT --headless:
##   Godot --path . --resolution 1280x720 res://tools/ui_flow_smoke.tscn
## The player's saved language and saves are not touched (test slot 9, removed at the end).

const TEST_SLOT := 9
const NONE := Vector2i(-9999, -9999)

var _main: Node
var _hud: Node
var _failures: int = 0
var _cyrillic := RegEx.create_from_string("[А-Яа-яЁё]")


func _ready() -> void:
	Localization.set_locale("ru", true, false)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_main)
	_run.call_deferred()


func get_orchestrator() -> GameOrchestrator:
	return _main.call("get_orchestrator") as GameOrchestrator


func _run() -> void:
	get_tree().current_scene = _main
	await _settle()
	_hud = _main.get_node("HUDCanvas/HUD")
	_start("appointed_administrator")
	await _settle()

	await _test_build_cards()
	await _test_action_buttons()
	await _test_tutorial_steps()
	await _test_locale_switch()
	await _test_save_load()
	await _test_new_run()
	await _test_founder()
	await _test_windows()

	print("UI FLOW SMOKE: %d failures" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _start(profile_id: String) -> void:
	_hud.call("_start_new_run", profile_id)
	SimulationRunner.paused = true


# --- 1. Build menu: a real click on a card picks the building; Escape drops it ---

func _test_build_cards() -> void:
	for category: String in ["Infrastructure", "Residential", "Production"]:
		_hud.call("_set_active_category", category)
		await _settle()
		var entries: Array = _hud.get("_build_entries")
		_check(not entries.is_empty(), "%s: the build list is not empty" % category)
		for entry: Dictionary in entries:
			var card: Control = entry.card as Control
			var type_id: String = entry.type_id as String
			if entry.locked as bool:
				continue
			(_hud.get("_build_scroll") as ScrollContainer).ensure_control_visible(card)
			await get_tree().process_frame
			await _click(card.get_global_rect().get_center())
			_check(_hud.get("_active_build_type") == type_id and _main.get("_build_mode") == type_id, "%s: a click on the card picks it" % type_id)
			_check((_hud.get("_info_label") as RichTextLabel).get_parsed_text().contains(Localization.content_text(ContentDB.get_building_def(type_id), "label", "?")), "%s: the card names the building being placed" % type_id)
			_key(KEY_ESCAPE)
			_check(_main.get("_build_mode") == "", "%s: Escape leaves build mode" % type_id)
	for category: String in ["Commercial", "Culture", "Advanced"]:
		var button: Button = (_hud.get("_category_buttons") as Dictionary)[category] as Button
		_check(not button.is_visible_in_tree(), "%s: an empty category is not offered" % category)
	_hud.call("_set_active_category", "Infrastructure")


# --- 2. Building card: the buttons do what U / R / B do ---

func _test_action_buttons() -> void:
	var upgrade: Button = _hud.get("_upgrade_button")
	var repair: Button = _hud.get("_repair_button")
	var bulldoze: Button = _hud.get("_bulldoze_button")
	for res_id: String in ["res_money", "res_wood", "res_stone", "res_tools", "res_food"]:
		GameStateStore.set_cap(res_id, 9999)
		GameStateStore.set_resource(res_id, 500.0)
	SimulationRunner.paused = false  # actions are allowed during the day; the clock barely moves in a few frames

	var shelter: Vector2i = _first("bld_shelter")
	await _select(shelter)
	_check(upgrade.is_visible_in_tree() and not upgrade.disabled, "shelter: Upgrade is offered and affordable")
	_check(not repair.is_visible_in_tree(), "healthy shelter: no Repair button")
	await _click(upgrade.get_global_rect().get_center())
	_check((GameStateStore.get_building(shelter).get("level", 0) as int) == 1, "Upgrade button raises the level")

	var bld: Dictionary = GameStateStore.get_building(shelter)
	bld["damaged"] = true
	GameStateStore.set_building(shelter, bld)
	_hud.call("_update_info")
	await _settle()
	_check(repair.is_visible_in_tree(), "damaged shelter: Repair appears")
	await _click(repair.get_global_rect().get_center())
	_check(not (GameStateStore.get_building(shelter).get("damaged", false) as bool), "Repair button repairs")

	GameStateStore.set_resource("res_wood", 0.0)
	GameStateStore.set_resource("res_stone", 0.0)
	_hud.call("_update_info")
	await _settle()
	_check(upgrade.disabled or not upgrade.is_visible_in_tree(), "no resources: Upgrade is disabled, not silently failing")

	await _click(bulldoze.get_global_rect().get_center())
	await _click(bulldoze.get_global_rect().get_center())
	_check(GameStateStore.has_building(shelter), "the only home cannot be demolished from under its residents")

	var field: Vector2i = _first("bld_field_strip")
	await _select(field)
	await _click(bulldoze.get_global_rect().get_center())
	_check(GameStateStore.has_building(field), "Demolish asks first: one click does not demolish")
	await _click(bulldoze.get_global_rect().get_center())
	_check(not GameStateStore.has_building(field), "a second click demolishes")
	_check(not (_hud.get("_info_actions") as Control).is_visible_in_tree() or not GameStateStore.has_building(_main.get("_selected_coord") as Vector2i),
		"after demolition the card no longer offers actions for a building that is gone")

	await _select(_first("bld_main_cistern"))
	_check(not bulldoze.is_visible_in_tree(), "the Cistern has no Demolish button")
	await _select(_first("bld_source_tower"))
	_check(not upgrade.is_visible_in_tree() and not bulldoze.is_visible_in_tree(), "the old tower offers neither Upgrade nor Demolish")
	SimulationRunner.paused = true


# --- 3. Tutorial: every step opens, finds its target and keeps its bubble on screen ---

func _test_tutorial_steps() -> void:
	_start("appointed_administrator")
	TutorialManager.enabled_for_next_run = true
	TutorialManager.on_run_started()
	var steps: Array = TutorialManager.get("_steps")
	_check(TutorialManager.active and steps.size() >= 10, "the tutorial starts (%d steps)" % steps.size())
	var view: Rect2 = get_viewport().get_visible_rect()
	for i: int in steps.size():
		TutorialManager.call("_go", i)
		await _settle()
		var bubble: Control = TutorialManager.get("_bubble")
		_check(view.grow(1.0).encloses(bubble.get_global_rect()), "step %d: the bubble is inside the window" % (i + 1))
		if TutorialManager.get("_has_target") as bool:
			var target: Rect2 = TutorialManager.get("_target_rect")
			_check(target.has_area() and view.intersects(target), "step %d: the highlighted target is on screen" % (i + 1))
			_check(not bubble.get_global_rect().intersects(target), "step %d: the bubble does not cover its own target" % (i + 1))
	TutorialManager.call("_finish", false)
	await _settle()
	_check(not TutorialManager.active, "the tutorial can be skipped at the end")


# --- 4. Language: switching in the middle of a run leaves no text in the old language ---

func _test_locale_switch() -> void:
	_start("appointed_administrator")
	await _select(_first("bld_well_pump"))
	(_hud.get("_toast_label") as Label).text = ""  # a notice already on screen keeps its language
	Localization.set_locale("en", true, false)
	await _settle()
	_scan("HUD after switching to English")
	_hud.call("_on_build_button", "bld_shelter")
	await _settle()
	_scan("build mode")
	_key(KEY_ESCAPE)
	for panel: String in ["toggle_help", "toggle_city_panel", "toggle_settings", "toggle_governance"]:
		_hud.call(panel)
		await _settle()
		_scan(panel)
		_hud.call(panel)
	for autoload: Node in [SeasonPanel, WaterPanel, EventLogPanel, DiaryManager]:
		autoload.call("_toggle")
		await _settle()
		_scan(autoload.name)
		autoload.call("_toggle")
	Localization.set_locale("ru", true, false)
	await _settle()


func _scan(where: String) -> void:
	var seen: Dictionary = {}
	for node: Node in get_tree().root.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree():
			continue
		var texts: Array[String] = [control.tooltip_text]
		if control is Label:
			texts.append((control as Label).text)
		elif control is Button:
			texts.append((control as Button).text)
		elif control is RichTextLabel:
			texts.append((control as RichTextLabel).get_parsed_text())
		for text: String in texts:
			if text != "" and _cyrillic.search(text) != null and not seen.has(text):
				seen[text] = true
	_check(seen.is_empty(), "%s: no Russian text left (%d strings)" % [where, seen.size()])
	for text: String in seen:
		print("    RU: ", text.substr(0, 90).replace("\n", " ⏎ "))


# --- 5. Save and load: an active effect and the run survive ---

func _test_save_load() -> void:
	_start("appointed_administrator")
	var option: Dictionary = (ContentDB.get_event_def("petition.pump_log").get("options", []) as Array)[0] as Dictionary
	EventManager.call("_apply_effects", option.get("effects", {}))
	var before: Array = GameStateStore.get_buffs().duplicate(true)
	_check(before.size() == 1, "a card's temporary effect is active")
	_check(SaveService.save_game(TEST_SLOT, true), "save: written to the test slot")
	_start("appointed_administrator")
	_check(GameStateStore.get_buffs().is_empty(), "a new run starts with no effects left over")
	_check(SaveService.load_game(TEST_SLOT), "load: the test slot loads")
	SimulationRunner.paused = true  # loading resumes the clock; hold it so the effect does not tick down
	await _settle()
	var after: Array = GameStateStore.get_buffs()
	_check(after.size() == 1 and absf(((after[0] as Dictionary).get("remaining", 0.0) as float) - ((before[0] as Dictionary).get("remaining", -1.0) as float)) <= 5.0,
		"the effect comes back from the save with the same time left")
	_check(SimulationRunner.run_active and (_hud.get("_left_column") as Control).visible, "after loading the run is active and the goals are shown")
	SaveService.delete_save(TEST_SLOT)


# --- 6. A new run after another one starts clean ---

func _test_new_run() -> void:
	_start("appointed_administrator")
	EventManager.call("_apply_effects", { "add_buff": { "id": "t", "production_mult": 0.1, "remaining": 900 } })
	EventManager.pending_events.append({ "runtime_id": "petition.thanks" })
	GameStateStore.mandate()["audit_done"] = true
	await _select(_first("bld_warehouse"))
	_hud.call("_on_build_button", "bld_road")
	_start("appointed_administrator")
	await _settle()
	_check(GameStateStore.get_buffs().is_empty(), "new run: no effects carried over")
	_check(EventManager.pending_events.is_empty(), "new run: no letters carried over")
	_check(not (GameStateStore.mandate().get("audit_done", false) as bool), "new run: the audit is ahead again")
	_check(_main.get("_selected_coord") == NONE and not (_hud.get("_info_actions") as Control).is_visible_in_tree(), "new run: nothing selected, no action buttons")
	_check(_main.get("_build_mode") == "" and _hud.get("_active_build_type") == "", "new run: build mode is off in the menu too")
	_check((GameStateStore.climate().get("total_day", 0) as int) == 1, "new run: day 1")


# --- 7. A founder has no patron: nothing on screen talks about one ---

func _test_founder() -> void:
	_start("founder_rebel")
	await _settle()
	var rows: Dictionary = _hud.get("_goal_rows")
	for id: String in ["audit", "water", "food", "mood", "grant"]:
		_check(not ((rows[id] as Dictionary)["row"] as Control).visible, "founder: no '%s' goal" % id)
	_check((((rows["finish"] as Dictionary)["row"]) as Control).visible, "founder: the finish line is still a goal")
	_check(not (_hud.get("_patron_label") as Control).visible and not (_hud.get("_trust_bar") as Control).visible, "founder: no patron trust in the top bar")
	_check(not (_hud.get("_rival_label") as Control).is_visible_in_tree(), "founder: no rival in the top bar")
	_start("appointed_administrator")


# --- 8. Windows: nothing leaves the screen and panels do not sit on each other ---

func _test_windows() -> void:
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1366, 705), Vector2i(1600, 900), Vector2i(1280, 650), Vector2i(1024, 600)]:
		get_tree().root.size = size
		await _settle()
		_main.call("_apply_ui_scale")
		await _settle()
		_start("appointed_administrator")
		await _select(_first("bld_well_pump"))
		var tag: String = "%dx%d" % [size.x, size.y]
		var view: Rect2 = get_viewport().get_visible_rect()
		var parts: Dictionary = {}
		for field: String in ["_resource_bar", "_minimap_panel", "_left_column", "_info_panel", "_build_panel", "_clock_panel"]:
			parts[field] = (_hud.get(field) as Control).get_global_rect()
			_check(view.grow(1.0).encloses(parts[field] as Rect2), "%s: %s is inside the window" % [tag, field])
		for pair: Array in [["_info_panel", "_left_column"], ["_info_panel", "_build_panel"], ["_clock_panel", "_build_panel"],
				["_clock_panel", "_minimap_panel"], ["_left_column", "_build_panel"]]:
			_check(not (parts[pair[0]] as Rect2).intersects(parts[pair[1]] as Rect2), "%s: %s and %s do not overlap" % [tag, pair[0], pair[1]])
		_hud.call("_on_build_button", "bld_warehouse")  # the tallest build-mode card
		await _settle()
		_check(not (_hud.get("_info_panel") as Control).get_global_rect().intersects((_hud.get("_left_column") as Control).get_global_rect()),
			"%s: the tallest build card does not cover the goals" % tag)
		_key(KEY_ESCAPE)
	get_tree().root.size = Vector2i(1280, 720)
	await _settle()
	_main.call("_apply_ui_scale")


# --- helpers ---

func _first(type_id: String) -> Vector2i:
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		if (GameStateStore.get_building(coord).get("type", "") as String) == type_id:
			return coord
	return NONE


func _select(coord: Vector2i) -> void:
	_main.set("_selected_coord", coord)
	EventBus.selection_changed.emit(coord)
	await _settle()


func _key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	_main.call("_handle_key", event)


func _click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	await get_tree().process_frame
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = at
		click.global_position = at
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		Input.parse_input_event(click)
		await get_tree().process_frame
	await get_tree().process_frame


func _settle() -> void:
	for _i: int in 6:
		await get_tree().process_frame


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
	print(("PASS: " if ok else "FAIL: ") + what)
