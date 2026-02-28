class_name TransportGraph
## Maintains connected components for road and pipe networks via BFS.
## Rebuilt when network topology changes.

var _components: Array = []  # Array[Array[Vector2i]]
var _coord_to_component: Dictionary = {}  # Vector2i → int (component index)
var _dirty: bool = true
var _network_type: String  # "road" or "pipe"
var _spatial: SpatialIndex


func _init(network_type: String, spatial: SpatialIndex) -> void:
	_network_type = network_type
	_spatial = spatial


func invalidate() -> void:
	_dirty = true


func ensure_fresh() -> void:
	if not _dirty:
		return
	_dirty = false
	_rebuild()


func are_connected(a: Vector2i, b: Vector2i) -> bool:
	ensure_fresh()
	if not _coord_to_component.has(a) or not _coord_to_component.has(b):
		return false
	return _coord_to_component[a] == _coord_to_component[b]


func get_component_of(coord: Vector2i) -> Array[Vector2i]:
	ensure_fresh()
	if not _coord_to_component.has(coord):
		return []
	var idx: int = _coord_to_component[coord] as int
	if idx >= 0 and idx < _components.size():
		var comp: Array[Vector2i] = []
		for c: Variant in _components[idx]:
			comp.append(c as Vector2i)
		return comp
	return []


func _rebuild() -> void:
	_components.clear()
	_coord_to_component.clear()

	var type_id: String = _network_type
	if _network_type == "pipe":
		type_id = "water_tower"  # pipe network is water_tower tiles

	var coords: Array[Vector2i] = _spatial.get_coords_of_type(type_id)
	var visited: Dictionary = {}
	var coord_set: Dictionary = {}
	for c: Vector2i in coords:
		coord_set[c] = true

	for start: Vector2i in coords:
		if visited.has(start):
			continue
		var component: Array = []
		var queue: Array[Vector2i] = [start]
		visited[start] = true
		while queue.size() > 0:
			var cur: Vector2i = queue.pop_front()
			component.append(cur)
			for nb: Vector2i in HexCoords.neighbors_of(cur):
				if visited.has(nb):
					continue
				if coord_set.has(nb):
					visited[nb] = true
					queue.append(nb)
		var comp_idx: int = _components.size()
		_components.append(component)
		for c: Variant in component:
			_coord_to_component[c as Vector2i] = comp_idx
