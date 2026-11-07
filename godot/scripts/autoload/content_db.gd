extends Node
## Loads and caches all JSON content files.
## Read-only after _ready().  Every system queries ContentDB for definitions.

var buildings: Dictionary = {}
var resources: Dictionary = {}
var city_levels: Array = []
var terrain_types: Dictionary = {}
var events: Dictionary = {}
var synergies: Array = []
var technologies: Dictionary = {}
var policies: Dictionary = {}
var start_profiles: Dictionary = {}
var start_legacies: Dictionary = {}  # what the previous administrator left: a choice at new game
var chapters: Dictionary = {}  # chapter id → chapter.json (the campaign's table of contents)
var active_chapter: String = "rust_pit"
var _cmdline_chapter: String = ""  # a tool asked for this chapter on the command line
var seasons: Dictionary = {}
var season_order: Array = []
var scenario: Dictionary = {}
var endings: Dictionary = {}
var diary_fragments: Array = []   # ordered fragment defs

const CONTENT_ROOT := "res://content/base/"
const CHAPTERS_ROOT := "res://content/chapters/"

## The vocabulary a card may use. _validate_content rejects anything else, so a typo in a
## trigger, season, patron, style or flag fails content_check instead of silently never firing.
const PATRON_IDS := ["restoration_league", "civic_directorate", "engineers_union"]
const STYLE_IDS := ["loyal", "pragmatist", "protector", "autonomist"]
const TRIGGER_STATS := ["stat_unrest_pressure", "stat_city_trust", "stat_league_trust", "stat_happiness",
	"stat_population", "stat_low_pressure_housing", "stat_rival_score", "stat_rival_gap", "stat_water_days", "stat_day",
	"stat_contested_fields", "stat_waste"]


func _ready() -> void:
	_load_chapter_index()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("chapter=") and chapters.has(arg.trim_prefix("chapter=")):
			_cmdline_chapter = arg.trim_prefix("chapter=")
			active_chapter = _cmdline_chapter
	_load_all()


## The chapter a run starts in when nobody names one: the command line's, else the first.
func default_chapter() -> String:
	if _cmdline_chapter != "":
		return _cmdline_chapter
	var ids: Array = get_chapter_ids(true)
	return ids[0] as String if not ids.is_empty() else active_chapter


## Every chapter folder with a chapter.json: the campaign's table of contents.
func _load_chapter_index() -> void:
	chapters = {}
	var dir := DirAccess.open(CHAPTERS_ROOT)
	if dir == null:
		push_warning("ContentDB: no chapters folder at %s" % CHAPTERS_ROOT)
		return
	for sub: String in dir.get_directories():
		var def: Variant = _load_json_raw(CHAPTERS_ROOT + sub + "/chapter.json")
		if def is Dictionary and ((def as Dictionary).get("id", "") as String) != "":
			chapters[(def as Dictionary)["id"] as String] = def


## Switch the active chapter: the base content is reloaded with that chapter's overlay.
## Call before GameStateStore.reset() / load_from_dict(), never mid-run.
func set_chapter(chapter_id: String) -> void:
	if chapter_id == "" or chapter_id == active_chapter or not chapters.has(chapter_id):
		return
	active_chapter = chapter_id
	_load_all()


func _chapter_file(file_name: String) -> String:
	return CHAPTERS_ROOT + active_chapter + "/" + file_name


