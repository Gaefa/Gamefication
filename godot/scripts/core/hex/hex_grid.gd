## hex_grid.gd -- Core data structure wrapping terrain and building data
## for the hex city builder.  Uses axial coordinates (q, r) throughout.
## Terrain is stored in a flat PackedInt32Array for cache-friendly access.
## Buildings are stored in a Dictionary keyed by Vector2i(q, r).
class_name HexGrid


## Width and height of the square grid (in offset coords).
var grid_size: int = 64

## Flat terrain array.  Index = r * grid_size + q (axial coords).
## Values correspond to terrain type IDs from terrain.json (0=grass, 1=water, etc.)
var terrain: PackedInt32Array = PackedInt32Array()

## Sparse building map.  Key: Vector2i(q, r) -> Dictionary with at minimum:
##   { "type": String, "level": int }
## May also contain "issue": Variant for damage / problem flags.
var buildings: Dictionary = {}


# ---- Lifecycle --------------------------------------------------------------

func _init(size: int = 64) -> void:
	grid_size = size
	terrain.resize(size * size)
	terrain.fill(0)  # Default terrain: grass (type 0)
	buildings = {}


# ---- Coordinate helpers -----------------------------------------------------

## Check whether axial (q, r) is within grid bounds.
func is_valid_coord(q: int, r: int) -> bool:
	return HexCoords.is_valid(q, r, grid_size)


## Compute the flat index for axial (q, r).
func get_terrain_flat_index(q: int, r: int) -> int:
	return r * grid_size + q


# ---- Terrain accessors ------------------------------------------------------

## Return the terrain type at axial (q, r).  Returns 0 (grass) if out of bounds.
func get_terrain(q: int, r: int) -> int:
	if not is_valid_coord(q, r):
		return 0
	var idx: int = get_terrain_flat_index(q, r)
	if idx < 0 or idx >= terrain.size():
		return 0
	return terrain[idx]


## Set the terrain type at axial (q, r).  Silently ignores out-of-bounds writes.
func set_terrain(q: int, r: int, type: int) -> void:
	if not is_valid_coord(q, r):
		return
	var idx: int = get_terrain_flat_index(q, r)
	if idx >= 0 and idx < terrain.size():
		terrain[idx] = type


# ---- Building accessors -----------------------------------------------------

## Return the building data Dictionary at (q, r), or null if none exists.
func get_building(q: int, r: int) -> Variant:
	var key := Vector2i(q, r)
	if buildings.has(key):
		return buildings[key]
	return null


## Place or overwrite a building at (q, r).
## [param data] should be a Dictionary like { "type": "hut", "level": 0 }.
func set_building(q: int, r: int, data: Dictionary) -> void:
	buildings[Vector2i(q, r)] = data


## Remove the building at (q, r).  No-op if no building exists there.
func remove_building(q: int, r: int) -> void:
	buildings.erase(Vector2i(q, r))


## Return true if a building exists at (q, r).
func has_building(q: int, r: int) -> bool:
	return buildings.has(Vector2i(q, r))


## Return the full buildings Dictionary (by reference).
func get_all_buildings() -> Dictionary:
	return buildings


## Return the number of placed buildings.
func get_building_count() -> int:
	return buildings.size()


## Remove all buildings from the grid.
func clear_buildings() -> void:
	buildings.clear()


# ---- Bulk operations --------------------------------------------------------

## Reset every tile to grass (terrain 0) and remove all buildings.
func clear_all() -> void:
	terrain.fill(0)
	buildings.clear()
