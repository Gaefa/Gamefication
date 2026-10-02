extends Node
## Dev tool: one screenshot per screen of the interface, for a visual review after UI changes.
## Run WITHOUT --headless:
##   Godot --path . --resolution 1280x720 res://tools/ui_shots.tscn -- out=/abs/dir [locale=en]
## The player's saved language setting is not changed.

var _dir: String = "user://"
var _locale: String = "ru"
var _main: Node


func _ready() -> void:
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
	EndingManager.call("_show_finale", ContentDB.get_ending_def("ending.win.protector"), "ending.win.protector")
	await _shot("20_ending")
	get_tree().quit()


func _first(type_id: String) -> Vector2i:
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		if (GameStateStore.get_building(coord).get("type", "") as String) == type_id:
			return coord
	return Vector2i.ZERO


func _shot(shot_name: String) -> void:
	for _i: int in 12:
		await get_tree().process_frame
	RenderingServer.force_draw(true)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_dir.path_join("%s_%s.png" % [_locale, shot_name]))
