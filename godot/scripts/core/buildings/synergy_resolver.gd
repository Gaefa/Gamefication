## synergy_resolver.gd -- Resolves synergy bonuses from ContentDB definitions.
class_name SynergyResolver

static func resolve(q: int, r: int, hex_grid: HexGrid) -> Dictionary:
	var building_raw: Variant = hex_grid.get_building(q, r)
	if building_raw == null:
		return {}
	var building: Dictionary = building_raw as Dictionary
	if building.is_empty():
		return {}
	var my_type: String = building.get("type", "")
	var synergy_defs: Array = ContentDB.get_synergies()
	var bonuses: Dictionary = {}

	var neighbors: Array[Vector2i] = HexCoords.axial_neighbors(q, r)
	for n: Vector2i in neighbors:
		var neighbor_raw: Variant = hex_grid.get_building(n.x, n.y)
		if neighbor_raw == null:
			continue
		var neighbor: Dictionary = neighbor_raw as Dictionary
		if neighbor.is_empty():
			continue
		var nbr_type: String = neighbor.get("type", "")

		for syn_def: Variant in synergy_defs:
			if not (syn_def is Dictionary):
				continue
			var syn_dict: Dictionary = syn_def as Dictionary
			var pair_raw: Variant = syn_dict.get("pair", [])
			if not (pair_raw is Array):
				continue
			var pair: Array = pair_raw as Array
			if pair.size() != 2:
				continue
			var p0: String = str(pair[0])
			var p1: String = str(pair[1])
			var match_a: bool = (my_type == p0 or p0 == "*") and (nbr_type == p1 or p1 == "*")
			var match_b: bool = (my_type == p1 or p1 == "*") and (nbr_type == p0 or p0 == "*")
			if not (match_a or match_b):
				continue
			var syn_bonuses_raw: Variant = syn_dict.get("bonuses", {})
			if not (syn_bonuses_raw is Dictionary):
				continue
			var syn_bonuses: Dictionary = syn_bonuses_raw as Dictionary
			var my_bonuses_raw: Variant = syn_bonuses.get(my_type, syn_bonuses.get("*", {}))
			if not (my_bonuses_raw is Dictionary):
				continue
			var my_bonuses: Dictionary = my_bonuses_raw as Dictionary
			for k: String in my_bonuses:
				var val: Variant = my_bonuses[k]
				if val is float or val is int:
					bonuses[k] = float(bonuses.get(k, 0.0)) + float(val)
				else:
					bonuses[k] = true
	return bonuses
