extends Node
## Single source of truth for the entire game state.
## All mutations go through typed accessors to keep consistency.

var _state: Dictionary = {}
var _tick: int = 0


func _ready() -> void:
	reset()


# --- State reset (new game) ---

func reset(start_profile_id: String = "appointed_administrator") -> void:
	_tick = 0
	_state = {
		"world": {
			"map_radius": 30,
			"terrain": {},       # Vector2i key → int terrain_id
			"buildings": {},     # Vector2i key → building dict
		},
		"economy": {
			"resources": {},     # res_id → float
			"caps": {},          # res_id → float
			"production": {},    # res_id → float (last tick net)
			"buffs": [],         # Array[{id, resource, multiplier, remaining}]
		},
		"population": {
			"total": 0,
			"happiness": 50.0,
			"growth_rate": 0.0,
		},
		"progression": {
			"city_level": 1,
			"prestige_stars": 0,
			"prestige_count": 0,
			"history": [],       # Array[{tick, event}] for stats
		},
		"governance": {
			"technologies": [],       # Array[tech_id]
			"active_policies": {},    # category -> policy_id
			"policy_cooldowns": {},   # policy_id -> ticks_remaining
		},
		"mandate": _default_mandate(),
		"climate": _default_climate(),
		"diary": { "discovered": [] },
		"onboarding": { "shown": [] },
		"pressure": {
			"index": 0.0,
			"phase": "calm",
			"active_policy": "",
		},
		"events": {
			"active": [],        # Array[{id, timer, ...}]
			"cooldowns": {},     # event_id → ticks_remaining
		},
		"meta": {
			"playtime_sec": 0.0,
			"difficulty": "normal",
			"rng_seed": 0,
			"schema_version": 1,
		},
	}
	_init_resources()
	apply_start_profile(start_profile_id)


func _init_resources() -> void:
	for res_id: String in ContentDB.get_resource_ids():
		var def: Dictionary = ContentDB.get_resource_def(res_id)
		_state.economy.resources[res_id] = def.get("starting", 0.0) as float
		_state.economy.caps[res_id] = def.get("default_cap", 9999.0) as float
		_state.economy.production[res_id] = 0.0


# --- Tick ---

func advance_tick() -> void:
	_tick += 1

func get_tick() -> int:
	return _tick


# --- Section accessors ---

func world() -> Dictionary:
	return _state.world

func economy() -> Dictionary:
	return _state.economy

func population() -> Dictionary:
	return _state.population

func progression() -> Dictionary:
	return _state.progression

func pressure() -> Dictionary:
	return _state.pressure

func governance() -> Dictionary:
	if not _state.has("governance"):
		_state["governance"] = _default_governance()
	return _state.governance

func mandate() -> Dictionary:
	if not _state.has("mandate"):
		_state["mandate"] = _default_mandate()
	return _state.mandate

func climate() -> Dictionary:
	if not _state.has("climate"):
		_state["climate"] = _default_climate()
	return _state.climate

func diary() -> Dictionary:
	if not _state.has("diary"):
		_state["diary"] = { "discovered": [] }
	return _state.diary

func onboarding() -> Dictionary:
	if not _state.has("onboarding"):
		_state["onboarding"] = { "shown": [] }
	return _state.onboarding

func events() -> Dictionary:
	return _state.events

func save_meta() -> Dictionary:
	return _state.meta


# --- Resource ID normalization ---
# Bidirectional aliasing: legacy ↔ canonical.
# All resource methods resolve through _canonical() so both old systems
# (EconomySystem using "coins") and new content (using "res_money") hit
# the same slot in the dictionary.

const _RES_ALIASES: Dictionary = {
	"coins": "res_money",
	"money": "res_money",
	"food": "res_food",
	"wood": "res_wood",
	"stone": "res_stone",
	"tools": "res_tools",
	"water_res": "res_water_stockpile",
	"water_stock": "res_water_stockpile",
}

func _canonical(res_id: String) -> String:
	return _RES_ALIASES.get(res_id, res_id)


# --- Resource helpers ---

func get_resource(res_id: String) -> float:
	return _state.economy.resources.get(_canonical(res_id), 0.0) as float

