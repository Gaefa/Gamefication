## hex_pathfinding.gd -- Pathfinding on hex grids using Godot's AStar2D.
## Maintains two separate A* graphs: one for road networks and one for
## pipe networks (roads + water towers + power plants).
class_name HexPathfinding


## A* graph for road-only tiles.
var _astar_road: AStar2D = AStar2D.new()

## A* graph for pipe network tiles (roads, water towers, power plants).
var _astar_pipe: AStar2D = AStar2D.new()

## Grid size, cached for coordinate-to-ID conversion.
var _grid_size: int = 64


# ---- Lifecycle --------------------------------------------------------------

func _init(grid_size: int = 64) -> void:
	_grid_size = grid_size


# ---- ID conversion ---------------------------------------------------------

## Convert axial (q, r) to a unique integer point ID for AStar2D.
func _coord_to_id(q: int, r: int) -> int:
	return r * _grid_size + q


## Convert point ID back to axial coordinates.
func _id_to_coord(id: int) -> Vector2i:
	@warning_ignore("integer_division")
	var r: int = id / _grid_size
	var q: int = id % _grid_size
	return Vector2i(q, r)


# ---- Road graph -------------------------------------------------------------

## Rebuild the road-only A* graph from the current hex grid state.
## Clears all existing points/connections then adds every tile whose
## building type is "road", and connects neighboring road tiles.
func rebuild_road_graph(hex_grid: HexGrid) -> void:
	_astar_road.clear()

	var all_buildings: Dictionary = hex_grid.get_all_buildings()
	var road_coords: Array[Vector2i] = []

	# Pass 1: add all road points
	for coord: Vector2i in all_buildings:
		var bdata: Dictionary = all_buildings[coord]
		if bdata.get("type", "") == "road":
			var pid: int = _coord_to_id(coord.x, coord.y)
			if not _astar_road.has_point(pid):
				var pixel: Vector2 = HexCoords.axial_to_pixel(coord.x, coord.y, 1.0)
				_astar_road.add_point(pid, pixel)
			road_coords.append(coord)

	# Pass 2: connect neighboring road tiles
	for coord: Vector2i in road_coords:
		var pid: int = _coord_to_id(coord.x, coord.y)
		var neighbors: Array[Vector2i] = HexCoords.axial_neighbors(coord.x, coord.y)
		for nb: Vector2i in neighbors:
			var nid: int = _coord_to_id(nb.x, nb.y)
			if _astar_road.has_point(nid) and not _astar_road.are_points_connected(pid, nid):
				_astar_road.connect_points(pid, nid)


# ---- Pipe graph (roads + water_tower + power) --------------------------------

## Rebuild the pipe network A* graph.  Pipe-eligible tiles are roads,
## water towers, and power plants.
func rebuild_pipe_graph(hex_grid: HexGrid) -> void:
	_astar_pipe.clear()

	var all_buildings: Dictionary = hex_grid.get_all_buildings()
	var pipe_coords: Array[Vector2i] = []
	var pipe_types: PackedStringArray = PackedStringArray(["road", "water_tower", "power"])

	# Pass 1: add all pipe-eligible points
	for coord: Vector2i in all_buildings:
		var bdata: Dictionary = all_buildings[coord]
		var btype: String = bdata.get("type", "")
		if btype in pipe_types:
			var pid: int = _coord_to_id(coord.x, coord.y)
			if not _astar_pipe.has_point(pid):
				var pixel: Vector2 = HexCoords.axial_to_pixel(coord.x, coord.y, 1.0)
				_astar_pipe.add_point(pid, pixel)
			pipe_coords.append(coord)

	# Pass 2: connect neighboring pipe tiles
	for coord: Vector2i in pipe_coords:
		var pid: int = _coord_to_id(coord.x, coord.y)
		var neighbors: Array[Vector2i] = HexCoords.axial_neighbors(coord.x, coord.y)
		for nb: Vector2i in neighbors:
			var nid: int = _coord_to_id(nb.x, nb.y)
			if _astar_pipe.has_point(nid) and not _astar_pipe.are_points_connected(pid, nid):
				_astar_pipe.connect_points(pid, nid)


# ---- Pathfinding queries ----------------------------------------------------

## Find the shortest road-only path between two axial coordinates.
## Returns an empty array if no path exists.
func find_road_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var from_id: int = _coord_to_id(from.x, from.y)
	var to_id: int = _coord_to_id(to.x, to.y)

	if not _astar_road.has_point(from_id) or not _astar_road.has_point(to_id):
		return [] as Array[Vector2i]

	var id_path: PackedInt64Array = _astar_road.get_id_path(from_id, to_id)
	var result: Array[Vector2i] = []
	result.resize(id_path.size())
	for i in id_path.size():
		result[i] = _id_to_coord(int(id_path[i]))
	return result


## Find the shortest pipe-network path between two axial coordinates.
## Returns an empty array if no path exists.
func find_pipe_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var from_id: int = _coord_to_id(from.x, from.y)
	var to_id: int = _coord_to_id(to.x, to.y)

	if not _astar_pipe.has_point(from_id) or not _astar_pipe.has_point(to_id):
		return [] as Array[Vector2i]

	var id_path: PackedInt64Array = _astar_pipe.get_id_path(from_id, to_id)
	var result: Array[Vector2i] = []
	result.resize(id_path.size())
	for i in id_path.size():
		result[i] = _id_to_coord(int(id_path[i]))
	return result


## Return true if two road tiles are connected (reachable via roads).
func is_road_reachable(from: Vector2i, to: Vector2i) -> bool:
	var from_id: int = _coord_to_id(from.x, from.y)
	var to_id: int = _coord_to_id(to.x, to.y)

	if not _astar_road.has_point(from_id) or not _astar_road.has_point(to_id):
		return false

	var id_path: PackedInt64Array = _astar_road.get_id_path(from_id, to_id)
	return id_path.size() > 0
