extends Node
## Run-state regressions: the start menu, autosave, the desk queue across runs and loads,
## Space under a critical card, and the finale. Runs the real main scene headless.
##
## Run: Godot --headless --fixed-fps 60 --path <proj> res://tools/run_state_smoke.tscn
## Dev tool, not shipped. Saves go to the tools folder (user://saves_tools/), never the player's.

const TEST_SLOT := 9

var _main: Node
var _hud: Node
var _failures: int = 0


func _ready() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_main)
	_run.call_deferred()


func _run() -> void:
	get_tree().current_scene = _main
	_hud = _main.get_node("HUDCanvas/HUD")

	# 1. Behind the start menu nothing ticks and nothing autosaves.
	var tick_before: int = GameStateStore.get_tick()
	await _frames(120)
	_check(not SimulationRunner.is_running(), "menu: simulation is not running")
	_check(GameStateStore.get_tick() == tick_before, "menu: no ticks behind the menu")
	_check((SaveService.get("_autosave_timer") as float) == 0.0, "menu: autosave timer does not advance")

	# 2. A letter left in the queue does not follow the player into a new run; neither does
	# the game speed or a hint queued for the menu map.
	EventManager.pending_events.append({"runtime_id": "test.leftover"})
	SimulationRunner.set_speed(3.0)
	(OnboardingManager.get("_queue") as Array).append("season_dust")
	_hud.call("_start_new_run", "directorate_administrator")
	_check(SimulationRunner.is_running(), "new run: simulation runs")
	_check(EventManager.pending_events.is_empty(), "new run: desk queue starts empty")
	_check(is_equal_approx(SimulationRunner.speed_scale, 1.0), "new run: speed back to ×1")
	_check(not (OnboardingManager.get("_queue") as Array).has("season_dust"), "new run: hints queued before it are dropped")

	# 2b. Event cooldowns count game ticks, not frames: one tick takes one second off.
	var cooldowns: Dictionary = EventManager.call("_event_cooldowns")
	cooldowns["test.cooldown"] = 10.0
	EventBus.tick_finished.emit(GameStateStore.get_tick())
	_check(is_equal_approx(cooldowns.get("test.cooldown", 0.0) as float, 9.0), "cooldown: one tick = one game second (got %.2f)" % (cooldowns.get("test.cooldown", 0.0) as float))
	SimulationRunner.set_speed(3.0)
	EventBus.tick_finished.emit(GameStateStore.get_tick())
	_check(is_equal_approx(cooldowns.get("test.cooldown", 0.0) as float, 8.0), "cooldown: the same at ×3")
	SimulationRunner.set_speed(1.0)
	cooldowns.erase("test.cooldown")

	# 2c. Skipping the "press Space" tutorial step does not leave the day frozen.
	TutorialManager.enabled_for_next_run = true
	TutorialManager.on_run_started()
	var steps: Array = TutorialManager.get("_steps")
	var space_step: int = -1
	for i: int in steps.size():
		var text: String = (steps[i] as Dictionary).get("text", "") as String
		if text.contains("[b]Space[/b]") or text.contains("[b]Пробел[/b]"):
			space_step = i
	_check(space_step >= 0 and SimulationRunner.paused, "tutorial: starts paused, Space step found")
	TutorialManager.call("_go", space_step)
	TutorialManager.call("_go", space_step + 1)  # what "Skip this step" does
	_check(not SimulationRunner.paused, "tutorial: skipping the Space step lets the day run")
	TutorialManager.call("_finish", false)
	TutorialManager.enabled_for_next_run = false

	# 3. The desk queue and the time left in the day ride the save.
	await _frames(30)
	EventManager.pending_events.append({"runtime_id": "test.saved_card", "title": "t", "options": []})
	SimulationRunner.day_timer = 123.0
	_check(SaveService.save_game(TEST_SLOT, true), "save: written to test slot")
	EventManager.clear_pending()
	SimulationRunner.day_timer = 300.0
	(OnboardingManager.get("_queue") as Array).append("season_dust")
	_check(SaveService.load_game(TEST_SLOT), "load: test slot loads")
	var ids: Array = EventManager.pending_events.map(func(e: Dictionary) -> String: return e.get("runtime_id", "") as String)
	_check(ids.has("test.saved_card"), "load: saved desk card is back")
	_check(is_equal_approx(SimulationRunner.day_timer, 123.0), "load: day timer restored (got %.1f)" % SimulationRunner.day_timer)
	_check(SimulationRunner.is_running(), "load: simulation runs")
	_check(not (OnboardingManager.get("_queue") as Array).has("season_dust"), "load: hints queued before the load are dropped")
	SaveService.delete_save(TEST_SLOT)
	EventManager.clear_pending()

	# 4. Space does not resume the day under a critical card.
	EventBus.critical_event_started.emit({"runtime_id": "test.critical", "title": "t", "options": [{"text": "ok", "effects": {}}]})
	SimulationRunner.paused = true
	SimulationRunner.toggle_pause()
	_check(SimulationRunner.paused, "critical card: Space keeps the pause")
	_main.get_node("HUDCanvas/DeskUI").call("_finish_evening")
	_check(SimulationRunner.is_running(), "critical card: closing it resumes the day")

	# 5. A finale ends the run: no more ticks, and the autosave is gone, so "Continue" cannot
	# reopen a finished run.
	_check(SaveService.save_game(0, true) and SaveService.has_save(0), "finale: an autosave exists before it")
	GameStateStore.mandate()["patron_trust"] = 0.0
	EventBus.tick_finished.emit(GameStateStore.get_tick())
	_check(not SimulationRunner.run_active, "finale: run is over")
	_check(not SaveService.has_save(0), "finale: the autosave of the finished run is removed")

	# 6. The play log (RunLog) recorded this run from start to finale, and nothing for the
	# throwaway map behind the start menu.
	var log_path: String = "user://analytics_tools/run_%d.jsonl" % (GameStateStore.save_meta().get("rng_seed", 0) as int)
	var kinds: Array = []
	var log_file := FileAccess.open(log_path, FileAccess.READ)
	if log_file != null:
		while not log_file.eof_reached():
			var line: String = log_file.get_line()
			var parsed: Variant = JSON.parse_string(line) if line != "" else null
			if parsed is Dictionary:
				kinds.append((parsed as Dictionary).get("kind", ""))
		log_file.close()
	_check(kinds.size() > 0 and kinds[0] == "run_start", "play log: starts with run_start (%s)" % ", ".join(kinds))
	_check(kinds.has("run_continue") and kinds.has("tutorial_step") and kinds.has("tutorial_end"), "play log: the load and the tutorial are there")
	_check(kinds.size() > 0 and kinds[-1] == "run_end", "play log: ends with run_end")
	_check(RunLog.get("_path") == "", "play log: closed after the finale")
	DirAccess.remove_absolute(log_path)

	print("=== RUN STATE SMOKE: %d failures ===" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _frames(count: int) -> void:
	for _i: int in count:
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_failures += 1
