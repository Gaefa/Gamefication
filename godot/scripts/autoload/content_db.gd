## content_db.gd -- Loads all JSON from content/base/ at _ready() and
## provides typed, O(1)-lookup accessors for every content table.
class_name ContentDBClass
extends Node

# ---- Internal storage (populated in _ready) ----
var _buildings: Dictionary = {}         # id -> Dictionary
var _resources: Array = []              # Array of Dictionary
var _resources_by_id: Dictionary = {}   # id -> Dictionary
var _city_levels: Array = []            # Array of Dictionary
var _events: Array = []                 # Array of Dictionary
var _events_by_id: Dictionary = {}      # id -> Dictionary
var _synergies: Array = []              # Array of Dictionary
var _terrain_types: Dictionary = {}     # type_id (int as string) -> Dictionary
var _tutorial_steps: Array = []         # Array of Dictionary
var _categories: Array = []             # Array of String

const BASE_PATH: String = "res://content/base/"

# ------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------

func _ready() -> void:
	_load_buildings()
	_load_resources()
	_load_city_levels()
	_load_events()
	_load_synergies()
	_load_terrain()
	_load_tutorial_steps()
	_load_categories()


# ------------------------------------------------------------------
# Buildings
# ------------------------------------------------------------------

func get_building(id: String) -> Dictionary:
	if _buildings.has(id):
		return _buildings[id]
	push_warning("ContentDB: building id '%s' not found." % id)
	return {}


func get_building_level(id: String, level: int) -> Dictionary:
	var bld: Dictionary = get_building(id)
	if bld.is_empty():
		return {}
	var levels: Array = bld.get("levels", [])
	if level < 0 or level >= levels.size():
		push_warning("ContentDB: building '%s' has no level %d (max %d)." % [id, level, levels.size() - 1])
		return {}
	return levels[level]


