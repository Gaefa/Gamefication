extends Node
## Full-loop smoke test (RELEASE_PLAN §2.4: the cycle plays from appointment to a finale
## without blockers). Runs the real main scene — real SimulationRunner day timer, real
## evening desk, real critical cards, real HUD — at the game's 300 ticks per day, with an
## auto-player that resolves every desk card with its first affordable option. Logs each
## evening and flags a blocker if the simulation sits paused with nothing to unpause it.
##
## Run: Godot --headless --fixed-fps 60 --path <proj> res://tools/loop_smoke.tscn
## Dev tool, not shipped.

var SPEED := 5.0              # 5 ticks per sim second → a 300-tick day in 60 sim seconds (override: -- speed=1)
const MAX_DAY := 44
const STUCK_FRAMES := 600     # 10 sim seconds paused with no desk and no finale → blocker

var _prepared: bool = false
var _legacy: String = ""        # start_legacies.json id (override: -- legacy=legacy_cistern)
var _main: Node
var _desk: Control
var _stuck: int = 0
var _evenings: int = 0
var _cards: int = 0
var _pop_min: int = 999  # the smallest district seen at any evening (acceptance: never empty)
var _ending: String = ""
var _repairs: int = 0
var _repair_money: float = 0.0


func _ready() -> void:
	SaveService.set("_autosave_timer", -1.0e12)  # never write over the player's real save slot
	for arg: String in OS.get_cmdline_user_args():
		if arg == "prepared":
			_prepared = true
		if arg.begins_with("speed="):
			SPEED = arg.trim_prefix("speed=").to_float()
		if arg.begins_with("legacy="):
			_legacy = arg.trim_prefix("legacy=")
	EventBus.ending_triggered.connect(func(eid: String, kind: String) -> void:
		_ending = "%s (%s)" % [eid, kind])
	EventBus.evening_started.connect(func(events: Array) -> void:
		_evenings += 1
		_pop_min = mini(_pop_min, GameStateStore.population().get("total", 0) as int)
		_repair_issues()  # a player presses R on the "!" pins before the Desk
		var prod: Dictionary = GameStateStore.economy().get("production", {}) as Dictionary
		print("  вечер, день %d: %d карт. деньги %d (%+d/дн) · еда %d · вода %d · дерево %d · камень %d · инстр %d · жители %d · сч %d%s" % [
			SimulationRunner.day_count, events.size(),
			int(GameStateStore.get_resource("res_money")), int(round((prod.get("res_money", 0.0) as float) * float(SimulationRunner.TICKS_PER_DAY))),
			int(GameStateStore.get_resource("res_food")), int(GameStateStore.get_resource("res_water_stockpile")),
			int(GameStateStore.get_resource("res_wood")), int(GameStateStore.get_resource("res_stone")), int(GameStateStore.get_resource("res_tools")),
			GameStateStore.population().get("total", 0) as int, int(GameStateStore.population().get("happiness", 0.0) as float), _mood_terms_text()]))
	EventBus.critical_event_started.connect(func(data: Dictionary) -> void:
		print("  СРОЧНО, день %d: %s" % [SimulationRunner.day_count, data.get("runtime_id", "?") as String]))
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_main)
	_attach.call_deferred()


func _attach() -> void:
	get_tree().current_scene = _main  # effects and HUD look the orchestrator up here
	_desk = _main.get_node("HUDCanvas/DeskUI") as Control
	# Behind the start menu nothing runs; start the run the way the menu button does.
	seed(12345)  # compare speed runs against the same city and issue sequence
	_main.get_node("HUDCanvas/HUD").set("_selected_legacy", _legacy)
	_main.get_node("HUDCanvas/HUD").call("_start_new_run", "appointed_administrator")
	if _prepared:
		# The prepared district of balance_sim's stand B: roads, two more barracks, a second
		# plot, a generator, and the water infrastructure at L2. Twelve people, a win path.
		var orch: GameOrchestrator = _main.call("get_orchestrator") as GameOrchestrator
		for coord: Vector2i in [Vector2i(-2, -1), Vector2i(-1, -2), Vector2i(0, -2), Vector2i(1, -2)]:
			GameStateStore.set_building(coord, {"type": "bld_road", "level": 0})
		for coord: Vector2i in [Vector2i(-2, 0), Vector2i(-1, 2)]:
			GameStateStore.set_building(coord, {"type": "bld_shelter", "level": 0, "damaged": false, "has_issue": false})
		GameStateStore.set_building(Vector2i(-1, -3), {"type": "bld_field_strip", "level": 0, "damaged": false, "has_issue": false})
		GameStateStore.set_building(Vector2i(1, -3), {"type": "bld_generator", "level": 0, "damaged": false, "has_issue": false})
		for coord: Vector2i in GameStateStore.get_all_building_coords():
			var bld: Dictionary = GameStateStore.get_building(coord)
			if bld.get("type", "") in ["bld_well_pump", "bld_main_cistern"]:
				bld["level"] = 2
				GameStateStore.set_building(coord, bld)
		orch.spatial.rebuild_from_state()
		orch.coverage.invalidate()
		orch.infrastructure_sys.process_tick()
	SimulationRunner.speed_scale = SPEED


