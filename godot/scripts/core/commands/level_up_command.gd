class_name LevelUpCommand extends CommandBase
## Manually triggers city level advancement (usually auto-detected by ProgressionSystem).

func execute(_ctx: Dictionary) -> void:
	var current_level: int = GameStateStore.progression().city_level as int
	var next_def: Dictionary = ContentDB.get_level_def(current_level + 1)
	if next_def.is_empty():
		message = Localization.t("ui.command.already_max_level", "Already at max level")
		return

	var reqs: Dictionary = next_def.get("requirements", {})
	var req_pop: int = reqs.get("population", 0) as int
	if (GameStateStore.population().total as int) < req_pop:
		message = Localization.t("ui.command.need_population", "Need %d population") % req_pop
		return

	var req_res: Dictionary = reqs.get("resources", {})
	if not GameStateStore.can_afford(req_res):
		message = Localization.t("ui.command.not_enough_resources", "Not enough resources")
		return

	GameStateStore.spend(req_res)
	GameStateStore.progression().city_level = current_level + 1
	success = true
	message = Localization.t("ui.command.advanced_level", "Advanced to level %d!") % (current_level + 1)
	EventBus.city_level_changed.emit(current_level + 1)
