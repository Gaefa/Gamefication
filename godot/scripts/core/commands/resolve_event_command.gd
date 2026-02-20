## resolve_event_command.gd -- Handles accepting or declining an active event.
class_name ResolveEventCommand
extends CommandBase

var accepted: bool

func _init(accepted_: bool = false) -> void:
	accepted = accepted_

func execute(state: Dictionary, hex_grid: HexGrid, spatial_index: SpatialIndex) -> bool:
	var events_state: Dictionary = state.get("events", {})
	if events_state.get("active_event") == null:
		return false
	var active_event: Variant = events_state.get("active_event")
	if not (active_event is Dictionary):
		return false
	var event_id: String = (active_event as Dictionary).get("id", "")
	var event_def: Dictionary = ContentDB.get_event(event_id)
	if event_def.is_empty():
		events_state["active_event"] = null
		return false

	var economy: Dictionary = state.get("economy", {})
	var resources: Dictionary = economy.get("resources", {})
	var caps: Dictionary = economy.get("caps", {})

	if accepted:
		# Check accept cost
		var accept_cost_raw: Variant = event_def.get("accept_cost")
		if accept_cost_raw is Dictionary:
			var accept_cost: Dictionary = accept_cost_raw as Dictionary
			if not accept_cost.is_empty():
				for k: String in accept_cost:
					if float(resources.get(k, 0.0)) < float(accept_cost[k]) - 0.001:
						return false
				for k: String in accept_cost:
					resources[k] = maxf(0.0, float(resources.get(k, 0.0)) - float(accept_cost[k]))
		# Apply accept effects
		var effects_raw: Variant = event_def.get("accept_effects", {})
		if effects_raw is Dictionary:
			_apply_effects(effects_raw as Dictionary, state)
	else:
		# Apply decline effects
		var effects_raw: Variant = event_def.get("decline_effects", {})
		if effects_raw is Dictionary:
			_apply_effects(effects_raw as Dictionary, state)

	events_state["active_event"] = null
	EventBus.event_resolved.emit(event_id, accepted)
	EventBus.resources_changed.emit()
	return true

func _apply_effects(effects: Dictionary, state: Dictionary) -> void:
	var economy: Dictionary = state.get("economy", {})
	var resources: Dictionary = economy.get("resources", {})
	var caps: Dictionary = economy.get("caps", {})
	var events_state: Dictionary = state.get("events", {})

	var add_res_raw: Variant = effects.get("add_resources")
	if add_res_raw is Dictionary:
		var add_res: Dictionary = add_res_raw as Dictionary
		for k: String in add_res:
			var cap: float = float(caps.get(k, 999999.0))
			resources[k] = clampf(float(resources.get(k, 0.0)) + float(add_res[k]), 0.0, cap)

	var rem_res_raw: Variant = effects.get("remove_resources")
	if rem_res_raw is Dictionary:
		var rem_res: Dictionary = rem_res_raw as Dictionary
		for k: String in rem_res:
			resources[k] = maxf(0.0, float(resources.get(k, 0.0)) - float(rem_res[k]))

	var add_buff_raw: Variant = effects.get("add_buff")
	if add_buff_raw is Dictionary:
		var buff: Dictionary = (add_buff_raw as Dictionary).duplicate()
		var buffs: Array = events_state.get("buffs", [])
		buffs.append(buff)

	if effects.has("force_issues"):
		state["_pending_force_issues"] = effects.get("force_issues")

	if effects.has("happiness_penalty_ticks"):
		var current: int = int(events_state.get("happiness_penalty_ticks", 0))
		events_state["happiness_penalty_ticks"] = current + int(effects.get("happiness_penalty_ticks", 0))
