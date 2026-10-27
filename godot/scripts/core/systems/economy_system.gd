class_name EconomySystem
## Processes production and consumption for all buildings each tick.
## Applies multipliers from terrain, roads, synergies, coverage, and buffs.

var _interactions: BuildingInteractions
var _resource_flow: ResourceFlow


func _init(interactions: BuildingInteractions, resource_flow: ResourceFlow) -> void:
	_interactions = interactions
	_resource_flow = resource_flow


func process_tick() -> void:
	_process_daily_spoilage()
	var season_mods: Dictionary = GameStateStore.climate().get("modifiers", {})

	var net_production: Dictionary = {}
	var available_inputs: Dictionary = {}
	var demand: Dictionary = {}  # what the district would draw with every input delivered
	for res_id: String in ContentDB.get_resource_ids():
		net_production[res_id] = 0.0
		available_inputs[res_id] = GameStateStore.get_resource(res_id)
		demand[res_id] = 0.0

	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		var type_id: String = bld.get("type", "") as String
		var level: int = bld.get("level", 0) as int

		# Skip damaged buildings
		if bld.get("damaged", false) as bool:
			continue

		var ldata: Dictionary = ContentDB.building_level_data(type_id, level)
		var produces: Dictionary = ldata.get("produces", {})
		var consumes: Dictionary = ldata.get("consumes", {})
		var delivery_efficiency: float = _resource_flow.input_efficiency_for(coord, consumes)
		var occupancy: float = housing_occupancy() if (ldata.get("population", 0) as int) > 0 else 1.0
		var stock_efficiency: float = _input_stock_efficiency_for(consumes, delivery_efficiency * occupancy, available_inputs, season_mods)
		var input_efficiency: float = delivery_efficiency * stock_efficiency
		var condition_efficiency := 0.5 if (bld.get("has_issue", false) as bool) else 1.0
		# Unpowered producers limp (electricity, GDD §6.2). PowerSystem set this flag.
		if not (bld.get("powered", true) as bool):
			condition_efficiency *= 0.3

		# Housing earns and eats by the people who actually live there, not by empty beds.
		input_efficiency *= occupancy
		for res_id: String in consumes:
			demand[res_id] = (demand[res_id] as float) + (consumes[res_id] as float) * occupancy * draw_multiplier(res_id, season_mods)

		# Get multipliers
		var mults: Dictionary = _interactions.get_total_multipliers(coord)

		# Production needs both inputs and an output route.
		for res_id: String in produces:
			var base: float = produces[res_id] as float
			var mult: float = mults.get(res_id, 1.0) as float
			var output_efficiency: float = _resource_flow.output_efficiency_for(res_id, coord, type_id)
			var gov_mult: float = _governance_production_multiplier(res_id)
			var season_mult: float = _season_production_mult(res_id, season_mods)
			var amount: float = base * mult * gov_mult * season_mult * input_efficiency * output_efficiency * condition_efficiency
			net_production[res_id] = (net_production[res_id] as float) + amount

		# If inputs cannot be delivered, the building stalls instead of silently draining stockpiles.
		for res_id: String in consumes:
			var amount: float = (consumes[res_id] as float) * input_efficiency * draw_multiplier(res_id, season_mods)
			net_production[res_id] = (net_production[res_id] as float) - amount
			available_inputs[res_id] = maxf((available_inputs.get(res_id, 0.0) as float) - amount, 0.0)

	# Upkeep is part of the money flow, so the HUD trend and the depletion warning see it.
	net_production["res_money"] = (net_production.get("res_money", 0.0) as float) - _maintenance_cost()

	GameStateStore.economy()["demand"] = demand

	# Apply net production
	for res_id: String in net_production:
		var net: float = net_production[res_id] as float
		if net != 0.0:
			GameStateStore.add_resource(res_id, net)
		GameStateStore.economy().production[res_id] = net

	EventBus.production_tick_done.emit()
	EventBus.resources_changed.emit(GameStateStore.economy().resources)

	# Check for depleted resources
	for res_id: String in ContentDB.get_resource_ids():
		if GameStateStore.get_resource(res_id) <= 0.0 and (net_production.get(res_id, 0.0) as float) < 0.0:
			EventBus.resource_depleted.emit(res_id)