## Base content first, then the active chapter's files: keyed files merge by id (the chapter
## wins), whole-set files (seasons, diary, legacies, scenario) replace the base when present.
func _load_all() -> void:
	content_warnings = []
	buildings = _load_json(CONTENT_ROOT + "buildings.json")
	_merge_keyed(buildings, _chapter_file("buildings.json"), "")
	_normalize_building_defs()
	# resources.json is an Array — convert to Dictionary keyed by "id"
	resources = {}
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
	_merge_keyed(resources, _chapter_file("resources.json"), "id")  # a chapter's own resource (metal)
	var terrain_raw: Dictionary = _load_json(CONTENT_ROOT + "terrain.json")
	terrain_types = (terrain_raw.get("types", terrain_raw) as Dictionary).duplicate(true)
	_merge_keyed(terrain_types, _chapter_file("terrain.json"), "")  # a chapter's palette: types by id
	events = {}
	_merge_keyed(events, CONTENT_ROOT + "events.json", "id")
	_merge_keyed(events, _chapter_file("events.json"), "id")
	synergies = _load_json_array(CONTENT_ROOT + "synergies.json")

	var levels_raw: Variant = _load_json_raw(CONTENT_ROOT + "city_levels.json")
	if levels_raw is Array:
		city_levels = levels_raw
	else:
		push_warning("ContentDB: city_levels.json should be an Array")

	technologies = _load_keyed_array(CONTENT_ROOT + "technologies.json", "id")
	policies = _load_keyed_array(CONTENT_ROOT + "policies.json", "id")
	start_profiles = _load_keyed_array(CONTENT_ROOT + "start_profiles.json", "id")
	var legacies_path: String = _first_existing(["start_legacies.json"])
	start_legacies = _load_keyed_array(legacies_path, "id") if legacies_path != "" else {}
	var chapter_def: Dictionary = get_chapter_def()
	var scenario_path: String = _first_existing(["scenario.json"])
	if chapter_def.has("scenario"):
		scenario = (chapter_def.get("scenario", {}) as Dictionary).duplicate(true)
	else:
		scenario = _load_json(scenario_path) if scenario_path != "" else {}
	seasons = {}
	season_order = []
	_load_seasons(_first_existing(["seasons.json"]))
	endings = {}
	_load_endings(CONTENT_ROOT + "endings.json")
	_load_endings(_chapter_file("endings.json"))
	_load_diary(_first_existing(["diary.json"]))
	_normalize_governance_defs()
	_validate_content()
	_normalize_start_profiles()


## The chapter's copy of a whole-set file when it has one, else the base copy, else "".
func _first_existing(names: Array) -> String:
	for name: String in names:
		if FileAccess.file_exists(_chapter_file(name)):
			return _chapter_file(name)
	for name: String in names:
		if FileAccess.file_exists(CONTENT_ROOT + name):
			return CONTENT_ROOT + name
	return ""


## Merge a keyed JSON file into `target`; an Array is keyed by `key_name`, a Dictionary by
## its own keys. Missing files are simply skipped: most chapters override only a few sets.
func _merge_keyed(target: Dictionary, path: String, key_name: String) -> void:
	if path == "" or not FileAccess.file_exists(path):
		return
	var raw: Variant = _load_json_raw(path)
	if raw is Array:
		for entry: Variant in raw:
			if entry is Dictionary and ((entry as Dictionary).get(key_name, "") as String) != "":
				target[(entry as Dictionary)[key_name] as String] = entry
	elif raw is Dictionary:
		for key: String in raw as Dictionary:
			target[key] = (raw as Dictionary)[key]


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
			if def.has("name_en"):
				def["label_en"] = def["name_en"]
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
		_scale_flows_per_cycle(def)


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


## Content lists what a building makes and eats per production cycle (cycle_time ticks);
## the simulation applies flows every tick, so they are divided once here.
func _scale_flows_per_cycle(def: Dictionary) -> void:
	var cycle: float = def.get("cycle_time", 0.0) as float
	if cycle <= 1.0:
		return
	var flow_sets: Array = [def]
	flow_sets.append_array(def.get("levels", []) as Array)
	for holder_var: Variant in flow_sets:
		var holder: Dictionary = holder_var as Dictionary
		for key: String in ["produces", "consumes"]:
			var flows: Dictionary = holder.get(key, {}) as Dictionary
			for res_id: String in flows:
				flows[res_id] = (flows[res_id] as float) / cycle


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


## Ruins and monuments: fixed scenery with no function. They never break down and cost no
## upkeep. A restored tower is a working water source, so it does not count.
func is_inert_landmark(type_id: String) -> bool:
	var tags: Array = get_building_def(type_id).get("tags", []) as Array
	return tags.has("landmark") and not tags.has("water_source")


## Content mistakes that used to fail silently: a price in a resource that does not exist
## (so the item can never be bought), a synergy or an event pointing at a missing building,
## a desk card with no free answer. Collected here and warned about at load; the dev tool
## tools/content_check.tscn fails on any of them.
var content_warnings: Array[String] = []


