extends Node
## EventManager (Autoload)
## Гибридная система событий по TDD.md:
##   ДЕНЬ: проверяет триггеры, копит события в pending_events.
##   ВЕЧЕР: передает массив в DeskUI для разбора.
##   Критические события (is_critical) ставят игру на паузу немедленно.


## Cards waiting for the evening desk. They live in the run state, so they ride the save
## and a new run (or a load) never inherits the previous run's letters.
var pending_events: Array:
	get:
		var ev_state: Dictionary = GameStateStore.events()
		if not ev_state.has("pending"):
			ev_state["pending"] = []
		return ev_state["pending"] as Array
## Cooldowns are in game seconds (ticks at ×1): 300 = one game day. They follow the game
## speed, so a repeatable petition returns after the same number of days at ×1 and ×3.
const DEFAULT_COOLDOWN_SEC := 900.0


func _ready() -> void:
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.desk_option_selected.connect(_on_option_selected)
	EventBus.pressure_threshold_reached.connect(_on_pressure_threshold)
	EventBus.tick_finished.connect(_on_tick_finished)


## Driven by the simulation tick, so cooldowns and polling follow game time exactly — the
## same at ×1 and ×5, and at any frame rate. The poll phase rides the save along with the
## cooldowns, so neither speed nor a load can reorder the mail.
func _on_tick_finished(_tick: int) -> void:
	# Только днём проверяем триггеры
	if not SimulationRunner.is_running():
		return
	_tick_cooldowns(SimulationRunner.TICK_INTERVAL)
	var state: Dictionary = GameStateStore.events()
	var polls: int = (state.get("poll_ticks", 0) as int) + 1
	state["poll_ticks"] = polls
	if polls % 5 == 1 and not SimulationRunner.card_open:
		_check_triggers()


func _check_triggers() -> void:
	# Проверяем все события из ContentDB
	for event_id: String in ContentDB.get_event_ids():
		var def: Dictionary = ContentDB.get_event_def(event_id)
		if _is_already_pending(event_id):
			continue
		if _is_on_cooldown(event_id):
			continue
		# Patron-specific events (письма покровителя) fire only under that patron.
		var event_patron: String = def.get("patron", "") as String
		if event_patron != "" and event_patron != (GameStateStore.mandate().get("patron_id", "") as String):
			continue
		# One-shot events (письма Койл, развилки) фаярятся ровно один раз за игру.
		if (def.get("once", false) as bool) and _has_fired(event_id):
			continue
		if _patronless_skip(def):
			continue
		# Pressure-driven crises are raised by the pressure director, not polled (GDD §15);
		# replies and debts ("callback" cards) come only when another card or a timer calls them.
		if (def.get("driver", "") as String) == "pressure" or (def.get("callback", false) as bool):
			continue
		if _trigger_met(def):
			_raise(event_id, def)


## Patron business (letters, sanctions, the recall ultimatum) never reaches a founder,
## who has no patron. The Forecaster quest is filed under "mandate" but is the district's own.
func _patronless_skip(def: Dictionary) -> bool:
	if (GameStateStore.mandate().get("patron_id", "") as String) != "":
		return false
	return (def.get("category", "") as String) == "mandate" and not (def.get("id", "") as String).begins_with("quest.")


func _raise(event_id: String, def: Dictionary) -> void:
	var event_data: Dictionary = def.duplicate(true)
	event_data["runtime_id"] = event_id
	# Критические события (ультиматум Лиги) — немедленная пауза и карточка,
	# не дожидаясь вечернего Стола (GDD §3.2: срочное не ждёт Стола).
	if def.get("is_critical", false) as bool:
		SimulationRunner.paused = true
		EventBus.critical_event_started.emit(event_data)
	else:
		pending_events.append(event_data)


