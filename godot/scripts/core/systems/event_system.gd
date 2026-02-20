## event_system.gd -- Timer-based event spawning filtered by city_level
## and pressure_phase.
class_name EventSystem

static func process_tick(state: Dictionary) -> void:
	var events_dict: Dictionary = state.get("events", {})
	var progression: Dictionary = state.get("progression", {})
	var pressure: Dictionary = state.get("pressure", {})

	# Decrement timer
	events_dict["timer"] = float(events_dict.get("timer", 60.0)) - 1.0

	# If there's already an active event, skip
	if events_dict.get("active_event") != null:
		return

	# If timer hasn't expired, skip
	if float(events_dict.get("timer", 1.0)) > 0.0:
		return

	# Roll a new event
	var city_level: int = int(progression.get("city_level", 1))
	var pressure_phase: int = int(pressure.get("phase", 0))

	var pool: Array = ContentDB.get_events_for_level(city_level) if ContentDB.has_method("get_events_for_level") else []
	var filtered: Array = []
	for ev: Variant in pool:
		if ev is Dictionary:
			var ev_dict: Dictionary = ev as Dictionary
			if int(ev_dict.get("pressure_phase_min", 0)) <= pressure_phase:
				filtered.append(ev_dict)

	if filtered.is_empty():
		events_dict["timer"] = 60.0
		return

	var chosen: Dictionary = filtered[randi() % filtered.size()]
	events_dict["active_event"] = {"id": chosen.get("id", "")}
	events_dict["timer"] = 90.0 + float(randi() % 60)
	EventBus.event_fired.emit(str(chosen.get("id", "")))
