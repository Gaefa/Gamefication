class_name PlacementRules
## Shared placement validation for commands, HUD, and world preview.


static func validate(coord: Vector2i, type_id: String, hex_grid: HexGrid = null) -> Dictionary:
	var def: Dictionary = ContentDB.get_building_def(type_id)
	if def.is_empty():
		return _fail(Localization.t("ui.command.unknown_building", "Unknown building: %s") % type_id)
	if not (def.get("player_buildable", true) as bool):
		return _fail(Localization.t("ui.command.cannot_build_here", "Cannot build here"))

	if hex_grid != null and not hex_grid.is_valid(coord):
		return _fail(Localization.t("ui.placement.out_of_bounds", "Outside city bounds"))

	if GameStateStore.has_building(coord):
		return _fail(Localization.t("ui.placement.occupied", "Tile already occupied"))

	var terrain_id: int = GameStateStore.get_terrain(coord)
	var tdef: Dictionary = ContentDB.get_terrain_def(terrain_id)
	if not tdef.is_empty() and not (tdef.get("buildable", true) as bool):
		return _fail(Localization.t("ui.command.cannot_build_here", "Cannot build here"))

	var req_level: int = def.get("unlock_level", 1) as int
	var city_level: int = GameStateStore.progression().city_level as int
	if city_level < req_level:
		return _fail(Localization.t("ui.command.requires_city_level", "Requires city level %d") % req_level)

	var build_cost: Dictionary = build_cost_for(def)
	if not GameStateStore.can_afford(build_cost):
		return _fail("%s: %s" % [
			Localization.t("ui.command.not_enough_resources", "Not enough resources"),
			missing_cost_text(build_cost),
		])

	return {"ok": true, "message": Localization.t("ui.placement.valid", "Can build here")}


## What a building costs right now: the base price times the season's build_cost_mult
## (the Window makes construction 10% cheaper, as the season panel says).
static func build_cost_for(def: Dictionary) -> Dictionary:
	var mult: float = (GameStateStore.climate().get("modifiers", {}) as Dictionary).get("build_cost_mult", 1.0) as float
	var base: Dictionary = def.get("build_cost", {})
	if is_equal_approx(mult, 1.0):
		return base
	var cost: Dictionary = {}
	for res_id: String in base:
		cost[res_id] = ceilf((base[res_id] as float) * mult)
	return cost


static func missing_cost_text(cost: Dictionary) -> String:
	var missing: Array[String] = []
	for res_id: String in cost:
		var needed: float = cost[res_id] as float
		var have: float = GameStateStore.get_resource(res_id)
		if have < needed:
			var rdef: Dictionary = ContentDB.get_resource_def(res_id)
			missing.append("%s %d/%d" % [Localization.content_text(rdef, "label", res_id), int(have), int(needed)])
	if missing.is_empty():
		return Localization.t("ui.common.none", "none")
	return ", ".join(missing)


static func terrain_bonus_text(coord: Vector2i, type_id: String) -> String:
	var def: Dictionary = ContentDB.get_building_def(type_id)
	var terrain_id: int = GameStateStore.get_terrain(coord)
	var bonuses: Dictionary = def.get("terrain_bonus", {})
	if not bonuses.has(str(terrain_id)):
		return ""
	var bonus: float = bonuses[str(terrain_id)] as float
	if bonus <= 0.0:
		return ""
	var tdef: Dictionary = ContentDB.get_terrain_def(terrain_id)
	return "%s +%d%%" % [Localization.content_text(tdef, "label", str(terrain_id)), int(bonus * 100.0)]


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}
