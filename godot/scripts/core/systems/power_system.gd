class_name PowerSystem
## Lean electricity model (GDD §6.2). Generation vs demand across three priority
## networks, no storage (batteries are post-MVP). Deficit is the norm — the player
## chooses who gets light in the peak. Solar generation is scaled by the season's
## solar_mult, so Пыль (×0.5) creates the "свет или вода" squeeze: the panels weaken,
## and the priority network (water pumps) starts eating everyone else's power.
##
## Effect is applied by tagging each building with a runtime `powered` flag, which
## EconomySystem (production) and ProgressionSystem (happiness) read — no cross-system
## references, no duplicated tier logic.
##
## Config gate: flip ENABLED to false to ship without electricity (GDD: MVP but
## optional). When off, everything is treated as powered.

const ENABLED := true

const UNPOWERED_PRODUCTION := 0.3   # a producer with no power limps at 30%
const UNPOWERED_HOUSING_HAPPINESS := -8.0  # cold, dark housing drags morale


func process_tick() -> void:
	var ps: Dictionary = GameStateStore.power()
	if not ENABLED:
		ps.enabled = false
		ps.tier_powered = { "priority": true, "secondary": true, "tertiary": true }
		_tag_all(true)
		return

	var solar_mult: float = (GameStateStore.climate().get("modifiers", {}) as Dictionary).get("solar_mult", 1.0) as float

	var generation: float = 0.0
	var demand := { "priority": 0.0, "secondary": 0.0, "tertiary": 0.0 }
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		if bld.get("damaged", false) as bool:
			continue
		var def: Dictionary = ContentDB.get_building_def(bld.get("type", "") as String)
		var out: float = def.get("power_output", 0.0) as float
		if out > 0.0:
			var is_solar: bool = (def.get("tags", []) as Array).has("solar")
			generation += out * (solar_mult if is_solar else 1.0)
		var need: float = def.get("power_need", 0.0) as float
		if need > 0.0:
			demand[_tier_of(def)] = (demand[_tier_of(def)] as float) + need

	# Serve top network first; the moment one can't be fully covered, it and every
	# lower network go dark (all-or-nothing per tier keeps the model readable).
	var available: float = generation
	var powered := { "priority": true, "secondary": true, "tertiary": true }
	var shed: bool = false
	for tier: String in ["priority", "secondary", "tertiary"]:
		var d: float = demand[tier] as float
		if shed:
			powered[tier] = false
		elif available >= d:
			available -= d
			powered[tier] = true
		else:
			powered[tier] = false
			shed = true

	ps.enabled = true
	ps.generation = generation
	ps.demand = (demand.priority as float) + (demand.secondary as float) + (demand.tertiary as float)
	ps.tier_powered = powered

	_apply_powered_flags(powered)
	EventBus.power_updated.emit(generation, ps.demand as float, powered)


func _apply_powered_flags(powered: Dictionary) -> void:
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		var def: Dictionary = ContentDB.get_building_def(bld.get("type", "") as String)
		var need: float = def.get("power_need", 0.0) as float
		var ok: bool = need <= 0.0 or (powered[_tier_of(def)] as bool)
		if (bld.get("powered", true) as bool) != ok:
			bld["powered"] = ok
			GameStateStore.set_building(coord, bld)


func _tag_all(value: bool) -> void:
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		if (bld.get("powered", true) as bool) != value:
			bld["powered"] = value
			GameStateStore.set_building(coord, bld)


func _tier_of(def: Dictionary) -> String:
	var tags: Array = def.get("tags", []) as Array
	if tags.has("water_source") or tags.has("water_storage") or tags.has("admin"):
		return "priority"
	if tags.has("housing"):
		return "tertiary"
	return "secondary"
