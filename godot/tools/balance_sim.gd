extends Node
## Headless balance harness. Boots the orchestrator, fast-forwards the Окно→Пыль
## cycle tick-by-tick (no real-time day timer), and prints a per-day trajectory:
## water / food (with net-per-tick), population, happiness, patron trust, pressure.
##
## Runs two scenarios so we can see whether preparation matters:
##   A) bootstrap — starter layout, everything level 0 (unprepared)
##   B) prepared  — well-pump and Main Cistern upgraded to level 2 (invested in water)
##
## Run: Godot --headless --path <proj> res://tools/balance_sim.tscn
## Not shipped with the game — a dev tool for reading the economy at a glance.

const TICKS_PER_DAY := 300   # matches SimulationRunner (day_duration 300s @ 1 tick/s)
const DAYS := 31             # one full Окно(18) → Пыль(11) cycle + tail

var active_orch: GameOrchestrator  # exposed like main.gd so map-changing effects can find it


func get_orchestrator() -> GameOrchestrator:
	return active_orch


func _ready() -> void:
	EventBus.audit_completed.connect(func(passed: bool, score: int) -> void:
		print("      >> АУДИТ: score=%d/3 passed=%s → доверие=%.0f" % [score, str(passed), GameStateStore.mandate().get("patron_trust", 0) as float]))
	EventBus.ending_triggered.connect(func(eid: String, kind: String) -> void:
		print("      >> ФИНАЛ [%s]: %s (день %d, нас %d, сч %.0f)" % [
			kind, eid,
			GameStateStore.climate().get("total_day", 0) as int,
			GameStateStore.population().get("total", 0) as int,
			GameStateStore.population().get("happiness", 0.0) as float]))
	EventBus.season_changed.connect(func(sid: String, _d: int, _l: int) -> void:
		print("      >> СЕЗОН → %s" % sid))
	_run("A) BOOTSTRAP (всё L0, неподготовлен)", false)
	print("")
	_run("B) PREPARED (насос+цистерна L2, вложился в воду)", true)

	# Scenario C: second patron — recall must use the Directorate's method (Комиссар),
	# proving the recall is data-driven by patron, not hardcoded to the League.
	print("\n=== C) DIRECTORATE recall test ===")
	var orch := GameOrchestrator.new()
	orch.new_game(12345, "directorate_administrator")
	print("patron_id = %s (ожидается civic_directorate)" % (GameStateStore.mandate().get("patron_id", "") as String))
	GameStateStore.mandate()["patron_trust"] = 0.0
	orch.tick_scheduler.run_tick()  # EndingManager evaluates on tick_finished

	# Scenario D: second patron WIN — should be told in the Directorate's voice.
	print("\n=== D) DIRECTORATE win test ===")
	var orch2 := GameOrchestrator.new()
	orch2.new_game(12345, "directorate_administrator")
	GameStateStore.climate()["total_day"] = 30
	GameStateStore.population()["happiness"] = 60.0
	GameStateStore.mandate()["patron_trust"] = 60.0
	GameStateStore.mandate()["support"] = 35.0
	orch2.tick_scheduler.run_tick()

	# Scenario E: напор — pressure fades at the radius edge and under load; a second pump
	# placed by the far house fixes it (a bigger reserve or radius alone would not).
	print("\n=== E) WATER PRESSURE test ===")
	var orch3 := GameOrchestrator.new()
	orch3.new_game(12345, "appointed_administrator")
	var far := Vector2i(4, 1)   # 4 hexes from the pump at (0,1): the edge of its radius
	var shelter := {"type": "bld_shelter", "level": 0, "damaged": false, "has_issue": false}
	GameStateStore.set_building(far, shelter.duplicate())
	for c: Vector2i in [Vector2i(1, 1), Vector2i(-1, 2), Vector2i(0, 2)]:
		GameStateStore.set_building(c, shelter.duplicate())
	orch3.coverage.invalidate()
	print("one pump:  far %.2f | near %.2f (6 consumers on a cap-3 pump)" % [orch3.coverage.water_pressure(far), orch3.coverage.water_pressure(Vector2i(-2, 1))])
	GameStateStore.set_building(Vector2i(4, 0), {"type": "bld_well_pump", "level": 0, "damaged": false, "has_issue": false})
	orch3.coverage.invalidate()
	print("two pumps: far %.2f | near %.2f (far house moved to its own pump)" % [orch3.coverage.water_pressure(far), orch3.coverage.water_pressure(Vector2i(-2, 1))])

	# Scenario F: the old tower's fate changes the map through the real desk path.
	print("\n=== F) OLD TOWER branch test ===")
	var opts: Array = ContentDB.get_event_def("branch.old_tower").get("options", []) as Array
	active_orch = GameOrchestrator.new()
	active_orch.new_game(12345, "appointed_administrator")
	var stone_before: float = GameStateStore.get_resource("res_stone")
	var demolish: Dictionary = opts[2] as Dictionary
	EventBus.desk_option_selected.emit("branch.old_tower", 2, demolish.get("effects", {}), demolish.get("cost", {}))
	print("demolish: (2,1) = '%s', stone %+.0f" % [GameStateStore.get_building(Vector2i(2, 1)).get("type", "<none>"), GameStateStore.get_resource("res_stone") - stone_before])
	active_orch = GameOrchestrator.new()
	active_orch.new_game(12345, "appointed_administrator")
	var probe := Vector2i(2, 6)  # 5 hexes from the tower, 7 from the pump: outside pump coverage
	var covered_before: bool = active_orch.coverage.is_water_covered(probe)
	var restore: Dictionary = opts[1] as Dictionary
	EventBus.desk_option_selected.emit("branch.old_tower", 1, restore.get("effects", {}), restore.get("cost", {}))
	print("restore:  (2,1) = '%s', cell %s water-covered %s → %s" % [GameStateStore.get_building(Vector2i(2, 1)).get("type", "<none>"), str(probe), str(covered_before), str(active_orch.coverage.is_water_covered(probe))])

	# Sanity-check the style-flag plumbing (events don't fire in this headless harness).
	GameStateStore.style_flags().clear()
	GameStateStore.add_style_flag("protector", 3)
	GameStateStore.add_style_flag("loyal", 1)
	print("\n=== style flags check: %s → dominant=%s ===" % [
		str(GameStateStore.style_flags()), GameStateStore.dominant_style("")])

	get_tree().quit()


