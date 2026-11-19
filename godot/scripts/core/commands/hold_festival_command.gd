class_name HoldFestivalCommand extends CommandBase
## A quarter's feast paid from the treasury: the mood rises for two days. It is the other
## thing money buys, and it does not stack: one feast at a time, and each one held in a run
## costs half as much again as the one before.

const BASE_COST := 60.0
const COST_STEP := 0.5
const MOOD := 6.0
const LASTS_TICKS := 600.0
const BUFF_ID := "quarter_feast"


static func cost() -> float:
	return ceilf(BASE_COST * (1.0 + COST_STEP * float(GameStateStore.economy().get("feasts_held", 0) as int)))


static func running() -> bool:
	for buff: Dictionary in GameStateStore.get_buffs():
		if (buff.get("id", "") as String) == BUFF_ID:
			return true
	return false


func execute(_ctx: Dictionary) -> void:
	if running():
		message = Localization.ru_en("Праздник ещё идёт", "The feast is still on")
		return
	var price: float = cost()
	if GameStateStore.get_resource("res_money") < price:
		message = Localization.ru_en("Не хватает денег: нужно %d", "Not enough money: %d needed") % int(price)
		return
	# The bookkeeper signs a feast the way he signs a policy: not out of the repair reserve.
	if EconomySystem.reserve_shortfall({"res_money": price}) > 0.0:
		message = Localization.ru_en("Счетовод не подпишет: после праздника не останется резерва на ремонт", "The bookkeeper will not sign: the feast would eat the repair reserve")
		return
	GameStateStore.spend({"res_money": price})
	GameStateStore.add_buff({"id": BUFF_ID, "name": "Праздник квартала", "name_en": "A quarter's feast", "happiness_add": MOOD, "remaining": LASTS_TICKS})
	GameStateStore.economy()["feasts_held"] = (GameStateStore.economy().get("feasts_held", 0) as int) + 1
	success = true
	message = Localization.ru_en("Праздник квартала: настроение +%d на два дня", "A quarter's feast: mood +%d for two days") % int(MOOD)
