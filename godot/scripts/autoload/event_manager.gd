extends Node
## EventManager (Autoload)
## Гибридная система событий по TDD.md:
##   ДЕНЬ: проверяет триггеры, копит события в pending_events.
##   ВЕЧЕР: передает массив в DeskUI для разбора.
##   Критические события (is_critical) ставят игру на паузу немедленно.

signal pin_spawned(coord: Vector2i, pin_type: String)
signal critical_event_fired(event_data: Dictionary)

var pending_events: Array = []
var _check_interval: float = 5.0
var _timer: float = 0.0
const DEFAULT_COOLDOWN_SEC := 300.0


func _ready() -> void:
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.desk_option_selected.connect(_on_option_selected)


func _process(delta: float) -> void:
	# Только днём проверяем триггеры
	if SimulationRunner.paused:
		return
	_tick_cooldowns(delta)
	_timer -= delta
	if _timer <= 0.0:
		_timer = _check_interval
		_check_triggers()


func _check_triggers() -> void:
	# Проверяем все события из ContentDB
	for event_id: String in ContentDB.get_event_ids():
		var def: Dictionary = ContentDB.get_event_def(event_id)
		if _is_already_pending(event_id):
			continue
		if _is_on_cooldown(event_id):
			continue
		# One-shot events (письма Койл, развилки) фаярятся ровно один раз за игру.
		if (def.get("once", false) as bool) and _has_fired(event_id):
			continue
		if _trigger_met(def):
			var event_data: Dictionary = def.duplicate(true)
			event_data["runtime_id"] = event_id
			
			# Критические события (ультиматум Лиги) — немедленная пауза
			if def.get("is_critical", false) as bool:
				SimulationRunner.paused = true
				critical_event_fired.emit(event_data)
			else:
				pending_events.append(event_data)


func _trigger_met(def: Dictionary) -> bool:
	# Пока упрощённая проверка: min_level и условие по ресурсам
	var min_level: int = def.get("min_level", 1) as int
	var current_level: int = GameStateStore.progression().get("city_level", 1) as int
	if current_level < min_level:
		return false

	# Дневной триггер: событие доступно только с N-го игрового дня (письма по срокам).
	if def.has("trigger_day"):
		var total_day: int = GameStateStore.climate().get("total_day", 1) as int
		if total_day < (def.get("trigger_day", 1) as int):
			return false
		# Если есть и условие — требуем оба; иначе достижение дня само по себе триггер.
		var day_cond: String = def.get("trigger_condition", "") as String
		if day_cond != "":
			return _evaluate_trigger(day_cond)
		return true

	# Проверка строковых триггеров из TDD (типа "stat_unrest_pressure >= 50")
	var trigger: String = def.get("trigger_condition", "") as String
	if trigger != "":
		return _evaluate_trigger(trigger)
	
	# Для старого формата — случайный шанс на основе pressure
	var pressure_min: int = def.get("pressure_phase_min", 0) as int
	var pressure_index: float = GameStateStore.pressure().get("index", 0.0) as float
	if pressure_index < float(pressure_min) * 25.0:
		return false
	
	# Случайный шанс (1% за проверку)
	return randf() < 0.01


func _evaluate_trigger(trigger: String) -> bool:
	# Парсим простые условия типа "res_water_stockpile == 0"
	# или "stat_unrest_pressure >= 50"
	if ">=" in trigger:
		var parts: PackedStringArray = trigger.split(">=")
		if parts.size() == 2:
			var val: float = _get_stat_value(parts[0].strip_edges())
			var threshold: float = parts[1].strip_edges().to_float()
			return val >= threshold
	elif "==" in trigger:
		var parts: PackedStringArray = trigger.split("==")
		if parts.size() == 2:
			var val: float = _get_stat_value(parts[0].strip_edges())
			var threshold: float = parts[1].strip_edges().to_float()
			return is_equal_approx(val, threshold)
	elif "<=" in trigger:
		var parts: PackedStringArray = trigger.split("<=")
		if parts.size() == 2:
			var val: float = _get_stat_value(parts[0].strip_edges())
			var threshold: float = parts[1].strip_edges().to_float()
			return val <= threshold
	return false


func _get_stat_value(stat_name: String) -> float:
	# Сначала проверяем ресурсы
	if stat_name.begins_with("res_"):
		return GameStateStore.get_resource(stat_name)
	# Потом статы из mandate/pressure
	match stat_name:
		"stat_unrest_pressure":
			return GameStateStore.pressure().get("index", 0.0) as float
		"stat_city_trust":
			return GameStateStore.mandate().get("support", 50) as float
		"stat_league_trust":
			return GameStateStore.mandate().get("patron_trust", 50) as float
		"stat_happiness":
			return GameStateStore.population().get("happiness", 50.0) as float
		"stat_population":
			return float(GameStateStore.population().get("total", 0) as int)
	return 0.0


func _is_already_pending(event_id: String) -> bool:
	for evt: Dictionary in pending_events:
		if evt.get("runtime_id", "") as String == event_id:
			return true
	return false


func _on_phase_changed(new_phase: String) -> void:
	if new_phase == "evening":
		# Передаём накопленные события в DeskUI
		EventBus.evening_started.emit(pending_events.duplicate())


