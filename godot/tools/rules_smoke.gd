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
	var mail_days: Array = [ContentDB.get_grant_day(), ContentDB.get_win_day()] + ContentDB.get_audit_days()
	for event_id: String in ContentDB.get_event_ids():
		var evt_def: Dictionary = ContentDB.get_event_def(event_id)
		if evt_def.has("trigger_day") and not evt_def.has("trigger_condition") and (evt_def.get("patron", "restoration_league") as String) == "restoration_league":
			mail_days.append(evt_def.get("trigger_day") as int)
	var longest_gap: int = 0
	var quiet: int = 0
	for day: int in range(5, ContentDB.get_win_day() + 1):
		quiet = 0 if mail_days.has(day) else quiet + 1
		longest_gap = maxi(longest_gap, quiet)
	_check(longest_gap <= 2, "no more than two quiet evenings in a row (longest: %d)" % longest_gap)

	_economy_rules()
	_primitive_rules()
	_heat_rules()

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


## The Desk's memory: flags gate cards, styles pick them, a buff can leave a card behind,
## a card can impose and lock a policy, policies cut the draw, the neighbour reacts.
func _primitive_rules() -> void:
	_new_game("appointed_administrator")
	_ticks(1)
	var gated: Dictionary = {"requires_flag": "ruben_debt", "trigger_day": 1}
	_check(not EventManager.call("_trigger_met", gated), "a card that requires a flag waits for it")
	EventManager.call("_apply_effects", {"set_flag": "ruben_debt"})
	_check(EventManager.call("_trigger_met", gated), "…and comes once the flag is set")
	_check(not EventManager.call("_trigger_met", {"excludes_flag": "ruben_debt", "trigger_day": 1}), "a card excluded by a flag stays away")
	EventManager.call("_apply_effects", {"clear_flag": "ruben_debt"})
	_check(not EventManager.call("_trigger_met", gated), "a cleared flag closes the card again")
	GameStateStore.style_flags().clear()
	GameStateStore.add_style_flag("protector", 2)
	_check(EventManager.call("_trigger_met", {"requires_style": "protector", "trigger_day": 1}) and not EventManager.call("_trigger_met", {"requires_style": "loyal", "trigger_day": 1}), "a card can ask for the player's style")
	GameStateStore.climate()["total_day"] = 10
	_check(EventManager.call("_evaluate_trigger", "stat_day > 5") and not EventManager.call("_evaluate_trigger", "stat_day < 5"), "triggers read > and <")
	var gap_before: float = RivalManager.player_score() - RivalManager.rival_score()
	EventManager.call("_apply_effects", {"stat_rival_score": -5})
	_check(is_equal_approx(RivalManager.player_score() - RivalManager.rival_score(), gap_before + 5.0), "a card can move the neighbour's score")
	_check(EventManager.call("_evaluate_trigger", "stat_rival_gap < 0"), "stat_rival_gap reads the gap to the neighbour")

	# A promise with a deadline: the buff runs out and the card it names is raised.
	EventManager.clear_pending()
	EventManager.call("_apply_effects", {"add_buff": {"id": "promise", "name": "Обещание", "name_en": "A promise", "production_mult": 0.0, "remaining": 1, "on_expire_event": "petition.thanks"}})
	orch.maintenance_sys.process_tick()
	_check(EventManager.pending_events.any(func(e: Dictionary) -> bool: return e.get("runtime_id", "") == "petition.thanks"), "an expired promise raises its card")
	_check(GameStateStore.get_buffs().is_empty(), "…and the timer itself is gone")
	EventManager.call("_apply_effects", {"add_buff": {"id": "promise2", "name": "Срок", "name_en": "A deadline", "production_mult": 0.0, "remaining": 1, "on_expire_flag": "promise_due"}})
	orch.maintenance_sys.process_tick()
	_check((GameStateStore.mandate().get("flags", {}) as Dictionary).get("promise_due", false), "an expired deadline can raise a flag instead")

	# An order imposes a policy and locks it; the player cannot switch until the day passes.
	EventManager.call("_apply_effects", {"set_policy": "low_taxes", "lock_policy_days": 5})
	_check(GameStateStore.get_active_policy("taxation") == "low_taxes", "a card can impose a policy")
	GameStateStore.set_resource("res_money", 500.0)
	var back: SetPolicyCommand = orch.command_bus.execute(SetPolicyCommand.new("balanced_budget")) as SetPolicyCommand
	_check(not back.success and GameStateStore.get_active_policy("taxation") == "low_taxes", "…and the player cannot switch it while the order stands (%s)" % back.message)
	GameStateStore.climate()["total_day"] = 16
	back = orch.command_bus.execute(SetPolicyCommand.new("balanced_budget")) as SetPolicyCommand
	_check(back.success, "…until the order expires")

	# Rationing: a policy's consumption_mult cuts the draw everywhere the draw is read.
	var taxes: Dictionary = ContentDB.get_policy_def("low_taxes")
	(taxes["effects"] as Dictionary)["consumption_mult"] = {"res_water_stockpile": -0.5}
	GameStateStore.set_active_policy("taxation", "low_taxes")
	_check(is_equal_approx(EconomySystem.consumption_multiplier("res_water_stockpile"), 0.5), "a policy halves the water draw")
	_check(is_equal_approx(EconomySystem.draw_multiplier("res_water_stockpile", {"water_mult": 2.0}), 1.0), "…and the Heat's thirst and the rationing multiply")
	(taxes["effects"] as Dictionary).erase("consumption_mult")
	GameStateStore.set_active_policy("taxation", "balanced_budget")

	# Hard seasons carry four cards an evening, the Window three.
	EventManager.clear_pending()
	for i: int in 5:
		EventManager.pending_events.append({"runtime_id": "petition.fake_%d" % i, "options": []})
	GameStateStore.climate()["season_id"] = "season_window"
	_check((EventManager.call("_evening_mail") as Array).size() == 3, "the Window brings three cards an evening")
	GameStateStore.climate()["season_id"] = "season_dust"
	_check((EventManager.call("_evening_mail") as Array).size() == 4, "the Dust brings four")
	EventManager.clear_pending()