func _run(label: String, prepared: bool) -> void:
	EventManager.clear_pending()
	var orch := GameOrchestrator.new()
	orch.new_game(12345, "appointed_administrator")
	if prepared:
		_upgrade_water_infra(orch)

	print("=== %s ===" % label)
	print(" д | сезон     дн | вода   (нет/т) | еда   (нет/т) | нас | сч | Лига | Город | давл")
	print("---+--------------+---------------+--------------+-----+----+------+-------+-----")
	var seen: int = 0
	for day: int in range(1, DAYS + 1):
		if day > 1:
			SimulationRunner.day_count += 1
		for _t: int in range(TICKS_PER_DAY):
			orch.tick_scheduler.run_tick()
		_log_day(day)
		while seen < EventManager.pending_events.size():
			print("      >> КРИЗИС из давления: %s (день %d)" % [EventManager.pending_events[seen].get("runtime_id", "") as String, day])
			seen += 1
	var raised: Array = EventManager.pending_events.map(func(e: Dictionary) -> String: return e.get("runtime_id", "") as String)
	print("      >> КРИЗИСЫ НА СТОЛЕ: %s" % str(raised))


func _upgrade_water_infra(orch: GameOrchestrator) -> void:
	# Upgrade the well-pump (more m³/tick) and the Main Cistern (bigger reserve) to L2.
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		var type_id: String = bld.get("type", "") as String
		if type_id == "bld_well_pump" or type_id == "bld_main_cistern":
			bld["level"] = 2
			GameStateStore.set_building(coord, bld)
	orch.spatial.rebuild_from_state()
	orch.coverage.invalidate()
	orch.road_graph.invalidate()
	orch.aura_cache.invalidate()
	orch.infrastructure_sys.process_tick()


func _log_day(day: int) -> void:
	var c: Dictionary = GameStateStore.climate()
	var sid: String = c.get("season_id", "?") as String
	var sdef: Dictionary = ContentDB.get_season_def(sid)
	var sname: String = sdef.get("label", sid) as String
	var prod: Dictionary = GameStateStore.economy().production
	var pw: Dictionary = GameStateStore.power()
	var tp: Dictionary = pw.get("tier_powered", {}) as Dictionary
	var pwr: String = "%s%s%s" % [
		"P" if tp.get("priority", true) else "·",
		"S" if tp.get("secondary", true) else "·",
		"T" if tp.get("tertiary", true) else "·"]
	print("%2d | %-9s %d/%-2d | %6.0f (%+5.2f) | %5.0f (%+5.2f) | %3d | %2.0f | %4.0f | %5.0f | %3.0f | эл %2.0f/%2.0f %s" % [
		day,
		sname,
		c.get("day_in_season", 0) as int,
		sdef.get("length_days", 0) as int,
		GameStateStore.get_resource("res_water_stockpile"),
		prod.get("res_water_stockpile", 0.0) as float,
		GameStateStore.get_resource("res_food"),
		prod.get("res_food", 0.0) as float,
		GameStateStore.population().get("total", 0) as int,
		GameStateStore.population().get("happiness", 0.0) as float,
		GameStateStore.mandate().get("patron_trust", 0) as float,
		GameStateStore.mandate().get("support", 0) as float,
		GameStateStore.pressure().get("index", 0.0) as float,
		pw.get("generation", 0.0) as float,
		pw.get("demand", 0.0) as float,
		pwr,
	])
