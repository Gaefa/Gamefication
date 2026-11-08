extends Node
## Campaign (Autoload): what the chapters leave behind. The result of each finished chapter
## (its ending, the dominant style, the trust the patron and the city were left with, the
## flags that mark decisions) lives in user://campaign.cfg, outside the run's save slots, so
## a new chapter can read the last one and the start screen knows which chapters are open.
## Chapter 1 is always open; chapter N opens once chapter N-1 has any finale.

const FILE_PATH := "user://campaign.cfg"
const TOOLS_FILE_PATH := "user://campaign_tools.cfg"
## Decision flags worth carrying between chapters: the rest stay in their run.
const CARRIED_FLAGS := ["ruben_burned", "unregistered_people", "forecaster_active", "strike_banned", "dried_rations",
	"covenant_treaty", "charters_deal", "strike_broken", "union_standard", "boat_pact", "levee_wall"]

var pending_chapter: String = ""  # set by the finale's "next chapter" button for the title screen
var _results: Dictionary = {}     # chapter id → result dictionary
var _path: String = FILE_PATH


func _ready() -> void:
	for arg: String in OS.get_cmdline_args():
		if arg.begins_with("res://tools/"):
			_path = TOOLS_FILE_PATH
	_load()
	EventBus.ending_triggered.connect(_on_ending_triggered)


func is_unlocked(chapter_id: String) -> bool:
	var ids: Array = ContentDB.get_chapter_ids(true)
	var index: int = ids.find(chapter_id)
	if index <= 0:
		return index == 0
	return _results.has(ids[index - 1] as String)


func result_of(chapter_id: String) -> Dictionary:
	return (_results.get(chapter_id, {}) as Dictionary).duplicate(true)


## The last chapter in campaign order that has a finale; "" before the first one.
func last_completed() -> String:
	var last: String = ""
	for chapter_id: String in ContentDB.get_chapter_ids(true):
		if _results.has(chapter_id):
			last = chapter_id
	return last


## The first chapter without a finale, or "" when every chapter is done.
func next_open_chapter() -> String:
	for chapter_id: String in ContentDB.get_chapter_ids():
		if not _results.has(chapter_id):
			return chapter_id
	return ""


func record_result(chapter_id: String, ending_id: String, kind: String) -> void:
	var flags: Dictionary = GameStateStore.mandate().get("flags", {}) as Dictionary
	var carried: Dictionary = {}
	for flag: String in CARRIED_FLAGS:
		if flags.get(flag, false) as bool:
			carried[flag] = true
	_results[chapter_id] = {
		"ending": ending_id,
		"kind": kind,
		"day": GameStateStore.climate().get("total_day", 1) as int,
		"style": GameStateStore.dominant_style(""),
		"patron_id": GameStateStore.mandate().get("patron_id", "") as String,
		"patron_trust": int(GameStateStore.mandate().get("patron_trust", 0) as float),
		"support": int(GameStateStore.mandate().get("support", 0) as float),
		"population": GameStateStore.population().get("total", 0) as int,
		"flags": carried,
	}
	_save()


func reset_campaign() -> void:
	_results = {}
	_save()


func _on_ending_triggered(ending_id: String, kind: String) -> void:
	var chapter_id: String = GameStateStore.save_meta().get("chapter_id", ContentDB.active_chapter) as String
	record_result(chapter_id, ending_id, kind)


func _load() -> void:
	_results = {}
	var cfg := ConfigFile.new()
	if cfg.load(_path) != OK:
		return
	for chapter_id: String in cfg.get_sections():
		var result: Dictionary = {}
		for key: String in cfg.get_section_keys(chapter_id):
			result[key] = cfg.get_value(chapter_id, key)
		_results[chapter_id] = result


func _save() -> void:
	var cfg := ConfigFile.new()
	for chapter_id: String in _results:
		for key: String in _results[chapter_id] as Dictionary:
			cfg.set_value(chapter_id, key, (_results[chapter_id] as Dictionary)[key])
	cfg.save(_path)
