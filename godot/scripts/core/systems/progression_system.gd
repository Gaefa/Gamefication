class_name ProgressionSystem
## Updates population, happiness, checks city level advancement, and win conditions.

var _aura_cache: AuraCache


func _init(aura_cache: AuraCache) -> void:
	_aura_cache = aura_cache


func process_tick() -> void:
	_update_population()
	_update_happiness()
	_check_level_up()
	_check_win_condition()
	_record_history()


func _update_population() -> void:
	var total: int = 0
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		if bld.get("damaged", false) as bool:
			continue
		var type_id: String = bld.get("type", "") as String
		var level: int = bld.get("level", 0) as int
		var ldata: Dictionary = ContentDB.building_level_data(type_id, level)
		total += ldata.get("population", 0) as int

	var prev: int = GameStateStore.population().total as int
	GameStateStore.population().total = total
	if total != prev:
		EventBus.population_changed.emit(total)


func _update_happiness() -> void:
	var total_happiness: float = 0.0
	var bld_count: int = 0
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		if bld.get("damaged", false) as bool:
			continue
		var type_id: String = bld.get("type", "") as String
		var level: int = bld.get("level", 0) as int
		var ldata: Dictionary = ContentDB.building_level_data(type_id, level)

		var base_h: float = ldata.get("happiness", 0.0) as float
		var aura_h: float = _aura_cache.get_happiness_bonus(coord)
		total_happiness += base_h + aura_h
		bld_count += 1

	# Happiness = base 50 + building happiness, clamped 0-100
	var happiness: float = clampf(50.0 + total_happiness * 0.1, 0.0, 100.0)
	var prev: float = GameStateStore.population().happiness as float
	GameStateStore.population().happiness = happiness
	if absf(happiness - prev) > 0.5:
		EventBus.happiness_changed.emit(happiness)


func _check_level_up() -> void:
	var current_level: int = GameStateStore.progression().city_level as int
	var next_level: int = current_level + 1
	var def: Dictionary = ContentDB.get_level_def(next_level)
	if def.is_empty():
		return

	var reqs: Dictionary = def.get("requirements", {})
	var pop: int = GameStateStore.population().total as int
	var req_pop: int = reqs.get("population", 0) as int
	if pop < req_pop:
		return

	var req_res: Dictionary = reqs.get("resources", {})
	for res_id: String in req_res:
		if GameStateStore.get_resource(res_id) < (req_res[res_id] as float):
			return

	# All requirements met — level up!
	GameStateStore.progression().city_level = next_level
	EventBus.city_level_changed.emit(next_level)
	EventBus.toast_requested.emit("City advanced to level %d!" % next_level, 5.0)


func _check_win_condition() -> void:
	var max_levels: int = ContentDB.city_levels.size()
	if (GameStateStore.progression().city_level as int) >= max_levels:
		EventBus.win_condition_met.emit()


func _record_history() -> void:
	var tick: int = GameStateStore.get_tick()
	if tick % 60 != 0:
		return
	var entry: Dictionary = {
		"tick": tick,
		"population": GameStateStore.population().total,
		"happiness": GameStateStore.population().happiness,
		"coins": GameStateStore.get_resource("coins"),
		"city_level": GameStateStore.progression().city_level,
	}
	(GameStateStore.progression().history as Array).append(entry)
