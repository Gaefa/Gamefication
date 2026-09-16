extends Node
## Dev tool: boots main.tscn and saves two PNGs — the start menu, then the map with the
## menu closed. Run WITHOUT --headless (needs a real renderer):
##   Godot --path . --resolution 1280x720 res://tools/screenshot.tscn -- out=/abs/dir

var _frames: int = 0
var _dir: String = "res://"


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_dir = a.trim_prefix("out=")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	# current_scene can only be set once the node is under root (hence deferred too).
	(func() -> void: get_tree().current_scene = main).call_deferred()


func _process(_dt: float) -> void:
	_frames += 1
	if _frames == 40:
		_save("menu.png")
		var hud: Node = get_tree().current_scene.get("_hud")
		if hud != null and hud.has_method("_close_start_panel"):
			hud.call("_close_start_panel")
	elif _frames == 100:
		_save("map.png")
		get_tree().quit()


func _save(name: String) -> void:
	var path: String = _dir.path_join(name)
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT saved: ", path)