func _heat_rules() -> void:
	_new_game("appointed_administrator")
	var climate: Dictionary = GameStateStore.climate()
	_check(is_zero_approx(EconomySystem.daily_spoilage()), "Window has no food spoilage")
	SimulationRunner.day_count = 19
	orch.season_sys.process_tick()
	_check(is_zero_approx(EconomySystem.daily_spoilage()), "Dust has no food spoilage")
	GameStateStore.set_resource("res_food", 200.0)
	SimulationRunner.day_count = 30
	orch.season_sys.process_tick()
	_check(climate["season_id"] == "season_heat", "Heat starts on day 30")
	_check(is_equal_approx(climate["heat_food_start"], 200.0), "Heat records incoming food before spoilage")
	_check(is_equal_approx(EconomySystem.daily_spoilage(), 8.0), "Heat loses 4% per day")
	orch.economy_sys.call("_process_daily_spoilage")
	_check(is_equal_approx(GameStateStore.get_resource("res_food"), 192.0), "daily spoilage subtracts food")
	orch.economy_sys.call("_process_daily_spoilage")
	_check(is_equal_approx(GameStateStore.get_resource("res_food"), 192.0), "same-day ticks never repeat spoilage")
	var warehouse: Dictionary = GameStateStore.get_building(_first("bld_warehouse"))
	warehouse["level"] = 1
	GameStateStore.set_building(_first("bld_warehouse"), warehouse)
	_check(is_equal_approx(EconomySystem.daily_spoilage(), 192.0 * 0.03), "displayed level 2 warehouse cuts loss by a quarter")
	GameStateStore.mandate()["flags"] = {"dried_rations": true}
	_check(is_equal_approx(EconomySystem.daily_spoilage(), 192.0 * 0.015), "dried rations halve the remaining loss")
	for coord: Vector2i in [Vector2i(8, 0), Vector2i(8, 1), Vector2i(8, 2), Vector2i(8, 3)]:
		GameStateStore.set_building(coord, warehouse.duplicate())
	_check(is_equal_approx(EconomySystem.daily_spoilage(), 192.0 * 0.005), "warehouse protection has a 25% floor")
	var water_cap: float = GameStateStore.get_cap("res_water_stockpile")
	GameStateStore.set_resource("res_water_stockpile", water_cap * 0.3)
	_check(is_zero_approx(ProgressionSystem.heat_stress_term()), "30% water is outside Heat stress")
	GameStateStore.set_resource("res_water_stockpile", water_cap * 0.29)
	_check(is_equal_approx(ProgressionSystem.heat_stress_term(), -8.0), "water below 30% incurs Heat stress")
	GameStateStore.set_resource("res_water_stockpile", water_cap * 0.04)
	_check(is_equal_approx(ProgressionSystem.heat_stress_term(), -20.0), "a cistern scraping the bottom (<5%) incurs -20, not stacked -28")
	orch.power_sys.process_tick()
	var heat_solar: float = GameStateStore.power().get("generation", 0.0) as float
	climate["modifiers"] = ContentDB.get_season_def("season_window")["modifiers"].duplicate(true)
	orch.power_sys.process_tick()
	_check(is_equal_approx(heat_solar, (GameStateStore.power().get("generation", 0.0) as float) * 1.2), "Heat solar generation is 1.2 times Window")
	_check(is_zero_approx(ProgressionSystem.heat_stress_term()), "Window never applies Heat stress")
	_new_game("appointed_administrator")
	EventManager.call("_on_pressure_threshold", "happiness")
	_check(not EventManager.pending_events.any(func(e: Dictionary) -> bool: return e.get("runtime_id", "") == "crisis.heat_collapse"), "Heat crisis cannot fire in Window")
	EventManager.clear_pending()
	SimulationRunner.day_count = 30
	orch.season_sys.process_tick()
	EventManager.call("_on_pressure_threshold", "happiness")
	_check(EventManager.pending_events.any(func(e: Dictionary) -> bool: return e.get("runtime_id", "") == "crisis.heat_collapse"), "Heat crisis takes priority during Heat")
	var shade: Dictionary = ContentDB.get_event_def("petition.covenant_shade")["options"][0]["effects"]
	EventManager.call("_apply_effects", shade)
	SimulationRunner.day_count = 41  # the Heat runs to the end of the term; the Window returns after it
	orch.season_sys.process_tick()
	orch.maintenance_sys.process_tick()
	_check(GameStateStore.get_buffs().is_empty(), "shade expires at Heat end even when accepted late")
	# Two real scheduled audits; no duplicate when called again on the same day.
	_new_game("appointed_administrator")
	GameStateStore.mandate()["patron_trust"] = 20.0
	GameStateStore.rival()["score"] = 0.0
	GameStateStore.population()["total"] = 12  # the people norm counts heads
	GameStateStore.population()["peak"] = 12
	GameStateStore.climate()["total_day"] = 20
	SimulationRunner.day_timer = 100.0
	MandateManager.call("_on_tick_finished", 0)
	_check(GameStateStore.mandate().get("audits_done", 0) == 0, "the inspector waits for the end of day 20")
	SimulationRunner.day_timer = 0.0
	MandateManager.call("_on_tick_finished", 0)
	MandateManager.call("_on_tick_finished", 0)
	_check(GameStateStore.mandate().get("audits_done", 0) == 1, "first audit fires once at the end of day 20")
	GameStateStore.climate()["total_day"] = 36
	MandateManager.call("_on_tick_finished", 0)
	_check(GameStateStore.mandate().get("audits_done", 0) == 2 and MandateManager.next_audit_day() == 0, "both audits complete after day 36")
	_check(is_equal_approx(GameStateStore.mandate().get("patron_trust", 0.0) as float, 57.5), "second audit applies exactly 1.5 times trust, preserving halves")
	var old_save: Dictionary = GameStateStore.to_save_dict().duplicate(true)
	old_save["mandate"].erase("audits_done")
	old_save["mandate"]["audit_done"] = true
	var migrated: Dictionary = SaveMigrator.migrate(old_save)
	_check(migrated["mandate"]["audits_done"] == 1 and not migrated["mandate"].has("audit_done"), "old audit_done migrates to one completed audit")
	_check(SaveValidator.validate(migrated).is_empty(), "migrated old save validates")
	GameStateStore.load_from_dict(migrated)
	orch.load_game()
	_check(MandateManager.next_audit_day() == 36, "old save loads with second audit still due")
	# The calendar, walked a day at a time from a fresh run: the term ends inside the Heat.
	_new_game("appointed_administrator")
	var seen_seasons: Dictionary = {}
	for d: int in range(1, 42):
		SimulationRunner.day_count = d
		orch.season_sys.process_tick()
		seen_seasons[d] = GameStateStore.climate()["season_id"]
	_check(seen_seasons[18] == "season_window" and seen_seasons[19] == "season_dust", "the Dust starts on day 19")
	_check(seen_seasons[29] == "season_dust" and seen_seasons[30] == "season_heat", "the Heat starts on day 30")
	_check(seen_seasons[40] == "season_heat", "day 40 is still the Heat")
	_check(seen_seasons[41] == "season_window", "the Window returns on day 41, after the term")


