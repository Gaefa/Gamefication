class_name ProductionMultiplier

static func get_city_level_bonus(level: int) -> float:
	if level >= 7: return 1.0
	if level == 6: return 0.5
	if level == 5: return 0.35
	if level == 4: return 0.2
	if level == 3: return 0.1
	return 0.0

static func get_prestige_bonus(stars: int) -> float:
	return stars * 0.05

static func calculate(building: Dictionary, q: int, r: int, resource_key: String, state: Dictionary, hex_grid: HexGrid, spatial_index: SpatialIndex, aura_cache: AuraCache, road_network: RoadNetwork) -> float:
	var mult := 1.0
	mult += get_city_level_bonus(state.progression.city_level)
	mult += get_prestige_bonus(state.progression.prestige_stars)
	# Active buff bonus
	for buff in state.events.get("buffs", []):
		mult += buff.get("production_mult", 0.0)
	# Terrain bonus
	var bld_type: String = building.get("type", "")
	var bld_def := ContentDB.get_building(bld_type)
	var terrain_bonus_map = bld_def.get("terrain_bonus", {})
	if terrain_bonus_map is Dictionary and not terrain_bonus_map.is_empty():
		var terrain_type := hex_grid.get_terrain(q, r)
		var terrain_key := str(terrain_type)
		mult += float(terrain_bonus_map.get(terrain_key, terrain_bonus_map.get(terrain_type, 0.0)))
	# Road boost (not for roads themselves)
	if bld_type != "road":
		mult += AdjacencyCalculator.get_road_boost(q, r, hex_grid)
	# Farm aura for food
	if resource_key == "food":
		mult += aura_cache.get_farm_aura(q, r, hex_grid, spatial_index)
	# Market boost for residential coins
	if resource_key == "coins" and bld_type in ["hut", "apartment"]:
		mult += AdjacencyCalculator.get_market_residential_boost(q, r, hex_grid)
	# Power aura (not for power/road)
	if bld_type != "power" and bld_type != "road":
		mult += aura_cache.get_power_aura(q, r, hex_grid, spatial_index)
	# Lumber adjacent boost for farms
	if bld_type == "farm":
		for n in HexCoords.axial_neighbors(q, r):
			var nbr := hex_grid.get_building(n.x, n.y)
			if not nbr.is_empty() and nbr.get("type", "") == "lumber" and nbr.get("level", 1) >= 2:
				var lumber_def := ContentDB.get_building("lumber")
				var levels: Array = lumber_def.get("levels", [])
				var lvl_idx: int = nbr.get("level", 1) - 1
				if lvl_idx >= 0 and lvl_idx < levels.size():
					var syn = levels[lvl_idx].get("synergy", {})
					if syn is Dictionary:
						mult += syn.get("farmAdjBoost", 0.0)
	# Road connectivity penalty
	if bld_def.get("requires_road", false) and not road_network.is_building_connected(q, r, hex_grid):
		mult *= 0.3
	# Water coverage penalty for residential
	if bld_type in ["hut", "apartment"] and not aura_cache.get_water_coverage(q, r, hex_grid, spatial_index):
		mult *= 0.6
	# Issue penalty
	if building.get("issue") != null:
		mult *= 0.5
	return maxf(0.0, mult)
