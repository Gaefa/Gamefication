class_name ProgressionSystem
## Updates population, happiness, checks city level advancement, and win conditions.

var _aura_cache: AuraCache
var _notified_upgrade_level: int = 0

# --- Population retention (tuning) ---
const OUTFLOW_RATE := 0.0012    # fraction of capacity that leaves per tick under duress
const INFLOW_RATE := 0.0006     # fraction of the empty gap that fills per tick when content
const MISERY_HAPPINESS := 25.0  # below this people start leaving even if fed
const CONTENT_HAPPINESS := 55.0 # at/above this newcomers arrive to fill housing
const HAPPINESS_SMOOTH := 0.04  # per-tick easing toward target; damps scarcity jitter


func _init(aura_cache: AuraCache) -> void:
	_aura_cache = aura_cache


func process_tick() -> void:
	_update_population()
	_update_happiness()
	_check_level_up()
	_check_win_condition()
	_record_history()


func _update_population() -> void:
	# Housing gives a capacity ceiling; the actual resident count drifts toward it.
	# People leave under duress (famine, thirst, misery) and arrive when the city is
	# content. This gives Пыль an irreversible cost and feeds the exodus/riot endings.
	var capacity: int = 0
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		if bld.get("damaged", false) as bool:
			continue
		var type_id: String = bld.get("type", "") as String
		var level: int = bld.get("level", 0) as int
		var ldata: Dictionary = ContentDB.building_level_data(type_id, level)
		capacity += ldata.get("population", 0) as int

	var pop_state: Dictionary = GameStateStore.population()
	var residents: float = pop_state.get("residents", float(capacity)) as float
	if not pop_state.has("residents"):
		residents = float(capacity)  # a freshly-settled district starts full

	var food: float = GameStateStore.get_resource("res_food")
	var water: float = GameStateStore.get_resource("res_water_stockpile")
	var happiness: float = pop_state.get("happiness", 50.0) as float
	var under_duress: bool = food <= 0.0 or water <= 0.0 or happiness < MISERY_HAPPINESS

	if under_duress:
		residents -= float(capacity) * OUTFLOW_RATE
	elif residents < float(capacity) and happiness >= CONTENT_HAPPINESS:
		residents += (float(capacity) - residents) * INFLOW_RATE
	residents = clampf(residents, 0.0, float(capacity))

	pop_state["residents"] = residents
	pop_state["capacity"] = capacity
	var total: int = int(round(residents))
	var prev: int = pop_state.total as int
	pop_state.total = total
	if total != prev:
		EventBus.population_changed.emit(total)


func _update_happiness() -> void:
	var total_happiness: float = 0.0
	var bld_count: int = 0
	var dark_housing: int = 0
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
		# Dark housing (shed by the power director) drags morale — the "кому свет" cost.
		if (ldata.get("population", 0) as int) > 0 and not (bld.get("powered", true) as bool):
			dark_housing += 1

	# Apply happiness from active buffs (happiness_add from events)
	var buff_happiness: float = 0.0
	for buff: Dictionary in GameStateStore.get_buffs():
		buff_happiness += buff.get("happiness_add", 0.0) as float
	var governance_happiness: float = _governance_happiness_add()

	# Happiness = base 50 + building happiness + buffs + governance + supply, clamped 0-100.
	# Supply term ties happiness to water/food (GDD §11.3): thirst/hunger drives people
	# down, comfortable reserves lift them. This is what powers petitions, strikes,
	# thanks, the pressure director and the audit's "are people staying" check.
	var supply_term: float = _supply_happiness_term()
	var power_term: float = float(dark_housing) * -6.0
	var target: float = clampf(50.0 + total_happiness * 0.1 + buff_happiness + governance_happiness + supply_term + power_term, 0.0, 100.0)
	# Ease happiness toward the target instead of snapping. At the scarcity boundary the
	# instantaneous supply term jitters tick-to-tick (food produced then eaten); a mood
	# is slow-moving, so this low-pass filter turns that jitter into a steady slide.
	var prev: float = GameStateStore.population().happiness as float
	var happiness: float = lerpf(prev, target, HAPPINESS_SMOOTH)
	GameStateStore.population().happiness = happiness
	if absf(happiness - prev) > 0.5:
		EventBus.happiness_changed.emit(happiness)


