## production_multiplier.gd -- Calculates the total production multiplier
## for a building at a given hex, including all bonuses and penalties.
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
	var progression: Dictionary = state.get("progression", {})
	var events_dict: Dictionary = state.get("events", {})

	var mult: float = 1.0
	mult += get_city_level_bonus(int(progression.get("city_level", 1)))
	mult += get_prestige_bonus(int(progression.get("prestige_stars", 0)))

	# Active buff bonus
	var buffs: Array = events_dict.get("buffs", [])
	for buff: Variant in buffs:
		if buff is Dictionary:
			mult += float((buff as Dictionary).get("production_mult", 0.0))

	# Terrain bonus
	var bld_type: String = building.get("type", "")
	var bld_def: Dictionary = ContentDB.get_building(bld_type)
	var terrain_bonus_raw: Variant = bld_def.get("terrain_bonus", {})
	if terrain_bonus_raw is Dictionary:
		var terrain_bonus_map: Dictionary = terrain_bonus_raw as Dictionary
		if not terrain_bonus_map.is_empty():
			var terrain_type: int = hex_grid.get_terrain(q, r)
			var terrain_key: String = str(terrain_type)
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
		var neighbors: Array[Vector2i] = HexCoords.axial_neighbors(q, r)
		for n: Vector2i in neighbors:
			var nbr_raw: Variant = hex_grid.get_building(n.x, n.y)
			if nbr_raw == null:
				continue
			var nbr: Dictionary = nbr_raw as Dictionary
			if nbr.is_empty() or nbr.get("type", "") != "lumber" or int(nbr.get("level", 1)) < 2:
				continue
			var lumber_def: Dictionary = ContentDB.get_building("lumber")
			var levels: Array = lumber_def.get("levels", [])
			var lvl_idx: int = int(nbr.get("level", 1)) - 1
			if lvl_idx >= 0 and lvl_idx < levels.size():
				var level_entry: Variant = levels[lvl_idx]
				if level_entry is Dictionary:
					var syn: Variant = (level_entry as Dictionary).get("synergy", {})
					if syn is Dictionary:
						mult += float((syn as Dictionary).get("farmAdjBoost", 0.0))

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
