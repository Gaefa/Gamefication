class_name AuraCache
## Caches aura effects per tile (happiness, production boosts, upgrade discounts).
## Invalidated whenever buildings are placed or removed.

var _happiness_bonus: Dictionary = {}    # Vector2i → float
var _production_boost: Dictionary = {}   # Vector2i → float
var _upgrade_discount: Dictionary = {}   # Vector2i → float
var _dirty: bool = true


func invalidate() -> void:
	_dirty = true


func ensure_fresh() -> void:
	if not _dirty:
		return
	_dirty = false
	_rebuild()


func get_happiness_bonus(coord: Vector2i) -> float:
	ensure_fresh()
	return _happiness_bonus.get(coord, 0.0) as float


func get_production_boost(coord: Vector2i) -> float:
	ensure_fresh()
	return _production_boost.get(coord, 0.0) as float


func get_upgrade_discount(coord: Vector2i) -> float:
	ensure_fresh()
	return _upgrade_discount.get(coord, 0.0) as float


func _rebuild() -> void:
	_happiness_bonus.clear()
	_production_boost.clear()
	_upgrade_discount.clear()

	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		var type_id: String = bld.get("type", "") as String
		var level: int = bld.get("level", 0) as int
		var ldata: Dictionary = ContentDB.building_level_data(type_id, level)
		var syn: Dictionary = ldata.get("synergy", {})

		# Happiness aura (parks)
		var happiness_aura: float = syn.get("happiness_aura", 0.0) as float
		if happiness_aura > 0.0:
			var radius: int = syn.get("radius", 4) as int
			var base_happiness: float = ldata.get("happiness", 0.0) as float
			for cell: Vector2i in HexCoords.disk(coord, radius):
				_happiness_bonus[cell] = (_happiness_bonus.get(cell, 0.0) as float) + base_happiness * happiness_aura

		# Powered boost (power plants)
		var powered_boost: float = syn.get("powered_boost", 0.0) as float
		if powered_boost > 0.0:
			var radius: int = syn.get("radius", 6) as int
			for cell: Vector2i in HexCoords.disk(coord, radius):
				_production_boost[cell] = (_production_boost.get(cell, 0.0) as float) + powered_boost

		# Upgrade discount (workshops)
		var disc: float = syn.get("upgrade_discount", 0.0) as float
		if disc > 0.0:
			var radius: int = syn.get("radius", 3) as int
			for cell: Vector2i in HexCoords.disk(coord, radius):
				_upgrade_discount[cell] = (_upgrade_discount.get(cell, 0.0) as float) + disc
