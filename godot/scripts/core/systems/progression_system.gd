## progression_system.gd -- Population growth/shrink, happiness calculation,
## win condition evaluation, and history recording.
class_name ProgressionSystem

static func process_tick(state: Dictionary, hex_grid: HexGrid, spatial_index: SpatialIndex, aura_cache: AuraCache) -> void:
	var economy: Dictionary = state.get("economy", {})
	var population: Dictionary = state.get("population", {})
	var progression: Dictionary = state.get("progression", {})
	var events_dict: Dictionary = state.get("events", {})
	var meta: Dictionary = state.get("meta", {})
	var resources: Dictionary = economy.get("resources", {})

	# Compute passive stats (pop_cap, happiness, issues)
	var stats: Dictionary = EconomySystem.compute_passive_stats(economy, state, hex_grid, spatial_index)
	var pop_cap: int = int(stats.get("pop_cap", 0))
	var happiness: int = int(stats.get("happiness", 50))

	population["happiness"] = happiness
	population["pop_cap"] = pop_cap

	# Population growth
	var current_pop: float = float(population.get("total", 0))
	if current_pop < float(pop_cap) and float(resources.get("food", 0.0)) > 0.0:
		var growth: float = clampf(float(happiness) / 260.0, 0.05, 0.8)
		population["total"] = minf(float(pop_cap), current_pop + growth)
	elif current_pop > float(pop_cap):
		population["total"] = maxf(float(pop_cap), current_pop - 0.2)

	# Happiness penalty decay
	if int(events_dict.get("happiness_penalty_ticks", 0)) > 0:
		events_dict["happiness_penalty_ticks"] = int(events_dict.get("happiness_penalty_ticks", 0)) - 1

	# Win conditions
	var city_level: int = int(progression.get("city_level", 1))
	var prestige_stars: int = int(progression.get("prestige_stars", 0))
	var total_prestiges: int = int(progression.get("total_prestiges", 0))
	var fame: float = float(resources.get("fame", 0.0))

	var c1: bool = city_level >= 7
	var c2: bool = total_prestiges >= 1
	var c3: bool = prestige_stars >= 3 and fame >= 1000.0

	if c1 and not progression.get("win_unlocked_at", false):
		progression["win_unlocked_at"] = int(Time.get_unix_time_from_system())
	if c1 and c2 and c3 and not progression.get("has_ultimate_win", false):
		progression["has_ultimate_win"] = true
		EventBus.message_posted.emit("Ultimate win condition completed!", 5.0)

	# History recording (every 30 seconds of play time)
	var play_time: int = int(meta.get("play_time", 0))
	if play_time > 0 and play_time % 30 == 0:
		var history: Array = meta.get("history", [])
		history.append({
			"t": play_time,
			"pop": int(population.get("total", 0)),
			"happy": happiness,
			"coins": int(resources.get("coins", 0)),
			"food": int(resources.get("food", 0)),
		})
		if history.size() > 200:
			history.pop_front()
		meta["history"] = history