func _on_pressure_threshold(category: String) -> void:
	# Seasonal crises get first refusal; generic crises remain the fallback.
	var ids: Array = []
	var generic: Array = []
	for id: String in ContentDB.get_event_ids():
		if ContentDB.get_event_def(id).has("season"):
			ids.append(id)
		else:
			generic.append(id)
	ids.append_array(generic)
	for event_id: String in ids:
		var def: Dictionary = ContentDB.get_event_def(event_id)
		if (def.get("driver", "") as String) != "pressure" or (def.get("category", "") as String) != category:
			continue
		if _is_already_pending(event_id) or _is_on_cooldown(event_id):
			continue
		if (def.get("once", false) as bool) and _has_fired(event_id):
			continue
		var event_patron: String = def.get("patron", "") as String
		if event_patron != "" and event_patron != (GameStateStore.mandate().get("patron_id", "") as String):
			continue
		if not _season_met(def) or not _flags_met(def):
			continue
		_raise(event_id, def)
		# The crisis landed: drop the category back only partway — the cause keeps pushing (§15.3).
		var pressure_state: Dictionary = GameStateStore.pressure()
		var cats: Dictionary = pressure_state.get("categories", {}) as Dictionary
		cats[category] = PressureSystem.RESET_TO
		# The first thing that broke is what the finale names as the root (EndingManager theses).
		if not pressure_state.has("first_crisis"):
			pressure_state["first_crisis"] = { "category": category, "day": GameStateStore.climate().get("total_day", 1) as int }
		return


func _season_met(def: Dictionary) -> bool:
	return not def.has("season") or def["season"] == GameStateStore.climate().get("season_id", "")


## A card can wait for an earlier decision (requires_flag), stay away after one
## (excludes_flag) or come only to a player of a certain style (requires_style).
func _flags_met(def: Dictionary) -> bool:
	var flags: Dictionary = GameStateStore.mandate().get("flags", {}) as Dictionary
	for flag: String in _as_list(def.get("requires_flag", [])):
		if not (flags.get(flag, false) as bool):
			return false
	for flag: String in _as_list(def.get("excludes_flag", [])):
		if flags.get(flag, false) as bool:
			return false
	if def.has("requires_style") and GameStateStore.dominant_style("") != (def.get("requires_style", "") as String):
		return false
	return true


func _as_list(value: Variant) -> Array:
	if value is Array:
		return value as Array
	if value is String and (value as String) != "":
		return [value]
	return []


## Another card wants this one raised now (a reply to an answer, a debt called in).
func raise_event(event_id: String) -> void:
	var def: Dictionary = ContentDB.get_event_def(event_id)
	if def.is_empty() or _is_already_pending(event_id):
		return
	if (def.get("once", false) as bool) and _has_fired(event_id):
		return
	_raise(event_id, def)


func _trigger_met(def: Dictionary) -> bool:
	if not _season_met(def) or not _flags_met(def):
		return false
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
	return _rng_chance(0.01)


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
	elif ">" in trigger:
		var parts: PackedStringArray = trigger.split(">")
		if parts.size() == 2:
			return _get_stat_value(parts[0].strip_edges()) > parts[1].strip_edges().to_float()
	elif "<" in trigger:
		var parts: PackedStringArray = trigger.split("<")
		if parts.size() == 2:
			return _get_stat_value(parts[0].strip_edges()) < parts[1].strip_edges().to_float()
	push_warning("EventManager: cannot read trigger '%s'" % trigger)
	return false


func _get_stat_value(stat_name: String) -> float:
	# Сначала проверяем ресурсы
	if stat_name.begins_with("res_"):
		return GameStateStore.get_resource(stat_name)
	# Потом статы из mandate/pressure
	match stat_name:
		"stat_unrest_pressure":
			return (GameStateStore.pressure().get("categories", {}) as Dictionary).get("happiness", 0.0) as float
		"stat_city_trust":
			return GameStateStore.mandate().get("support", 50) as float
		"stat_league_trust":
			return GameStateStore.mandate().get("patron_trust", 50) as float
		"stat_happiness":
			return GameStateStore.population().get("happiness", 50.0) as float
		"stat_population":
			return float(GameStateStore.population().get("total", 0) as int)
		"stat_low_pressure_housing":
			return float(GameStateStore.population().get("low_pressure_housing", 0) as int)
		"stat_rival_score":
			return RivalManager.rival_score()
		"stat_rival_gap":
			return RivalManager.player_score() - RivalManager.rival_score()  # negative: behind the neighbour
		"stat_water_days":
			var days: float = EconomySystem.days_of("res_water_stockpile")
			return 999.0 if is_inf(days) else days
		"stat_day":
			return float(GameStateStore.climate().get("total_day", 1) as int)
	push_warning("EventManager: unknown stat '%s' in a trigger" % stat_name)
	return 0.0


