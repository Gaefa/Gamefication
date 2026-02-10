class_name SynergyResolver

static func resolve(q: int, r: int, hex_grid: HexGrid) -> Dictionary:
	var building := hex_grid.get_building(q, r)
	if building.is_empty():
		return {}
	var my_type: String = building.get("type", "")
	var synergy_defs: Array = ContentDB.get_synergies()
	var bonuses: Dictionary = {}
	for n in HexCoords.axial_neighbors(q, r):
		var neighbor := hex_grid.get_building(n.x, n.y)
		if neighbor.is_empty():
			continue
		var nbr_type: String = neighbor.get("type", "")
		for syn_def in synergy_defs:
			var pair: Array = syn_def.get("pair", [])
			if pair.size() != 2:
				continue
			var match_a: bool = (my_type == pair[0] or pair[0] == "*") and (nbr_type == pair[1] or pair[1] == "*")
			var match_b: bool = (my_type == pair[1] or pair[1] == "*") and (nbr_type == pair[0] or pair[0] == "*")
			if not (match_a or match_b):
				continue
			var syn_bonuses: Dictionary = syn_def.get("bonuses", {})
			var my_bonuses = syn_bonuses.get(my_type, syn_bonuses.get("*", {}))
			if my_bonuses is Dictionary:
				for k in my_bonuses:
					bonuses[k] = bonuses.get(k, 0.0) + float(my_bonuses[k]) if my_bonuses[k] is float or my_bonuses[k] is int else true
	return bonuses
