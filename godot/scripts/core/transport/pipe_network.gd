## pipe_network.gd -- Pipe-specific logic layered on TransportGraph.
## Determines water and energy coverage at a given hex coordinate by
## checking nearby water towers and power plants via the spatial index.
class_name PipeNetwork


var _transport_graph: TransportGraph


# ------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------

func _init(transport_graph: TransportGraph) -> void:
	_transport_graph = transport_graph


# ------------------------------------------------------------------
# Public API
# ------------------------------------------------------------------

## Returns true if any water_tower within its water_radius (hex distance)
## covers the hex at (q, r).
## Uses spatial_index.get_by_type("water_tower") to find all water towers.
func has_water(q: int, r: int, hex_grid, spatial_index) -> bool:
	var towers: Array = []
	if spatial_index.has_method("get_by_type"):
		towers = spatial_index.get_by_type("water_tower")

	for entry: Variant in towers:
		var coord: Vector2i = _extract_coord(entry)
		var building: Dictionary = _extract_building(entry, hex_grid, coord)
		if building.is_empty():
			continue

		var level: int = int(building.get("level", 1))
		# ContentDB levels are 0-indexed.
		var level_data: Dictionary = ContentDB.get_building_level("water_tower", level - 1)
		var synergy: Dictionary = level_data.get("synergy", {})
		var water_radius: int = int(synergy.get("water_radius", 4))

		var dist: int = HexCoords.hex_distance(q, r, coord.x, coord.y)
		if dist <= water_radius:
			return true

	return false


## Returns true if any power plant of level >= 2 within its powered radius
## (hex distance) covers the hex at (q, r).
## Uses spatial_index.get_by_type("power") to find all power plants.
func has_energy(q: int, r: int, hex_grid, spatial_index) -> bool:
	var plants: Array = []
	if spatial_index.has_method("get_by_type"):
		plants = spatial_index.get_by_type("power")

	for entry: Variant in plants:
		var coord: Vector2i = _extract_coord(entry)
		var building: Dictionary = _extract_building(entry, hex_grid, coord)
		if building.is_empty():
			continue

		var level: int = int(building.get("level", 1))
		# Power aura only active at level >= 2.
		if level < 2:
			continue

		var level_data: Dictionary = ContentDB.get_building_level("power", level - 1)
		var synergy: Dictionary = level_data.get("synergy", {})
		var radius: int = int(synergy.get("radius", 6))

		var dist: int = HexCoords.hex_distance(q, r, coord.x, coord.y)
		if dist <= radius:
			return true

	return false


# ------------------------------------------------------------------
# Internal helpers
# ------------------------------------------------------------------

## Extract Vector2i coord from a spatial_index entry.
## The entry may be a Dictionary with "coord" key, or a Vector2i directly.
func _extract_coord(entry) -> Vector2i:
	if entry is Vector2i:
		return entry
	if entry is Dictionary:
		if entry.has("coord"):
			return entry["coord"] as Vector2i
		# Fallback: try q/r keys.
		return Vector2i(int(entry.get("q", 0)), int(entry.get("r", 0)))
	return Vector2i.ZERO


## Extract the building Dictionary for a spatial entry.
## Prefers the "building" key in the entry dict; falls back to hex_grid lookup.
func _extract_building(entry, hex_grid, coord: Vector2i) -> Dictionary:
	if entry is Dictionary and entry.has("building"):
		return entry["building"] as Dictionary
	if hex_grid.has_method("get_building"):
		return hex_grid.get_building(coord.x, coord.y)
	return {}
