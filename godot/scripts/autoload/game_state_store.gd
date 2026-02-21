extends Node
## Single source of truth for the entire game state.
## All mutations go through typed accessors to keep consistency.

var _state: Dictionary = {}
var _tick: int = 0


func _ready() -> void:
	reset()


# --- State reset (new game) ---

func reset() -> void:
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

func events() -> Dictionary:
	return _state.events

func save_meta() -> Dictionary:
	return _state.meta


# --- Resource helpers ---

func get_resource(res_id: String) -> float:
	return _state.economy.resources.get(res_id, 0.0) as float

func set_resource(res_id: String, value: float) -> void:
	var cap: float = _state.economy.caps.get(res_id, 9999.0) as float
	_state.economy.resources[res_id] = clampf(value, 0.0, cap)

func add_resource(res_id: String, amount: float) -> void:
	set_resource(res_id, get_resource(res_id) + amount)

func get_cap(res_id: String) -> float:
	return _state.economy.caps.get(res_id, 9999.0) as float

func set_cap(res_id: String, value: float) -> void:
	_state.economy.caps[res_id] = value

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
	# Restore Vector2i keys
	_state.world.terrain = _dict_str_to_v2i(_state.world.terrain)
	_state.world.buildings = _dict_str_to_v2i(_state.world.buildings)


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