func _validate_content() -> void:
	content_warnings.clear()
	for tech_id: String in technologies:
		var tech: Dictionary = technologies[tech_id] as Dictionary
		_check_resources(tech.get("cost", {}), "technology %s cost" % tech_id)
		_check_resources((tech.get("effects", {}) as Dictionary).get("production_mult", {}), "technology %s effects" % tech_id)
		for req: Variant in tech.get("requires", []) as Array:
			if not technologies.has(req as String):
				content_warnings.append("technology %s requires unknown technology %s" % [tech_id, req])
	for policy_id: String in policies:
		var policy: Dictionary = policies[policy_id] as Dictionary
		_check_resources(policy.get("switch_cost", {}), "policy %s cost" % policy_id)
		_check_resources((policy.get("effects", {}) as Dictionary).get("production_mult", {}), "policy %s effects" % policy_id)
	for type_id: String in buildings:
		var def: Dictionary = buildings[type_id] as Dictionary
		_check_resources(def.get("build_cost", {}), "building %s cost" % type_id)
		for level: Variant in def.get("levels", []) as Array:
			var ldata: Dictionary = level as Dictionary
			for key: String in ["cost", "produces", "consumes"]:
				_check_resources(ldata.get(key, {}), "building %s %s" % [type_id, key])
		if _has_flows(def) and (def.get("cycle_time", 0.0) as float) < 1.0:
			content_warnings.append("building %s has flows but no cycle_time: they would run per tick, not per cycle" % type_id)
	for syn: Dictionary in synergies:
		_check_resources(syn.get("effects_a", {}), "synergy %s effects" % syn.get("id", "?"))
		_check_resources(syn.get("effects_b", {}), "synergy %s effects" % syn.get("id", "?"))
		for other: Variant in syn.get("pair", []) as Array:
			if not buildings.has(other as String):
				content_warnings.append("synergy %s names unknown building %s" % [syn.get("id", "?"), other])
	for legacy_id: String in start_legacies:
		var legacy: Dictionary = start_legacies[legacy_id] as Dictionary
		_check_resources(legacy.get("resources", {}), "legacy %s resources" % legacy_id)
		for entry: Variant in legacy.get("buildings", []) as Array:
			if not buildings.has((entry as Dictionary).get("type", "") as String):
				content_warnings.append("legacy %s places unknown building %s" % [legacy_id, (entry as Dictionary).get("type", "")])
		for type_id: Variant in legacy.get("damaged", []) as Array:
			if not buildings.has(type_id as String):
				content_warnings.append("legacy %s damages unknown building %s" % [legacy_id, type_id])
	var set_flags: Array = _flags_set_by_cards()
	for event_id: String in events:
		var card: Dictionary = events[event_id] as Dictionary
		_check_card_gates(card, event_id, set_flags)
		var options: Array = card.get("options", []) as Array
		var has_free: bool = options.is_empty()
		for option: Variant in options:
			var opt: Dictionary = option as Dictionary
			var cost: Dictionary = opt.get("cost", {})
			if cost.is_empty():
				has_free = true
			_check_resources(cost, "event %s cost" % event_id)
			var effects: Dictionary = opt.get("effects", {})
			_check_resources(effects.get("add_resources", {}), "event %s add_resources" % event_id)
			_check_resources(effects.get("remove_resources", {}), "event %s remove_resources" % event_id)
			var targets: Array = [effects.get("demolish_building", ""), effects.get("damage_building", "")]
			var swap: Dictionary = effects.get("replace_building", {})
			targets.append(swap.get("from", ""))
			targets.append(swap.get("to", ""))
			targets.append((effects.get("add_buff", {}) as Dictionary).get("target", ""))
			var set_policy: String = effects.get("set_policy", "") as String
			if set_policy != "" and get_policy_def(set_policy).is_empty():
				content_warnings.append("event %s sets unknown policy %s" % [event_id, set_policy])
			if effects.has("lock_policy_days") and set_policy == "":
				content_warnings.append("event %s locks a policy without set_policy" % event_id)
			if effects.has("style") and not STYLE_IDS.has(effects.get("style", "") as String):
				content_warnings.append("event %s names unknown style %s" % [event_id, effects.get("style", "")])
			var buff: Dictionary = effects.get("add_buff", {}) as Dictionary
			if not buff.is_empty():
				_check_buff(buff, event_id)
			for follow_up: String in [effects.get("raise_event", "") as String, (effects.get("add_buff", {}) as Dictionary).get("on_expire_event", "") as String]:
				if follow_up != "" and not events.has(follow_up):
					content_warnings.append("event %s raises unknown event %s" % [event_id, follow_up])
			for target: Variant in targets:
				if (target as String) != "" and not buildings.has(target as String):
					content_warnings.append("event %s names unknown building %s" % [event_id, target])
		if not has_free:
			content_warnings.append("event %s has no free answer: a broke player would be stuck at the Desk" % event_id)
	for profile_id: String in start_profiles:
		var profile: Dictionary = start_profiles[profile_id] as Dictionary
		_check_resources(profile.get("starting_resources", {}), "start profile %s resources" % profile_id)
		for policy: Variant in profile.get("default_policies", []) as Array:
			if not policies.has(policy as String):
				content_warnings.append("start profile %s names unknown policy %s" % [profile_id, policy])
	for sid: Variant in get_season_order():
		if not seasons.has(sid as String):
			content_warnings.append("scenario season_order names unknown season %s" % sid)
	for warning: String in content_warnings:
		push_warning("ContentDB: " + warning)


