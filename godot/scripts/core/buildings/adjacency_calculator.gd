class_name AdjacencyCalculator

static func count_adjacent_of_type(q: int, r: int, type_id: String, hex_grid: HexGrid) -> int:
	var count := 0
	for n in HexCoords.axial_neighbors(q, r):
		var bld := hex_grid.get_building(n.x, n.y)
		if not bld.is_empty() and bld.get("type", "") == type_id:
			count += 1
	return count

static func get_adjacent_buildings(q: int, r: int, hex_grid: HexGrid) -> Array:
	var result: Array = []
	for n in HexCoords.axial_neighbors(q, r):
		var bld := hex_grid.get_building(n.x, n.y)
		if not bld.is_empty():
			result.append({"coord": n, "building": bld})
	return result

static func get_road_boost(q: int, r: int, hex_grid: HexGrid) -> float:
	var road_count := 0
	var best_level := 1
	for n in HexCoords.axial_neighbors(q, r):
		var bld := hex_grid.get_building(n.x, n.y)
		if not bld.is_empty() and bld.get("type", "") == "road":
			road_count += 1
			best_level = maxi(best_level, bld.get("level", 1))
	if road_count == 0:
		return 0.0
	var road_def := ContentDB.get_building("road")
	var levels: Array = road_def.get("levels", [])
	var lvl_idx: int = best_level - 1
	if lvl_idx < 0 or lvl_idx >= levels.size():
		return 0.0
	var bonus_data = levels[lvl_idx].get("bonus", {})
	return bonus_data.get("road_boost", bonus_data.get("roadBoost", 0.05)) * road_count

static func get_market_residential_boost(q: int, r: int, hex_grid: HexGrid) -> float:
	var boost := 0.0
	for n in HexCoords.axial_neighbors(q, r):
		var bld := hex_grid.get_building(n.x, n.y)
		if not bld.is_empty() and bld.get("type", "") == "market":
			var bld_def := ContentDB.get_building("market")
			var levels: Array = bld_def.get("levels", [])
			var lvl_idx: int = bld.get("level", 1) - 1
			if lvl_idx >= 0 and lvl_idx < levels.size():
				var syn = levels[lvl_idx].get("synergy", {})
				if syn is Dictionary:
					boost += syn.get("residentialCoins", 0.0)
	return boost
