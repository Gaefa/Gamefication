extends Node
## Loads and caches all JSON content files.
## Read-only after _ready().  Every system queries ContentDB for definitions.

var buildings: Dictionary = {}
var resources: Dictionary = {}
var city_levels: Array = []
var terrain_types: Dictionary = {}
var events: Dictionary = {}
var synergies: Array = []
var categories: Array = []
var tutorial_steps: Array = []
var technologies: Dictionary = {}
var policies: Dictionary = {}
var start_profiles: Dictionary = {}
var seasons: Dictionary = {}
var season_order: Array = []
var endings: Dictionary = {}

const CONTENT_ROOT := "res://content/base/"


func _ready() -> void:
	buildings = _load_json(CONTENT_ROOT + "buildings.json")
	_normalize_building_defs()
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
	categories = _load_json_array(CONTENT_ROOT + "categories.json")

	var levels_raw: Variant = _load_json_raw(CONTENT_ROOT + "city_levels.json")
	if levels_raw is Array:
		city_levels = levels_raw
	else:
		push_warning("ContentDB: city_levels.json should be an Array")

	var tut_raw: Variant = _load_json_raw(CONTENT_ROOT + "tutorial_steps.json")
	if tut_raw is Array:
		tutorial_steps = tut_raw

	technologies = _load_keyed_array(CONTENT_ROOT + "technologies.json", "id")
	policies = _load_keyed_array(CONTENT_ROOT + "policies.json", "id")
	start_profiles = _load_keyed_array(CONTENT_ROOT + "start_profiles.json", "id")
	_load_seasons()
	_load_endings()
	_normalize_governance_defs()
	_normalize_start_profiles()


# --- Content normalization ---

const RESOURCE_ID_ALIASES := {
	"coins": "res_money",
	"money": "res_money",
	"food": "res_food",
	"wood": "res_wood",
	"stone": "res_stone",
	"tools": "res_tools",
	"water_res": "res_water_stockpile",
}


func _normalize_building_defs() -> void:
	for type_id: String in buildings:
		var def: Dictionary = buildings[type_id] as Dictionary
		if def.has("name") and not def.has("label"):
			def["label"] = def["name"]
		if def.has("cost_build") and not def.has("build_cost"):
			def["build_cost"] = _with_resource_aliases(def.get("cost_build", {}) as Dictionary)
		elif def.has("build_cost"):
			def["build_cost"] = _with_resource_aliases(def.get("build_cost", {}) as Dictionary)
		if def.has("outputs") and not def.has("produces"):
			def["produces"] = _with_resource_aliases(def.get("outputs", {}) as Dictionary)
		elif def.has("produces"):
			def["produces"] = _with_resource_aliases(def.get("produces", {}) as Dictionary)
		if def.has("consumes"):
			def["consumes"] = _with_resource_aliases(def.get("consumes", {}) as Dictionary)
		if not def.has("category"):
			def["category"] = _derive_building_category(type_id, def)
		if not def.has("unlock_level"):
			def["unlock_level"] = 1
		var tags: Array = def.get("tags", []) as Array
		if tags.has("needs_road") and not def.has("requires_road"):
			def["requires_road"] = true
		if not def.has("levels") or (def.get("levels", []) as Array).is_empty():
			def["levels"] = [_level_from_top_level_def(def)]
		else:
			var normalized_levels: Array = []
			for level_var: Variant in def.get("levels", []) as Array:
				if level_var is Dictionary:
					var level_data: Dictionary = (level_var as Dictionary).duplicate(true)
					if level_data.has("outputs") and not level_data.has("produces"):
						level_data["produces"] = level_data.get("outputs", {})
					if level_data.has("produces"):
						level_data["produces"] = _with_resource_aliases(level_data.get("produces", {}) as Dictionary)
					if level_data.has("consumes"):
						level_data["consumes"] = _with_resource_aliases(level_data.get("consumes", {}) as Dictionary)
					normalized_levels.append(level_data)
			def["levels"] = normalized_levels


func _normalize_start_profiles() -> void:
	for profile_id: String in start_profiles:
		var profile: Dictionary = start_profiles[profile_id] as Dictionary
		if profile.has("starting_resources"):
			profile["starting_resources"] = _with_resource_aliases(profile.get("starting_resources", {}) as Dictionary)
		var effects: Dictionary = profile.get("effects", {})
		if effects.has("production_mult"):
			effects["production_mult"] = _with_resource_aliases(effects.get("production_mult", {}) as Dictionary)


func _normalize_governance_defs() -> void:
	for technology_id: String in technologies:
		_normalize_effect_container(technologies[technology_id] as Dictionary, "cost")
	for policy_id: String in policies:
		_normalize_effect_container(policies[policy_id] as Dictionary, "switch_cost")


func _normalize_effect_container(def: Dictionary, cost_key: String) -> void:
	if def.has(cost_key):
		def[cost_key] = _with_resource_aliases(def.get(cost_key, {}) as Dictionary)
	var effects: Dictionary = def.get("effects", {})
	if effects.has("production_mult"):
		effects["production_mult"] = _with_resource_aliases(effects.get("production_mult", {}) as Dictionary)


