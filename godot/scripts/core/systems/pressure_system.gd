class_name PressureSystem
## RimWorld-style pressure director.
## Calculates a 0-100 pressure index based on city state.
## Higher pressure → more/harder events.

func process_tick() -> void:
	var pressure_state: Dictionary = GameStateStore.pressure()
	var index: float = _calculate_index()
	pressure_state.index = clampf(index, 0.0, 100.0)
	pressure_state.phase = _index_to_phase(index)
	EventBus.pressure_updated.emit(pressure_state.index, pressure_state.phase as String)


func _calculate_index() -> float:
	var city_scale: float = _city_scale_score()
	var deficit: float = _deficit_score()
	var unrest: float = _unrest_score()
	var fragility: float = _fragility_score()
	return city_scale * 0.25 + deficit * 0.3 + unrest * 0.25 + fragility * 0.2


func _city_scale_score() -> float:
	## Larger city = higher base pressure.
	var pop: int = GameStateStore.population().total as int
	var level: int = GameStateStore.progression().city_level as int
	var bld_count: int = GameStateStore.get_all_building_coords().size()
	return clampf(pop * 0.02 + level * 5.0 + bld_count * 0.1, 0.0, 100.0)


func _deficit_score() -> float:
	## Negative production in key resources raises pressure.
	var score: float = 0.0
	var production: Dictionary = GameStateStore.economy().production
	var key_resources: Array = ["food", "coins", "energy", "water_res"]
	for res_id: String in key_resources:
		var net: float = production.get(res_id, 0.0) as float
		if net < 0.0:
			score += absf(net) * 5.0
	return clampf(score, 0.0, 100.0)


func _unrest_score() -> float:
	## Low happiness increases pressure.
	var happiness: float = GameStateStore.population().happiness as float
	if happiness >= 60.0:
		return 0.0
	return (60.0 - happiness) * 1.5


func _fragility_score() -> float:
	## Damaged buildings increase fragility.
	var damaged: int = 0
	var total: int = 0
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		total += 1
		var bld: Dictionary = GameStateStore.get_building(coord)
		if bld.get("damaged", false) as bool or bld.get("has_issue", false) as bool:
			damaged += 1
	if total == 0:
		return 0.0
	return (float(damaged) / float(total)) * 100.0


func _index_to_phase(index: float) -> String:
	if index < 25.0:
		return "calm"
	elif index < 50.0:
		return "tension"
	elif index < 75.0:
		return "crisis"
	else:
		return "emergency"
