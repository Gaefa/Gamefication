class_name ProductionMultiplier
## Aggregates all production modifiers for a building:
##   terrain bonus × road boost × coverage efficiency × synergy × buffs.

var _synergy: SynergyResolver
var _road_network: RoadNetwork
var _coverage: CoverageMap


func _init(synergy: SynergyResolver, road_network: RoadNetwork, coverage: CoverageMap) -> void:
	_synergy = synergy
	_road_network = road_network
	_coverage = coverage


func compute(coord: Vector2i) -> Dictionary:
	## Returns {resource_id: final_multiplier} for all resources this building produces.
	var bld: Dictionary = GameStateStore.get_building(coord)
	if bld.is_empty():
		return {}
	var type_id: String = bld.get("type", "") as String
	var level: int = bld.get("level", 0) as int
	var ldata: Dictionary = ContentDB.building_level_data(type_id, level)
	var produces: Dictionary = ldata.get("produces", {})
	if produces.is_empty():
		return {}

	# Base multipliers
	var terrain_mult: float = _terrain_bonus(coord, type_id)
	var road_mult: float = 1.0 + _road_network.road_boost_at(coord)
	var road_eff: float = _coverage.road_efficiency(coord)
	var water_eff: float = _coverage.water_efficiency(coord)

	# Synergy multipliers (per resource)
	var syn_mults: Dictionary = _synergy.get_production_multiplier(coord, type_id)

	# Buff multiplier
	var buff_mult: float = _buff_multiplier(type_id)

	var result: Dictionary = {}
	for res_id: String in produces:
		var base: float = terrain_mult * road_mult * road_eff * water_eff * buff_mult
		var syn: float = syn_mults.get(res_id, 1.0) as float
		result[res_id] = base * syn

	return result


func _terrain_bonus(coord: Vector2i, type_id: String) -> float:
	var def: Dictionary = ContentDB.get_building_def(type_id)
	var terrain_bonus: Dictionary = def.get("terrain_bonus", {})
	if terrain_bonus.is_empty():
		return 1.0
	var terrain_id: int = GameStateStore.get_terrain(coord)
	var bonus: float = terrain_bonus.get(str(terrain_id), 0.0) as float
	return 1.0 + bonus


func _buff_multiplier(type_id: String) -> float:
	var mult: float = 1.0
	for buff: Dictionary in GameStateStore.get_buffs():
		var target: String = buff.get("target", "") as String
		if target == "" or target == type_id:
			mult *= buff.get("multiplier", 1.0) as float
	return mult
