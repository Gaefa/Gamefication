extends Node
## Loads and caches all JSON content files.
## Read-only after _ready().  Every system queries ContentDB for definitions.

var buildings: Dictionary = {}
var resources: Dictionary = {}
var city_levels: Array = []
var terrain_types: Dictionary = {}
var events: Dictionary = {}
var synergies: Array = []
var categories: Dictionary = {}
var tutorial_steps: Array = []

const CONTENT_ROOT := "res://content/base/"


func _ready() -> void:
	buildings = _load_json(CONTENT_ROOT + "buildings.json")
	# resources.json is an Array — convert to Dictionary keyed by "id"
	var res_raw: Variant = _load_json_raw(CONTENT_ROOT + "resources.json")
	if res_raw is Array:
		for entry: Variant in res_raw:
			if entry is Dictionary:
				var d: Dictionary = entry as Dictionary
				var res_id: String = d.get("id", "") as String
				if res_id != "":
					resources[res_id] = d
	elif res_raw is Dictionary:
		resources = res_raw as Dictionary
	var terrain_raw: Dictionary = _load_json(CONTENT_ROOT + "terrain.json")
	terrain_types = terrain_raw.get("types", terrain_raw)
	# events.json is an Array — convert to Dictionary keyed by "id"
	var ev_raw: Variant = _load_json_raw(CONTENT_ROOT + "events.json")
	if ev_raw is Array:
		for entry: Variant in ev_raw:
			if entry is Dictionary:
				var d: Dictionary = entry as Dictionary
				var ev_id: String = d.get("id", "") as String
				if ev_id != "":
					events[ev_id] = d
	elif ev_raw is Dictionary:
		events = ev_raw as Dictionary
	synergies = _load_json_array(CONTENT_ROOT + "synergies.json")
	categories = _load_json(CONTENT_ROOT + "categories.json")

	var levels_raw: Variant = _load_json_raw(CONTENT_ROOT + "city_levels.json")
	if levels_raw is Array:
		city_levels = levels_raw
	else:
		push_warning("ContentDB: city_levels.json should be an Array")

	var tut_raw: Variant = _load_json_raw(CONTENT_ROOT + "tutorial_steps.json")
	if tut_raw is Array:
		tutorial_steps = tut_raw


# --- Public queries ---

func get_building_def(type_id: String) -> Dictionary:
	return buildings.get(type_id, {})


func get_resource_def(res_id: String) -> Dictionary:
	return resources.get(res_id, {})


func get_terrain_def(terrain_id: Variant) -> Dictionary:
	return terrain_types.get(str(terrain_id), {})


func get_event_def(event_id: String) -> Dictionary:
	return events.get(event_id, {})


func get_level_def(level: int) -> Dictionary:
	if level >= 1 and level <= city_levels.size():
		return city_levels[level - 1]
	return {}


func get_building_ids() -> Array:
	return buildings.keys()


func get_resource_ids() -> Array:
	return resources.keys()


func get_event_ids() -> Array:
	return events.keys()


func get_level_requirement(level: int, key: String) -> Variant:
	var def := get_level_def(level)
	var reqs: Dictionary = def.get("requirements", {})
	return reqs.get(key, 0)


func building_level_data(type_id: String, level: int) -> Dictionary:
	var def := get_building_def(type_id)
	var levels: Array = def.get("levels", [])
	if level >= 0 and level < levels.size():
		return levels[level]
	return {}


func max_building_level(type_id: String) -> int:
	var def := get_building_def(type_id)
	return def.get("levels", []).size()


# --- Internal loaders ---

func _load_json(path: String) -> Dictionary:
	var raw: Variant = _load_json_raw(path)
	if raw is Dictionary:
		return raw
	push_warning("ContentDB: expected Dictionary in %s" % path)
	return {}


func _load_json_array(path: String) -> Array:
	var raw: Variant = _load_json_raw(path)
	if raw is Array:
		return raw
	push_warning("ContentDB: expected Array in %s" % path)
	return []


func _load_json_raw(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("ContentDB: file not found: %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("ContentDB: cannot open %s" % path)
		return null
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("ContentDB: JSON parse error in %s: %s" % [path, json.get_error_message()])
		return null
	return json.data
