class_name AuraCache

var _cache: Dictionary = {}

func get_farm_aura(q: int, r: int, hex_grid: HexGrid, spatial_index: SpatialIndex) -> float:
	var key := "farm:%d:%d" % [q, r]
	if _cache.has(key):
		return _cache[key]
	var boost := 0.0
	for farm_coord in spatial_index.get_by_type("farm"):
		var farm := hex_grid.get_building(farm_coord.x, farm_coord.y)
		if farm.is_empty() or farm.get("level", 1) < 3:
			continue
		var bld_def := ContentDB.get_building("farm")
		var levels: Array = bld_def.get("levels", [])
		var lvl_idx: int = farm.get("level", 1) - 1
		if lvl_idx < 0 or lvl_idx >= levels.size():
			continue
		var syn = levels[lvl_idx].get("synergy", {})
		if not (syn is Dictionary):
			continue
		var radius: int = int(syn.get("radius", 3))
		if HexCoords.hex_distance(q, r, farm_coord.x, farm_coord.y) <= radius:
			boost += syn.get("auraFoodBoost", 0.0)
	boost = clampf(boost, 0.0, 0.5)
	_cache[key] = boost
	return boost

func get_power_aura(q: int, r: int, hex_grid: HexGrid, spatial_index: SpatialIndex) -> float:
	var key := "power:%d:%d" % [q, r]
	if _cache.has(key):
		return _cache[key]
	var boost := 0.0
	for plant_coord in spatial_index.get_by_type("power"):
		var plant := hex_grid.get_building(plant_coord.x, plant_coord.y)
		if plant.is_empty() or plant.get("level", 1) < 2:
			continue
		var bld_def := ContentDB.get_building("power")
		var levels: Array = bld_def.get("levels", [])
		var lvl_idx: int = plant.get("level", 1) - 1
		if lvl_idx < 0 or lvl_idx >= levels.size():
			continue
		var syn = levels[lvl_idx].get("synergy", {})
		if not (syn is Dictionary):
			continue
		var radius: int = int(syn.get("radius", 6))
		if HexCoords.hex_distance(q, r, plant_coord.x, plant_coord.y) <= radius:
			boost += syn.get("poweredBoost", 0.0)
	boost = clampf(boost, 0.0, 0.6)
	_cache[key] = boost
	return boost

func get_water_coverage(q: int, r: int, hex_grid: HexGrid, spatial_index: SpatialIndex) -> bool:
	var key := "water:%d:%d" % [q, r]
	if _cache.has(key):
		return _cache[key] > 0.5
	for tower_coord in spatial_index.get_by_type("water_tower"):
		var tower := hex_grid.get_building(tower_coord.x, tower_coord.y)
		if tower.is_empty():
			continue
		var bld_def := ContentDB.get_building("water_tower")
		var levels: Array = bld_def.get("levels", [])
		var lvl_idx: int = tower.get("level", 1) - 1
		if lvl_idx < 0 or lvl_idx >= levels.size():
			continue
		var syn = levels[lvl_idx].get("synergy", {})
		if not (syn is Dictionary):
			continue
		var radius: int = int(syn.get("waterRadius", 4))
		if HexCoords.hex_distance(q, r, tower_coord.x, tower_coord.y) <= radius:
			_cache[key] = 1.0
			return true
	_cache[key] = 0.0
	return false

func get_park_happiness(q: int, r: int, hex_grid: HexGrid, spatial_index: SpatialIndex) -> float:
	var key := "park:%d:%d" % [q, r]
	if _cache.has(key):
		return _cache[key]
	var happiness := 0.0
	for park_coord in spatial_index.get_by_type("park"):
		var park := hex_grid.get_building(park_coord.x, park_coord.y)
		if park.is_empty():
			continue
		var bld_def := ContentDB.get_building("park")
		var levels: Array = bld_def.get("levels", [])
		var lvl_idx: int = park.get("level", 1) - 1
		if lvl_idx < 0 or lvl_idx >= levels.size():
			continue
		var syn = levels[lvl_idx].get("synergy", {})
		if not (syn is Dictionary):
			continue
		var radius: int = int(syn.get("radius", 4))
		if HexCoords.hex_distance(q, r, park_coord.x, park_coord.y) <= radius:
			happiness += syn.get("happinessAura", 0.0) * 10.0
	_cache[key] = happiness
	return happiness

func get_workshop_discount(q: int, r: int, hex_grid: HexGrid, spatial_index: SpatialIndex) -> float:
	var key := "workshop:%d:%d" % [q, r]
	if _cache.has(key):
		return _cache[key]
	var discount := 0.0
	for ws_coord in spatial_index.get_by_type("workshop"):
		var ws := hex_grid.get_building(ws_coord.x, ws_coord.y)
		if ws.is_empty() or ws.get("level", 1) < 2:
			continue
		var bld_def := ContentDB.get_building("workshop")
		var levels: Array = bld_def.get("levels", [])
		var lvl_idx: int = ws.get("level", 1) - 1
		if lvl_idx < 0 or lvl_idx >= levels.size():
			continue
		var syn = levels[lvl_idx].get("synergy", {})
		if not (syn is Dictionary):
			continue
		var radius: int = int(syn.get("radius", 3))
		if HexCoords.hex_distance(q, r, ws_coord.x, ws_coord.y) <= radius:
			discount += syn.get("upgradeDiscount", 0.0)
	discount = clampf(discount, 0.0, 0.45)
	_cache[key] = discount
	return discount

func invalidate_at(q: int, r: int, radius: int = 15) -> void:
	var to_remove: Array = []
	for key in _cache:
		var parts: PackedStringArray = key.split(":")
		if parts.size() >= 3:
			var kq := int(parts[1])
			var kr := int(parts[2])
			if HexCoords.hex_distance(q, r, kq, kr) <= radius:
				to_remove.append(key)
	for key in to_remove:
		_cache.erase(key)

func invalidate_all() -> void:
	_cache.clear()
