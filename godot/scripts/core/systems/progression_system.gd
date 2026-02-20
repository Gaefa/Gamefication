class_name ProgressionSystem

static func process_tick(state: Dictionary, hex_grid: HexGrid, spatial_index: SpatialIndex, aura_cache: AuraCache) -> void:
	var stats := EconomySystem.compute_passive_stats(state, hex_grid, spatial_index, aura_cache)
	state.population["happiness"] = stats.happiness
	state.population["pop_cap"] = stats.pop_cap
	# Population growth
	if state.population.total < stats.pop_cap and state.economy.resources.get("food", 0.0) > 0:
		var growth: float = clampf(float(stats.happiness) / 260.0, 0.05, 0.8)
		state.population["total"] = minf(float(stats.pop_cap), state.population.total + growth)
	if state.population.total > stats.pop_cap:
		state.population["total"] = maxf(float(stats.pop_cap), state.population.total - 0.2)
	# Happiness penalty decay
	if state.events.get("happiness_penalty_ticks", 0) > 0:
		state.events["happiness_penalty_ticks"] -= 1
	# Win conditions
	var c1: bool = state.progression.city_level >= 7
	var c2: bool = state.progression.prestige_count >= 1
	var c3: bool = state.progression.prestige_stars >= 3 and state.economy.resources.get("fame", 0.0) >= 1000
	if c1 and not state.progression.get("win_unlocked_at", 0):
		state.progression["win_unlocked_at"] = int(Time.get_unix_time_from_system())
	if c1 and c2 and c3 and not state.progression.get("has_ultimate_win", false):
		state.progression["has_ultimate_win"] = true
		EventBus.message_posted.emit("Ultimate win condition completed!", 5.0)
	# History recording
	state.meta["play_time_seconds"] = state.meta.get("play_time_seconds", 0) + 1
	if state.meta.play_time_seconds % 30 == 0:
		var history: Array = state.meta.get("history", [])
		history.append({"t": state.meta.play_time_seconds, "pop": int(state.population.total), "happy": stats.happiness, "coins": int(state.economy.resources.get("coins", 0)), "food": int(state.economy.resources.get("food", 0))})
		if history.size() > 200:
			history.pop_front()
		state.meta["history"] = history