func set_resource(res_id: String, value: float) -> void:
	var cid: String = _canonical(res_id)
	var cap: float = _state.economy.caps.get(cid, 9999.0) as float
	_state.economy.resources[cid] = clampf(value, 0.0, cap)

func add_resource(res_id: String, amount: float) -> void:
	set_resource(res_id, get_resource(res_id) + amount)

func get_cap(res_id: String) -> float:
	return _state.economy.caps.get(_canonical(res_id), 9999.0) as float

func set_cap(res_id: String, value: float) -> void:
	_state.economy.caps[_canonical(res_id)] = value

func can_afford(costs: Dictionary) -> bool:
	for res_id: String in costs:
		if get_resource(res_id) < (costs[res_id] as float):
			return false
	return true

func spend(costs: Dictionary) -> bool:
	if not can_afford(costs):
		return false
	for res_id: String in costs:
		add_resource(res_id, -(costs[res_id] as float))
	return true


# --- Building helpers ---

func get_building(coord: Vector2i) -> Dictionary:
	return _state.world.buildings.get(coord, {})

func set_building(coord: Vector2i, bld: Dictionary) -> void:
	_state.world.buildings[coord] = bld

func remove_building(coord: Vector2i) -> void:
	_state.world.buildings.erase(coord)

func has_building(coord: Vector2i) -> bool:
	return _state.world.buildings.has(coord)

func get_all_building_coords() -> Array:
	return _state.world.buildings.keys()

func get_buildings() -> Dictionary:
	return _state.world.buildings


# --- Terrain helpers ---

func get_terrain(coord: Vector2i) -> int:
	return _state.world.terrain.get(coord, 0) as int

func set_terrain(coord: Vector2i, terrain_id: int) -> void:
	_state.world.terrain[coord] = terrain_id


# --- Buff helpers ---

func add_buff(buff: Dictionary) -> void:
	_state.economy.buffs.append(buff)

func get_buffs() -> Array:
	return _state.economy.buffs

func clear_expired_buffs() -> void:
	var keep: Array = []
	for b: Dictionary in _state.economy.buffs:
		if (b.get("remaining", 0.0) as float) > 0.0:
			keep.append(b)
	_state.economy.buffs = keep


# --- Governance helpers ---

func has_technology(technology_id: String) -> bool:
	return (governance().technologies as Array).has(technology_id)

func add_technology(technology_id: String) -> void:
	if not has_technology(technology_id):
		(governance().technologies as Array).append(technology_id)

func get_technologies() -> Array:
	return governance().technologies as Array

func set_active_policy(category: String, policy_id: String) -> void:
	governance().active_policies[category] = policy_id
	# Keep legacy pressure key populated until older UI/save paths are removed.
	pressure().active_policy = policy_id

func get_active_policy(category: String) -> String:
	return governance().active_policies.get(category, "") as String

func get_active_policies() -> Dictionary:
	return governance().active_policies


# --- Start profile / mandate helpers ---

func apply_start_profile(profile_id: String) -> void:
	var profile: Dictionary = ContentDB.get_start_profile_def(profile_id)
	if profile.is_empty():
		profile_id = "appointed_administrator"
		profile = ContentDB.get_start_profile_def(profile_id)
	if profile.is_empty():
		return

	save_meta().start_profile_id = profile_id
	var mandate_state: Dictionary = mandate()
	mandate_state.start_profile_id = profile_id
	mandate_state.start_path = profile.get("start_path", "appointed") as String
	mandate_state.founder_archetype = profile.get("founder_archetype", "") as String
	mandate_state.patron_id = profile.get("patron_id", "") as String
	mandate_state.effects = (profile.get("effects", {}) as Dictionary).duplicate(true)

	var profile_mandate: Dictionary = profile.get("mandate", {})
	for key: String in profile_mandate:
		mandate_state[key] = profile_mandate[key]

	var resources: Dictionary = profile.get("starting_resources", {})
	for res_id: String in resources:
		set_resource(res_id, resources[res_id] as float)

	var policies: Array = profile.get("default_policies", [])
	for policy_var: Variant in policies:
		var policy_id: String = policy_var as String
		var policy_def: Dictionary = ContentDB.get_policy_def(policy_id)
		if policy_def.is_empty():
			continue
		set_active_policy(policy_def.get("category", "general") as String, policy_id)


