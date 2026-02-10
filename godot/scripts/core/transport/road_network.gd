## road_network.gd -- Road-specific logic layered on TransportGraph.
## Provides connection checks, road boost calculations, and road masks
## for hex rendering.
class_name RoadNetwork


var _transport_graph: TransportGraph


# ------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------

func _init(transport_graph: TransportGraph) -> void:
	_transport_graph = transport_graph


# ------------------------------------------------------------------
# Public API
# ------------------------------------------------------------------

## Returns true if the building at (q, r) is adjacent to at least one
## road tile in the transport network.
func is_building_connected(q: int, r: int, hex_grid) -> bool:
	return _transport_graph.is_road_connected(Vector2i(q, r), hex_grid)


## Calculate production boost from adjacent road tiles.
## Counts neighbouring roads, finds the best road level among them,
## and returns  road_boost_value * road_count.
## road_boost is read from ContentDB: road level -> bonus.road_boost.
func get_road_boost(q: int, r: int, hex_grid) -> float:
	var neighbors: Array[Vector2i] = HexCoords.axial_neighbors(q, r)
	var road_count: int = 0
	var best_level: int = 1

	for nb: Vector2i in neighbors:
		var building: Dictionary = {}
		if hex_grid.has_method("get_building"):
			building = hex_grid.get_building(nb.x, nb.y)
		if building.is_empty():
			continue
		if building.get("type", "") == "road":
			road_count += 1
			var lvl: int = int(building.get("level", 1))
			if lvl > best_level:
				best_level = lvl

	if road_count == 0:
		return 0.0

	# Road levels in ContentDB are 0-indexed (level 1 = index 0).
	var level_data: Dictionary = ContentDB.get_building_level("road", best_level - 1)
	var bonus: Dictionary = level_data.get("bonus", {})
	var boost_per_road: float = float(bonus.get("road_boost", 0.0))

	return boost_per_road * road_count


## Returns a 6-bit mask indicating which hex directions (0-5) have a
## neighbouring road tile.  Bit 0 = direction 0 (East), etc.
func get_road_mask(q: int, r: int, hex_grid) -> int:
	var mask: int = 0
	for dir_idx in 6:
		var nb: Vector2i = HexCoords.axial_neighbor(q, r, dir_idx)
		var building: Dictionary = {}
		if hex_grid.has_method("get_building"):
			building = hex_grid.get_building(nb.x, nb.y)
		if not building.is_empty() and building.get("type", "") == "road":
			mask |= (1 << dir_idx)
	return mask
