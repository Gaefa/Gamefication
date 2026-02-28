class_name AdjacencyCalculator
## Computes adjacency-based bonuses between specific building pairs.
## Uses synergy definitions from ContentDB.


func calculate_adjacency_bonus(coord: Vector2i, type_id: String) -> Dictionary:
	## Returns {resource_id: bonus_multiplier} from adjacent building synergies.
	var bonuses: Dictionary = {}
	var neighbors: Array[Vector2i] = HexCoords.neighbors_of(coord)

	for syn: Dictionary in ContentDB.synergies:
		if (syn.get("type", "") as String) != "adjacency":
			continue
		var pair: Array = syn.get("pair", [])
		if pair.size() != 2:
			continue
		var pair_a: String = pair[0] as String
		var pair_b: String = pair[1] as String

		# Check if this building is one of the pair
		var other_type: String = ""
		var effects_key: String = ""
		if type_id == pair_a:
			other_type = pair_b
			effects_key = "effects_a"
		elif type_id == pair_b:
			other_type = pair_a
			effects_key = "effects_b"
		else:
			continue

		# Count adjacent buildings of the other type
		var adjacent_count: int = 0
		for nb: Vector2i in neighbors:
			var nb_bld: Dictionary = GameStateStore.get_building(nb)
			if not nb_bld.is_empty() and (nb_bld.get("type", "") as String) == other_type:
				adjacent_count += 1

		if adjacent_count > 0:
			var effects: Dictionary = syn.get(effects_key, {})
			for res_id: String in effects:
				var bonus: float = (effects[res_id] as float) * adjacent_count
				bonuses[res_id] = bonuses.get(res_id, 0.0) as float + bonus

	return bonuses