func _economy_rules() -> void:
	# Flows in content are per cycle: a barrack (cycle 10) draws 0.1 water a tick, 30 a day.
	_new_game("appointed_administrator")
	var shelter: Dictionary = ContentDB.building_level_data("bld_shelter", 0)
	_check(is_equal_approx(shelter.get("consumes", {}).get("res_water_stockpile", 0.0), 0.1), "a barrack draws 0.1 water per tick (1 per 10-tick cycle)")
	_check(is_equal_approx(ContentDB.building_level_data("bld_well_pump", 0).get("produces", {}).get("res_water_stockpile", 0.0), 5.0 / 15.0), "a pump gives 5 water per 15-tick cycle")
	# The start layout: one barrack and one plot, 0.15 a tick, 45 a day.
	_check(is_equal_approx(EconomySystem.daily_consumption("res_water_stockpile"), 45.0), "the starting district draws 45 water a day (%.1f)" % EconomySystem.daily_consumption("res_water_stockpile"))
	GameStateStore.set_resource("res_water_stockpile", 90.0)
	_check(is_equal_approx(EconomySystem.days_of("res_water_stockpile"), 2.0), "90 water is two days of that draw")

	# Housing earns by occupancy: half the beds empty, half the income.
	_ticks(2)
	var upkeep: float = orch.economy_sys.call("_maintenance_cost") as float
	var full_money: float = (GameStateStore.economy().production.get("res_money", 0.0) as float) + upkeep
	GameStateStore.population()["total"] = 2
	orch.economy_sys.process_tick()
	upkeep = orch.economy_sys.call("_maintenance_cost") as float  # two fewer heads, a little less upkeep
	var half_money: float = (GameStateStore.economy().production.get("res_money", 0.0) as float) + upkeep
	_check(full_money > 0.0 and is_equal_approx(half_money / full_money, 0.5), "a half-empty barrack earns half (%.3f vs %.3f per tick)" % [full_money, half_money])

	# The people norm counts heads, not only mood.
	var pop_state: Dictionary = GameStateStore.population()
	pop_state["happiness"] = 60.0
	pop_state["total"] = 4
	pop_state["peak"] = 4
	_check(not MandateManager.people_staying(false), "four people do not pass the people norm")
	pop_state["total"] = 8
	pop_state["peak"] = 8
	_check(MandateManager.people_staying(false), "eight people with steady mood do")
	pop_state["peak"] = 12
	_check(not MandateManager.people_staying(false), "…unless the district lost a third of them")
	pop_state["total"] = 12
	pop_state["peak"] = 12
	_check(MandateManager.people_staying(true), "the second audit asks for twelve")
	pop_state["peak"] = 20
	_check(not MandateManager.people_staying(true), "…who are not the remains of twenty")

	# Growth: at the starting mood newcomers fill an empty barrack within days, and a card can bring people in.
	_new_game("appointed_administrator")
	_ticks(1)  # the first census settles the starting district; a barrack built later starts empty
	_place(Vector2i(-1, 2), "bld_shelter")  # by the starter road, inside the pump's radius
	orch.infrastructure_sys.process_tick()
	_ticks(1)
	var before_growth: int = GameStateStore.population().get("total", 0) as int
	GameStateStore.population()["happiness"] = ProgressionSystem.CONTENT_HAPPINESS
	for _d: int in 4:
		GameStateStore.population()["happiness"] = ProgressionSystem.CONTENT_HAPPINESS
		GameStateStore.set_resource("res_food", 200.0)
		GameStateStore.set_resource("res_water_stockpile", 400.0)
		_ticks(300)
	var after_growth: int = GameStateStore.population().get("total", 0) as int
	_check(after_growth >= before_growth + 3, "at the starting mood a second barrack fills within four days (%d → %d)" % [before_growth, after_growth])
	EventManager.call("_apply_effects", {"add_residents": 50})
	_check((GameStateStore.population().get("total", 0) as int) == (GameStateStore.population().get("capacity", 0) as int), "people brought by a card fill the free beds and no more (%d of %d)" % [GameStateStore.population().get("total", 0) as int, GameStateStore.population().get("capacity", 0) as int])
	_check(is_equal_approx(RepairBuildingCommand.REPAIR_COST_COINS, 10.0), "a repair costs 10")

	# A dry cistern in the Heat stalls a barrack: the stock check uses the Heat draw.
	_check(is_equal_approx(EconomySystem._input_stock_efficiency_for({"res_water_stockpile": 0.1}, 1.0, {"res_water_stockpile": 0.1}, {"water_mult": 2.0}), 0.5),
		"the stock check doubles the draw in the Heat")
	# Breakdowns from a card never land on ruins.
	EventManager.call("_apply_effects", {"force_issues": 30})
	var broken_landmark: bool = false
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		if ContentDB.is_inert_landmark(bld.get("type", "") as String) and (bld.get("has_issue", false) as bool):
			broken_landmark = true
	_check(not broken_landmark, "force_issues leaves the landmarks alone")
	# The ground matters: a pump on a clay hill gives a fifth more than one on dusty ground.
	var on_hill: Vector2i = Vector2i(-9999, -9999)
	var on_grass: Vector2i = Vector2i(-9999, -9999)
	for q: int in range(-12, 13):
		for r: int in range(-12, 13):
			var c := Vector2i(q, r)
			if GameStateStore.has_building(c):
				continue
			if on_hill == Vector2i(-9999, -9999) and GameStateStore.get_terrain(c) == 3:
				on_hill = c
			elif on_grass == Vector2i(-9999, -9999) and GameStateStore.get_terrain(c) == 0:
				on_grass = c
	if on_hill != Vector2i(-9999, -9999) and on_grass != Vector2i(-9999, -9999):
		_place(on_hill, "bld_well_pump")
		_place(on_grass, "bld_well_pump")
		var hill_out: float = orch.production_mult.compute(on_hill).get("res_water_stockpile", 0.0) as float
		var grass_out: float = orch.production_mult.compute(on_grass).get("res_water_stockpile", 0.0) as float
		_check(grass_out > 0.0 and is_equal_approx(hill_out / grass_out, 1.2), "a pump on a clay hill gives +20%% (%.3f vs %.3f)" % [hill_out, grass_out])
	else:
		print("SKIP: no clay hill and dusty ground pair within radius 12 on this map")

	# The ledger: after a tick, days-of-reserve come from what the economy wrote, not a walk.
	_check(GameStateStore.economy().has("demand"), "the economy writes the demand ledger")
	# Saves: garbage types are refused before they touch the game; a finished .tmp is recovered.
	var garbage: Dictionary = {"meta": {"schema_version": 1}, "world": {"map_radius": 30, "terrain": "x", "buildings": {}},
		"economy": {"resources": {}, "caps": {}, "production": {}, "buffs": {}}, "population": {}, "progression": {}, "pressure": {}, "events": {"active": {}, "cooldowns": {}}}
	_check(SaveValidator.validate(garbage).size() >= 3, "a save with the wrong types is refused (%d errors)" % SaveValidator.validate(garbage).size())
	var slot_path: String = SaveService.call("_slot_path", 8) as String
	SaveService.delete_save(8)
	SaveService.save_game(8, true)
	DirAccess.rename_absolute(slot_path, slot_path + ".tmp")  # as a crash between remove and rename leaves it
	_check(SaveService.has_save(8) and FileAccess.file_exists(slot_path), "a finished .tmp beside a missing slot is recovered")
	SaveService.delete_save(8)
	_check(not FileAccess.file_exists(slot_path + ".tmp"), "deleting a slot removes its .tmp too")
	pop_state = GameStateStore.population()

	# The term ends on day 40 for everyone: a hut by a pump is not renewed.
	pop_state["total"] = 4
	pop_state["peak"] = 4
	GameStateStore.climate()["total_day"] = ContentDB.get_win_day()
	SimulationRunner.day_timer = 100.0
	EndingManager.call("_evaluate")
	_check(_ended == "", "day 40 is played before the term ends (ended: '%s')" % _ended)
	SimulationRunner.day_timer = 0.0
	EndingManager.call("_evaluate")
	_check(_ended == "ending.lose.not_renewed", "four happy people at the end of day 40 lose the mandate (ended: '%s')" % _ended)

	# A founder's self-set term ends on day 40 as well: a hut disperses, a district holds.
	_new_game("founder_rebel")
	_ticks(1)
	GameStateStore.climate()["total_day"] = ContentDB.get_win_day()
	SimulationRunner.day_timer = 0.0
	EndingManager.call("_evaluate")
	_check(_ended == "ending.lose.founder_dispersed", "a founder's hut disperses at the end of the term (ended: '%s')" % _ended)
	_new_game("founder_rebel")
	_ticks(1)
	GameStateStore.population()["total"] = 12
	GameStateStore.population()["peak"] = 12
	GameStateStore.population()["happiness"] = 60.0
	GameStateStore.climate()["total_day"] = ContentDB.get_win_day()
	SimulationRunner.day_timer = 0.0
	EndingManager.call("_evaluate")
	_check(_ended == "ending.win.founder", "a founder's district of twelve holds (ended: '%s')" % _ended)

	# Two of three norms pass the League and fail the Directorate.
	for profile: String in ["appointed_administrator", "directorate_administrator"]:
		_new_game(profile)
		var result: Array = []
		var on_audit := func(passed: bool, score: int) -> void: result.append([passed, score])
		EventBus.audit_completed.connect(on_audit)
		GameStateStore.set_resource("res_water_stockpile", 500.0)
		GameStateStore.set_resource("res_food", 300.0)
		GameStateStore.population()["happiness"] = 60.0  # four people: the people norm fails
		MandateManager.call("_run_audit")
		EventBus.audit_completed.disconnect(on_audit)
		var passed: bool = result.size() == 1 and (result[0][0] as bool)
		var score: int = (result[0][1] as int) if result.size() == 1 else -1
		if profile == "appointed_administrator":
			_check(score == 2 and passed, "the League passes a 2 of 3 audit (score %d, passed %s)" % [score, str(passed)])
		else:
			_check(score == 2 and not passed, "the Directorate does not (score %d, passed %s)" % [score, str(passed)])
