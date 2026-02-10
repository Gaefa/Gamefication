class_name ResolveEventCommand
extends CommandBase

var accepted: bool

func _init(accepted_: bool = false) -> void:
	accepted = accepted_

func execute(state: Dictionary, hex_grid: HexGrid, spatial_index: SpatialIndex) -> bool:
	var events_state: Dictionary = state.events
	if events_state.get("active_event") == null:
		return false
	var event_id: String = events_state.active_event.get("id", "")
	var event_def := ContentDB.get_event(event_id)
	if event_def.is_empty():
		events_state["active_event"] = null
		return false

	if accepted:
		# Check accept cost
		var accept_cost = event_def.get("accept_cost")
		if accept_cost is Dictionary and not accept_cost.is_empty():
			for k in accept_cost:
				if state.economy.resources.get(k, 0.0) < accept_cost[k] - 0.001:
					return false
			for k in accept_cost:
				state.economy.resources[k] = maxf(0.0, state.economy.resources.get(k, 0.0) - accept_cost[k])
		# Apply accept effects
		var effects: Dictionary = event_def.get("accept_effects", {})
		_apply_effects(effects, state)
	else:
		# Apply decline effects
		var effects: Dictionary = event_def.get("decline_effects", {})
		_apply_effects(effects, state)

	events_state["active_event"] = null
	EventBus.event_resolved.emit(event_id, accepted)
	EventBus.resources_changed.emit()
	return true

func _apply_effects(effects: Dictionary, state: Dictionary) -> void:
	if effects.has("add_resources"):
		for k in effects.add_resources:
			var cap: float = state.economy.caps.get(k, 999999.0)
			state.economy.resources[k] = clampf(state.economy.resources.get(k, 0.0) + effects.add_resources[k], 0.0, cap)
	if effects.has("remove_resources"):
		for k in effects.remove_resources:
			state.economy.resources[k] = maxf(0.0, state.economy.resources.get(k, 0.0) - effects.remove_resources[k])
	if effects.has("add_buff"):
		var buff: Dictionary = effects.add_buff.duplicate()
		state.events.buffs.append(buff)
	if effects.has("force_issues"):
		state["_pending_force_issues"] = effects.force_issues
	if effects.has("happiness_penalty_ticks"):
		state.events["happiness_penalty_ticks"] = state.events.get("happiness_penalty_ticks", 0) + effects.happiness_penalty_ticks
