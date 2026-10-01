extends Node
## Headless regression checks for the rules a code review found broken (0.1.4):
## founders are not recalled, fixed buildings cannot be bulldozed, housing without water
## holds no residents, a road counts only when it reaches a hub, a broken pump covers
## nothing, season modifiers are applied.
##
## Run: Godot --headless --path <proj> res://tools/rules_smoke.tscn
## Dev tool, not shipped.

var orch: GameOrchestrator
var _failures: int = 0
var _ended: String = ""


func get_orchestrator() -> GameOrchestrator:
	return orch


func _ready() -> void:
	get_tree().current_scene = self
	SaveService.set("_autosave_timer", -1.0e12)
	EventBus.ending_triggered.connect(func(id: String, _kind: String) -> void: _ended = id)

	# 1. A founder has no patron: no recall, no patron letters, no mandate pressure.
	_new_game("founder_rebel")
	_ticks(600)
	_check(_ended == "", "founder start is not recalled (ended: '%s')" % _ended)
	_check(((GameStateStore.pressure().get("categories", {}) as Dictionary).get("mandate", 0.0) as float) <= 0.0, "founder has no mandate pressure")
	var patron_mail: bool = false
	for evt: Dictionary in EventManager.pending_events:
		if (evt.get("category", "") as String) == "mandate" and not (evt.get("runtime_id", "") as String).begins_with("quest."):
			patron_mail = true
	_check(not patron_mail, "founder receives no patron mail")

	# 2. Fixed buildings are protected; ruins and the player's own buildings are not.
	_new_game("appointed_administrator")
	var cistern: Vector2i = _first("bld_main_cistern")
	orch.command_bus.execute(BulldozeCommand.new(cistern))
	_check(GameStateStore.has_building(cistern), "the Cistern cannot be bulldozed")
	var tower: Vector2i = _first("bld_source_tower")
	orch.command_bus.execute(BulldozeCommand.new(tower))
	_check(GameStateStore.has_building(tower), "the old tower cannot be bulldozed by hand")
	orch.command_bus.execute(BulldozeCommand.new(tower, true))
	_check(not GameStateStore.has_building(tower), "an event can still remove the tower")
	var ruin: Vector2i = _first("bld_company_ruin")
	var stone_before: float = GameStateStore.get_resource("res_stone")
	orch.command_bus.execute(BulldozeCommand.new(ruin))
	_check(not GameStateStore.has_building(ruin) and GameStateStore.get_resource("res_stone") > stone_before, "a ruin can be salvaged")

	# 6. Housing without water adds no residents.
	_new_game("appointed_administrator")
	_ticks(5)
	var pop_before: int = GameStateStore.population().get("total", 0) as int
	var far := Vector2i(14, -7)  # far outside any pump's radius
	_place(far, "bld_shelter")
	_ticks(300)
	_check((GameStateStore.population().get("capacity", 0) as int) > (GameStateStore.population().get("served", 0) as int), "a dry shelter is not served housing")
	_check((GameStateStore.population().get("total", 0) as int) <= pop_before, "a dry shelter adds no residents (%d → %d)" % [pop_before, GameStateStore.population().get("total", 0) as int])

	# 9. A lone road tile is not logistics.
	_new_game("appointed_administrator")
	var site := Vector2i(12, 2)
	_place(site, "bld_lumber_yard")
	_place(site + Vector2i(1, 0), "bld_road")
	orch.coverage.invalidate()
	_check(not orch.coverage.is_road_connected(site), "an isolated road tile does not connect a building")
	_check(orch.coverage.is_road_connected(_first("bld_shelter")), "the starter shelter is connected through the hub roads")

	# 10. A broken pump covers nothing; repairing it restores coverage.
	_new_game("appointed_administrator")
	var pump: Vector2i = _first("bld_well_pump")
	var shelter: Vector2i = _first("bld_shelter")
	_check(orch.coverage.is_water_covered(shelter), "the starter shelter has water")
	var bld: Dictionary = GameStateStore.get_building(pump)
	bld["damaged"] = true
	GameStateStore.set_building(pump, bld)
	orch.coverage.invalidate()
	_check(not orch.coverage.is_water_covered(shelter), "a broken pump covers nothing")
	orch.command_bus.execute(RepairBuildingCommand.new(pump))
	_check(orch.coverage.is_water_covered(shelter), "a repaired pump covers again")

	# 7. The Window's cheaper construction is real.
	_new_game("appointed_administrator")
	var def: Dictionary = ContentDB.get_building_def("bld_shelter")
	var base: float = (def.get("build_cost", {}) as Dictionary).get("res_wood", 0.0) as float
	var now: float = PlacementRules.build_cost_for(def).get("res_wood", 0.0) as float
	_check(now < base, "the Window makes a shelter cheaper (%d → %d wood)" % [int(base), int(now)])

	# 4/5. Content references resolve.
	_check(ContentDB.content_warnings.is_empty(), "content check is clean (%d problems)" % ContentDB.content_warnings.size())

	print("=== RULES SMOKE: %d failures ===" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _new_game(profile_id: String) -> void:
	_ended = ""
	EventManager.clear_pending()
	orch = GameOrchestrator.new()
	orch.new_game(12345, profile_id)
	SimulationRunner.start_run()


func _ticks(count: int) -> void:
	for _i: int in range(count):
		orch.tick_scheduler.run_tick()
		EventManager.call("_check_triggers")


func _first(type_id: String) -> Vector2i:
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		if (GameStateStore.get_building(coord).get("type", "") as String) == type_id:
			return coord
	return Vector2i(-9999, -9999)


func _place(coord: Vector2i, type_id: String) -> void:
	GameStateStore.set_building(coord, { "type": type_id, "level": 0, "damaged": false, "has_issue": false })
	orch.spatial.add(coord, type_id)
	orch.coverage.invalidate()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
	print(("PASS: " if ok else "FAIL: ") + what)
