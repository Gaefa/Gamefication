class_name ResearchTechnologyCommand extends CommandBase
## Researches a base-game technology and stores it in governance state.

var technology_id: String


func _init(p_technology_id: String) -> void:
	technology_id = p_technology_id


func execute(_ctx: Dictionary) -> void:
	var def: Dictionary = ContentDB.get_technology_def(technology_id)
	if def.is_empty():
		message = Localization.t("ui.command.unknown_technology", "Unknown technology: %s") % technology_id
		return
	if GameStateStore.has_technology(technology_id):
		message = Localization.t("ui.command.already_researched", "Already researched: %s") % Localization.content_text(def, "label", technology_id)
		return
	var missing: Array[String] = _missing_requirements(def)
	if not missing.is_empty():
		message = Localization.t("ui.command.missing_requirements", "Missing requirements: %s") % ", ".join(missing)
		return
	var cost: Dictionary = def.get("cost", {})
	if not GameStateStore.can_afford(cost):
		message = Localization.t("ui.command.not_enough_resources", "Not enough resources")
		return
	GameStateStore.spend(cost)
	GameStateStore.add_technology(technology_id)
	success = true
	message = Localization.t("ui.command.researched", "Researched %s") % Localization.content_text(def, "label", technology_id)


func _missing_requirements(def: Dictionary) -> Array[String]:
	var missing: Array[String] = []
	var requires: Array = def.get("requires", [])
	for req_var: Variant in requires:
		var req_id: String = req_var as String
		if not GameStateStore.has_technology(req_id):
			var req_def: Dictionary = ContentDB.get_technology_def(req_id)
			missing.append(Localization.content_text(req_def, "label", req_id))
	return missing
