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
	for res_id: String in ContentDB.get_resource_ids():
		net_production[res_id] = 0.0

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

		# Get multipliers
		var mults: Dictionary = _interactions.get_total_multipliers(coord)

		# Production — always produces regardless of transport
		for res_id: String in produces:
			var base: float = produces[res_id] as float
			var mult: float = mults.get(res_id, 1.0) as float
			var amount: float = base * mult
			net_production[res_id] = (net_production[res_id] as float) + amount

		# Consumption
		for res_id: String in consumes:
			var amount: float = consumes[res_id] as float
			net_production[res_id] = (net_production[res_id] as float) - amount

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
