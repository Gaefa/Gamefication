class_name SetPolicyCommand extends CommandBase
## Sets one active policy per category.

var policy_id: String


func _init(p_policy_id: String) -> void:
	policy_id = p_policy_id


func execute(_ctx: Dictionary) -> void:
	var def: Dictionary = ContentDB.get_policy_def(policy_id)
	if def.is_empty():
		message = "Unknown policy: %s" % policy_id
		return
	var missing: Array[String] = _missing_requirements(def)
	if not missing.is_empty():
		message = "Missing requirements: " + ", ".join(missing)
		return
	var switch_cost: Dictionary = def.get("switch_cost", {})
	if not GameStateStore.can_afford(switch_cost):
		message = "Not enough resources"
		return
	GameStateStore.spend(switch_cost)
	var category: String = def.get("category", "general") as String
	GameStateStore.set_active_policy(category, policy_id)
	success = true
	message = "Policy set: %s" % def.get("label", policy_id)


func _missing_requirements(def: Dictionary) -> Array[String]:
	var missing: Array[String] = []
	var requirements: Dictionary = def.get("requirements", {})
	var city_level: int = requirements.get("city_level", 1) as int
	if (GameStateStore.progression().city_level as int) < city_level:
		missing.append("City level %d" % city_level)
	var techs: Array = requirements.get("tech", [])
	for tech_var: Variant in techs:
		var tech_id: String = tech_var as String
		if not GameStateStore.has_technology(tech_id):
			var tech_def: Dictionary = ContentDB.get_technology_def(tech_id)
			missing.append(tech_def.get("label", tech_id) as String)
	return missing