func _level_from_top_level_def(def: Dictionary) -> Dictionary:
	var level_data: Dictionary = {}
	level_data["produces"] = _with_resource_aliases(def.get("produces", {}) as Dictionary)
	level_data["consumes"] = _with_resource_aliases(def.get("consumes", {}) as Dictionary)
	if def.has("storage"):
		var storage_value: Variant = def.get("storage", 0.0)
		if storage_value is Dictionary:
			# Keep per-resource storage as-is (canonical IDs)
			level_data["storage"] = _with_resource_aliases(storage_value as Dictionary)
		else:
			level_data["storage"] = storage_value
	if def.has("population"):
		level_data["population"] = def["population"]
	if def.has("synergy"):
		level_data["synergy"] = def["synergy"]
	if def.has("bonus"):
		level_data["bonus"] = def["bonus"]
	if def.has("cycle_time"):
		level_data["cycle_time"] = def["cycle_time"]
	if def.has("water_radius"):
		level_data["synergy"] = {"water_radius": def["water_radius"]}
	return level_data


func _derive_building_category(type_id: String, def: Dictionary) -> String:
	var tags: Array = def.get("tags", []) as Array
	if tags.has("housing"):
		return "Residential"
	if tags.has("production") or tags.has("food_source"):
		return "Production"
	if tags.has("commercial"):
		return "Commercial"
	if tags.has("culture"):
		return "Culture"
	if tags.has("road") or tags.has("water_source") or tags.has("water_storage") or tags.has("storage") or tags.has("admin") or type_id.begins_with("bld_"):
		return "Infrastructure"
	return "Advanced"


func _with_resource_aliases(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for res_id: String in raw:
		var canonical: String = RESOURCE_ID_ALIASES.get(res_id, res_id) as String
		var value: Variant = raw[res_id]
		if value is int or value is float:
			out[canonical] = (out.get(canonical, 0.0) as float) + (value as float)
		else:
			out[canonical] = value
	return out


# --- Public queries ---

func get_building_def(type_id: String) -> Dictionary:
	return buildings.get(type_id, {})


func get_resource_def(res_id: String) -> Dictionary:
	return resources.get(res_id, {})


func get_terrain_def(terrain_id: Variant) -> Dictionary:
	return terrain_types.get(str(terrain_id), {})


func get_event_def(event_id: String) -> Dictionary:
	return events.get(event_id, {})


func get_technology_def(technology_id: String) -> Dictionary:
	return technologies.get(technology_id, {})


func get_policy_def(policy_id: String) -> Dictionary:
	return policies.get(policy_id, {})


func get_start_profile_def(profile_id: String) -> Dictionary:
	return start_profiles.get(profile_id, {})


func get_season_def(season_id: String) -> Dictionary:
	return seasons.get(season_id, {})


func get_season_ids() -> Array:
	return seasons.keys()


func get_season_order() -> Array:
	return season_order.duplicate()


func get_ending_def(ending_id: String) -> Dictionary:
	return endings.get(ending_id, {})


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


func get_technology_ids() -> Array:
	return technologies.keys()


func get_policy_ids() -> Array:
	return policies.keys()


func get_start_profile_ids() -> Array:
	return start_profiles.keys()


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


func _load_seasons() -> void:
	var raw: Variant = _load_json_raw(CONTENT_ROOT + "seasons.json")
	var season_list: Array = []
	if raw is Dictionary:
		var d: Dictionary = raw as Dictionary
		season_list = d.get("seasons", []) as Array
		season_order = (d.get("order", []) as Array).duplicate()
	elif raw is Array:
		season_list = raw as Array
	for entry: Variant in season_list:
		if entry is Dictionary:
			var def: Dictionary = entry as Dictionary
			var sid: String = def.get("id", "") as String
			if sid != "":
				seasons[sid] = def
	# Fallback order: every loaded season, in file order.
	if season_order.is_empty():
		for entry: Variant in season_list:
			if entry is Dictionary:
				var sid: String = (entry as Dictionary).get("id", "") as String
				if sid != "":
					season_order.append(sid)
	# Drop any ordered ids that have no definition.
	var clean_order: Array = []
	for sid_var: Variant in season_order:
		if seasons.has(sid_var as String):
			clean_order.append(sid_var)
	season_order = clean_order


func _load_endings() -> void:
	var raw: Variant = _load_json_raw(CONTENT_ROOT + "endings.json")
	var ending_list: Array = []
	if raw is Dictionary:
		ending_list = (raw as Dictionary).get("endings", []) as Array
	elif raw is Array:
		ending_list = raw as Array
	for entry: Variant in ending_list:
		if entry is Dictionary:
			var eid: String = (entry as Dictionary).get("id", "") as String
			if eid != "":
				endings[eid] = entry


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


func _load_keyed_array(path: String, key_name: String) -> Dictionary:
	var out: Dictionary = {}
	var raw: Variant = _load_json_raw(path)
	if raw is Array:
		for entry: Variant in raw:
			if entry is Dictionary:
				var d: Dictionary = entry as Dictionary
				var id: String = d.get(key_name, "") as String
				if id != "":
					out[id] = d
	elif raw is Dictionary:
		out = raw as Dictionary
	else:
		push_warning("ContentDB: expected Array or Dictionary in %s" % path)
	return out


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
