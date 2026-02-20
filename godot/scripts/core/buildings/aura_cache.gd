## aura_cache.gd -- Cached aura calculations for building interactions.
class_name AuraCache

var _cache: Dictionary = {}

func get_farm_aura(q: int, r: int, hex_grid: HexGrid, spatial_index: SpatialIndex) -> float:
	var key: String = "farm:%d:%d" % [q, r]
	if _cache.has(key):
		return float(_cache[key])
	var boost: float = 0.0
	var farms: Array = spatial_index.get_by_type("farm")
	for farm_coord: Variant in farms:
		var fc: Vector2i = farm_coord as Vector2i
		var farm_raw: Variant = hex_grid.get_building(fc.x, fc.y)
		if farm_raw == null:
			continue
		var farm: Dictionary = farm_raw as Dictionary
		if farm.is_empty() or int(farm.get("level", 1)) < 3:
			continue
		var bld_def: Dictionary = ContentDB.get_building("farm")
		var levels: Array = bld_def.get("levels", [])
		var lvl_idx: int = int(farm.get("level", 1)) - 1
		if lvl_idx < 0 or lvl_idx >= levels.size():
			continue
		var level_entry: Variant = levels[lvl_idx]
		if not (level_entry is Dictionary):
			continue
		var syn: Variant = (level_entry as Dictionary).get("synergy", {})
		if not (syn is Dictionary):
			continue
		var syn_dict: Dictionary = syn as Dictionary
		var radius: int = int(syn_dict.get("radius", 3))
		if HexCoords.hex_distance(q, r, fc.x, fc.y) <= radius:
			boost += float(syn_dict.get("auraFoodBoost", 0.0))
	boost = clampf(boost, 0.0, 0.5)
	_cache[key] = boost
	return boost

func get_power_aura(q: int, r: int, hex_grid: HexGrid, spatial_index: SpatialIndex) -> float:
	var key: String = "power:%d:%d" % [q, r]
	if _cache.has(key):
		return float(_cache[key])
	var boost: float = 0.0
	var plants: Array = spatial_index.get_by_type("power")
	for plant_coord: Variant in plants:
		var pc: Vector2i = plant_coord as Vector2i
		var plant_raw: Variant = hex_grid.get_building(pc.x, pc.y)
		if plant_raw == null:
			continue
		var plant: Dictionary = plant_raw as Dictionary
		if plant.is_empty() or int(plant.get("level", 1)) < 2:
			continue
		var bld_def: Dictionary = ContentDB.get_building("power")
		var levels: Array = bld_def.get("levels", [])
		var lvl_idx: int = int(plant.get("level", 1)) - 1
		if lvl_idx < 0 or lvl_idx >= levels.size():
			continue
		var level_entry: Variant = levels[lvl_idx]
		if not (level_entry is Dictionary):
			continue
		var syn: Variant = (level_entry as Dictionary).get("synergy", {})
		if not (syn is Dictionary):
			continue
		var syn_dict: Dictionary = syn as Dictionary
		var radius: int = int(syn_dict.get("radius", 6))
		if HexCoords.hex_distance(q, r, pc.x, pc.y) <= radius:
			boost += float(syn_dict.get("poweredBoost", 0.0))
	boost = clampf(boost, 0.0, 0.6)
	_cache[key] = boost
	return boost

func get_water_coverage(q: int, r: int, hex_grid: HexGrid, spatial_index: SpatialIndex) -> bool:
	var key: String = "water:%d:%d" % [q, r]
	if _cache.has(key):
		return float(_cache[key]) > 0.5
	var towers: Array = spatial_index.get_by_type("water_tower")
	for tower_coord: Variant in towers:
		var tc: Vector2i = tower_coord as Vector2i
		var tower_raw: Variant = hex_grid.get_building(tc.x, tc.y)
		if tower_raw == null:
			continue
		var tower: Dictionary = tower_raw as Dictionary
		if tower.is_empty():
			continue
		var bld_def: Dictionary = ContentDB.get_building("water_tower")
		var levels: Array = bld_def.get("levels", [])
		var lvl_idx: int = int(tower.get("level", 1)) - 1
		if lvl_idx < 0 or lvl_idx >= levels.size():
			continue
		var level_entry: Variant = levels[lvl_idx]
		if not (level_entry is Dictionary):
			continue
		var syn: Variant = (level_entry as Dictionary).get("synergy", {})
		if not (syn is Dictionary):
			continue
		var syn_dict: Dictionary = syn as Dictionary
		var radius: int = int(syn_dict.get("waterRadius", 4))
		if HexCoords.hex_distance(q, r, tc.x, tc.y) <= radius:
			_cache[key] = 1.0
			return true
	_cache[key] = 0.0
	return false

