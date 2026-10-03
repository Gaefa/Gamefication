extends Node
## RunLog (Autoload) — local play analytics for playtests.
## Each run writes one JSON-lines file, user://analytics/run_<seed>.jsonl: the start, a
## snapshot every evening, every answer at the Desk, full pressure bars, tutorial steps, the
## finale and a quit mid-run. A Continue appends to the same file (the run's seed names it).
## Nothing leaves the machine: testers send the folder (Options → "Open folder"), and
## tools/analytics_report.py turns a pile of logs into a funnel.

const SCHEMA := 1

var _dir: String = "user://analytics/"
var _path: String = ""
var _pressure_logged: Dictionary = {}
var _session_start_ms: int = 0


func _ready() -> void:
	# Dev tools play real runs; keep their logs out of the player's folder.
	for arg: String in OS.get_cmdline_args():
		if arg.begins_with("res://tools/"):
			_dir = "user://analytics_tools/"
	EventBus.run_started.connect(func(continued: bool) -> void: _open("run_continue" if continued else "run_start"))
	EventBus.phase_changed.connect(func(phase: String) -> void:
		if phase == "evening":
			_log("day_end", _snapshot()))
	EventBus.desk_option_selected.connect(func(event_id: String, option_index: int, _effects: Dictionary, _cost: Dictionary) -> void:
		_log("desk_choice", { "event": event_id, "option": option_index }))
	# A full pressure bar signals every tick until a crisis lands: log it once a day.
	EventBus.pressure_threshold_reached.connect(func(category: String) -> void:
		var day: int = GameStateStore.climate().get("total_day", 1) as int
		var key: String = "%s@%d" % [category, day]
		if not _pressure_logged.has(key):
			_pressure_logged[key] = true
			_log("pressure_full", { "category": category, "day": day }))
	EventBus.audit_completed.connect(func(passed: bool, score: int) -> void:
		_log("audit", { "passed": passed, "score": score }))
	EventBus.ending_triggered.connect(func(ending_id: String, kind: String) -> void:
		_log("run_end", _snapshot().merged({ "ending": ending_id, "result": kind }))
		_path = "")
	TutorialManager.step_shown.connect(func(index: int, total: int) -> void:
		_log("tutorial_step", { "step": index + 1, "of": total }))
	TutorialManager.closed.connect(func(completed: bool, index: int) -> void:
		_log("tutorial_end", { "completed": completed, "at_step": index + 1 }))


func _notification(what: int) -> void:
	# Closing the window mid-run is the drop-off point a funnel most needs to see.
	if what == NOTIFICATION_WM_CLOSE_REQUEST and SimulationRunner.run_active:
		_log("quit", _snapshot())


## The folder testers send back; created on first use.
func folder() -> String:
	DirAccess.make_dir_recursive_absolute(_dir)
	return ProjectSettings.globalize_path(_dir)


func _open(kind: String) -> void:
	_pressure_logged.clear()
	_session_start_ms = Time.get_ticks_msec()
	_path = _dir + "run_%d.jsonl" % (GameStateStore.save_meta().get("rng_seed", 0) as int)
	DirAccess.make_dir_recursive_absolute(_dir)
	_log(kind, _snapshot().merged({
		"schema": SCHEMA,
		"version": ProjectSettings.get_setting("application/config/version", "") as String,
		"profile": GameStateStore.get_start_profile_id(),
		"patron": GameStateStore.mandate().get("patron_id", "") as String,
		"locale": Localization.current_locale,
		"tutorial": TutorialManager.enabled_for_next_run,
		"os": OS.get_name(),
	}))


func _snapshot() -> Dictionary:
	var resources: Dictionary = {}
	var stock: Dictionary = GameStateStore.economy().get("resources", {}) as Dictionary
	for res_id: String in stock:
		resources[res_id] = snappedf(stock[res_id] as float, 0.1)
	var population: Dictionary = GameStateStore.population()
	var mandate: Dictionary = GameStateStore.mandate()
	return {
		"day": GameStateStore.climate().get("total_day", 1) as int,
		"season": GameStateStore.climate().get("season_id", "") as String,
		"playtime": int(GameStateStore.save_meta().get("playtime_sec", 0.0) as float),  # game seconds
		"session_sec": int((Time.get_ticks_msec() - _session_start_ms) / 1000.0),  # real seconds since start/continue
		"buildings": GameStateStore.get_all_building_coords().size(),
		"population": population.get("total", 0) as int,
		"happiness": snappedf(population.get("happiness", 0.0) as float, 0.1),
		"pressure": snappedf(GameStateStore.pressure().get("index", 0.0) as float, 0.1),
		"trust": snappedf(mandate.get("patron_trust", 0.0) as float, 0.1),
		"support": snappedf(mandate.get("support", 0.0) as float, 0.1),
		"resources": resources,
	}


func _log(kind: String, data: Dictionary) -> void:
	if _path == "":
		return  # no run yet (start menu) or the run is over
	var line: Dictionary = { "t": Time.get_datetime_string_from_system(true), "kind": kind }
	line.merge(data)
	var file := FileAccess.open(_path, FileAccess.READ_WRITE if FileAccess.file_exists(_path) else FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify(line))
	file.close()
