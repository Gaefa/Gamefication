## transport_graph.gd -- Maintains connected components for road and pipe
## networks using BFS flood fill over the hex grid.
class_name TransportGraph


# ---- Connected-component maps ----
# Each maps Vector2i (axial coord) -> component_id (int).
var _road_components: Dictionary = {}
var _pipe_components: Dictionary = {}

var _road_component_count: int = 0
var _pipe_component_count: int = 0

var _dirty: bool = true


# ------------------------------------------------------------------
# Public API
# ------------------------------------------------------------------

## Full rebuild of both road and pipe connected-component maps.
## Call after any road/pipe/building placement or removal.
func rebuild(hex_grid) -> void:
	_road_components.clear()
	_pipe_components.clear()
	_road_component_count = 0
	_pipe_component_count = 0

	var road_visited: Dictionary = {}
	var pipe_visited: Dictionary = {}

	# Iterate every cell that has a building.
	var all_coords: Array = hex_grid.get_all_building_coords() if hex_grid.has_method("get_all_building_coords") else _collect_coords(hex_grid)

	for coord: Vector2i in all_coords:
		var building: Dictionary = hex_grid.get_building(coord.x, coord.y) if hex_grid.has_method("get_building") else {}
		if building.is_empty():
			continue

		var btype: String = building.get("type", "")

		# --- Road components ---
		if btype == "road" and not road_visited.has(coord):
			_flood_fill(coord, hex_grid, "road", _road_component_count, road_visited)
			_road_component_count += 1

		# --- Pipe components ---
		# Pipes include roads + buildings whose network_type is "water" or "power".
		var net_type: String = _get_network_type(btype)
		var is_pipe_eligible: bool = (btype == "road" or net_type == "water" or net_type == "power")
		if is_pipe_eligible and not pipe_visited.has(coord):
			_flood_fill(coord, hex_grid, "pipe", _pipe_component_count, pipe_visited)
			_pipe_component_count += 1

	# Copy visited sets into component maps.
	_road_components = road_visited.duplicate()
	_pipe_components = pipe_visited.duplicate()
	_dirty = false


## Returns true if any of the 6 hex neighbours of [param coord] belongs
## to the road component map (i.e., is a road tile in the network).
func is_road_connected(coord: Vector2i, hex_grid) -> bool:
	var neighbors: Array[Vector2i] = HexCoords.axial_neighbors(coord.x, coord.y)
	for nb: Vector2i in neighbors:
		if _road_components.has(nb):
			return true
	return false


## Check whether two coords are in the same road connected component.
func are_same_road_component(a: Vector2i, b: Vector2i) -> bool:
	if not _road_components.has(a) or not _road_components.has(b):
		return false
	return _road_components[a] == _road_components[b]


## Check whether two coords are in the same pipe connected component.
func are_same_pipe_component(a: Vector2i, b: Vector2i) -> bool:
	if not _pipe_components.has(a) or not _pipe_components.has(b):
		return false
	return _pipe_components[a] == _pipe_components[b]


## Returns the road component id for a coord, or -1 if not in any component.
func get_road_component(coord: Vector2i) -> int:
	if _road_components.has(coord):
		return _road_components[coord] as int
	return -1


## Returns the pipe component id for a coord, or -1 if not in any component.
func get_pipe_component(coord: Vector2i) -> int:
	if _pipe_components.has(coord):
		return _pipe_components[coord] as int
	return -1


## Mark the graph as needing a rebuild.
func invalidate() -> void:
	_dirty = true


## Rebuild only if dirty.
func ensure_fresh(hex_grid) -> void:
	if _dirty:
		rebuild(hex_grid)


# ------------------------------------------------------------------
# Internal
# ------------------------------------------------------------------

## BFS flood fill from [param start].
## For "road": only expands to hex neighbours that are roads.
## For "pipe": expands to neighbours that are roads OR have network_type
## in ["water", "power"].
func _flood_fill(start: Vector2i, hex_grid, network_type: String,
		component_id: int, visited: Dictionary) -> void:
	var queue: Array[Vector2i] = [start]
	visited[start] = component_id

	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()
		var neighbors: Array[Vector2i] = HexCoords.axial_neighbors(current.x, current.y)

		for nb: Vector2i in neighbors:
			if visited.has(nb):
				continue

			# Check that there is a building at this neighbor.
			var nb_building: Dictionary = {}
			if hex_grid.has_method("get_building"):
				nb_building = hex_grid.get_building(nb.x, nb.y)
			if nb_building.is_empty():
				continue

			var nb_type: String = nb_building.get("type", "")

			var accept: bool = false
			if network_type == "road":
				accept = (nb_type == "road")
			elif network_type == "pipe":
				var nb_net: String = _get_network_type(nb_type)
				accept = (nb_type == "road" or nb_net == "water" or nb_net == "power")

			if accept:
				visited[nb] = component_id
				queue.append(nb)


## Retrieve the network_type for a building type from ContentDB.
## Returns "" if not found or null.
func _get_network_type(building_type: String) -> String:
	var bdef: Dictionary = ContentDB.get_building(building_type)
	if bdef.is_empty():
		return ""
	var nt: Variant = bdef.get("network_type", null)
	if nt == null:
		return ""
	return str(nt)


## Fallback coord collector when hex_grid does not expose
## get_all_building_coords().  Tries iterating via get_building() over
## a reasonable grid range.
func _collect_coords(hex_grid) -> Array:
	var coords: Array = []
	# Try common grid size accessors.
	var grid_size: int = 0
	if hex_grid.has_method("get_grid_size"):
		grid_size = hex_grid.get_grid_size()
	elif "grid_size" in hex_grid:
		grid_size = int(hex_grid.grid_size)
	else:
		grid_size = 30  # sensible default

	for r in range(-grid_size, grid_size + 1):
		for q in range(-grid_size, grid_size + 1):
			if hex_grid.has_method("has_building") and hex_grid.has_building(q, r):
				coords.append(Vector2i(q, r))
	return coords
