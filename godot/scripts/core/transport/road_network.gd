class_name RoadNetwork
## Calculates road adjacency boost for buildings.
## Each adjacent road tile gives a small production bonus based on road level.

var _spatial: SpatialIndex


func _init(spatial: SpatialIndex) -> void:
	_spatial = spatial


func road_boost_at(coord: Vector2i) -> float:
	var total: float = 0.0
	for nb: Vector2i in HexCoords.neighbors_of(coord):
		var bld: Dictionary = GameStateStore.get_building(nb)
		if bld.is_empty():
			continue
		if (bld.get("type", "") as String) != "road":
			continue
		var level: int = bld.get("level", 0) as int
		var ldata: Dictionary = ContentDB.building_level_data("road", level)
		var bonus: Dictionary = ldata.get("bonus", {})
		total += bonus.get("road_boost", 0.0) as float
	return total
