class_name EventSystem

static func process_tick(state: Dictionary) -> void:
	state.events["event_timer"] = state.events.get("event_timer", 60.0) - 1.0
	if state.events.get("active_event") != null:
		return
	if state.events.event_timer > 0:
		return
	var pool: Array = ContentDB.get_events_for_level(state.progression.city_level)
	var pressure_phase: int = state.pressure.get("phase", 0)
	var filtered: Array = []
	for ev in pool:
		if ev.get("pressure_phase_min", 0) <= pressure_phase:
			filtered.append(ev)
	if filtered.is_empty():
		state.events["event_timer"] = 60.0
		return
	var chosen: Dictionary = filtered[randi() % filtered.size()]
	state.events["active_event"] = {"id": chosen.id}
	state.events["event_timer"] = 90.0 + float(randi() % 60)
	EventBus.event_fired.emit(chosen.id)