func get_start_profile_id() -> String:
	return mandate().get("start_profile_id", "appointed_administrator") as String


# --- Serialization ---

func to_save_dict() -> Dictionary:
	var save_data := _state.duplicate(true)
	save_data["tick"] = _tick
	# Convert Vector2i keys to strings for JSON
	save_data.world.terrain = _dict_v2i_to_str(_state.world.terrain)
	save_data.world.buildings = _dict_v2i_to_str(_state.world.buildings)
	return save_data

func load_from_dict(data: Dictionary) -> void:
	_tick = data.get("tick", 0) as int
	_state = data.duplicate(true)
	_state.erase("tick")
	_ensure_runtime_defaults()
	# Restore Vector2i keys
	_state.world.terrain = _dict_str_to_v2i(_state.world.terrain)
	_state.world.buildings = _dict_str_to_v2i(_state.world.buildings)


func _ensure_runtime_defaults() -> void:
	if not _state.has("governance"):
		_state["governance"] = _default_governance()
	else:
		var gov: Dictionary = _state.governance
		if not gov.has("technologies"):
			gov["technologies"] = []
		if not gov.has("active_policies"):
			gov["active_policies"] = {}
		if not gov.has("policy_cooldowns"):
			gov["policy_cooldowns"] = {}
	if not _state.has("mandate"):
		_state["mandate"] = _default_mandate()
	else:
		var mandate_state: Dictionary = _state.mandate
		var defaults: Dictionary = _default_mandate()
		for key: String in defaults:
			if not mandate_state.has(key):
				mandate_state[key] = defaults[key]
	if not _state.has("pressure"):
		_state["pressure"] = {"index": 0.0, "phase": "calm", "active_policy": ""}
	elif not (_state.pressure as Dictionary).has("active_policy"):
		_state.pressure["active_policy"] = ""
	if not _state.has("climate"):
		_state["climate"] = _default_climate()
	else:
		var climate_state: Dictionary = _state.climate
		var climate_defaults: Dictionary = _default_climate()
		for key: String in climate_defaults:
			if not climate_state.has(key):
				climate_state[key] = climate_defaults[key]
	if not _state.has("diary"):
		_state["diary"] = { "discovered": [] }
	elif not (_state.diary as Dictionary).has("discovered"):
		_state.diary["discovered"] = []
	if not _state.has("onboarding"):
		_state["onboarding"] = { "shown": [] }
	elif not (_state.onboarding as Dictionary).has("shown"):
		_state.onboarding["shown"] = []


func _default_governance() -> Dictionary:
	return {
		"technologies": [],
		"active_policies": {},
		"policy_cooldowns": {},
	}


func _default_climate() -> Dictionary:
	return {
		"season_id": "",        # filled by SeasonSystem.initialize()
		"season_index": 0,      # index into ContentDB.season_order
		"day_in_season": 1,     # 1-based day within the current season
		"total_day": 1,         # 1-based game day since the mandate began
		"modifiers": {},        # active season modifiers (water_mult, crop_mult, ...)
	}


func _default_mandate() -> Dictionary:
	return {
		"start_profile_id": "appointed_administrator",
		"start_path": "appointed",
		"founder_archetype": "",
		"patron_id": "restoration_league",
		"patron_trust": 50,
		"legitimacy": 50,
		"autonomy": 30,
		"recall_risk": 0,
		"support": 50,
		"effects": {},
	}


func _dict_v2i_to_str(src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in src:
		if key is Vector2i:
			out["%d,%d" % [key.x, key.y]] = src[key]
		else:
			out[key] = src[key]
	return out

func _dict_str_to_v2i(src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in src:
		if key is String and "," in (key as String):
			var parts: PackedStringArray = (key as String).split(",")
			if parts.size() == 2:
				out[Vector2i(parts[0].to_int(), parts[1].to_int())] = src[key]
				continue
		out[key] = src[key]
	return out