func get_buildings_by_category(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in _buildings:
		var bld: Dictionary = _buildings[id]
		if bld.get("category", "") == category:
			result.append(bld)
	return result


func get_buildings_for_level(city_level: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in _buildings:
		var bld: Dictionary = _buildings[id]
		if bld.get("unlock_level", 999) <= city_level:
			result.append(bld)
	return result


func get_all_building_ids() -> Array[String]:
	var result: Array[String] = []
	for id: String in _buildings:
		result.append(id)
	return result


# ------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------

func get_resource_def(id: String) -> Dictionary:
	if _resources_by_id.has(id):
		return _resources_by_id[id]
	push_warning("ContentDB: resource id '%s' not found." % id)
	return {}


func get_resources() -> Array:
	return _resources


# ------------------------------------------------------------------
# City levels
# ------------------------------------------------------------------

func get_city_level(level: int) -> Dictionary:
	for entry: Dictionary in _city_levels:
		if int(entry.get("level", -1)) == level:
			return entry
	push_warning("ContentDB: city level %d not found." % level)
	return {}


func get_city_levels() -> Array:
	return _city_levels


# ------------------------------------------------------------------
# Events
# ------------------------------------------------------------------

func get_event(id: String) -> Dictionary:
	if _events_by_id.has(id):
		return _events_by_id[id]
	push_warning("ContentDB: event id '%s' not found." % id)
	return {}


func get_events() -> Array:
	return _events


func get_events_for_level(city_level: int) -> Array:
	var result: Array = []
	for ev: Dictionary in _events:
		if int(ev.get("min_level", 999)) <= city_level:
			result.append(ev)
	return result


func get_events_for_pressure_phase(phase: int) -> Array:
	var result: Array = []
	for ev: Dictionary in _events:
		if int(ev.get("pressure_phase_min", 0)) <= phase:
			result.append(ev)
	return result


# ------------------------------------------------------------------
# Synergies
# ------------------------------------------------------------------

func get_synergies() -> Array:
	return _synergies


func get_synergy_for_pair(type_a: String, type_b: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for syn: Dictionary in _synergies:
		var pair: Array = syn.get("pair", [])
		if pair.size() < 2:
			continue
		var pa: String = str(pair[0])
		var pb: String = str(pair[1])
		# Match either order, or wildcard
		if (pa == type_a and (pb == type_b or pb == "*")) \
			or (pa == type_b and (pb == type_a or pb == "*")) \
			or (pb == type_a and (pa == type_b or pa == "*")) \
			or (pb == type_b and (pa == type_a or pa == "*")):
			result.append(syn)
	return result


# ------------------------------------------------------------------
# Terrain
# ------------------------------------------------------------------

func get_terrain_type(type_id: int) -> Dictionary:
	var key: String = str(type_id)
	if _terrain_types.has(key):
		return _terrain_types[key]
	push_warning("ContentDB: terrain type %d not found." % type_id)
	return {}


# ------------------------------------------------------------------
# Tutorial
# ------------------------------------------------------------------

func get_tutorial_steps() -> Array:
	return _tutorial_steps


# ------------------------------------------------------------------
# Categories
# ------------------------------------------------------------------

func get_categories() -> Array:
	return _categories


# ==================================================================
# Private loaders
# ==================================================================

func _load_json_file(filename: String) -> Variant:
	var path: String = BASE_PATH + filename
	if not FileAccess.file_exists(path):
		push_warning("ContentDB: file not found -- %s" % path)
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("ContentDB: could not open %s (error %d)." % [path, FileAccess.get_open_error()])
		return null
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_warning("ContentDB: JSON parse failed for %s." % path)
		return null
	return parsed


func _load_buildings() -> void:
	var data: Variant = _load_json_file("buildings.json")
	if data is Dictionary:
		# The JSON is a dict keyed by building id.
		for id: String in data:
			var bld: Dictionary = data[id]
			bld["id"] = id   # inject the id inside the dict for convenience
			_buildings[id] = bld
		print("ContentDB: loaded %d buildings." % _buildings.size())
	else:
		push_warning("ContentDB: buildings.json should be a Dictionary.")


func _load_resources() -> void:
	var data: Variant = _load_json_file("resources.json")
	if data is Array:
		_resources = data
		for res: Dictionary in _resources:
			var rid: String = res.get("id", "")
			if rid != "":
				_resources_by_id[rid] = res
		print("ContentDB: loaded %d resources." % _resources.size())
	else:
		push_warning("ContentDB: resources.json should be an Array.")


func _load_city_levels() -> void:
	var data: Variant = _load_json_file("city_levels.json")
	if data is Array:
		_city_levels = data
		print("ContentDB: loaded %d city levels." % _city_levels.size())
	else:
		push_warning("ContentDB: city_levels.json should be an Array.")


func _load_events() -> void:
	var data: Variant = _load_json_file("events.json")
	if data is Array:
		_events = data
		for ev: Dictionary in _events:
			var eid: String = ev.get("id", "")
			if eid != "":
				_events_by_id[eid] = ev
		print("ContentDB: loaded %d events." % _events.size())
	else:
		push_warning("ContentDB: events.json should be an Array.")


func _load_synergies() -> void:
	var data: Variant = _load_json_file("synergies.json")
	if data is Array:
		_synergies = data
		print("ContentDB: loaded %d synergies." % _synergies.size())
	else:
		push_warning("ContentDB: synergies.json should be an Array.")


func _load_terrain() -> void:
	var data: Variant = _load_json_file("terrain.json")
	if data is Dictionary:
		var types: Variant = data.get("types", {})
		if types is Dictionary:
			_terrain_types = types
		print("ContentDB: loaded %d terrain types." % _terrain_types.size())
	else:
		push_warning("ContentDB: terrain.json should be a Dictionary with 'types' key.")


func _load_tutorial_steps() -> void:
	var data: Variant = _load_json_file("tutorial_steps.json")
	if data is Array:
		_tutorial_steps = data
		print("ContentDB: loaded %d tutorial steps." % _tutorial_steps.size())
	else:
		push_warning("ContentDB: tutorial_steps.json should be an Array.")


func _load_categories() -> void:
	var data: Variant = _load_json_file("categories.json")
	if data is Array:
		_categories = data
		print("ContentDB: loaded %d categories." % _categories.size())
	else:
		push_warning("ContentDB: categories.json should be an Array.")
