class_name PrestigeCommand
extends CommandBase

func execute(state: Dictionary, hex_grid: HexGrid, spatial_index: SpatialIndex) -> bool:
	if state.progression.city_level < 7:
		return false
	var fame: float = state.economy.resources.get("fame", 0.0)
	var science: float = state.economy.resources.get("science", 0.0)
	var gain: int = 1 + int(fame / 2000.0) + int(science / 5000.0)
	if gain <= 0:
		return false
	state.progression.prestige_stars += gain
	state.progression.prestige_count += 1
	state["_prestige_stars_gained"] = gain
	EventBus.prestige_completed.emit(gain)
	return true
