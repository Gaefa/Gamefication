## game_state_store.gd -- Holds the root game-state Dictionary.
## Every sub-system reads / writes through the typed accessors.
class_name GameStateStoreClass
extends Node

# ---- Public state ----
var state: Dictionary = {}
var current_slot: int = -1
var is_playing: bool = false

# ------------------------------------------------------------------
# New game
# ------------------------------------------------------------------

func new_game(seed_value: int = 0) -> void:
	var actual_seed: int = seed_value if seed_value != 0 else randi()

	# -- Build starting resources and caps from ContentDB --
	var starting_resources: Dictionary = {}
	var resource_caps: Dictionary = {}
	var resources_array: Array = ContentDB.get_resources()
	for res: Dictionary in resources_array:
		var rid: String = res.get("id", "")
		if rid == "":
			continue
		starting_resources[rid] = float(res.get("starting", 0))
		resource_caps[rid] = float(res.get("default_cap", 300))

	state = {
		"world": {
			"grid_size": 64,
			"seed": actual_seed,
			"buildings": {},          # "x,y" -> { type_id, level, health, placed_tick, issues }
			"terrain": {},            # filled by terrain generator later
		},
		"economy": {
			"resources": starting_resources,
			"caps": resource_caps,
			"production_rates": {},   # computed each tick
			"consumption_rates": {},  # computed each tick
			"buffs": [],              # Array of buff dicts { id, name, remaining, production_mult, happiness_add }
		},
		"population": {
			"total": 0,
			"happiness": 60.0,
			"requests": [],           # Array of citizen request dicts
		},
		"progression": {
			"city_level": 1,
			"prestige_stars": 0,
			"total_prestiges": 0,
			"total_upgrades_done": 0,
			"total_buildings_placed": 0,
			"tutorial_step": 0,
		},
		"pressure": {
			"index": 0.0,
			"phase": 0,               # 0 = calm, 1 = tension, 2 = crisis
			"issue_count": 0,
			"decay_rate": 0.01,
		},
		"events": {
			"timer": 30.0,            # seconds until next event roll
			"active_event": null,     # current event dict or null
			"history": [],            # list of { id, tick, accepted }
		},
		"meta": {
			"created_at": Time.get_unix_time_from_system(),
			"last_saved_at": 0.0,
			"play_time": 0.0,
			"tick_count": 0,
			"version": "0.1.0",
		},
	}

	current_slot = -1
	is_playing = true
	EventBus.game_started.emit()


# ------------------------------------------------------------------
# Section accessors
# ------------------------------------------------------------------

func get_world() -> Dictionary:
	return state.get("world", {})


func get_economy() -> Dictionary:
	return state.get("economy", {})


func get_population() -> Dictionary:
	return state.get("population", {})


func get_progression() -> Dictionary:
	return state.get("progression", {})


func get_pressure() -> Dictionary:
	return state.get("pressure", {})


func get_events() -> Dictionary:
	return state.get("events", {})


func get_meta() -> Dictionary:
	return state.get("meta", {})


# ------------------------------------------------------------------
# Helpers -- resource manipulation (used across many systems)
# ------------------------------------------------------------------

func get_resource(resource_id: String) -> float:
	var economy: Dictionary = get_economy()
	var resources: Dictionary = economy.get("resources", {})
	return float(resources.get(resource_id, 0.0))


func set_resource(resource_id: String, amount: float) -> void:
	var economy: Dictionary = get_economy()
	var resources: Dictionary = economy.get("resources", {})
	var caps: Dictionary = economy.get("caps", {})
	var cap: float = float(caps.get(resource_id, 999999.0))
	resources[resource_id] = clampf(amount, 0.0, cap)
	EventBus.resource_changed.emit(resource_id)


func add_resource(resource_id: String, amount: float) -> void:
	set_resource(resource_id, get_resource(resource_id) + amount)


func can_afford(cost: Dictionary) -> bool:
	for rid: String in cost:
		if get_resource(rid) < float(cost[rid]):
			return false
	return true


func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for rid: String in cost:
		add_resource(rid, -float(cost[rid]))
	EventBus.resources_changed.emit()
	return true


func grant(rewards: Dictionary) -> void:
	for rid: String in rewards:
		add_resource(rid, float(rewards[rid]))
	EventBus.resources_changed.emit()


# ------------------------------------------------------------------
# Helpers -- buildings
# ------------------------------------------------------------------

func get_building_at(coord: Vector2i) -> Dictionary:
	var world: Dictionary = get_world()
	var buildings: Dictionary = world.get("buildings", {})
	var key: String = "%d,%d" % [coord.x, coord.y]
	return buildings.get(key, {})


func set_building_at(coord: Vector2i, data: Dictionary) -> void:
	var world: Dictionary = get_world()
	var buildings: Dictionary = world.get("buildings", {})
	var key: String = "%d,%d" % [coord.x, coord.y]
	buildings[key] = data
	EventBus.state_dirty.emit("world")


func remove_building_at(coord: Vector2i) -> void:
	var world: Dictionary = get_world()
	var buildings: Dictionary = world.get("buildings", {})
	var key: String = "%d,%d" % [coord.x, coord.y]
	buildings.erase(key)
	EventBus.state_dirty.emit("world")


# ------------------------------------------------------------------
# Prestige reset
# ------------------------------------------------------------------

func reset_for_prestige(stars_gained: int, new_seed: int) -> void:
	var progression: Dictionary = get_progression()
	var old_stars: int = int(progression.get("prestige_stars", 0))
	var old_prestiges: int = int(progression.get("total_prestiges", 0))

	# Compute prestige bonus: +10% starting resources per star, capped at +200%
	var bonus_multiplier: float = clampf(1.0 + (old_stars + stars_gained) * 0.10, 1.0, 3.0)

	# Build fresh starting resources with prestige bonus
	var starting_resources: Dictionary = {}
	var resource_caps: Dictionary = {}
	var resources_array: Array = ContentDB.get_resources()
	for res: Dictionary in resources_array:
		var rid: String = res.get("id", "")
		if rid == "":
			continue
		starting_resources[rid] = float(res.get("starting", 0)) * bonus_multiplier
		resource_caps[rid] = float(res.get("default_cap", 300))

	var actual_seed: int = new_seed if new_seed != 0 else randi()

	# Reset world and economy but keep progression meta
	state["world"] = {
		"grid_size": 64,
		"seed": actual_seed,
		"buildings": {},
		"terrain": {},
	}
	state["economy"] = {
		"resources": starting_resources,
		"caps": resource_caps,
		"production_rates": {},
		"consumption_rates": {},
		"buffs": [],
	}
	state["population"] = {
		"total": 0,
		"happiness": 60.0,
		"requests": [],
	}
	state["progression"] = {
		"city_level": 1,
		"prestige_stars": old_stars + stars_gained,
		"total_prestiges": old_prestiges + 1,
		"total_upgrades_done": 0,
		"total_buildings_placed": 0,
		"tutorial_step": 0,
	}
	state["pressure"] = {
		"index": 0.0,
		"phase": 0,
		"issue_count": 0,
		"decay_rate": 0.01,
	}
	state["events"] = {
		"timer": 30.0,
		"active_event": null,
		"history": [],
	}
	state["meta"]["last_saved_at"] = 0.0
	state["meta"]["play_time"] = 0.0
	state["meta"]["tick_count"] = 0

	EventBus.prestige_completed.emit(stars_gained)
	EventBus.game_started.emit()
