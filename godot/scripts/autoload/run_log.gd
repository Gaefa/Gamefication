extends Node
## RunLog (Autoload) — local play analytics for playtests.
## Each run writes one JSON-lines file, user://analytics/run_<seed>.jsonl: the start, a
## snapshot every evening, every answer at the Desk, full pressure bars, tutorial steps, the
## finale and a quit mid-run. A Continue appends to the same file (the run's seed names it).
## Nothing leaves the machine: testers send one archive (Options → "Pack a report", see
## pack_report), and tools/analytics_report.py turns a pile of logs into a funnel.

const SCHEMA := 1

var _dir: String = "user://analytics/"
var _path: String = ""
var _pressure_logged: Dictionary = {}
var _session_start_ms: int = 0


func _ready() -> void:
	# Dev tools play real runs; keep their logs out of the player's folder.
	if ContentDB.is_tool_run():
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


## The pause menu's two exits are drop-off points too; the report must not count them as crashes.
func note_exit(kind: String) -> void:
	if SimulationRunner.run_active:
		_log(kind, _snapshot())


## The folder testers send back; created on first use.
func folder() -> String:
	DirAccess.make_dir_recursive_absolute(_dir)
	return ProjectSettings.globalize_path(_dir)


func _open(kind: String) -> void:
	_pressure_logged.clear()
	_session_start_ms = Time.get_ticks_msec()
	_path = _dir + "run_%d.jsonl" % (GameStateStore.save_meta().get("rng_seed", 0) as int)
	DirAccess.make_dir_recursive_absolute(_dir)
	# The tools replay the same seeds for ever: a new run starts its file over instead of
	# appending to last month's (a thousand logs had grown in that folder).
	if kind == "run_start" and _dir != "user://analytics/" and FileAccess.file_exists(_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))
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
		"chapter": GameStateStore.save_meta().get("chapter_id", ContentDB.active_chapter) as String,
		"legacy": GameStateStore.save_meta().get("legacy_id", "") as String,
		"day": GameStateStore.climate().get("total_day", 1) as int,
		"season": GameStateStore.climate().get("season_id", "") as String,
		"playtime": int(GameStateStore.save_meta().get("playtime_sec", 0.0) as float),  # game seconds
		"session_sec": int((Time.get_ticks_msec() - _session_start_ms) / 1000.0),  # real seconds since start/continue
		"speed": SimulationRunner.speed_scale,  # "long" and "boring" look the same without it
		"buildings": GameStateStore.get_all_building_coords().size(),
		"population": population.get("total", 0) as int,
		"happiness": snappedf(population.get("happiness", 0.0) as float, 0.1),
		"pressure": snappedf(GameStateStore.pressure().get("index", 0.0) as float, 0.1),
		"trust": snappedf(mandate.get("patron_trust", 0.0) as float, 0.1),
		"support": snappedf(mandate.get("support", 0.0) as float, 0.1),
		"resources": resources,
		# The 0.4 mechanics: without these a log cannot say whether a tester found them.
		"norm": _norm_snapshot(),
		"rushes": SimulationRunner.rushes,                  # "to the evening" presses this run
		"lots_bought": GameStateStore.economy().get("lots_bought", 0) as int,
		"feasts": GameStateStore.economy().get("feasts_held", 0) as int,
	}


func _norm_snapshot() -> Dictionary:
	if not ChapterNorm.active():
		return {}
	var stage: int = ChapterNorm.current_stage()
	var now: Dictionary = ChapterNorm.progress(stage)
	return { "have": int(now["have"] as float), "need": int(now["need"] as float), "met": ChapterNorm.met(stage), "held": ChapterNorm.holding() }


## Everything a tester is asked to send, in one archive on the Desktop (or the next folder
## the system allows): the play logs, the engine's logs, the campaign file and a line about
## the machine. Returns the archive's path, or "" when nothing could be written.
func pack_report(only_folder: String = "") -> String:
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var version: String = ProjectSettings.get_setting("application/config/version", "") as String
	var file_name: String = "MandateCities_report_%s_%s.zip" % [version, stamp]
	var folders: Array[String] = []
	if only_folder != "":
		folders.append(only_folder)  # the tools pack into their own folder, never onto the Desktop
	else:
		for dir_id: int in [OS.SYSTEM_DIR_DESKTOP, OS.SYSTEM_DIR_DOWNLOADS, OS.SYSTEM_DIR_DOCUMENTS]:
			var system_dir: String = OS.get_system_dir(dir_id)
			if system_dir != "":
				folders.append(system_dir)
		folders.append(ProjectSettings.globalize_path("user://"))
	for target: String in folders:
		var path: String = target.path_join(file_name)
		var zip := ZIPPacker.new()
		if zip.open(path) != OK:
			continue
		_zip_text(zip, "info.txt", "\n".join([
			"Mandate Cities %s" % version,
			"os: %s %s" % [OS.get_name(), OS.get_version()],
			"model: %s" % OS.get_model_name(),
			"locale: %s (system %s)" % [Localization.current_locale, OS.get_locale()],
			"window: %s, screen: %s" % [str(DisplayServer.window_get_size()), str(DisplayServer.screen_get_size())],
			"packed: %s" % Time.get_datetime_string_from_system(),
		]))
		_zip_folder(zip, _dir, "analytics")
		_zip_folder(zip, "user://logs/", "logs")
		for extra: String in ["user://campaign.cfg"]:
			if FileAccess.file_exists(extra):
				_zip_bytes(zip, extra.get_file(), FileAccess.get_file_as_bytes(extra))
		zip.close()
		return path
	return ""


func _zip_folder(zip: ZIPPacker, dir_path: String, inside: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		_zip_bytes(zip, inside.path_join(file_name), FileAccess.get_file_as_bytes(dir_path.path_join(file_name)))


func _zip_text(zip: ZIPPacker, inside: String, text: String) -> void:
	_zip_bytes(zip, inside, text.to_utf8_buffer())


func _zip_bytes(zip: ZIPPacker, inside: String, bytes: PackedByteArray) -> void:
	if zip.start_file(inside) == OK:
		zip.write_file(bytes)
		zip.close_file()


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