func _check_resources(raw: Variant, where: String) -> void:
	if raw is not Dictionary:
		return
	for res_id: String in raw as Dictionary:
		if not resources.has(RESOURCE_ID_ALIASES.get(res_id, res_id) as String):
			content_warnings.append("%s uses unknown resource %s" % [where, res_id])


func _has_flows(def: Dictionary) -> bool:
	var holders: Array = [def]
	holders.append_array(def.get("levels", []) as Array)
	for holder: Variant in holders:
		for key: String in ["produces", "consumes"]:
			if not ((holder as Dictionary).get(key, {}) as Dictionary).is_empty():
				return true
	return false


func _flags_set_by_cards() -> Array:
	var flags: Array = []
	for legacy_id: String in start_legacies:
		flags.append_array((start_legacies[legacy_id] as Dictionary).get("flags", []) as Array)
	for event_id: String in events:
		for option: Variant in (events[event_id] as Dictionary).get("options", []) as Array:
			var effects: Dictionary = (option as Dictionary).get("effects", {}) as Dictionary
			for flag: Variant in [effects.get("set_flag", ""), (effects.get("add_buff", {}) as Dictionary).get("on_expire_flag", "")]:
				if (flag as String) != "":
					flags.append(flag as String)
	return flags


func _check_card_gates(card: Dictionary, event_id: String, set_flags: Array) -> void:
	if card.has("season") and not seasons.has(card.get("season", "") as String):
		content_warnings.append("event %s names unknown season %s" % [event_id, card.get("season", "")])
	if card.has("patron") and not PATRON_IDS.has(card.get("patron", "") as String):
		content_warnings.append("event %s names unknown patron %s" % [event_id, card.get("patron", "")])
	if card.has("requires_style") and not STYLE_IDS.has(card.get("requires_style", "") as String):
		content_warnings.append("event %s requires unknown style %s" % [event_id, card.get("requires_style", "")])
	for key: String in ["requires_flag", "excludes_flag"]:
		if card.has(key) and not set_flags.has(card.get(key, "") as String):
			content_warnings.append("event %s %s %s, which no card sets" % [event_id, key, card.get(key, "")])
	var trigger: String = card.get("trigger_condition", "") as String
	if trigger == "":
		return
	# EventManager._evaluate_trigger reads exactly this shape; anything else never fires.
	var shape := RegEx.create_from_string("^(res_[a-z_]+|stat_[a-z_]+)\\s*(>=|<=|==|>|<)\\s*-?[0-9]+(\\.[0-9]+)?$")
	var found: RegExMatch = shape.search(trigger)
	if found == null:
		content_warnings.append("event %s trigger '%s' is not '<stat> <op> <number>'" % [event_id, trigger])
		return
	var stat: String = found.get_string(1)
	if stat.begins_with("res_"):
		if not resources.has(RESOURCE_ID_ALIASES.get(stat, stat) as String):
			content_warnings.append("event %s trigger uses unknown resource %s" % [event_id, stat])
	elif not TRIGGER_STATS.has(stat):
		content_warnings.append("event %s trigger uses unknown stat %s" % [event_id, stat])