func _physics_process(_delta: float) -> void:
	if _desk == null:
		return
	if _ending != "":
		_finish("финал " + _ending)
	elif SimulationRunner.day_count > MAX_DAY:
		_finish("дошли до дня %d без финала" % SimulationRunner.day_count)
	elif _desk.visible:
		_stuck = 0
		_auto_resolve()
	elif SimulationRunner.paused:
		_stuck += 1
		if _stuck > STUCK_FRAMES:
			_finish("БЛОКЕР: пауза без Стола и финала (день %d, фаза %d)" % [SimulationRunner.day_count, SimulationRunner.current_phase])
	else:
		_stuck = 0


## Why the mood is what it is: every term that moves it by a point or more (ProgressionSystem.mood_terms).
func _mood_terms_text() -> String:
	var terms: Dictionary = GameStateStore.population().get("mood_terms", {}) as Dictionary
	var parts: Array[String] = []
	for key: String in ["supply", "power", "pressure", "buildings", "buffs", "governance", "neighbours", "waste"]:
		var value: float = terms.get(key, 0.0) as float
		if absf(value) >= 1.0:
			parts.append("%s %+d" % [key, roundi(value)])
	return "" if parts.is_empty() else " (→%d: %s)" % [int(terms.get("target", 50.0) as float), ", ".join(parts)]

func _auto_resolve() -> void:
	if (_desk.get("_finish_btn") as Button).visible:
		_desk.call("_finish_evening")
		return
	if (_desk.get("_next_btn") as Button).visible:
		_desk.call("_show_next_event")
		return
	var events: Array = _desk.get("_events") as Array
	var idx: int = _desk.get("_current_index") as int
	if idx >= events.size():
		return
	var evt: Dictionary = events[idx] as Dictionary
	var options: Array = evt.get("options", []) as Array
	if options.is_empty():
		return
	var pick: int = 0
	for i: int in options.size():
		var cost: Dictionary = (options[i] as Dictionary).get("cost", {})
		if cost.is_empty() or GameStateStore.can_afford(cost):
			pick = i
			break
	var opt: Dictionary = options[pick] as Dictionary
	_cards += 1
	print("    день %d: %s → «%s»" % [SimulationRunner.day_count, evt.get("runtime_id", "?") as String, (opt.get("text", "?") as String).left(40)])
	var preview: String = _desk.call("_consequences_text", opt.get("effects", {}), opt.get("cost", {})) as String
	if preview != "":
		print("      ⓘ " + preview.replace("\n", " | "))
	_desk.call("_select_option", evt.get("runtime_id", "") as String, pick, opt.get("effects", {}), opt.get("cost", {}))


func _finish(result: String) -> void:
	print("=== SMOKE: %s | вечеров %d, карт %d, день %d ===" % [result, _evenings, _cards, SimulationRunner.day_count])
	print((EndingManager.get("_theses_label") as RichTextLabel).get_parsed_text())
	var entries: Array = GameStateStore.events().get("log", []) as Array
	print("журнал событий: %d записей; последняя: %s" % [entries.size(), str(entries.back()) if not entries.is_empty() else "—"])
	print("соперник: %s %.0f · вы %.0f; грант решён: %s" % [RivalManager.rival_short(), RivalManager.rival_score(), RivalManager.player_score(), str(GameStateStore.rival().get("grant_decided", false))])
	# Chapter acceptance (plan §3, sprint 5): a hands-off run reaches the term's end with people still there.
	var full_term: bool = SimulationRunner.day_count >= ContentDB.get_win_day()
	var accepted: bool = full_term and _pop_min > 0 and _evenings >= ContentDB.get_win_day() - 1
	print("CHAPTER ACCEPTANCE [%s]: %s (day %d of %d, smallest district %d, evenings %d)" % [
		ContentDB.active_chapter, "PASS" if accepted else "NOT MET", SimulationRunner.day_count, ContentDB.get_win_day(), _pop_min, _evenings])
	set_physics_process(false)
	get_tree().quit()


## What any player does once a day: repair whatever broke, as long as the treasury allows.
func _repair_issues() -> void:
	var orch: GameOrchestrator = _main.call("get_orchestrator") as GameOrchestrator
	if orch == null:
		return
	var fixed: int = 0
	var before: float = GameStateStore.get_resource("res_money")
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		if (bld.get("has_issue", false) as bool) or (bld.get("damaged", false) as bool):
			orch.command_bus.execute(RepairBuildingCommand.new(coord))
			fixed += 1
	_repairs += fixed
	_repair_money += before - GameStateStore.get_resource("res_money")
	if fixed > 0:
		print("    ремонт: %d поломок, −%d денег (всего за партию %d / −%d)" % [fixed, int(before - GameStateStore.get_resource("res_money")), _repairs, int(_repair_money)])