func get_park_happiness(q: int, r: int, hex_grid: HexGrid, spatial_index: SpatialIndex) -> float:
	var key: String = "park:%d:%d" % [q, r]
	if _cache.has(key):
		return float(_cache[key])
	var happiness: float = 0.0
	var parks: Array = spatial_index.get_by_type("park")
	for park_coord: Variant in parks:
		var pkc: Vector2i = park_coord as Vector2i
		var park_raw: Variant = hex_grid.get_building(pkc.x, pkc.y)
		if park_raw == null:
			continue
		var park: Dictionary = park_raw as Dictionary
		if park.is_empty():
			continue
		var bld_def: Dictionary = ContentDB.get_building("park")
		var levels: Array = bld_def.get("levels", [])
		var lvl_idx: int = int(park.get("level", 1)) - 1
		if lvl_idx < 0 or lvl_idx >= levels.size():
			continue
		var level_entry: Variant = levels[lvl_idx]
		if not (level_entry is Dictionary):
			continue
		var syn: Variant = (level_entry as Dictionary).get("synergy", {})
		if not (syn is Dictionary):
			continue
		var syn_dict: Dictionary = syn as Dictionary
		var radius: int = int(syn_dict.get("radius", 4))
		if HexCoords.hex_distance(q, r, pkc.x, pkc.y) <= radius:
			happiness += float(syn_dict.get("happinessAura", 0.0)) * 10.0
	_cache[key] = happiness
	return happiness

func get_workshop_discount(q: int, r: int, hex_grid: HexGrid, spatial_index: SpatialIndex) -> float:
	var key: String = "workshop:%d:%d" % [q, r]
	if _cache.has(key):
		return float(_cache[key])
	var discount: float = 0.0
	var workshops: Array = spatial_index.get_by_type("workshop")
	for ws_coord: Variant in workshops:
		var wc: Vector2i = ws_coord as Vector2i
		var ws_raw: Variant = hex_grid.get_building(wc.x, wc.y)
		if ws_raw == null:
			continue
		var ws: Dictionary = ws_raw as Dictionary
		if ws.is_empty() or int(ws.get("level", 1)) < 2:
			continue
		var bld_def: Dictionary = ContentDB.get_building("workshop")
		var levels: Array = bld_def.get("levels", [])
		var lvl_idx: int = int(ws.get("level", 1)) - 1
		if lvl_idx < 0 or lvl_idx >= levels.size():
			continue
		var level_entry: Variant = levels[lvl_idx]
		if not (level_entry is Dictionary):
			continue
		var syn: Variant = (level_entry as Dictionary).get("synergy", {})
		if not (syn is Dictionary):
			continue
		var syn_dict: Dictionary = syn as Dictionary
		var radius: int = int(syn_dict.get("radius", 3))
		if HexCoords.hex_distance(q, r, wc.x, wc.y) <= radius:
			discount += float(syn_dict.get("upgradeDiscount", 0.0))
	discount = clampf(discount, 0.0, 0.45)
	_cache[key] = discount
	return discount

func invalidate_at(q: int, r: int, radius: int = 15) -> void:
	var to_remove: Array[String] = []
	for key: String in _cache:
		var parts: PackedStringArray = key.split(":")
		if parts.size() >= 3:
			var kq: int = int(parts[1])
			var kr: int = int(parts[2])
			if HexCoords.hex_distance(q, r, kq, kr) <= radius:
				to_remove.append(key)
	for key: String in to_remove:
		_cache.erase(key)

func invalidate_all() -> void:
	_cache.clear()
