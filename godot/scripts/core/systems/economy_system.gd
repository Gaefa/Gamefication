## economy_system.gd -- Core production logic: resource checking, spending,
## production tick, caps update, and passive stats.
class_name EconomySystem

static func has_resources(state: Dictionary, cost: Variant) -> bool:
	if cost == null or not (cost is Dictionary):
		return true
	var economy: Dictionary = state.get("economy", {})
	var resources: Dictionary = economy.get("resources", {})
	var cost_dict: Dictionary = cost as Dictionary
	for k: String in cost_dict:
		if float(resources.get(k, 0.0)) < float(cost_dict[k]) - 0.001:
			return false
	return true

static func spend_resources(state: Dictionary, cost: Dictionary) -> void:
	var economy: Dictionary = state.get("economy", {})
	var resources: Dictionary = economy.get("resources", {})
	for k: String in cost:
		resources[k] = maxf(0.0, snappedf(float(resources.get(k, 0.0)) - float(cost[k]), 0.001))

static func add_resources(state: Dictionary, bundle: Dictionary) -> void:
	var economy: Dictionary = state.get("economy", {})
	var resources: Dictionary = economy.get("resources", {})
	var caps: Dictionary = economy.get("caps", {})
	for k: String in bundle:
		var cap: float = float(caps.get(k, 999999.0))
		resources[k] = clampf(snappedf(float(resources.get(k, 0.0)) + float(bundle[k]), 0.001), 0.0, cap)

static func apply_production_tick(economy: Dictionary, state: Dictionary, hex_grid: HexGrid, spatial_index: SpatialIndex, aura_cache: AuraCache, road_network: RoadNetwork, pipe_network: PipeNetwork) -> void:
	var resources: Dictionary = economy.get("resources", {})
	var caps: Dictionary = economy.get("caps", {})
	var buildings: Dictionary = hex_grid.get_all_buildings()

	for coord: Vector2i in buildings:
		var bld: Dictionary = buildings[coord]
		var bld_def: Dictionary = ContentDB.get_building(bld.get("type", ""))
		if bld_def.is_empty():
			continue
		var levels: Array = bld_def.get("levels", [])
		var lvl_idx: int = int(bld.get("level", 1)) - 1
		if lvl_idx < 0 or lvl_idx >= levels.size():
			continue
		var ld_raw: Variant = levels[lvl_idx]
		if not (ld_raw is Dictionary):
			continue
		var ld: Dictionary = ld_raw as Dictionary

		# Check can operate (consumes)
		var consumes_raw: Variant = ld.get("consumes")
		if consumes_raw is Dictionary:
			var consumes: Dictionary = consumes_raw as Dictionary
			if not consumes.is_empty():
				var can_operate: bool = true
				for k: String in consumes:
					if float(resources.get(k, 0.0)) < float(consumes[k]) - 0.001:
						can_operate = false
						break
				if not can_operate:
					continue
				spend_resources(state, consumes)

		# Calculate production
		var produces_raw: Variant = ld.get("produces")
		if produces_raw is Dictionary:
			var produces: Dictionary = produces_raw as Dictionary
			var produced: Dictionary = {}
			for k: String in produces:
				var mult: float = ProductionMultiplier.calculate(bld, coord.x, coord.y, k, state, hex_grid, spatial_index, aura_cache, road_network)
				produced[k] = float(produces[k]) * mult

			# Bank interest
			var interest: float = float(ld.get("interestPerMin", 0.0))
			if interest > 0.0 and float(resources.get("coins", 0.0)) > 0.0:
				produced["coins"] = float(produced.get("coins", 0.0)) + float(resources.get("coins", 0.0)) * interest / 60.0

			add_resources(state, produced)

static func update_caps(economy: Dictionary, hex_grid: HexGrid, spatial_index: SpatialIndex) -> void:
	var res_defs: Array = ContentDB.get_resources()
	var caps: Dictionary = {}
	for rd: Variant in res_defs:
		if rd is Dictionary:
			var rd_dict: Dictionary = rd as Dictionary
			var rid: String = rd_dict.get("id", "")
			caps[rid] = float(rd_dict.get("default_cap", 300))

	var storage_bonus: float = 0.0
	var buildings: Dictionary = hex_grid.get_all_buildings()
	for coord: Vector2i in buildings:
		var bld: Dictionary = buildings[coord]
		if bld.get("type", "") == "warehouse":
			var bld_def: Dictionary = ContentDB.get_building("warehouse")
			var levels: Array = bld_def.get("levels", [])
			var lvl_idx: int = int(bld.get("level", 1)) - 1
			if lvl_idx >= 0 and lvl_idx < levels.size():
				var ld_raw: Variant = levels[lvl_idx]
				if ld_raw is Dictionary:
					storage_bonus += float((ld_raw as Dictionary).get("storage", 0))

	for k: String in caps:
		if k != "coins" and k != "fame" and k != "water_res":
			caps[k] = float(caps[k]) + storage_bonus

	economy["caps"] = caps
	var resources: Dictionary = economy.get("resources", {})
	for k: String in resources:
		resources[k] = minf(float(resources.get(k, 0.0)), float(caps.get(k, 999999.0)))

static func compute_passive_stats(economy: Dictionary, state: Dictionary, hex_grid: HexGrid, spatial_index: SpatialIndex) -> Dictionary:
	var pop_cap: int = 0
	var happiness: int = 50
	var issues: int = 0
	var buildings: Dictionary = hex_grid.get_all_buildings()

	for coord: Vector2i in buildings:
		var bld: Dictionary = buildings[coord]
		var bld_def: Dictionary = ContentDB.get_building(bld.get("type", ""))
		if bld_def.is_empty():
			continue
		var levels: Array = bld_def.get("levels", [])
		var lvl_idx: int = int(bld.get("level", 1)) - 1
		if lvl_idx < 0 or lvl_idx >= levels.size():
			continue
		var ld_raw: Variant = levels[lvl_idx]
		if not (ld_raw is Dictionary):
			continue
		var ld: Dictionary = ld_raw as Dictionary
		pop_cap += int(ld.get("population", 0))
		happiness += int(ld.get("happiness", 0))
		if bld.get("issue") != null:
			issues += 1
			happiness -= 2

	# Buff bonuses
	var events_dict: Dictionary = state.get("events", {})
	var buffs: Array = events_dict.get("buffs", [])
	for buff: Variant in buffs:
		if buff is Dictionary:
			happiness += int((buff as Dictionary).get("happiness_add", 0))

	# Prestige happiness
	var progression: Dictionary = state.get("progression", {})
	happiness += int(float(progression.get("prestige_stars", 0)) * 0.02 * 100.0)

	# Penalty
	if int(events_dict.get("happiness_penalty_ticks", 0)) > 0:
		happiness -= 8

	return {"pop_cap": maxi(0, pop_cap), "happiness": clampi(happiness, 0, 250), "issues": issues}
