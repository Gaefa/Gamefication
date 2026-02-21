class_name CoverageMap
## Caches per-tile coverage for road, water, and power networks.
## Dirty-flag driven: only recomputes when buildings change.

var _road_connected: Dictionary = {}   # Vector2i → bool
var _water_covered: Dictionary = {}    # Vector2i → bool
var _power_covered: Dictionary = {}    # Vector2i → bool
var _dirty: bool = true

var _spatial: SpatialIndex
var _hex_grid: HexGrid


func _init(spatial: SpatialIndex, hex_grid: HexGrid) -> void:
	_spatial = spatial
	_hex_grid = hex_grid


func invalidate() -> void:
	_dirty = true


func ensure_fresh() -> void:
	if not _dirty:
		return
	_dirty = false
	_rebuild_road_coverage()
	_rebuild_water_coverage()
	_rebuild_power_coverage()


func is_road_connected(coord: Vector2i) -> bool:
	ensure_fresh()
	return _road_connected.get(coord, false) as bool


func is_water_covered(coord: Vector2i) -> bool:
	ensure_fresh()
	return _water_covered.get(coord, false) as bool


func is_power_covered(coord: Vector2i) -> bool:
	ensure_fresh()
	return _power_covered.get(coord, false) as bool


func road_efficiency(coord: Vector2i) -> float:
	var bld: Dictionary = GameStateStore.get_building(coord)
	if bld.is_empty():
		return 1.0
	var def: Dictionary = ContentDB.get_building_def(bld.get("type", "") as String)
	if not (def.get("requires_road", false) as bool):
		return 1.0
	return 1.0 if is_road_connected(coord) else 0.3


func water_efficiency(coord: Vector2i) -> float:
	var bld: Dictionary = GameStateStore.get_building(coord)
	if bld.is_empty():
		return 1.0
	var def: Dictionary = ContentDB.get_building_def(bld.get("type", "") as String)
	var cat: String = def.get("category", "") as String
	if cat != "Residential":
		return 1.0
	return 1.0 if is_water_covered(coord) else 0.6


# --- Internal rebuilds ---

func _rebuild_road_coverage() -> void:
	_road_connected.clear()
	var road_coords: Array[Vector2i] = _spatial.get_coords_of_type("road")
	var road_set: Dictionary = {}
	for c: Vector2i in road_coords:
		road_set[c] = true
	# A building is "road connected" if any neighbor is a road
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		for nb: Vector2i in HexCoords.neighbors_of(coord):
			if road_set.has(nb):
				_road_connected[coord] = true
				break


func _rebuild_water_coverage() -> void:
	_water_covered.clear()
	var water_coords: Array[Vector2i] = _spatial.get_coords_of_type("water_tower")
	for wc: Vector2i in water_coords:
		var bld: Dictionary = GameStateStore.get_building(wc)
		var level: int = bld.get("level", 0) as int
		var ldata: Dictionary = ContentDB.building_level_data("water_tower", level)
		var syn: Dictionary = ldata.get("synergy", {})
		var r: int = syn.get("water_radius", 4) as int
		for cell: Vector2i in HexCoords.disk(wc, r):
			_water_covered[cell] = true


func _rebuild_power_coverage() -> void:
	_power_covered.clear()
	var power_coords: Array[Vector2i] = _spatial.get_coords_of_type("power")
	for pc: Vector2i in power_coords:
		var bld: Dictionary = GameStateStore.get_building(pc)
		var level: int = bld.get("level", 0) as int
		var ldata: Dictionary = ContentDB.building_level_data("power", level)
		var syn: Dictionary = ldata.get("synergy", {})
		var r: int = syn.get("radius", 0) as int
		if r > 0:
			for cell: Vector2i in HexCoords.disk(pc, r):
				_power_covered[cell] = true
