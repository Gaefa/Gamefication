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
	get_tree().quit()


func _run(label: String, prepared: bool) -> void:
	var orch := GameOrchestrator.new()
	orch.new_game(12345, "appointed_administrator")
	if prepared:
		_upgrade_water_infra(orch)

	print("=== %s ===" % label)
	print(" д | сезон     дн | вода   (нет/т) | еда   (нет/т) | нас | сч | дов | давл")
	print("---+--------------+---------------+--------------+-----+----+-----+-----")
	for day: int in range(1, DAYS + 1):
		if day > 1:
			SimulationRunner.day_count += 1
		for _t: int in range(TICKS_PER_DAY):
			orch.tick_scheduler.run_tick()
		_log_day(day)


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
	print("%2d | %-9s %d/%-2d | %6.0f (%+5.2f) | %5.0f (%+5.2f) | %3d | %2.0f | %3.0f | %3.0f" % [
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
		GameStateStore.pressure().get("index", 0.0) as float,
	])
