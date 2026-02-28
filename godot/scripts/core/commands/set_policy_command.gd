class_name SetPolicyCommand extends CommandBase
## Sets the active policy for the pressure director.

var policy_id: String


func _init(p_policy_id: String) -> void:
	policy_id = p_policy_id


func execute(_ctx: Dictionary) -> void:
	GameStateStore.pressure().active_policy = policy_id
	success = true
	message = "Policy set: %s" % policy_id
