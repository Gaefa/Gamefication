extends Node
## P3 integration checks, including rendered removal. Run without --headless.

var _failures: int = 0
var _draws: int = 0
var _viewport: SubViewport
var _layer: Node2D
var _orch: GameOrchestrator


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("props_smoke needs a real renderer (omit --headless)")
		get_tree().quit(1)
		return
	SaveService.set("_autosave_timer", -1.0e12)
	_orch = GameOrchestrator.new()
	_orch.new_game(12345)
	var initial: Array = GameStateStore.world().decor.props.duplicate(true)
	var rng_before: int = _orch.rng.get_state()
	_orch.call("_bootstrap_company_traces")
	_check(initial == GameStateStore.world().decor.props, "fixed layout repeats exactly")
	_check(rng_before == _orch.rng.get_state(), "bootstrap does not consume RNG")
	var ids: Dictionary = {}
	for prop: Dictionary in initial:
		ids[prop.id] = true
		_check(not GameStateStore.has_building(Vector2i(prop.q, prop.r)), "prop cell is unoccupied")
	_check(ids.size() == 10, "all ten prop types in starting district")
	var snapshot: Dictionary = SaveMigrator.migrate(JSON.parse_string(JSON.stringify(GameStateStore.to_save_dict())) as Dictionary)
	_check(SaveValidator.validate(snapshot).is_empty(), "decorated save validates")
	GameStateStore.load_from_dict(snapshot)
	_orch.load_game()
	_check(JSON.parse_string(JSON.stringify(initial)) == GameStateStore.world().decor.props, "props survive JSON save and load")

	GameStateStore.reset()
	GameStateStore.climate()["season_id"] = "season_window"
	GameStateStore.set_terrain(Vector2i.ZERO, 0)
	_orch.build()
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(256, 256)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_layer = (load("res://scripts/scenes/hex_terrain_layer.gd") as GDScript).new() as Node2D
	_layer.position = Vector2(128, 170)
	_layer.scale = Vector2(3, 3)
	_layer.draw.connect(func() -> void: _draws += 1)
	_viewport.add_child(_layer)
	_layer.call("render_terrain", HexGrid.new(0))
	_run.call_deferred()


func _run() -> void:
	var bare: Image = await _capture()
	for id: String in ["prop_pipe_straight", "prop_pipe_bend", "prop_pipe_broken", "prop_sign_company", "prop_debris", "prop_dry_well", "prop_barrels", "prop_tarp_tent", "prop_leaflets", "prop_fence"]:
		var texture: Texture2D = _layer.call("_prop_texture", id) as Texture2D
		_check(texture != null, "%s loads" % id)
		_check(texture == _layer.call("_prop_texture", id), "%s uses cache" % id)
	_check(_layer.call("_prop_texture", "missing_prop") == null, "missing sprite skipped")
	var props: Array = [
		{"q": 0, "r": 0, "id": "prop_barrels"},
		{"q": 0, "r": 0, "id": "prop_leaflets"},
		{"q": 1, "r": 0, "id": "prop_fence"},
	]
	GameStateStore.world()["decor"] = {"props": props}
	_layer.queue_redraw()
	var decorated: Image = await _capture()
	_check(bare.get_data() != decorated.get_data(), "props change actual rendered pixels")
	_check(not GameStateStore.has_building(Vector2i.ZERO), "props do not occupy building cells")
	var rejected: CommandBase = _orch.command_bus.execute(PlaceBuildingCommand.new(Vector2i.ZERO, "missing_building"))
	_check(not rejected.success and props.size() == 3, "failed placement keeps all props")
	GameStateStore.set_terrain(Vector2i.ZERO, 1)
	rejected = _orch.command_bus.execute(PlaceBuildingCommand.new(Vector2i.ZERO, "bld_road"))
	_check(not rejected.success and props.size() == 3, "unbuildable terrain keeps all props")
	GameStateStore.set_terrain(Vector2i.ZERO, 0)
	var before_draws: int = _draws
	var placed: CommandBase = _orch.command_bus.execute(PlaceBuildingCommand.new(Vector2i.ZERO, "bld_road"))
	_check(placed.success, "construction over decoration succeeds")
	_check(props.size() == 1 and props[0].id == "prop_fence", "all props on built cell removed, other cells preserved")
	var cleared: Image = await _capture()
	_check(_draws > before_draws, "placement signal triggers terrain redraw")
	_check(cleared.get_data() == bare.get_data(), "removed props leave no stale pixels")
	var saved: Dictionary = SaveMigrator.migrate(JSON.parse_string(JSON.stringify(GameStateStore.to_save_dict())) as Dictionary)
	GameStateStore.load_from_dict(saved)
	_orch.load_game()
	_check(GameStateStore.world().decor.props.size() == 1, "removed props stay removed after load")
	var demolished: CommandBase = _orch.command_bus.execute(BulldozeCommand.new(Vector2i.ZERO))
	_check(demolished.success and GameStateStore.world().decor.props.size() == 1, "bulldoze does not respawn decoration")
	GameStateStore.world().erase("decor")
	_layer.queue_redraw()
	var legacy: Image = await _capture()
	_check(legacy.get_data() == bare.get_data(), "legacy world without decor renders normally")
	placed = _orch.command_bus.execute(PlaceBuildingCommand.new(Vector2i.ZERO, "bld_road"))
	_check(placed.success, "legacy world without decor supports construction")
	print("PROPS SMOKE: %d failures" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _capture() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return _viewport.get_texture().get_image()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		push_error(message)