func _is_already_pending(event_id: String) -> bool:
	for evt: Dictionary in pending_events:
		if evt.get("runtime_id", "") as String == event_id:
			return true
	return false


func _on_phase_changed(new_phase: String) -> void:
	if new_phase == "evening":
		# Передаём накопленные события в DeskUI
		EventBus.evening_started.emit(_evening_mail())


const MAX_CARDS_PER_EVENING := 3
const MAX_CARDS_HARD_SEASON := 4  # the Dust and the Heat bring replies and debts on top of the mail


## Tonight's mail: at most three cards (four in a hard season), crises first, then the
## patron's letters, then petitions. Whatever does not fit stays in the queue for tomorrow,
## so a bad day never buries the player under a stack of paper.
func _evening_mail() -> Array:
	var mail: Array = pending_events.duplicate()
	mail.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _mail_rank(a) < _mail_rank(b))  # stable enough: ranks differ by kind only
	var limit: int = MAX_CARDS_PER_EVENING if (GameStateStore.climate().get("season_id", "") as String) == "season_window" else MAX_CARDS_HARD_SEASON
	return mail.slice(0, limit)


func _mail_rank(evt: Dictionary) -> int:
	var id: String = evt.get("runtime_id", "") as String
	if id.begins_with("crisis."):
		return 0
	if id.begins_with("patron.") or id.begins_with("rival."):
		return 1
	return 2


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


## People brought in by a card move into whatever served housing is free; the rest go on.
func _add_residents(count: int) -> void:
	var pop_state: Dictionary = GameStateStore.population()
	var residents: float = pop_state.get("residents", float(pop_state.get("total", 0))) as float
	var room: float = float(pop_state.get("served", pop_state.get("capacity", 0)))
	pop_state["residents"] = clampf(residents + float(count), 0.0, maxf(room, residents))
	pop_state["total"] = int(round(pop_state["residents"] as float))


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
			"add_residents":
				_add_residents(effects[key] as int)
			"remove_resources":
				_apply_resource_delta(effects[key], -1.0)
			"force_issues":
				_force_issues(effects[key] as int)
			"damage_buildings":
				_damage_random_buildings(effects[key] as int)
			"message":
				EventBus.toast_requested.emit(Localization.content_text(effects, "message", effects[key] as String), 5.0)
			"set_flag":
				_set_mandate_flag(effects[key] as String)
			"clear_flag":
				(GameStateStore.mandate().get("flags", {}) as Dictionary).erase(effects[key] as String)
			"set_policy":
				# A card can impose a policy outright (a patron's order); the lock below keeps it.
				var policy_def: Dictionary = ContentDB.get_policy_def(effects[key] as String)
				if not policy_def.is_empty():
					GameStateStore.set_active_policy(policy_def.get("category", "general") as String, effects[key] as String)
			"lock_policy_days":
				var locked_policy: Dictionary = ContentDB.get_policy_def(effects.get("set_policy", "") as String)
				if not locked_policy.is_empty():
					var locks: Dictionary = GameStateStore.governance().get("policy_locks", {}) as Dictionary
					locks[locked_policy.get("category", "general") as String] = (GameStateStore.climate().get("total_day", 1) as int) + (effects[key] as int)
					GameStateStore.governance()["policy_locks"] = locks
			"raise_event":
				raise_event(effects[key] as String)
			"style":
				GameStateStore.add_style_flag(effects[key] as String)
			"demolish_building":
				_demolish_building(effects[key] as String)
			"replace_building":
				var swap: Dictionary = effects[key] as Dictionary
				_replace_building(swap.get("from", "") as String, swap.get("to", "") as String)
			_:
				if key.begins_with("res_"):
					GameStateStore.add_resource(key, effects[key] as float)
				elif key.begins_with("stat_"):
					_apply_stat_delta(key, effects[key] as float)


