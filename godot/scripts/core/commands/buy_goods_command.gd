class_name BuyGoodsCommand extends CommandBase
## The neighbours' market: a lot of stone, wood, tools or metal for money. It is where the
## treasury goes when the district lacks one thing and has coins for everything: dear enough
## that a quarry is still the answer, and each lot bought the same day costs a quarter more
## than the last. A Village (city level 2) has a trading yard and buys a fifth cheaper.

const LOTS := {
	"res_stone": {"amount": 20.0, "price": 30.0},
	"res_wood": {"amount": 20.0, "price": 24.0},
	"res_tools": {"amount": 2.0, "price": 40.0},
	"res_metal": {"amount": 10.0, "price": 40.0},
}
const DAILY_STEP := 0.25
const VILLAGE_DISCOUNT := 0.8

var res_id: String


func _init(p_res_id: String) -> void:
	res_id = p_res_id


## What the market sells in this chapter: metal only where metal exists.
static func goods() -> Array[String]:
	var out: Array[String] = []
	for id: String in LOTS:
		if ContentDB.get_resource_ids().has(id):
			out.append(id)
	return out


static func lot_amount(p_res_id: String) -> float:
	return (LOTS.get(p_res_id, {}) as Dictionary).get("amount", 0.0) as float


## Lots of this good bought today (the count resets with the day).
static func bought_today(p_res_id: String) -> int:
	var market: Dictionary = GameStateStore.economy().get("market", {}) as Dictionary
	if (market.get("day", 0) as int) != (GameStateStore.climate().get("total_day", 1) as int):
		return 0
	return (market.get("bought", {}) as Dictionary).get(p_res_id, 0) as int


static func price(p_res_id: String) -> float:
	var base: float = (LOTS.get(p_res_id, {}) as Dictionary).get("price", 0.0) as float
	var discount: float = VILLAGE_DISCOUNT if (GameStateStore.progression().city_level as int) >= 2 else 1.0
	return ceilf(base * discount * (1.0 + DAILY_STEP * float(bought_today(p_res_id))))


func execute(_ctx: Dictionary) -> void:
	if not goods().has(res_id):
		message = Localization.ru_en("Соседи этим не торгуют", "The neighbours do not sell that")
		return
	var amount: float = lot_amount(res_id)
	var cap: float = GameStateStore.get_cap(res_id)
	if cap > 0.0 and GameStateStore.get_resource(res_id) + amount > cap:
		message = Localization.ru_en("Склад полон: купленное некуда сложить", "The store is full: nowhere to put the lot")
		return
	var cost: float = price(res_id)
	if GameStateStore.get_resource("res_money") < cost:
		message = Localization.ru_en("Не хватает денег: нужно %d", "Not enough money: %d needed") % int(cost)
		return
	GameStateStore.spend({"res_money": cost})
	GameStateStore.add_resource(res_id, amount)
	var day: int = GameStateStore.climate().get("total_day", 1) as int
	var market: Dictionary = GameStateStore.economy().get("market", {}) as Dictionary
	if (market.get("day", 0) as int) != day:
		market = {"day": day, "bought": {}}
	(market["bought"] as Dictionary)[res_id] = ((market["bought"] as Dictionary).get(res_id, 0) as int) + 1
	GameStateStore.economy()["market"] = market
	GameStateStore.economy()["lots_bought"] = (GameStateStore.economy().get("lots_bought", 0) as int) + 1
	success = true
	message = Localization.ru_en("Куплено: %s +%d за %d монет", "Bought: %s +%d for %d coins") % [
		Localization.content_text(ContentDB.get_resource_def(res_id), "label", res_id), int(amount), int(cost)]
