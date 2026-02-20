class_name EconomySystem

static func has_resources(state: Dictionary, cost) -> bool:
	if cost == null or not (cost is Dictionary):
		return true
	for k in cost:
		if state.economy.resources.get(k, 0.0) < cost[k] - 0.001:
			return false
	return true

static func spend_resources(state: Dictionary, cost: Dictionary) -> void:
	for k in cost:
		state.economy.resources[k] = maxf(0.0, snappedf(state.economy.resources.get(k, 0.0) - cost[k], 0.001))

static func add_resources(state: Dictionary, bundle: Dictionary) -> void:
	for k in bundle:
		var cap: float = state.economy.caps.get(k, 999999.0)
		state.economy.resources[k] = clampf(snappedf(state.economy.resources.get(k, 0.0) + bundle[k], 0.001), 0.0, cap)

static func apply_production_tick(state: Dictionary, hex_grid: HexGrid, spatial_index: SpatialIndex, aura_cache: AuraCache, road_network: RoadNetwork) -> void:
	var buildings := hex_grid.get_all_buildings()
	for coord in buildings:
		var bld: Dictionary = buildings[coord]
		var bld_def := ContentDB.get_building(bld.get("type", ""))
		if bld_def.is_empty():
			continue
		var levels: Array = bld_def.get("levels", [])
		var lvl_idx: int = bld.get("level", 1) - 1
		if lvl_idx < 0 or lvl_idx >= levels.size():
			continue
		var ld: Dictionary = levels[lvl_idx]
		# Check can operate
		var consumes = ld.get("consumes")
		if consumes is Dictionary and not consumes.is_empty():
			var can_operate := true
			for k in consumes:
				if state.economy.resources.get(k, 0.0) < consumes[k] - 0.001:
					can_operate = false
					break
			if not can_operate:
				continue
			spend_resources(state, consumes)
		# Calculate production
		var produces = ld.get("produces")
		if produces is Dictionary:
			var produced := {}
			for k in produces:
				var mult: float = ProductionMultiplier.calculate(bld, coord.x, coord.y, k, state, hex_grid, spatial_index, aura_cache, road_network)
				produced[k] = produces[k] * mult
			# Bank interest
			var interest: float = ld.get("interestPerMin", 0.0)
			if interest > 0 and state.economy.resources.get("coins", 0.0) > 0:
				produced["coins"] = produced.get("coins", 0.0) + state.economy.resources.coins * interest / 60.0
			add_resources(state, produced)
			# Track stats
			if produced.has("coins"):
				state.meta["total_coins_earned"] = state.meta.get("total_coins_earned", 0.0) + produced.coins
			if produced.has("food"):
				state.meta["total_food_produced"] = state.meta.get("total_food_produced", 0.0) + produced.food

static func update_caps(state: Dictionary, hex_grid: HexGrid) -> void:
	var res_defs: Array = ContentDB.get_resources()
	var caps := {}
	for rd in res_defs:
		caps[rd.id] = rd.get("default_cap", 300)
	var storage_bonus := 0.0
	var buildings := hex_grid.get_all_buildings()
	for coord in buildings:
		var bld: Dictionary = buildings[coord]
		if bld.get("type", "") == "warehouse":
			var bld_def := ContentDB.get_building("warehouse")
			var levels: Array = bld_def.get("levels", [])
			var lvl_idx: int = bld.get("level", 1) - 1
			if lvl_idx >= 0 and lvl_idx < levels.size():
				storage_bonus += levels[lvl_idx].get("storage", 0)
	for k in caps:
		if k != "coins" and k != "fame" and k != "water_res":
			caps[k] += storage_bonus
	state.economy["caps"] = caps
	for k in state.economy.resources:
		state.economy.resources[k] = minf(state.economy.resources.get(k, 0.0), caps.get(k, 999999.0))

static func compute_passive_stats(state: Dictionary, hex_grid: HexGrid, spatial_index: SpatialIndex, aura_cache: AuraCache) -> Dictionary:
	var pop_cap := 0
	var happiness := 50
	var issues := 0
	var buildings := hex_grid.get_all_buildings()
	for coord in buildings:
		var bld: Dictionary = buildings[coord]
		var bld_def := ContentDB.get_building(bld.get("type", ""))
		if bld_def.is_empty():
			continue
		var levels: Array = bld_def.get("levels", [])
		var lvl_idx: int = bld.get("level", 1) - 1
		if lvl_idx < 0 or lvl_idx >= levels.size():
			continue
		var ld: Dictionary = levels[lvl_idx]
		pop_cap += int(ld.get("population", 0))
		happiness += int(ld.get("happiness", 0))
		if bld.get("issue") != null:
			issues += 1
			happiness -= 2
		# Park happiness aura
		if bld.get("type", "") != "park":
			happiness += int(aura_cache.get_park_happiness(coord.x, coord.y, hex_grid, spatial_index))
	# Buff bonuses
	for buff in state.events.get("buffs", []):
		happiness += int(buff.get("happiness_add", 0))
	# Prestige happiness
	happiness += int(state.progression.get("prestige_stars", 0) * 0.02 * 100)
	# Penalty
	if state.events.get("happiness_penalty_ticks", 0) > 0:
		happiness -= 8
	return {"pop_cap": maxi(0, pop_cap), "happiness": clampi(happiness, 0, 250), "issues": issues}

static func resolve_auto_sell_food(state: Dictionary, hex_grid: HexGrid) -> void:
	var has_auto_sell := false
	var buildings := hex_grid.get_all_buildings()
	for coord in buildings:
		var bld: Dictionary = buildings[coord]
		if bld.get("type", "") == "farm":
			var bld_def := ContentDB.get_building("farm")
			var levels: Array = bld_def.get("levels", [])
			var lvl_idx: int = bld.get("level", 1) - 1
			if lvl_idx >= 0 and lvl_idx < levels.size():
				var synergy = levels[lvl_idx].get("synergy")
				if synergy is Dictionary and synergy.get("autoSellFood", false):
					has_auto_sell = true
					break
	if not has_auto_sell:
		return
	var cap: float = state.economy.caps.get("food", 300.0)
	if state.economy.resources.get("food", 0.0) > cap * 0.95:
		var excess: float = state.economy.resources.food - cap * 0.95
		if excess > 0:
			state.economy.resources["food"] -= excess
			state.economy.resources["coins"] = state.economy.resources.get("coins", 0.0) + excess * 1.2
