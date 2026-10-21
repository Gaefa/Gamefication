class_name MaintenanceSystem
## Decays active buffs each tick and removes expired ones.

func process_tick() -> void:
	var buffs: Array = GameStateStore.get_buffs()
	for buff: Dictionary in buffs:
		var remaining: float = buff.get("remaining", 0.0) as float
		remaining -= 1.0
		if buff.has("until_season_end") and buff["until_season_end"] != GameStateStore.climate().get("season_id", ""):
			remaining = 0.0
		buff["remaining"] = remaining
		# A promise with a deadline: when the timer runs out, the card it names is raised.
		if remaining <= 0.0 and buff.has("on_expire_event"):
			EventManager.raise_event(buff.get("on_expire_event", "") as String)
		if remaining <= 0.0 and buff.has("on_expire_flag"):
			var flags: Dictionary = GameStateStore.mandate().get("flags", {}) as Dictionary
			flags[buff.get("on_expire_flag", "") as String] = true
			GameStateStore.mandate()["flags"] = flags
	GameStateStore.clear_expired_buffs()
