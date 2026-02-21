class_name HexPathfinding
## A* pathfinding over the hex grid, constrained to road/pipe tiles.

var _astar := AStar2D.new()
var _coord_to_id: Dictionary = {}  # Vector2i → int
var _next_id: int = 0


func clear() -> void:
	_astar.clear()
	_coord_to_id.clear()
	_next_id = 0


func add_point(coord: Vector2i) -> void:
	if _coord_to_id.has(coord):
		return
	var id := _next_id
	_next_id += 1
	_coord_to_id[coord] = id
	_astar.add_point(id, Vector2(coord.x, coord.y))


func connect_neighbors(coord: Vector2i) -> void:
	if not _coord_to_id.has(coord):
		return
	var id: int = _coord_to_id[coord] as int
	for nb: Vector2i in HexCoords.neighbors_of(coord):
		if _coord_to_id.has(nb):
			var nb_id: int = _coord_to_id[nb] as int
			if not _astar.are_points_connected(id, nb_id):
				_astar.connect_points(id, nb_id)


func has_point(coord: Vector2i) -> bool:
	return _coord_to_id.has(coord)


func are_connected(a: Vector2i, b: Vector2i) -> bool:
	if not _coord_to_id.has(a) or not _coord_to_id.has(b):
		return false
	var id_a: int = _coord_to_id[a] as int
	var id_b: int = _coord_to_id[b] as int
	var path := _astar.get_id_path(id_a, id_b)
	return path.size() > 0


func get_connected_component(start: Vector2i) -> Array[Vector2i]:
	## BFS from start, returning all reachable points.
	if not _coord_to_id.has(start):
		return []
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	var result: Array[Vector2i] = []
	while queue.size() > 0:
		var cur: Vector2i = queue.pop_front()
		result.append(cur)
		var cur_id: int = _coord_to_id[cur] as int
		for nb: Vector2i in HexCoords.neighbors_of(cur):
			if visited.has(nb):
				continue
			if not _coord_to_id.has(nb):
				continue
			var nb_id: int = _coord_to_id[nb] as int
			if _astar.are_points_connected(cur_id, nb_id):
				visited[nb] = true
				queue.append(nb)
	return result