func _supply_happiness_term() -> float:
	## Water/food effect on happiness. Empty stores hurt a lot; a draining trend hurts
	## some; comfortable reserves help; a fully-provisioned city is "thriving".
	var prod: Dictionary = GameStateStore.economy().get("production", {})
	var term: float = 0.0

	var water: float = GameStateStore.get_resource("res_water_stockpile")
	var water_cap: float = maxf(GameStateStore.get_cap("res_water_stockpile"), 1.0)
	var water_net: float = prod.get("res_water_stockpile", 0.0) as float
	if water <= 1.0:
		term -= 30.0
	elif water_net < 0.0:
		term -= 12.0
	elif water >= 0.5 * water_cap:
		term += 6.0

	var food: float = GameStateStore.get_resource("res_food")
	var food_cap: float = maxf(GameStateStore.get_cap("res_food"), 1.0)
	var food_net: float = prod.get("res_food", 0.0) as float
	if food <= 1.0:
		term -= 30.0
	elif food_net < 0.0:
		term -= 10.0
	elif food >= 0.5 * food_cap:
		term += 6.0

	# Thriving: both comfortably stocked and not draining.
	if water > 0.5 * water_cap and food > 0.5 * food_cap and water_net >= 0.0 and food_net >= 0.0:
		term += 12.0

	return term


func _governance_happiness_add() -> float:
	var total := 0.0
	for tech_var: Variant in GameStateStore.get_technologies():
		var tech_id: String = tech_var as String
		var tech_def: Dictionary = ContentDB.get_technology_def(tech_id)
		var effects: Dictionary = tech_def.get("effects", {})
		total += effects.get("happiness_add", 0.0) as float
	for policy_var: Variant in GameStateStore.get_active_policies().values():
		var policy_id: String = policy_var as String
		var policy_def: Dictionary = ContentDB.get_policy_def(policy_id)
		var effects: Dictionary = policy_def.get("effects", {})
		total += effects.get("happiness_add", 0.0) as float
	var mandate_effects: Dictionary = GameStateStore.mandate().get("effects", {})
	total += mandate_effects.get("happiness_add", 0.0) as float
	return total


func _check_level_up() -> void:
	var current_level: int = GameStateStore.progression().city_level as int
	var next_level: int = current_level + 1
	var def: Dictionary = ContentDB.get_level_def(next_level)
	if def.is_empty():
		return

	# city_levels.json format: {level, name, requirements: {res: amount} or null, reward}
	var reqs_raw: Variant = def.get("requirements", null)
	if reqs_raw == null or not (reqs_raw is Dictionary):
		# null requirements = free level up (only level 1 should have this, and we start at 1)
		# Don't auto-level — level 1 is the starting level
		return

	var reqs: Dictionary = reqs_raw as Dictionary
	if reqs.is_empty():
		return

	# Check if player can afford ALL required resources
	for res_id: String in reqs:
		var required: float = reqs[res_id] as float
		if GameStateStore.get_resource(res_id) < required:
			if _notified_upgrade_level == next_level:
				_notified_upgrade_level = 0
			return

	if _notified_upgrade_level == next_level:
		return
	_notified_upgrade_level = next_level
	EventBus.toast_requested.emit(
		Localization.t("ui.progress.city_upgrade_ready", "City upgrade available: %s (level %d)")
			% [Localization.content_text(def, "name", "?"), next_level],
		5.0
	)


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
		"res_money": GameStateStore.get_resource("res_money"),
		"city_level": GameStateStore.progression().city_level,
	}
	(GameStateStore.progression().history as Array).append(entry)
