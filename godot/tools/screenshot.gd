extends Node
## Dev tool: boots main.tscn and saves two PNGs — the start menu, then the map with the
## menu closed. Run WITHOUT --headless (needs a real renderer):
##   Godot --path . --resolution 1280x720 res://tools/screenshot.tscn -- out=/abs/dir
## Optional seed=12345 makes before/after terrain reproducible; capture_dust also saves dust.png.

var _frames: int = 0
var _dir: String = "res://"
var _capture_dust: bool = false


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_dir = a.trim_prefix("out=")
		elif a.begins_with("seed="):
			seed(a.trim_prefix("seed=").to_int())
		elif a == "capture_dust":
			_capture_dust = true
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	# current_scene can only be set once the node is under root (hence deferred too).
	(func() -> void: get_tree().current_scene = main).call_deferred()


func _process(_dt: float) -> void:
	_frames += 1
	if _frames == 40:
		await _save("menu.png")
		var hud: Node = get_tree().current_scene.get("_hud")
		if hud != null and hud.has_method("_close_start_panel"):
			hud.call("_close_start_panel")
	elif _frames == 100:
		await _save("map.png")
		if _capture_dust:
			# Visual fixture only: redraw via the same signal emitted by SeasonSystem.
			GameStateStore.climate()["season_id"] = "season_dust"
			EventBus.season_changed.emit("season_dust", 1, 11)
		else:
			get_tree().quit()
	elif _frames == 160 and _capture_dust:
		await _save("dust.png")
		get_tree().quit()


func _save(name: String) -> void:
	var path: String = _dir.path_join(name)
	# An occluded window (the tool usually runs behind other apps) stops presenting frames,
	# so the viewport texture would still hold the first frame. Force one real draw.
	RenderingServer.force_draw(true)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT saved: ", path)