## How much of what the building needs this tick is actually in stock. `delivery` already
## carries the delivery efficiency and the occupancy; the season raises the draw the same
## way the ledger does, so a dry cistern in the Heat stalls a barrack instead of feeding it.
static func _input_stock_efficiency_for(consumes: Dictionary, delivery: float, available_inputs: Dictionary, season_mods: Dictionary) -> float:
	if consumes.is_empty():
		return 1.0
	if delivery <= 0.0:
		return 0.0
	var efficiency := 1.0
	for res_id: String in consumes:
		var required: float = (consumes[res_id] as float) * delivery * draw_multiplier(res_id, season_mods)
		if required <= 0.0:
			continue
		var available: float = available_inputs.get(res_id, 0.0) as float
		efficiency = minf(efficiency, clampf(available / required, 0.0, 1.0))
	return efficiency


func _maintenance_cost() -> float:
	var bld_count: int = 0
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		if not ContentDB.is_inert_landmark(GameStateStore.get_building(coord).get("type", "") as String):
			bld_count += 1
	if bld_count == 0:
		return 0.0  # No buildings = no maintenance
	var pop: int = GameStateStore.population().total as int
	# Scaling: pop*0.001 + buildings*0.002 coins/tick (no base cost); a barrack brings in 0.1/tick.
	return pop * 0.001 + bld_count * 0.002


func _season_production_mult(res_id: String, season_mods: Dictionary) -> float:
	## Пыль режет урожай (crop_mult на еду) и душит добычу воды (water_supply_mult на
	## насосы: засорённые фильтры, просадка водоносных слоёв). Вместе с ×water_mult на
	## потребление это и делает Пыль настоящим экзаменом запаса воды.
	if season_mods.is_empty():
		return 1.0
	if res_id == "res_food":
		return season_mods.get("crop_mult", 1.0) as float
	if res_id == "res_water_stockpile":
		return season_mods.get("water_supply_mult", 1.0) as float
	return 1.0


## What a unit of need costs today: the season's thirst times the district's rationing.
static func draw_multiplier(res_id: String, season_mods: Dictionary) -> float:
	return _season_consumption_mult(res_id, season_mods) * consumption_multiplier(res_id)


## Policies and technologies can cut (or raise) the draw of a resource: water by the hour.
static func consumption_multiplier(res_id: String) -> float:
	var total: float = 0.0
	for policy_var: Variant in GameStateStore.get_active_policies().values():
		var effects: Dictionary = ContentDB.get_policy_def(policy_var as String).get("effects", {}) as Dictionary
		total += (effects.get("consumption_mult", {}) as Dictionary).get(res_id, 0.0) as float
	for tech_var: Variant in GameStateStore.get_technologies():
		var effects: Dictionary = ContentDB.get_technology_def(tech_var as String).get("effects", {}) as Dictionary
		total += (effects.get("consumption_mult", {}) as Dictionary).get(res_id, 0.0) as float
	return maxf(1.0 + total, 0.1)


static func _season_consumption_mult(res_id: String, season_mods: Dictionary) -> float:
	## Пыль/Жара поднимают расход воды: water_mult применяется к потреблению воды.
	if season_mods.is_empty():
		return 1.0
	if res_id == "res_water_stockpile":
		return season_mods.get("water_mult", 1.0) as float
	return 1.0


