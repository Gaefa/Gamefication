class_name MaintenanceSystem

static func process_tick(state: Dictionary) -> void:
	var buffs: Array = state.events.get("buffs", [])
	var remaining_buffs: Array = []
	for buff in buffs:
		buff["remaining"] = buff.get("remaining", 0) - 1
		if buff.remaining > 0:
			remaining_buffs.append(buff)
	state.events["buffs"] = remaining_buffs
