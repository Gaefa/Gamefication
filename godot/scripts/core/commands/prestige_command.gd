class_name PrestigeCommand extends CommandBase
## Resets city but grants prestige stars based on performance.

func execute(_ctx: Dictionary) -> void:
	var prog: Dictionary = GameStateStore.progression()
	var city_level: int = prog.city_level as int
	if city_level < 3:
		message = "Need at least level 3 to prestige"
		return

	# Stars = city_level - 2 (so level 3 = 1 star, level 7 = 5 stars)
	var stars: int = city_level - 2
	var total_stars: int = (prog.prestige_stars as int) + stars
	var count: int = (prog.prestige_count as int) + 1

	# Reset state but keep prestige progress
	GameStateStore.reset()
	GameStateStore.progression().prestige_stars = total_stars
	GameStateStore.progression().prestige_count = count

	success = true
	message = "Prestige! Earned %d stars (total: %d)" % [stars, total_stars]
	EventBus.prestige_triggered.emit(stars)
