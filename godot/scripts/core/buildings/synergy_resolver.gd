class_name SynergyResolver
## Resolves all synergy effects for a building at a given coordinate.
## Combines adjacency bonuses + aura bonuses + market residential boost.

var _adjacency: AdjacencyCalculator
var _aura_cache: AuraCache


func _init(adjacency: AdjacencyCalculator, aura_cache: AuraCache) -> void:
	_adjacency = adjacency
	_aura_cache = aura_cache


func get_production_multiplier(coord: Vector2i, type_id: String) -> Dictionary:
	## Returns {resource_id: total_multiplier} combining all synergies.
	var result: Dictionary = {}

	# 1. Adjacency synergies
	var adj_bonuses: Dictionary = _adjacency.calculate_adjacency_bonus(coord, type_id)
	for res_id: String in adj_bonuses:
		result[res_id] = 1.0 + (adj_bonuses[res_id] as float)

	# 2. Aura production boost (power plants)
	var aura_boost: float = _aura_cache.get_production_boost(coord)
	if aura_boost > 0.0:
		# Apply to all resources this building produces
		var bld: Dictionary = GameStateStore.get_building(coord)
		var level: int = bld.get("level", 0) as int
		var ldata: Dictionary = ContentDB.building_level_data(type_id, level)
		var produces: Dictionary = ldata.get("produces", {})
		for res_id: String in produces:
			result[res_id] = (result.get(res_id, 1.0) as float) + aura_boost

	# 3. Market residential coin boost
	_apply_market_boost(coord, type_id, result)

	return result


func _apply_market_boost(coord: Vector2i, type_id: String, result: Dictionary) -> void:
	var def: Dictionary = ContentDB.get_building_def(type_id)
	var cat: String = def.get("category", "") as String
	if cat != "Residential":
		return
	# Check if any adjacent market
	for nb: Vector2i in HexCoords.neighbors_of(coord):
		var nb_bld: Dictionary = GameStateStore.get_building(nb)
		if nb_bld.is_empty():
			continue
		if (nb_bld.get("type", "") as String) != "market":
			continue
		var nb_level: int = nb_bld.get("level", 0) as int
		var ldata: Dictionary = ContentDB.building_level_data("market", nb_level)
		var syn: Dictionary = ldata.get("synergy", {})
		var boost: float = syn.get("residential_coins", 0.0) as float
		if boost > 0.0:
			result["coins"] = (result.get("coins", 1.0) as float) + boost
