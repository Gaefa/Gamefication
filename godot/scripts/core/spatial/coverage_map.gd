## coverage_map.gd -- Cached coverage bitmaps for road, water and power networks.
## Rebuilt on demand when the grid state changes.  Other systems should call
## ensure_fresh() before querying, or listen to EventBus.coverage_invalidated
## and call invalidate().
class_name CoverageMap


## Coord -> bool: true if the building at that coord has at least one
## adjacent road tile (non-road buildings only).
var _road_connected: Dictionary = {}

## Coord -> bool: true if the hex is within the water radius of any water_tower.
var _water_covered: Dictionary = {}

## Coord -> bool: true if the hex is within the power radius of a power plant
## at level >= 2 (i.e., a plant that has a powered_boost synergy).
var _powered: Dictionary = {}

## Whether the cache is stale and needs rebuilding.
var _dirty: bool = true


# ---- Public queries ---------------------------------------------------------

## Return true if the building at (q, r) has road adjacency.
func is_road_connected(q: int, r: int) -> bool:
	return _road_connected.get(Vector2i(q, r), false)


## Return true if (q, r) is within range of a water tower.
func is_water_covered(q: int, r: int) -> bool:
	return _water_covered.get(Vector2i(q, r), false)


## Return true if (q, r) is within range of a powered power plant (level >= 2).
func is_powered(q: int, r: int) -> bool:
	return _powered.get(Vector2i(q, r), false)


# ---- Cache management -------------------------------------------------------

## Mark the cache as stale.  Next ensure_fresh() call will trigger a full rebuild.
func invalidate() -> void:
	_dirty = true


## If the cache is dirty, rebuild it from the current grid state.
func ensure_fresh(hex_grid: HexGrid, spatial_index: SpatialIndex) -> void:
	if _dirty:
		rebuild(hex_grid, spatial_index)


## Full rebuild of all three coverage maps.
func rebuild(hex_grid: HexGrid, spatial_index: SpatialIndex) -> void:
	_road_connected.clear()
	_water_covered.clear()
	_powered.clear()

	var all_buildings: Dictionary = hex_grid.get_all_buildings()

	# ---- Road connectivity ---------------------------------------------------
	# For each non-road building, check if any of its 6 hex neighbors is a road.
	for coord: Vector2i in all_buildings:
		var bdata: Dictionary = all_buildings[coord]
		if bdata.get("type", "") == "road":
			continue  # Roads themselves don't need road-adjacency checks.

		var neighbors: Array[Vector2i] = HexCoords.axial_neighbors(coord.x, coord.y)
		var connected: bool = false
		for nb: Vector2i in neighbors:
			if hex_grid.has_building(nb.x, nb.y):
				var nb_data: Variant = hex_grid.get_building(nb.x, nb.y)
				if nb_data is Dictionary and nb_data.get("type", "") == "road":
					connected = true
					break
		_road_connected[coord] = connected

	# ---- Water coverage ------------------------------------------------------
	# For each water_tower, determine its water_radius from ContentDB (autoload),
	# then mark all hexes within that radius as water-covered.
	var water_towers: Array = spatial_index.get_by_type("water_tower")
	for coord: Vector2i in water_towers:
		var water_radius: int = _get_water_radius(hex_grid, coord)
		if water_radius <= 0:
			continue
		var covered_hexes: Array[Vector2i] = HexCoords.spiral(coord.x, coord.y, water_radius)
		for hex_coord: Vector2i in covered_hexes:
			_water_covered[hex_coord] = true

	# ---- Power coverage ------------------------------------------------------
	# For each power plant at level >= 2 (which has a powered_boost synergy),
	# determine its power radius from ContentDB and mark hexes as powered.
	var power_plants: Array = spatial_index.get_by_type("power")
	for coord: Vector2i in power_plants:
		var bdata: Variant = hex_grid.get_building(coord.x, coord.y)
		if bdata == null or not (bdata is Dictionary):
			continue
		var level: int = bdata.get("level", 0)
		if level < 1:  # level index 1 = "Grid Plant" (first level with powered_boost)
			continue
		var power_radius: int = _get_power_radius(hex_grid, coord)
		if power_radius <= 0:
			continue
		var covered_hexes: Array[Vector2i] = HexCoords.spiral(coord.x, coord.y, power_radius)
		for hex_coord: Vector2i in covered_hexes:
			_powered[hex_coord] = true

	_dirty = false