func _check_buff(buff: Dictionary, event_id: String) -> void:
	if (buff.get("id", "") as String) == "":
		content_warnings.append("event %s adds a buff without id" % event_id)
	var until: String = buff.get("until_season_end", "") as String
	if until != "" and not seasons.has(until):
		content_warnings.append("event %s buff lasts until unknown season %s" % [event_id, until])
	if until == "" and (buff.get("remaining", 0.0) as float) <= 0.0:
		content_warnings.append("event %s buff %s has no remaining: it would expire on its first tick" % [event_id, buff.get("id", "?")])


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


func get_season_order() -> Array:
	return (scenario.get("season_order", season_order) as Array).duplicate()


func get_win_day() -> int:
	return scenario.get("win_day", 30) as int


func get_audit_days() -> Array:
	return (scenario.get("audit_days", [20]) as Array).duplicate()


func get_grant_day() -> int:
	return scenario.get("grant_day", 14) as int


func get_ending_def(ending_id: String) -> Dictionary:
	return endings.get(ending_id, {})


func get_diary_fragments() -> Array:
	return diary_fragments


func get_diary_fragment_def(fragment_id: String) -> Dictionary:
	for frag: Variant in diary_fragments:
		if (frag as Dictionary).get("id", "") as String == fragment_id:
			return frag as Dictionary
	return {}


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


## Chapters in campaign order; hidden ones (stubs) only when asked for.
func get_chapter_ids(include_hidden: bool = false) -> Array:
	var ids: Array = []
	for chapter_id: String in chapters:
		if include_hidden or not ((chapters[chapter_id] as Dictionary).get("hidden", false) as bool):
			ids.append(chapter_id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		return ((chapters[a] as Dictionary).get("order", 99) as int) < ((chapters[b] as Dictionary).get("order", 99) as int))
	return ids


func get_chapter_def(chapter_id: String = "") -> Dictionary:
	return chapters.get(active_chapter if chapter_id == "" else chapter_id, {})


## The chapter that follows `chapter_id` in order, hidden stubs included; "" after the last.
func next_chapter_id(chapter_id: String = "") -> String:
	var ids: Array = get_chapter_ids(true)
	var index: int = ids.find(active_chapter if chapter_id == "" else chapter_id)
	return ids[index + 1] as String if index >= 0 and index + 1 < ids.size() else ""


func get_start_legacy_ids() -> Array:
	return start_legacies.keys()


func get_start_legacy_def(legacy_id: String) -> Dictionary:
	return start_legacies.get(legacy_id, {})


func building_level_data(type_id: String, level: int) -> Dictionary:
	var def := get_building_def(type_id)
	var levels: Array = def.get("levels", [])
	if level >= 0 and level < levels.size():
		return levels[level]
	return {}


func max_building_level(type_id: String) -> int:
	var def := get_building_def(type_id)
	return def.get("levels", []).size()


func _load_seasons(path: String) -> void:
	if path == "" or not FileAccess.file_exists(path):
		return
	var raw: Variant = _load_json_raw(path)
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


func _load_diary(path: String) -> void:
	if path == "" or not FileAccess.file_exists(path):
		return
	var raw: Variant = _load_json_raw(path)
	var frags: Array = []
	if raw is Dictionary:
		frags = (raw as Dictionary).get("fragments", []) as Array
	elif raw is Array:
		frags = raw as Array
	var clean: Array = []
	for entry: Variant in frags:
		if entry is Dictionary and ((entry as Dictionary).get("id", "") as String) != "":
			clean.append(entry)
	clean.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a.get("order", 0) as int) < (b.get("order", 0) as int))
	diary_fragments = clean


func _load_endings(path: String) -> void:
	if path == "" or not FileAccess.file_exists(path):
		return
	var raw: Variant = _load_json_raw(path)
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
