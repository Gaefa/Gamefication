class_name EconomySystem
## Processes production and consumption for all buildings each tick.
## Applies multipliers from terrain, roads, synergies, coverage, and buffs.

var _interactions: BuildingInteractions
var _resource_flow: ResourceFlow


func _init(interactions: BuildingInteractions, resource_flow: ResourceFlow) -> void:
	_interactions = interactions
	_resource_flow = resource_flow


func process_tick() -> void:
	var net_production: Dictionary = {}
	var available_inputs: Dictionary = {}
	for res_id: String in ContentDB.get_resource_ids():
		net_production[res_id] = 0.0
		available_inputs[res_id] = GameStateStore.get_resource(res_id)

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
		var stock_efficiency: float = _input_stock_efficiency_for(consumes, delivery_efficiency, available_inputs)
		var input_efficiency: float = delivery_efficiency * stock_efficiency
		var condition_efficiency := 0.5 if (bld.get("has_issue", false) as bool) else 1.0

		# Get multipliers
		var mults: Dictionary = _interactions.get_total_multipliers(coord)

		# Production needs both inputs and an output route.
		for res_id: String in produces:
			var base: float = produces[res_id] as float
			var mult: float = mults.get(res_id, 1.0) as float
			var output_efficiency: float = _resource_flow.output_efficiency_for(res_id, coord, type_id)
			var gov_mult: float = _governance_production_multiplier(res_id)
			var amount: float = base * mult * gov_mult * input_efficiency * output_efficiency * condition_efficiency
			net_production[res_id] = (net_production[res_id] as float) + amount

		# If inputs cannot be delivered, the building stalls instead of silently draining stockpiles.
		for res_id: String in consumes:
			var amount: float = (consumes[res_id] as float) * input_efficiency
			net_production[res_id] = (net_production[res_id] as float) - amount
			available_inputs[res_id] = maxf((available_inputs.get(res_id, 0.0) as float) - amount, 0.0)

	# Bank interest (special mechanic)
	_process_bank_interest(net_production)

	# Apply net production
	for res_id: String in net_production:
		var net: float = net_production[res_id] as float
		if net != 0.0:
			GameStateStore.add_resource(res_id, net)
		GameStateStore.economy().production[res_id] = net

	# Maintenance cost (only if there are buildings)
	_apply_maintenance()

	EventBus.production_tick_done.emit()
	EventBus.resources_changed.emit(GameStateStore.economy().resources)

	# Check for depleted resources
	for res_id: String in ContentDB.get_resource_ids():
		if GameStateStore.get_resource(res_id) <= 0.0 and (net_production.get(res_id, 0.0) as float) < 0.0:
			EventBus.resource_depleted.emit(res_id)


func _input_stock_efficiency_for(consumes: Dictionary, delivery_efficiency: float, available_inputs: Dictionary) -> float:
	if consumes.is_empty():
		return 1.0
	if delivery_efficiency <= 0.0:
		return 0.0
	var efficiency := 1.0
	for res_id: String in consumes:
		var required: float = (consumes[res_id] as float) * delivery_efficiency
		if required <= 0.0:
			continue
		var available: float = available_inputs.get(res_id, 0.0) as float
		efficiency = minf(efficiency, clampf(available / required, 0.0, 1.0))
	return efficiency


func _process_bank_interest(net: Dictionary) -> void:
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		if (bld.get("type", "") as String) != "bank":
			continue
		var level: int = bld.get("level", 0) as int
		var ldata: Dictionary = ContentDB.building_level_data("bank", level)
		var rate: float = ldata.get("interest_per_min", 0.0) as float
		if rate > 0.0:
			var per_tick: float = rate / 60.0
			var interest: float = GameStateStore.get_resource("coins") * per_tick
			net["coins"] = (net.get("coins", 0.0) as float) + interest


func _apply_maintenance() -> void:
	var bld_count: int = GameStateStore.get_all_building_coords().size()
	if bld_count == 0:
		return  # No buildings = no maintenance
	var pop: int = GameStateStore.population().total as int
	# Scaling: pop*0.01 + buildings*0.02 coins/tick (no base cost)
	var cost: float = pop * 0.01 + bld_count * 0.02
	if cost > 0.0:
		GameStateStore.add_resource("coins", -cost)


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
