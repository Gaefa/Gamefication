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

	# The only home cannot be demolished while people live in it; with a second one it can.
	_new_game("appointed_administrator")
	_ticks(5)
	var home: Vector2i = _first("bld_shelter")
	orch.command_bus.execute(BulldozeCommand.new(home))
	_check(GameStateStore.has_building(home), "the last shelter cannot be demolished from under its residents")
	_place(_free_neighbour(home), "bld_shelter")
	orch.command_bus.execute(BulldozeCommand.new(home))
	_check(not GameStateStore.has_building(home), "with a second shelter the first can go")
	# A damaged shelter has no beds, so it does not count as the second home.
	_new_game("appointed_administrator")
	_ticks(5)
	home = _first("bld_shelter")
	var broken_home: Vector2i = _free_neighbour(home)
	GameStateStore.set_building(broken_home, { "type": "bld_shelter", "level": 0, "damaged": true, "has_issue": false })
	orch.command_bus.execute(BulldozeCommand.new(home))
	_check(GameStateStore.has_building(home), "a damaged second shelter does not unlock demolishing the last working one")

	# Spare housing standing empty does not make people leave faster in a bad day.
	_new_game("appointed_administrator")
	_ticks(5)
	_place(Vector2i(14, 6), "bld_shelter")
	_place(Vector2i(15, 6), "bld_shelter")
	var field: Vector2i = _first("bld_field_strip")
	GameStateStore.remove_building(field)
	orch.spatial.remove(field, "bld_field_strip")
	GameStateStore.set_resource("res_food", 0.0)
	_ticks(250)
	var left: int = GameStateStore.population().get("total", 0) as int
	_check(left >= 2 and left < 4, "a hungry day with empty barracks around thins the district but does not empty it (%d of 4 left)" % left)

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

	# Neighbour rules (synergies.json).
	_new_game("appointed_administrator")
	var warehouse: Vector2i = _first("bld_warehouse")
	var beside: Vector2i = _free_neighbour(warehouse)
	_place(beside, "bld_lumber_yard")
	_check(is_equal_approx(orch.adjacency.calculate_adjacency_bonus(beside, "bld_lumber_yard").get("res_wood", 0.0) as float, 0.1), "a lumber yard next to a warehouse gets +10% wood")
	_place(Vector2i(13, 3), "bld_lumber_yard")
	_check(orch.adjacency.calculate_adjacency_bonus(Vector2i(13, 3), "bld_lumber_yard").is_empty(), "a lumber yard far from a warehouse gets nothing")
	var quarry := Vector2i(10, -5)
	_place(quarry, "bld_quarry_pit")
	_place(quarry + Vector2i(1, 0), "bld_shelter")
	_check(is_equal_approx(orch.adjacency.value_at(quarry + Vector2i(1, 0), "bld_shelter", "mood"), -3.0), "a shelter next to a quarry loses 3 mood")
	var by_cistern: Vector2i = _free_neighbour(_first("bld_main_cistern"))
	_place(by_cistern, "bld_shelter")
	_check(orch.coverage.is_water_covered(by_cistern) and is_equal_approx(orch.coverage.water_pressure(by_cistern), 1.0), "a shelter at the Cistern has full pressure")
	_check(PressureSystem.new().call("_water_queue") > 0.0, "…and makes the water queue grow")
	var cistern_shelter: Dictionary = GameStateStore.get_building(by_cistern)
	cistern_shelter["damaged"] = true
	GameStateStore.set_building(by_cistern, cistern_shelter)
	_check(is_zero_approx(orch.adjacency.value_at(by_cistern, "bld_shelter", "water_queue")), "a damaged shelter at the Cistern adds no queue")
	var quarry_bld: Dictionary = GameStateStore.get_building(quarry)
	quarry_bld["damaged"] = true
	GameStateStore.set_building(quarry, quarry_bld)
	_check(is_zero_approx(orch.adjacency.value_at(quarry + Vector2i(1, 0), "bld_shelter", "mood")), "a damaged quarry no longer bothers its neighbours")

	# A card's temporary effect raises output for its term and then expires.
	_new_game("appointed_administrator")
	var log_pump: Vector2i = _first("bld_well_pump")
	var pump_before: float = orch.production_mult.compute(log_pump).get("res_water_stockpile", 0.0) as float
	var log_card: Dictionary = (ContentDB.get_event_def("petition.pump_log").get("options", []) as Array)[0] as Dictionary
	EventManager.call("_apply_effects", log_card.get("effects", {}))
	var pump_tuned: float = orch.production_mult.compute(log_pump).get("res_water_stockpile", 0.0) as float
	_check(pump_before > 0.0 and is_equal_approx(pump_tuned / pump_before, 1.15), "the pump log gives the pumps +15% output")
	_ticks(1500)
	_check(GameStateStore.get_buffs().is_empty(), "…and the effect ends after five days")

	# The Desk is never silent for long: from day 5 to the finale a League administrator
	# gets a scheduled letter at least every third evening.
	var mail_days: Array = [RivalManager.GRANT_DAY, MandateManager.AUDIT_DAY, EndingManager.WIN_DAY]
	for event_id: String in ContentDB.get_event_ids():
		var evt_def: Dictionary = ContentDB.get_event_def(event_id)
		if evt_def.has("trigger_day") and not evt_def.has("trigger_condition") and (evt_def.get("patron", "restoration_league") as String) == "restoration_league":
			mail_days.append(evt_def.get("trigger_day") as int)
	var longest_gap: int = 0
	var quiet: int = 0
	for day: int in range(5, EndingManager.WIN_DAY + 1):
		quiet = 0 if mail_days.has(day) else quiet + 1
		longest_gap = maxi(longest_gap, quiet)
	_check(longest_gap <= 2, "no more than two quiet evenings in a row (longest: %d)" % longest_gap)

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


func _free_neighbour(coord: Vector2i) -> Vector2i:
	for nb: Vector2i in HexCoords.neighbors_of(coord):
		if not GameStateStore.has_building(nb):
			return nb
	return Vector2i(-9999, -9999)


func _place(coord: Vector2i, type_id: String) -> void:
	GameStateStore.set_building(coord, { "type": type_id, "level": 0, "damaged": false, "has_issue": false })
	orch.spatial.add(coord, type_id)
	orch.coverage.invalidate()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
	print(("PASS: " if ok else "FAIL: ") + what)