# ---- ContentDB helpers ------------------------------------------------------
# These look up radius values from the ContentDB autoload.  If ContentDB
# is not available (e.g., unit tests), fallback defaults are used.

## Get the water radius for a water_tower at the given coord.
func _get_water_radius(hex_grid: HexGrid, coord: Vector2i) -> int:
	var bdata: Variant = hex_grid.get_building(coord.x, coord.y)
	if bdata == null or not (bdata is Dictionary):
		return 4

	var level: int = bdata.get("level", 0)

	# Try to read from ContentDB autoload.
	if Engine.has_singleton("ContentDB"):
		return _get_radius_from_content_db("water_tower", level, "water_radius", 4)

	# Fallback: check if the ContentDB node exists in the scene tree.
	var content_db: Node = _get_content_db_node()
	if content_db and content_db.has_method("get_building_def"):
		var bdef: Variant = content_db.call("get_building_def", "water_tower")
		if bdef is Dictionary:
			return _extract_radius_from_def(bdef, level, "water_radius", 4)

	# Hardcoded fallback matching buildings.json water_tower levels.
	var fallback_radii: Array[int] = [4, 6, 8, 10, 14]
	if level >= 0 and level < fallback_radii.size():
		return fallback_radii[level]
	return 4


## Get the power radius for a power plant at the given coord.
func _get_power_radius(hex_grid: HexGrid, coord: Vector2i) -> int:
	var bdata: Variant = hex_grid.get_building(coord.x, coord.y)
	if bdata == null or not (bdata is Dictionary):
		return 0

	var level: int = bdata.get("level", 0)

	# Level 0 power plants have no radius synergy.
	if level < 1:
		return 0

	# Try ContentDB autoload.
	if Engine.has_singleton("ContentDB"):
		return _get_radius_from_content_db("power", level, "radius", 0)

	# Fallback: ContentDB node.
	var content_db: Node = _get_content_db_node()
	if content_db and content_db.has_method("get_building_def"):
		var bdef: Variant = content_db.call("get_building_def", "power")
		if bdef is Dictionary:
			return _extract_radius_from_def(bdef, level, "radius", 0)

	# Hardcoded fallback matching buildings.json power levels 1-4.
	var fallback_radii: Array[int] = [0, 6, 7, 8, 10]
	if level >= 0 and level < fallback_radii.size():
		return fallback_radii[level]
	return 0


## Try to find the ContentDB autoload node via the scene tree.
func _get_content_db_node() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root: Node = tree.root
	if root == null:
		return null
	if root.has_node("ContentDB"):
		return root.get_node("ContentDB")
	return null


## Generic helper: read a radius value from ContentDB autoload for a given
## building type, level, and synergy key.
func _get_radius_from_content_db(building_type: String, level: int, key: String, fallback: int) -> int:
	var content_db: Node = _get_content_db_node()
	if content_db == null:
		return fallback
	if not content_db.has_method("get_building_def"):
		return fallback
	var bdef: Variant = content_db.call("get_building_def", building_type)
	if not (bdef is Dictionary):
		return fallback
	return _extract_radius_from_def(bdef, level, key, fallback)


## Extract a radius value from a building definition dictionary at a given level.
## Looks in levels[level].synergy[key].
func _extract_radius_from_def(bdef: Dictionary, level: int, key: String, fallback: int) -> int:
	if not bdef.has("levels"):
		return fallback
	var levels: Array = bdef["levels"]
	if level < 0 or level >= levels.size():
		return fallback
	var level_data: Variant = levels[level]
	if not (level_data is Dictionary):
		return fallback
	var synergy: Variant = level_data.get("synergy", null)
	if not (synergy is Dictionary):
		return fallback
	return int(synergy.get(key, fallback))
