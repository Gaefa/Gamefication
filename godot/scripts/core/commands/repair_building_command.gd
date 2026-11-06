class_name RepairBuildingCommand extends CommandBase
## Repairs a damaged building for a small coin cost.

var coord: Vector2i

const REPAIR_COST_COINS := 10.0  # cheap on purpose: the treasury is for technologies


func _init(p_coord: Vector2i) -> void:
	coord = p_coord


func execute(ctx: Dictionary) -> void:
	if not GameStateStore.has_building(coord):
		message = Localization.t("ui.command.no_building_here", "No building here")
		return

	var bld: Dictionary = GameStateStore.get_building(coord)
	var is_damaged: bool = bld.get("damaged", false) as bool
	var has_issue: bool = bld.get("has_issue", false) as bool
	if not is_damaged and not has_issue:
		message = Localization.t("ui.command.building_fine", "Building is fine")
		return

	if not GameStateStore.can_afford({"res_money": REPAIR_COST_COINS}):
		message = Localization.t("ui.command.need_coins", "Need %d coins") % int(REPAIR_COST_COINS)
		return

	GameStateStore.spend({"res_money": REPAIR_COST_COINS})
	_note_repair_spend()
	bld["damaged"] = false
	bld["has_issue"] = false
	GameStateStore.set_building(coord, bld)
	var coverage: CoverageMap = ctx.get("coverage") as CoverageMap
	if coverage:
		coverage.invalidate()  # a repaired pump covers its radius again

	success = true
	message = Localization.t("ui.command.building_repaired", "Building repaired")
	EventBus.building_repaired.emit(coord)


## Today's repair bill, for the treasury tooltip: the money trend only sees flows, and a
## player who repairs four "!" a day would otherwise watch a "+25" treasury shrink.
static func _note_repair_spend() -> void:
	var economy: Dictionary = GameStateStore.economy()
	var today: int = GameStateStore.climate().get("total_day", 1) as int
	if (economy.get("repairs_day", 0) as int) != today:
		economy["repairs_day"] = today
		economy["repairs_today"] = 0
	economy["repairs_today"] = (economy.get("repairs_today", 0) as int) + 1
