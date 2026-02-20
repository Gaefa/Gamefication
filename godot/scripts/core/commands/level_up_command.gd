class_name LevelUpCommand
extends CommandBase

func execute(state: Dictionary, hex_grid: HexGrid, spatial_index: SpatialIndex) -> bool:
	var current_level: int = state.progression.city_level
	var levels: Array = ContentDB.get_city_levels()
	var next_entry: Dictionary = {}
	for entry in levels:
		if entry.get("level", 0) == current_level + 1:
			next_entry = entry
			break
	if next_entry.is_empty():
		return false
	var reqs = next_entry.get("requirements")
	if reqs is Dictionary:
		for k in reqs:
			if state.economy.resources.get(k, 0.0) < reqs[k] - 0.001:
				return false
		for k in reqs:
			state.economy.resources[k] = maxf(0.0, state.economy.resources.get(k, 0.0) - reqs[k])
	var reward = next_entry.get("reward", {})
	if reward is Dictionary:
		for k in reward:
			var cap: float = state.economy.caps.get(k, 999999.0)
			state.economy.resources[k] = minf(state.economy.resources.get(k, 0.0) + reward[k], cap)
	state.progression.city_level = current_level + 1
	EventBus.city_level_changed.emit(state.progression.city_level)
	EventBus.resources_changed.emit()
	return true