func _on_option_selected(event_id: String, option_index: int, effects: Dictionary, cost: Dictionary) -> void:
	if not cost.is_empty() and not GameStateStore.spend(cost):
		EventBus.toast_requested.emit(Localization.t("ui.command.not_enough_resources", "Not enough resources"), 4.0)
		return
	_apply_effects(effects)
	_set_cooldown(event_id)
	# Убираем обработанное событие
	var idx: int = -1
	for i: int in pending_events.size():
		if pending_events[i].get("runtime_id", "") as String == event_id:
			idx = i
			break
	if idx >= 0:
		pending_events.remove_at(idx)
	# One-shot events never return once resolved.
	if ContentDB.get_event_def(event_id).get("once", false) as bool:
		_mark_fired(event_id)


func _apply_effects(effects: Dictionary) -> void:
	if effects.is_empty():
		return

	for key: String in effects:
		match key:
			"add_buff":
				var buff_raw: Variant = effects[key]
				if buff_raw is Dictionary:
					var buff := (buff_raw as Dictionary).duplicate(true)
					buff["name"] = Localization.content_text(buff, "name", buff.get("name", "") as String)
					GameStateStore.add_buff(buff)
			"add_resources":
				_apply_resource_delta(effects[key], 1.0)
			"remove_resources":
				_apply_resource_delta(effects[key], -1.0)
			"force_issues":
				_force_issues(effects[key] as int)
			"damage_buildings":
				_damage_random_buildings(effects[key] as int)
			"message":
				EventBus.toast_requested.emit(Localization.content_text(effects, "message", effects[key] as String), 5.0)
			_:
				if key.begins_with("res_"):
					GameStateStore.add_resource(key, effects[key] as float)
				elif key.begins_with("stat_"):
					_apply_stat_delta(key, effects[key] as float)


func _apply_resource_delta(raw: Variant, sign: float) -> void:
	if raw is not Dictionary:
		return
	for res_id: String in raw as Dictionary:
		GameStateStore.add_resource(res_id, sign * ((raw as Dictionary)[res_id] as float))


func _apply_stat_delta(stat_id: String, amount: float) -> void:
	match stat_id:
		"stat_city_trust":
			var mandate_state: Dictionary = GameStateStore.mandate()
			mandate_state["support"] = clampf((mandate_state.get("support", 50) as float) + amount, 0.0, 100.0)
		"stat_league_trust":
			var mandate_state: Dictionary = GameStateStore.mandate()
			mandate_state["patron_trust"] = clampf((mandate_state.get("patron_trust", 50) as float) + amount, 0.0, 100.0)
		"stat_unrest_pressure":
			var pressure_state: Dictionary = GameStateStore.pressure()
			pressure_state["index"] = clampf((pressure_state.get("index", 0.0) as float) + amount, 0.0, 100.0)


func _force_issues(count: int) -> void:
	var coords: Array = _pick_unique_coords(_candidate_problem_coords(true, true), count)
	for coord: Vector2i in coords:
		var bld: Dictionary = GameStateStore.get_building(coord)
		bld["has_issue"] = true
		GameStateStore.set_building(coord, bld)
		EventBus.building_issue_added.emit(coord)


func _damage_random_buildings(count: int) -> void:
	var coords: Array = _pick_unique_coords(_candidate_problem_coords(true, false), count)
	for coord: Vector2i in coords:
		var bld: Dictionary = GameStateStore.get_building(coord)
		bld["damaged"] = true
		GameStateStore.set_building(coord, bld)
		EventBus.building_damaged.emit(coord, 1.0)


func _candidate_problem_coords(skip_damaged: bool, skip_issues: bool) -> Array:
	var result: Array = []
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		var type_id: String = bld.get("type", "") as String
		if type_id == "road" or type_id == "bld_road":
			continue
		if skip_damaged and (bld.get("damaged", false) as bool):
			continue
		if skip_issues and (bld.get("has_issue", false) as bool):
			continue
		result.append(coord)
	return result


func _pick_unique_coords(candidates: Array, count: int) -> Array:
	var pool: Array = candidates.duplicate()
	var picked: Array = []
	while picked.size() < count and not pool.is_empty():
		var idx: int = randi() % pool.size()
		picked.append(pool[idx])
		pool.remove_at(idx)
	return picked


func _event_cooldowns() -> Dictionary:
	var ev_state: Dictionary = GameStateStore.events()
	if not ev_state.has("cooldowns"):
		ev_state["cooldowns"] = {}
	return ev_state["cooldowns"] as Dictionary


func _tick_cooldowns(delta: float) -> void:
	var cooldowns: Dictionary = _event_cooldowns()
	var expired: Array[String] = []
	for event_id: String in cooldowns:
		cooldowns[event_id] = (cooldowns[event_id] as float) - delta
		if (cooldowns[event_id] as float) <= 0.0:
			expired.append(event_id)
	for event_id: String in expired:
		cooldowns.erase(event_id)


func _is_on_cooldown(event_id: String) -> bool:
	return _event_cooldowns().has(event_id)


func _fired_events() -> Array:
	var ev_state: Dictionary = GameStateStore.events()
	if not ev_state.has("fired"):
		ev_state["fired"] = []
	return ev_state["fired"] as Array


func _has_fired(event_id: String) -> bool:
	return _fired_events().has(event_id)


func _mark_fired(event_id: String) -> void:
	var fired: Array = _fired_events()
	if not fired.has(event_id):
		fired.append(event_id)


func _set_cooldown(event_id: String) -> void:
	var def: Dictionary = ContentDB.get_event_def(event_id)
	_event_cooldowns()[event_id] = def.get("cooldown_sec", DEFAULT_COOLDOWN_SEC) as float


func clear_pending() -> void:
	pending_events.clear()