func _set_mandate_flag(flag_id: String) -> void:
	if flag_id == "":
		return
	var mandate_state: Dictionary = GameStateStore.mandate()
	if not mandate_state.has("flags"):
		mandate_state["flags"] = {}
	(mandate_state["flags"] as Dictionary)[flag_id] = true


const NO_COORD := Vector2i(-9999, -9999)


func _orchestrator() -> GameOrchestrator:
	var scene: Node = get_tree().current_scene
	if scene != null and scene.has_method("get_orchestrator"):
		return scene.call("get_orchestrator") as GameOrchestrator
	return null


func _first_coord_of_type(type_id: String) -> Vector2i:
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		if (GameStateStore.get_building(coord).get("type", "") as String) == type_id:
			return coord
	return NO_COORD


func _demolish_building(type_id: String) -> void:
	# Decisions can change the map (e.g. the old tower's fate). Reuse the bulldoze path
	# so the spatial index, caches and rendering stay consistent.
	var coord: Vector2i = _first_coord_of_type(type_id)
	var orch: GameOrchestrator = _orchestrator()
	if coord == NO_COORD or orch == null:
		push_warning("EventManager: cannot demolish %s" % type_id)
		return
	orch.command_bus.execute(BulldozeCommand.new(coord, true))


func _replace_building(from_type: String, to_type: String) -> void:
	var coord: Vector2i = _first_coord_of_type(from_type)
	var orch: GameOrchestrator = _orchestrator()
	if coord == NO_COORD or orch == null or ContentDB.get_building_def(to_type).is_empty():
		push_warning("EventManager: cannot replace %s → %s" % [from_type, to_type])
		return
	GameStateStore.set_building(coord, {"type": to_type, "level": 0, "damaged": false, "has_issue": false})
	orch.spatial.remove(coord, from_type)
	orch.spatial.add(coord, to_type)
	orch.interactions.invalidate_caches()
	orch.coverage.invalidate()
	EventBus.building_removed.emit(coord, from_type)
	EventBus.building_placed.emit(coord, to_type)


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
		"stat_rival_score":
			var rival_state: Dictionary = GameStateStore.rival()
			rival_state["score"] = clampf((rival_state.get("score", 55.0) as float) + amount, 0.0, 100.0)
		"stat_unrest_pressure":
			# Unrest effects (suppression +, relief −) now land in the persistent people
			# accumulator; before, the per-tick index recompute silently erased them.
			var pressure_state: Dictionary = GameStateStore.pressure()
			if not pressure_state.has("categories"):
				pressure_state["categories"] = {}
			var cats: Dictionary = pressure_state["categories"] as Dictionary
			cats["happiness"] = clampf((cats.get("happiness", 0.0) as float) + amount, 0.0, 100.0)


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
	var orch: GameOrchestrator = _orchestrator()
	if orch != null:
		orch.coverage.invalidate()  # a broken pump stops covering its radius


func _candidate_problem_coords(skip_damaged: bool, skip_issues: bool) -> Array:
	var result: Array = []
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		var type_id: String = bld.get("type", "") as String
		if type_id == "road" or type_id == "bld_road" or ContentDB.is_inert_landmark(type_id):
			continue  # a ruin cannot "run at half strength"; IssueSystem skips them too
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
		var idx: int = _rng_index(pool.size())
		picked.append(pool[idx])
		pool.remove_at(idx)
	return picked


## Event randomness draws from the run's seeded generator, so a load replays it exactly.
func _rng_chance(probability: float) -> bool:
	var orch: GameOrchestrator = _orchestrator()
	if orch == null:
		return randf() < probability
	var hit: bool = orch.rng.chance(probability)
	GameStateStore.save_meta().rng_state = orch.rng.get_state()  # a save between draws replays the same cards
	return hit


func _rng_index(size: int) -> int:
	var orch: GameOrchestrator = _orchestrator()
	if orch == null:
		return randi() % size
	var index: int = orch.rng.range_int(0, size)
	GameStateStore.save_meta().rng_state = orch.rng.get_state()
	return index


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
