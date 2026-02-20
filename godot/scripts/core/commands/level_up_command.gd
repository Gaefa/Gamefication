## level_up_command.gd -- Advances the city to the next level when
## resource requirements are met.
class_name LevelUpCommand
extends CommandBase


func execute(state: Dictionary, hex_grid: HexGrid, spatial_index: SpatialIndex) -> bool:
	var progression: Dictionary = state.get("progression", {})
	var economy: Dictionary = state.get("economy", {})
	var resources: Dictionary = economy.get("resources", {})
	var caps: Dictionary = economy.get("caps", {})

	var current_level: int = int(progression.get("city_level", 1))
	var levels: Array = ContentDB.get_city_levels()

	# Find the next level entry
	var next_entry: Dictionary = {}
	for entry: Variant in levels:
		if entry is Dictionary:
			var entry_dict: Dictionary = entry as Dictionary
			if int(entry_dict.get("level", 0)) == current_level + 1:
				next_entry = entry_dict
				break

	if next_entry.is_empty():
		return false

	# Check and spend requirements
	var reqs_raw: Variant = next_entry.get("requirements")
	if reqs_raw is Dictionary:
		var reqs: Dictionary = reqs_raw as Dictionary
		# Validate affordability
		for k: String in reqs:
			if float(resources.get(k, 0.0)) < float(reqs[k]) - 0.001:
				return false
		# Spend resources
		for k: String in reqs:
			resources[k] = maxf(0.0, float(resources.get(k, 0.0)) - float(reqs[k]))

	# Grant rewards
	var reward_raw: Variant = next_entry.get("reward", {})
	if reward_raw is Dictionary:
		var reward: Dictionary = reward_raw as Dictionary
		for k: String in reward:
			var cap: float = float(caps.get(k, 999999.0))
			resources[k] = minf(float(resources.get(k, 0.0)) + float(reward[k]), cap)

	progression["city_level"] = current_level + 1
	EventBus.city_level_changed.emit(current_level + 1)
	EventBus.resources_changed.emit()
	return true
