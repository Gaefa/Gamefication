extends Node
## Dev tool: English UI screenshots for a layout check (menu, HUD, the longest desk card,
## help, season, a finale). Run WITHOUT --headless:
##   Godot --path . --resolution 1280x720 res://tools/en_screens.tscn -- out=/abs/dir
## The player's saved language setting is not changed.

var _dir: String = "user://"
var _main: Node


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_dir = a.trim_prefix("out=")
	Localization.set_locale("en", true, false)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_main)
	_run.call_deferred()


func _run() -> void:
	get_tree().current_scene = _main
	await _shot("en_menu.png")
	var hud: Node = _main.get_node("HUDCanvas/HUD")
	hud.call("_start_new_run", "appointed_administrator")
	SimulationRunner.paused = true
	await _shot("en_hud.png")
	# The longest desk card body is the worst case for wrapping.
	var longest: String = ""
	for event_id: String in ContentDB.get_event_ids():
		var body: String = ContentDB.get_event_def(event_id).get("body_en", "") as String
		if body.length() > (ContentDB.get_event_def(longest).get("body_en", "") as String).length() if longest != "" else true:
			longest = event_id
	var evt: Dictionary = ContentDB.get_event_def(longest).duplicate(true)
	evt["runtime_id"] = longest
	var desk: Node = _main.get_node("HUDCanvas/DeskUI")
	desk.call("_on_evening_started", [evt])
	await _shot("en_desk.png")
	desk.set("visible", false)
	hud.call("toggle_help")
	await _shot("en_help.png")
	hud.call("toggle_help")
	SeasonPanel.call("open")
	await _shot("en_season.png")
	SeasonPanel.call("_toggle")
	EndingManager.call("_show_finale", ContentDB.get_ending_def("ending.win.protector"), "ending.win.protector")
	await _shot("en_ending.png")
	get_tree().quit()


func _shot(name: String) -> void:
	for _i: int in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_dir.path_join(name))
