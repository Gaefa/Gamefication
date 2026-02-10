class_name BuildingInteractions

static func get_all_modifiers(q: int, r: int, state: Dictionary, hex_grid: HexGrid, spatial_index: SpatialIndex, aura_cache: AuraCache, road_network: RoadNetwork) -> Dictionary:
	var bld := hex_grid.get_building(q, r)
	if bld.is_empty():
		return {}
	var result := {}
	result["road_boost"] = AdjacencyCalculator.get_road_boost(q, r, hex_grid)
	result["farm_aura"] = aura_cache.get_farm_aura(q, r, hex_grid, spatial_index)
	result["power_aura"] = aura_cache.get_power_aura(q, r, hex_grid, spatial_index)
	result["water_coverage"] = aura_cache.get_water_coverage(q, r, hex_grid, spatial_index)
	result["park_happiness"] = aura_cache.get_park_happiness(q, r, hex_grid, spatial_index)
	result["workshop_discount"] = aura_cache.get_workshop_discount(q, r, hex_grid, spatial_index)
	result["road_connected"] = road_network.is_building_connected(q, r, hex_grid)
	result["synergies"] = SynergyResolver.resolve(q, r, hex_grid)
	return result
