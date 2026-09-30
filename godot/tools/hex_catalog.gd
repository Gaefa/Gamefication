extends Node
## Full P7 catalog through production building/prop renderers; real renderer required.
## Godot --path godot res://tools/hex_catalog.tscn -- out=/abs/existing/dir

const Preview = preload("res://tools/hex_footprint_preview.gd")
const Buildings = preload("res://scripts/scenes/building_layer.gd")
const Terrain = preload("res://scripts/scenes/hex_terrain_layer.gd")
const PROP_IDS := ["prop_pipe_straight", "prop_pipe_bend", "prop_pipe_broken", "prop_sign_company", "prop_debris", "prop_dry_well", "prop_barrels", "prop_tarp_tent", "prop_leaflets", "prop_fence"]
var _dir := "user://"
var _failures := 0

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("hex_catalog requires a real renderer")
		get_tree().quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_dir = arg.trim_prefix("out=")
	SaveService.set("_autosave_timer", -1.0e12)
	SimulationRunner.paused = true
	GameStateStore.reset()
	_run.call_deferred()

func _run() -> void:
	var entries: Array[Dictionary] = []
	var buildings := Buildings.new()
	for id: String in ContentDB.buildings:
		var def: Dictionary = ContentDB.get_building_def(id)
		if def.get("footprint", "") != "hex":
			continue
		var paths: Array = def.get("sprites_by_level", [])
		for level: int in paths.size():
			_check(buildings._uses_hex_footprint(def, level), "%s L%d projection" % [id, level])
			_check(buildings._get_building_sprite(id, level) != null, "%s L%d texture" % [id, level])
			entries.append({"id": id, "level": level, "name": (paths[level] as String).get_file().get_basename()})
	_check(entries.size() == 33, "33 building sprites connected")
	# A synthetic mixed definition verifies the retained legacy upgrade path.
	var mixed := {"footprint": "hex", "sprites_by_level": ["shelter_t1_hex.png", "shelter_t2.png"]}
	_check(buildings._uses_hex_footprint(mixed, 0) and not buildings._uses_hex_footprint(mixed, 1), "mixed projection fallback")
	_check(not buildings._uses_hex_footprint({}, 0), "missing flag fallback")
	_check(buildings._get_building_sprite("missing_building", 0) == null, "missing building fallback")
	buildings.free()
	var terrain := Terrain.new()
	for id: String in PROP_IDS:
		_check(terrain._prop_texture_path(id).ends_with("_hex.png"), id + " selects hex")
		_check(terrain._prop_texture(id) != null, id + " texture loads")
		entries.append({"id": id, "name": id + "_hex", "prop": true})
	_check(terrain._prop_texture("missing_prop") == null, "missing prop skips drawing")
	_check(terrain._prop_texture_path("missing_prop") == "res://assets/props/missing_prop.png", "missing hex chooses legacy path")
	# Force the legacy resource into the selection cache: it still loads and draws.
	terrain._prop_paths["legacy_probe"] = "res://assets/props/prop_fence.png"
	_check(terrain._prop_texture("legacy_probe") != null, "legacy prop texture loads")
	terrain.free()
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.name < b.name)
	var board := SubViewport.new()
	board.size = Vector2i(1800, 60 + 8 * 250)
	board.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(board)
	var bg := ColorRect.new()
	bg.size = Vector2(board.size)
	bg.color = Color("302d28")
	board.add_child(bg)
	_label(board, "P7 / ALL 43 / production render at 2x and 1x / outlines = cell boundary", Vector2(20, 18))
	for i: int in entries.size():
		var entry: Dictionary = entries[i]
		var card := SubViewport.new()
		card.size = Vector2i(300, 220)
		card.transparent_bg = true
		card.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(card)
		GameStateStore.world()["decor"] = {"props": [{"id": entry.id, "q": 0, "r": 0}]}
		for zoom: float in [2.0, 1.0]:
			var at := Vector2(90, 140) if zoom == 2.0 else Vector2(235, 178)
			if entry.get("prop", false):
				var layer := Terrain.new()
				layer.position = at
				layer.scale = Vector2.ONE * zoom
				card.add_child(layer)
				layer.render_terrain(HexGrid.new(0))
			else:
				var sample := Preview.Sample.new()
				sample.type_id = entry.id
				sample.level = entry.level
				sample.position = at
				sample.scale = Vector2.ONE * zoom
				card.add_child(sample)
		await get_tree().process_frame
		RenderingServer.force_draw(true)
		var screenshot := card.get_texture().get_image()
		_check(screenshot.get_used_rect().has_area(), entry.name + " rendered")
		var tile := TextureRect.new()
		tile.texture = ImageTexture.create_from_image(screenshot)
		tile.position = Vector2(i % 6 * 300, 88 + (i / 6) * 250)
		board.add_child(tile)
		_label(board, entry.name, Vector2(i % 6 * 300 + 8, 63 + (i / 6) * 250), 13)
		card.queue_free()
	await get_tree().process_frame
	RenderingServer.force_draw(true)
	_check(board.get_texture().get_image().save_png(_dir.path_join("hex_catalog.png")) == OK, "catalog saved")
	print("HEX CATALOG: %d failures" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)

func _label(parent: Node, text: String, at: Vector2, size: int = 20) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)

func _check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		_failures += 1
		push_error(message)
