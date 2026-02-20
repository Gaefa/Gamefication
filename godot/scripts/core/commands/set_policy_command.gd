class_name SetPolicyCommand
extends CommandBase

var policy_id: String

func _init(policy_: String = "social") -> void:
	policy_id = policy_

func execute(state: Dictionary, hex_grid: HexGrid, spatial_index: SpatialIndex) -> bool:
	if policy_id not in ["austerity", "social", "technocracy"]:
		return false
	state.pressure["active_policy"] = policy_id
	return true
