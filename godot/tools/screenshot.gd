extends Node
## Dev tool: boots main.tscn and saves two PNGs — the start menu, then the map with the
## menu closed. Run WITHOUT --headless (needs a real renderer):
##   Godot --path . --resolution 1280x720 res://tools/screenshot.tscn -- out=/abs/dir
## Optional seed=12345 makes before/after terrain reproducible; capture_dust also saves dust.png.
## legacy_art renders pre-P7 assets with the same map, UI and renderer for comparison.

var _frames: int = 0
var _dir: String = "res://"
var _capture_dust: bool = false
var _legacy_art: bool = false


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_dir = a.trim_prefix("out=")
		elif a.begins_with("seed="):
			seed(a.trim_prefix("seed=").to_int())
		elif a == "capture_dust":
			_capture_dust = true
		elif a == "legacy_art":
			_legacy_art = true
	if _legacy_art:
		for id: String in ContentDB.buildings:
			var def: Dictionary = ContentDB.get_building_def(id)
			var paths: Array = def.get("sprites_by_level", [])
			for level: int in paths.size():
				paths[level] = (paths[level] as String).replace("_hex.png", ".png").replace("/field_strip_t", "/farm_t").replace("/generator_t", "/power_t")
			def.erase("footprint")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	# current_scene can only be set once the node is under root (hence deferred too).
	(func() -> void: get_tree().current_scene = main).call_deferred()


func _process(_dt: float) -> void:
	_frames += 1
	if _frames == 40:
		if _legacy_art:
			var terrain: Node2D = get_tree().current_scene.get_node("World/TerrainLayer")
			(terrain.get("_prop_cache") as Dictionary).clear()
			for prop: Dictionary in GameStateStore.world().get("decor", {}).get("props", []):
				(terrain.get("_prop_paths") as Dictionary)[prop["id"]] = "res://assets/props/%s.png" % prop["id"]
			terrain.queue_redraw()
		await _save("menu.png")
		var hud: Node = get_tree().current_scene.get("_hud")
		if hud != null and hud.has_method("_close_start_panel"):
			hud.call("_close_start_panel")
			# The fixture keeps the seeded bootstrap world instead of starting a second run.
			# Populate the current HUD just as the normal start action does.
			if hud.has_method("_update_resource_bar"):
				hud.call("_update_resource_bar")
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
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT saved: ", path)
