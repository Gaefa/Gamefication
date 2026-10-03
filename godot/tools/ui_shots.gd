extends Node
## Dev tool: one screenshot per screen of the interface, for a visual review after UI changes.
## Run WITHOUT --headless:
##   Godot --path . --resolution 1280x720 res://tools/ui_shots.tscn -- out=/abs/dir [locale=en]
## The player's saved language setting is not changed.

var _dir: String = "user://"
var _locale: String = "ru"
var _failures: int = 0
var _main: Node


func _ready() -> void:
	SaveService.set("_autosave_timer", -1.0e12)
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_dir = a.trim_prefix("out=")
		elif a.begins_with("locale="):
			_locale = a.trim_prefix("locale=")
	Localization.set_locale(_locale, true, false)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_main)
	_run.call_deferred()


func _run() -> void:
	get_tree().current_scene = _main
	var hud: Node = _main.get_node("HUDCanvas/HUD")
	await _shot("01_menu")
	hud.set("_start_menu_mode", "campaign")
	hud.call("_rebuild_start_panel")
	await _shot("02_mandates")
	hud.call("_start_new_run", "appointed_administrator")
	SimulationRunner.paused = true
	await _shot("03_hud")

	var shelter: Vector2i = _first("bld_shelter")
	_main.set("_selected_coord", shelter)
	EventBus.selection_changed.emit(shelter)
	await _shot("04_selected")
	hud.call("_on_build_button", "bld_well_pump")
	await _shot("05_build_mode")
	EventBus.build_mode_changed.emit("")
	hud.call("_set_active_category", "Production")
	await _shot("06_production")
	hud.call("_set_active_category", "Infrastructure")

	var desk: Node = _main.get_node("HUDCanvas/DeskUI")
	var evt: Dictionary = ContentDB.get_event_def("rival.voss_exchange").duplicate(true)
	evt["runtime_id"] = "rival.voss_exchange"
	desk.call("_on_evening_started", [evt])
	await _shot("07_desk")
	desk.call("_on_evening_started", [])
	await _shot("08_desk_quiet")
	desk.set("visible", false)
	SimulationRunner.card_open = false

	hud.call("toggle_help")
	await _shot("09_help")
	hud.call("toggle_help")
	WaterPanel.call("_toggle")
	await _shot("10_water")
	WaterPanel.call("_toggle")
	SeasonPanel.call("_toggle")
	await _shot("11_season")
	SeasonPanel.call("_toggle")
	EventLogPanel.call("_toggle")
	await _shot("12_log")
	EventLogPanel.call("_toggle")
	DiaryManager.call("_toggle")
	await _shot("13_diary")
	DiaryManager.call("_toggle")
	hud.call("toggle_city_panel")
	await _shot("14_city")
	hud.call("toggle_city_panel")
	hud.call("toggle_governance")
	await _shot("15_governance")
	hud.call("toggle_governance")
	hud.call("toggle_settings")
	await _shot("16_settings")
	hud.call("toggle_settings")
	EventBus.toast_requested.emit(Localization.ru_en("Недостаточно ресурсов", "Not enough resources"), 4.0)
	await _shot("17_toast")
	TutorialManager.enabled_for_next_run = true
	TutorialManager.on_run_started()
	await _shot("18_tutorial")
	TutorialManager.call("_go", 5)
	await _shot("19_tutorial_target")
	TutorialManager.call("_finish", false)
	# A broken pump and a faulty warehouse: badges and warning pins side by side.
	for pair: Array in [["bld_well_pump", "damaged"], ["bld_warehouse", "has_issue"]]:
		var coord: Vector2i = _first(pair[0] as String)
		var bld: Dictionary = GameStateStore.get_building(coord)
		bld[pair[1]] = true
		GameStateStore.set_building(coord, bld)
		if pair[1] == "damaged":
			EventBus.building_damaged.emit(coord, 1.0)
		else:
			EventBus.building_issue_added.emit(coord)
	EventBus.building_placed.emit(_first("bld_field_strip"), "bld_field_strip")
	EventBus.selection_changed.emit(Vector2i(-9999, -9999))
	await _shot("20_pins", 4)  # early, while the flashes are still on screen
	# Same map before/after Heat, plus the day-32 goals and spoilage forecast.
	TutorialManager.enabled_for_next_run = false
	hud.call("_start_new_run", "appointed_administrator")
	SimulationRunner.paused = true
	OnboardingManager.suppressed = true
	(OnboardingManager.get("_layer") as CanvasLayer).visible = false
	await _shot("22_before_window")
	var orch: GameOrchestrator = _main.call("get_orchestrator") as GameOrchestrator
	SimulationRunner.day_count = 32
	orch.season_sys.process_tick()
	GameStateStore.mandate()["audits_done"] = 1
	GameStateStore.mandate()["first_audit_score"] = 3
	hud.call("_update_resource_bar")
	hud.call("_update_goals")
	await _shot("23_heat_map")
	SeasonPanel.open()
	await _shot("24_heat_season")
	SeasonPanel.call("_toggle")
	for id: String in ["patron.letter.heat_warning", "patron.letter.heat_warning_directorate", "report.heat_stock", "petition.covenant_shade", "rival.voss_heat", "patron.letter.audit2_warning", "patron.letter.audit2_warning_directorate", "crisis.heat_collapse", "crisis.spoiled_stock"]:
		var card: Dictionary = ContentDB.get_event_def(id).duplicate(true)
		card["runtime_id"] = id
		desk.call("_on_evening_started", [card])
		await _shot("25_" + id.replace(".", "_"))
	GameStateStore.climate()["total_day"] = 36
	MandateManager.call("_run_audit")
	await _shot("26_audit2")
	desk.set("visible", false)
	SimulationRunner.card_open = false
	EndingManager.call("_show_finale", ContentDB.get_ending_def("ending.win.protector"), "ending.win.protector")
	await _shot("21_ending")
	print("UI SHOTS: %d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _first(type_id: String) -> Vector2i:
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		if (GameStateStore.get_building(coord).get("type", "") as String) == type_id:
			return coord
	return Vector2i.ZERO


func _shot(shot_name: String, frames: int = 12) -> void:
	for _i: int in frames:
		await get_tree().process_frame
	if shot_name.begins_with("25_") or shot_name == "26_audit2":
		var desk: Node = _main.get_node("HUDCanvas/DeskUI")
		var viewport_rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
		var fits: bool = true
		for key: String in ["_title_label", "_header_label", "_body_label", "_options_container"]:
			fits = fits and viewport_rect.encloses((desk.get(key) as Control).get_global_rect())
		var body: RichTextLabel = desk.get("_body_label") as RichTextLabel
		fits = fits and body.get_content_height() <= body.size.y + 1.0
		print("%s: %s %s fits 1280x720" % ["PASS" if fits else "FAIL", _locale, shot_name])
		if not fits:
			_failures += 1
	RenderingServer.force_draw(true)
	get_viewport().get_texture().get_image().save_png(_dir.path_join("%s_%s.png" % [_locale, shot_name]))
