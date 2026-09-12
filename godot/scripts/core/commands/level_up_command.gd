class_name LevelUpCommand extends CommandBase
## Manually triggers city level advancement (usually auto-detected by ProgressionSystem).

func execute(_ctx: Dictionary) -> void:
	var current_level: int = GameStateStore.progression().city_level as int
	var next_def: Dictionary = ContentDB.get_level_def(current_level + 1)
	if next_def.is_empty():
		message = Localization.t("ui.command.already_max_level", "Already at max level")
		return

	var reqs_raw: Variant = next_def.get("requirements", null)
	if reqs_raw == null or not (reqs_raw is Dictionary):
		message = Localization.t("ui.command.no_upgrade_available", "No upgrade available")
		return

	var reqs: Dictionary = reqs_raw as Dictionary
	if not GameStateStore.can_afford(reqs):
		message = "%s: %s" % [
			Localization.t("ui.command.not_enough_resources", "Not enough resources"),
			_missing_cost_text(reqs),
		]
		return

	GameStateStore.spend(reqs)
	GameStateStore.progression().city_level = current_level + 1
	var reward: Variant = next_def.get("reward", null)
	if reward is Dictionary:
		for res_id: String in (reward as Dictionary):
			GameStateStore.add_resource(res_id, (reward as Dictionary)[res_id] as float)

	success = true
	message = Localization.t("ui.command.advanced_level", "Advanced to level %d!") % (current_level + 1)
	EventBus.city_level_changed.emit(current_level + 1)


func _missing_cost_text(cost: Dictionary) -> String:
	var missing: Array[String] = []
	for res_id: String in cost:
		var needed: float = cost[res_id] as float
		var have: float = GameStateStore.get_resource(res_id)
		if have < needed:
			var rdef: Dictionary = ContentDB.get_resource_def(res_id)
			missing.append("%s %d/%d" % [Localization.content_text(rdef, "label", res_id), int(have), int(needed)])
	return ", ".join(missing)
