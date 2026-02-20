## maintenance_system.gd -- Decays active buffs each tick.
class_name MaintenanceSystem

static func process_tick(state: Dictionary) -> void:
	var events_dict: Dictionary = state.get("events", {})
	var buffs: Array = events_dict.get("buffs", [])
	var remaining_buffs: Array = []
	for buff: Variant in buffs:
		if not (buff is Dictionary):
			continue
		var b: Dictionary = buff as Dictionary
		b["remaining"] = int(b.get("remaining", 0)) - 1
		if int(b.get("remaining", 0)) > 0:
			remaining_buffs.append(b)
	events_dict["buffs"] = remaining_buffs
