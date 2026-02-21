class_name HexGrid
## Core hex grid data structure.
## Stores terrain per cell and delegates building storage to GameStateStore.

var radius: int


func _init(map_radius: int = 30) -> void:
	radius = map_radius


func is_valid(coord: Vector2i) -> bool:
	return HexCoords.distance(Vector2i.ZERO, coord) <= radius


func all_coords() -> Array[Vector2i]:
	return HexCoords.disk(Vector2i.ZERO, radius)


func get_terrain_at(coord: Vector2i) -> int:
	return GameStateStore.get_terrain(coord)


func set_terrain_at(coord: Vector2i, terrain_id: int) -> void:
	GameStateStore.set_terrain(coord, terrain_id)


func has_building_at(coord: Vector2i) -> bool:
	return GameStateStore.has_building(coord)


func can_build_at(coord: Vector2i) -> bool:
	if not is_valid(coord):
		return false
	if has_building_at(coord):
		return false
	var terrain_id := get_terrain_at(coord)
	var tdef: Dictionary = ContentDB.get_terrain_def(terrain_id)
	if not tdef.is_empty():
		return tdef.get("buildable", true) as bool
	return true