func _governance_production_multiplier(res_id: String) -> float:
	var total_bonus: float = 0.0
	for tech_var: Variant in GameStateStore.get_technologies():
		var tech_id: String = tech_var as String
		var tech_def: Dictionary = ContentDB.get_technology_def(tech_id)
		total_bonus += _production_bonus_from_effects(tech_def.get("effects", {}), res_id)
	for policy_var: Variant in GameStateStore.get_active_policies().values():
		var policy_id: String = policy_var as String
		var policy_def: Dictionary = ContentDB.get_policy_def(policy_id)
		total_bonus += _production_bonus_from_effects(policy_def.get("effects", {}), res_id)
	total_bonus += _production_bonus_from_effects(GameStateStore.mandate().get("effects", {}), res_id)
	return maxf(1.0 + total_bonus, 0.1)


func _production_bonus_from_effects(effects: Dictionary, res_id: String) -> float:
	var prod_mult: Dictionary = effects.get("production_mult", {})
	return prod_mult.get(res_id, 0.0) as float


## Lived-in share of the housing; 1.0 before the first census, when capacity is still 0.
static func housing_occupancy() -> float:
	var pop_state: Dictionary = GameStateStore.population()
	var capacity: float = float(pop_state.get("capacity", 0))
	if capacity <= 0.0:
		return 1.0
	return clampf(float(pop_state.get("total", 0)) / capacity, 0.0, 1.0)


## What the district draws per day at today's season rates; damaged buildings draw nothing.
## Read from the ledger the last tick wrote; walked only before the first tick of a run.
static func daily_consumption(res_id: String) -> float:
	var ledger: Dictionary = GameStateStore.economy().get("demand", {}) as Dictionary
	if ledger.has(res_id):
		return (ledger[res_id] as float) * float(SimulationRunner.TICKS_PER_DAY)
	var season_mods: Dictionary = GameStateStore.climate().get("modifiers", {})
	var occupancy: float = housing_occupancy()
	var per_tick: float = 0.0
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		if bld.get("damaged", false) as bool:
			continue
		var ldata: Dictionary = ContentDB.building_level_data(bld.get("type", "") as String, bld.get("level", 0) as int)
		var consumes: Dictionary = ldata.get("consumes", {})
		# Empty beds draw nothing, in the ledger as in the simulation.
		var share: float = occupancy if (ldata.get("population", 0) as int) > 0 else 1.0
		per_tick += (consumes.get(res_id, 0.0) as float) * share
	return per_tick * draw_multiplier(res_id, season_mods) * float(SimulationRunner.TICKS_PER_DAY)


## How many days the reserve lasts at today's draw; INF when nothing draws it.
static func days_of(res_id: String) -> float:
	var stock: float = GameStateStore.get_resource(res_id)
	if stock <= 0.0:
		return 0.0  # an empty store is empty whoever draws on it
	var per_day: float = daily_consumption(res_id)
	return INF if per_day <= 0.0 else stock / per_day


## Saved day marker prevents double spoilage on reload. Charge at the start of each
## Heat day, before production; the first charge uses the actual incoming reserve.
func _process_daily_spoilage() -> void:
	var climate: Dictionary = GameStateStore.climate()
	var day: int = climate.get("total_day", 1) as int
	if day <= (climate.get("spoilage_day", 0) as int):
		return
	climate["spoilage_day"] = day
	var loss: float = daily_spoilage()
	GameStateStore.add_resource("res_food", -loss)
	if (climate.get("season_id", "") as String) == "season_heat":
		climate["heat_food_spoiled"] = (climate.get("heat_food_spoiled", 0.0) as float) + loss


static func daily_spoilage() -> float:
	var mods: Dictionary = GameStateStore.climate().get("modifiers", {})
	var rate: float = mods.get("food_spoilage_per_day", 0.0) as float
	var warehouses: int = 0
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		# Building levels are zero-based: displayed level 2 is index 1.
		if bld.get("type", "") == "bld_warehouse" and (bld.get("level", 0) as int) >= 1 and not bld.get("damaged", false):
			warehouses += 1
	if (GameStateStore.mandate().get("flags", {}) as Dictionary).get("dried_rations", false):
		rate *= 0.5
	return GameStateStore.get_resource("res_food") * rate * maxf(0.25, 1.0 - 0.25 * warehouses)
