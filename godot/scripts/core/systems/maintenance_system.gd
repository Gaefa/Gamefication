class_name MaintenanceSystem
## Decays active buffs each tick and removes expired ones.

func process_tick() -> void:
	var buffs: Array = GameStateStore.get_buffs()
	for buff: Dictionary in buffs:
		var remaining: float = buff.get("remaining", 0.0) as float
		remaining -= 1.0
		buff["remaining"] = remaining
	GameStateStore.clear_expired_buffs()
