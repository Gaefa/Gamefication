## spatial_index.gd -- Maintains reverse indexes of buildings by type for
## O(1) lookup.  Every placed building is tracked in two dictionaries:
##   _by_type:      type_id -> Array[Vector2i]   (all coords with that type)
##   _coord_to_type: Vector2i -> type_id          (what type is at that coord)
class_name SpatialIndex


## type_id (String) -> Array of Vector2i coords that have that building type.
var _by_type: Dictionary = {}

## Vector2i coord -> type_id (String).
var _coord_to_type: Dictionary = {}


# ---- Mutation ---------------------------------------------------------------

## Register a building of [param type_id] at [param coord].
## If a building already exists at that coord, it is removed first.
func add(coord: Vector2i, type_id: String) -> void:
	# Remove existing entry at this coord if present.
	if _coord_to_type.has(coord):
		_remove_from_type_list(_coord_to_type[coord], coord)

	_coord_to_type[coord] = type_id

	if not _by_type.has(type_id):
		_by_type[type_id] = []
	(_by_type[type_id] as Array).append(coord)


## Remove whatever building exists at [param coord].
func remove(coord: Vector2i) -> void:
	if not _coord_to_type.has(coord):
		return

	var type_id: String = _coord_to_type[coord]
	_remove_from_type_list(type_id, coord)
	_coord_to_type.erase(coord)


## Return all coords that have buildings of [param type_id].
## Returns an empty array if the type has no buildings.
func get_by_type(type_id: String) -> Array:
	if _by_type.has(type_id):
		return _by_type[type_id]
	return []


## Return the type_id at [param coord], or "" if nothing is there.
func get_type_at(coord: Vector2i) -> String:
	if _coord_to_type.has(coord):
		return _coord_to_type[coord]
	return ""


# ---- Spatial queries --------------------------------------------------------

## Return all indexed coords within [param radius] hex distance of center,
## optionally filtered to only [param type_filter].
## Uses HexCoords.spiral to enumerate candidate hexes, then checks the index.
func get_in_radius(center_q: int, center_r: int, radius: int, type_filter: String = "") -> Array[Vector2i]:
	var candidates: Array[Vector2i] = HexCoords.spiral(center_q, center_r, radius)
	var results: Array[Vector2i] = []

	for coord: Vector2i in candidates:
		if not _coord_to_type.has(coord):
			continue
		if type_filter != "" and _coord_to_type[coord] != type_filter:
			continue
		results.append(coord)

	return results


# ---- Counts -----------------------------------------------------------------

## Return the number of buildings of [param type_id].
func get_count(type_id: String) -> int:
	if _by_type.has(type_id):
		return (_by_type[type_id] as Array).size()
	return 0


## Return the total number of indexed buildings.
func get_total_count() -> int:
	return _coord_to_type.size()


# ---- Bulk operations --------------------------------------------------------

## Clear all indexes.
func clear() -> void:
	_by_type.clear()
	_coord_to_type.clear()


## Clear and rebuild the entire index from an existing HexGrid.
func rebuild(hex_grid: HexGrid) -> void:
	clear()
	var all_buildings: Dictionary = hex_grid.get_all_buildings()
	for coord: Vector2i in all_buildings:
		var bdata: Dictionary = all_buildings[coord]
		var type_id: String = bdata.get("type", "")
		if type_id != "":
			add(coord, type_id)


# ---- Internal helpers -------------------------------------------------------

## Remove [param coord] from the _by_type list for [param type_id].
func _remove_from_type_list(type_id: String, coord: Vector2i) -> void:
	if not _by_type.has(type_id):
		return
	var arr: Array = _by_type[type_id]
	var idx: int = arr.find(coord)
	if idx >= 0:
		arr.remove_at(idx)
	# Clean up empty arrays to avoid accumulating empty keys.
	if arr.is_empty():
		_by_type.erase(type_id)
