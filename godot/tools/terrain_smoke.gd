extends Node
## Render-backed checks for P2. Run WITHOUT --headless; this reads viewport pixels.
## Godot --path godot res://tools/terrain_smoke.tscn

var _failures: int = 0
var _draws: int = 0
var _viewport: SubViewport
var _layer: Node2D


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("terrain_smoke needs a real renderer (omit --headless)")
		get_tree().quit(1)
		return
	SaveService.set("_autosave_timer", -1.0e12)
	GameStateStore.reset()
	GameStateStore.climate()["season_id"] = "season_window"
	GameStateStore.set_terrain(Vector2i.ZERO, 0)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(256, 192)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_layer = (load("res://scripts/scenes/hex_terrain_layer.gd") as GDScript).new() as Node2D
	_layer.position = Vector2(128, 96)
	_layer.scale = Vector2(3, 3)
	_layer.draw.connect(func() -> void: _draws += 1)
	_viewport.add_child(_layer)
	_layer.call("render_terrain", HexGrid.new(0))
	_run.call_deferred()


func _run() -> void:
	for terrain_id: int in 6:
		var normal: Texture2D = _layer.call("_terrain_texture", terrain_id, false) as Texture2D
		var dust: Texture2D = _layer.call("_terrain_texture", terrain_id, true) as Texture2D
		_check(normal != null and dust != null and normal != dust, "both seasons load for type %d" % terrain_id)
		_check(normal == _layer.call("_terrain_texture", terrain_id, false), "texture reused for type %d" % terrain_id)
	_check((_layer.get("_tile_cache") as Dictionary).size() == 12, "12 textures cached")
	var normal_image: Image = await _capture()
	var previous_draws: int = _draws
	GameStateStore.climate()["season_id"] = "season_dust"
	EventBus.season_changed.emit("season_dust", 1, 11)
	var dust_image: Image = await _capture()
	_check(_draws > previous_draws, "season signal triggers redraw without render_terrain")
	_check(normal_image.get_data() != dust_image.get_data(), "dust changes rendered pixels")
	GameStateStore.climate()["season_id"] = "season_window"
	EventBus.season_changed.emit("season_window", 1, 18)
	var restored_image: Image = await _capture()
	_check(normal_image.get_data() == restored_image.get_data(), "return to Window restores exact pixels")

	var definition: Dictionary = ContentDB.get_terrain_def(0)
	var original: String = definition["tile"] as String
	definition.erase("tile")
	_layer.call("render_terrain", HexGrid.new(0))
	var fallback_image: Image = await _capture()
	var expected := Color(definition["color"] as String)
	_check(fallback_image.get_pixel(128, 96).is_equal_approx(expected), "missing field renders configured color")
	definition["tile"] = "res://assets/tiles/not_present.png"
	_layer.call("render_terrain", HexGrid.new(0))
	var missing_image: Image = await _capture()
	_check(fallback_image.get_data() == missing_image.get_data(), "missing file renders same fallback")
	_check((_layer.get("_tile_cache") as Dictionary).has(definition["tile"]), "missing resource is cached")
	definition["tile"] = original
	_check(_layer.call("_terrain_texture", 9999, false) == null, "unknown terrain has no texture")
	_check(_layer.call("_terrain_color", 9999) == Color.GRAY, "unknown terrain retains grey fallback")
	print("TERRAIN SMOKE: %d failures" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _capture() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return _viewport.get_texture().get_image()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
	else:
		print("PASS: ", message)
