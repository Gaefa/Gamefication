class_name SetPolicyCommand extends CommandBase
## Sets one active policy per category.

var policy_id: String


func _init(p_policy_id: String) -> void:
	policy_id = p_policy_id


func execute(_ctx: Dictionary) -> void:
	var def: Dictionary = ContentDB.get_policy_def(policy_id)
	if def.is_empty():
		message = Localization.t("ui.command.unknown_policy", "Unknown policy: %s") % policy_id
		return
	var missing: Array[String] = _missing_requirements(def)
	if not missing.is_empty():
		message = Localization.t("ui.command.missing_requirements", "Missing requirements: %s") % ", ".join(missing)
		return
	var switch_cost: Dictionary = def.get("switch_cost", {})
	if not GameStateStore.can_afford(switch_cost):
		message = Localization.t("ui.command.not_enough_resources", "Not enough resources")
		return
	GameStateStore.spend(switch_cost)
	var category: String = def.get("category", "general") as String
	GameStateStore.set_active_policy(category, policy_id)
	success = true
	message = Localization.t("ui.command.policy_set", "Policy set: %s") % Localization.content_text(def, "label", policy_id)


func _missing_requirements(def: Dictionary) -> Array[String]:
	var missing: Array[String] = []
	var requirements: Dictionary = def.get("requirements", {})
	var city_level: int = requirements.get("city_level", 1) as int
	if (GameStateStore.progression().city_level as int) < city_level:
		missing.append(Localization.t("ui.command.requires_city_level", "Requires city level %d") % city_level)
	var techs: Array = requirements.get("tech", [])
	for tech_var: Variant in techs:
		var tech_id: String = tech_var as String
		if not GameStateStore.has_technology(tech_id):
			var tech_def: Dictionary = ContentDB.get_technology_def(tech_id)
			missing.append(Localization.content_text(tech_def, "label", tech_id))
	return missing
