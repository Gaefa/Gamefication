extends Node
## Run-state regressions: the start menu, autosave, the desk queue across runs and loads,
## Space under a critical card, and the finale. Runs the real main scene headless.
##
## Run: Godot --headless --fixed-fps 60 --path <proj> res://tools/run_state_smoke.tscn
## Dev tool, not shipped. Uses save slot 9 and deletes it; never touches slot 0.

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

	# 2. A letter left in the queue does not follow the player into a new run.
	EventManager.pending_events.append({"runtime_id": "test.leftover"})
	_hud.call("_start_new_run", "directorate_administrator")
	_check(SimulationRunner.is_running(), "new run: simulation runs")
	_check(EventManager.pending_events.is_empty(), "new run: desk queue starts empty")

	# 3. The desk queue and the time left in the day ride the save.
	await _frames(30)
	EventManager.pending_events.append({"runtime_id": "test.saved_card", "title": "t", "options": []})
	SimulationRunner.day_timer = 123.0
	_check(SaveService.save_game(TEST_SLOT, true), "save: written to test slot")
	EventManager.clear_pending()
	SimulationRunner.day_timer = 300.0
	_check(SaveService.load_game(TEST_SLOT), "load: test slot loads")
	var ids: Array = EventManager.pending_events.map(func(e: Dictionary) -> String: return e.get("runtime_id", "") as String)
	_check(ids.has("test.saved_card"), "load: saved desk card is back")
	_check(is_equal_approx(SimulationRunner.day_timer, 123.0), "load: day timer restored (got %.1f)" % SimulationRunner.day_timer)
	_check(SimulationRunner.is_running(), "load: simulation runs")
	SaveService.delete_save(TEST_SLOT)
	EventManager.clear_pending()

	# 4. Space does not resume the day under a critical card.
	EventBus.critical_event_started.emit({"runtime_id": "test.critical", "title": "t", "options": [{"text": "ok", "effects": {}}]})
	SimulationRunner.paused = true
	SimulationRunner.toggle_pause()
	_check(SimulationRunner.paused, "critical card: Space keeps the pause")
	_main.get_node("HUDCanvas/DeskUI").call("_finish_evening")
	_check(SimulationRunner.is_running(), "critical card: closing it resumes the day")

	# 5. A finale ends the run: no more ticks, no autosave.
	GameStateStore.mandate()["patron_trust"] = 0.0
	EventBus.tick_finished.emit(GameStateStore.get_tick())
	_check(not SimulationRunner.run_active, "finale: run is over")

	print("=== RUN STATE SMOKE: %d failures ===" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _frames(count: int) -> void:
	for _i: int in count:
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_failures += 1
