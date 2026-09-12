class_name CoverageMap
## Caches per-tile coverage for road, water, and power networks.
## Dirty-flag driven: only recomputes when buildings change.

var _road_connected: Dictionary = {}   # Vector2i → bool
var _water_covered: Dictionary = {}    # Vector2i → bool
var _water_pressure: Dictionary = {}   # Vector2i → float, water consumers only
var _power_covered: Dictionary = {}    # Vector2i → bool
var _dirty: bool = true

var _spatial: SpatialIndex
var _hex_grid: HexGrid

# --- Water pressure / напор (GDD §6.1) — tuning ---
const PRESSURE_NEAR := 2               # full pressure within this many hexes of the source
const PRESSURE_FAR := 0.55             # pressure at the very edge of the source's radius
const PRESSURE_CAPACITY_BASE := 3      # consumers a level-0 source serves at full pressure
const PRESSURE_CAPACITY_PER_LEVEL := 2 # each source upgrade serves this many more
const PRESSURE_MIN := 0.3


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


func water_pressure(coord: Vector2i) -> float:
	## 1.0 = full напор; lower = partial supply. Meaningful for covered water consumers.
	ensure_fresh()
	return _water_pressure.get(coord, 1.0) as float


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
	var road_set: Dictionary = {}
	for c: Vector2i in _coords_with_tag_or_type("road", ["road", "bld_road"]):
		road_set[c] = true
	# A building is "road connected" if any neighbor is a road
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		for nb: Vector2i in HexCoords.neighbors_of(coord):
			if road_set.has(nb):
				_road_connected[coord] = true
				break


func _rebuild_water_coverage() -> void:
	_water_covered.clear()
	var sources: Array[Dictionary] = []
	for wc: Vector2i in _coords_with_tag_or_type("water_source", ["water_tower", "bld_well_pump"]):
		var bld: Dictionary = GameStateStore.get_building(wc)
		var type_id: String = bld.get("type", "") as String
		var level: int = bld.get("level", 0) as int
		var ldata: Dictionary = ContentDB.building_level_data(type_id, level)
		var syn: Dictionary = ldata.get("synergy", {})
		var r: int = syn.get("water_radius", 4) as int
		for cell: Vector2i in HexCoords.disk(wc, r):
			_water_covered[cell] = true
		sources.append({"coord": wc, "radius": r, "level": level})
	_rebuild_water_pressure(sources)


func _rebuild_water_pressure(sources: Array[Dictionary]) -> void:
	## Напор: each water consumer draws from its nearest covering source. Pressure fades
	## toward the edge of that source's radius and drops when the source is overloaded —
	## so it is fixed differently from the reserve (pumps/cisterns) and from coverage
	## (radius): put a source closer to the far houses, or split the load.
	_water_pressure.clear()
	var assigned: Dictionary = {}  # consumer coord → [source index, distance]
	var demand: Array[int] = []
	demand.resize(sources.size())
	demand.fill(0)
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		if not _consumes_water(coord):
			continue
		var best: int = -1
		var best_d: int = 0
		for i: int in sources.size():
			var d: int = HexCoords.distance(coord, sources[i].coord as Vector2i)
			if d <= (sources[i].radius as int) and (best < 0 or d < best_d):
				best = i
				best_d = d
		if best >= 0:
			assigned[coord] = [best, best_d]
			demand[best] += 1
	for coord: Vector2i in assigned:
		var idx: int = assigned[coord][0] as int
		var d: int = assigned[coord][1] as int
		var src: Dictionary = sources[idx]
		var dist_factor: float = 1.0
		if d > PRESSURE_NEAR:
			var span: int = maxi((src.radius as int) - PRESSURE_NEAR, 1)
			dist_factor = lerpf(1.0, PRESSURE_FAR, clampf(float(d - PRESSURE_NEAR) / float(span), 0.0, 1.0))
		var capacity: int = PRESSURE_CAPACITY_BASE + PRESSURE_CAPACITY_PER_LEVEL * (src.level as int)
		var load_factor: float = minf(1.0, float(capacity) / float(demand[idx]))
		_water_pressure[coord] = clampf(dist_factor * load_factor, PRESSURE_MIN, 1.0)


func _consumes_water(coord: Vector2i) -> bool:
	var bld: Dictionary = GameStateStore.get_building(coord)
	var ldata: Dictionary = ContentDB.building_level_data(bld.get("type", "") as String, bld.get("level", 0) as int)
	return (ldata.get("consumes", {}) as Dictionary).has("res_water_stockpile")


func _rebuild_power_coverage() -> void:
	_power_covered.clear()
	for pc: Vector2i in _coords_with_tag_or_type("power_source", ["power", "bld_power"]):
		var bld: Dictionary = GameStateStore.get_building(pc)
		var type_id: String = bld.get("type", "") as String
		var level: int = bld.get("level", 0) as int
		var ldata: Dictionary = ContentDB.building_level_data(type_id, level)
		var syn: Dictionary = ldata.get("synergy", {})
		var r: int = syn.get("radius", 0) as int
		if r > 0:
			for cell: Vector2i in HexCoords.disk(pc, r):
				_power_covered[cell] = true


func _coords_with_tag_or_type(tag: String, type_ids: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		var type_id: String = bld.get("type", "") as String
		var def: Dictionary = ContentDB.get_building_def(type_id)
		var tags: Array = def.get("tags", []) as Array
		if tags.has(tag) or type_ids.has(type_id):
			result.append(coord)
	return result
