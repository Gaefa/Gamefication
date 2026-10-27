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
