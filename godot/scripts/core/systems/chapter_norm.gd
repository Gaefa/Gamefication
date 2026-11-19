class_name ChapterNorm
## The chapter's own audit norm (chapter.json "norm"): what this patron sent you here for.
## Water, food and people are asked of every district; the norm is the fourth line of both
## audits and a condition of the mandate's extension at the end of the term. Two kinds:
##
##   "quota"     — the patron's wagons. Whenever the store of `resource` holds `keep` plus a
##                 full `wagon`, a wagon leaves: the store drops, the district is paid `pay`,
##                 and the shipped total (climate.norm_shipped) grows toward `targets`
##                 (one figure per audit; the last one also stands at the end of the term).
##   "buildings" — what must stand by each audit: `stages` is a list of {type id: count}.
##
## A founder answers to no one and has no norm. The Desk reads the shipped total as
## stat_norm_shipped and how far the district is behind the next target as stat_norm_gap.


func process_tick() -> void:
	if not active() or not is_quota():
		return
	var norm: Dictionary = def()
	var res_id: String = norm.get("resource", "") as String
	var wagon: float = maxf(norm.get("wagon", 50.0) as float, 1.0)
	var keep: float = norm.get("keep", 0.0) as float
	var climate: Dictionary = GameStateStore.climate()
	if climate.get("norm_hold", false) as bool:
		return  # the administrator holds the wagons (HUD goal row)
	# The patron takes what the mandate names and no more: past the last figure the wagons stop.
	var final_target: float = (norm.get("targets", [0.0]) as Array).back() as float
	while shipped() < final_target and GameStateStore.get_resource(res_id) >= keep + wagon:
		GameStateStore.set_resource(res_id, GameStateStore.get_resource(res_id) - wagon)
		climate["norm_shipped"] = shipped() + wagon
		var pay: Dictionary = norm.get("pay", {}) as Dictionary
		for pay_id: String in pay:
			GameStateStore.add_resource(pay_id, pay[pay_id] as float)


static func def() -> Dictionary:
	return ContentDB.get_chapter_def().get("norm", {}) as Dictionary


static func active() -> bool:
	return not def().is_empty() and (GameStateStore.mandate().get("patron_id", "") as String) != ""


static func is_quota() -> bool:
	return (def().get("kind", "") as String) == "quota"


static func shipped() -> float:
	return GameStateStore.climate().get("norm_shipped", 0.0) as float


static func holding() -> bool:
	return GameStateStore.climate().get("norm_hold", false) as bool


static func stage_count() -> int:
	var norm: Dictionary = def()
	return ((norm.get("targets", []) as Array) if is_quota() else (norm.get("stages", []) as Array)).size()


## The stage the district is working toward now: 0 before the first audit, then 1, and the
## last one from the last audit to the end of the term.
static func current_stage() -> int:
	return clampi(GameStateStore.mandate().get("audits_done", 0) as int, 0, maxi(stage_count() - 1, 0))


static func last_stage() -> int:
	return maxi(stage_count() - 1, 0)


## What the stage asks for and what the district has: {"have": float, "need": float}.
static func progress(stage: int) -> Dictionary:
	var norm: Dictionary = def()
	if stage_count() == 0:
		return {"have": 0.0, "need": 0.0}
	stage = clampi(stage, 0, stage_count() - 1)
	if is_quota():
		return {"have": shipped(), "need": (norm.get("targets", []) as Array)[stage] as float}
	var wanted: Dictionary = (norm.get("stages", []) as Array)[stage] as Dictionary
	var have: float = 0.0
	var need: float = 0.0
	for type_id: String in wanted:
		var count: int = 0
		for coord: Vector2i in GameStateStore.get_all_building_coords():
			var bld: Dictionary = GameStateStore.get_building(coord)
			if (bld.get("type", "") as String) == type_id and not (bld.get("damaged", false) as bool):
				count += 1
		need += wanted[type_id] as float
		have += minf(float(count), wanted[type_id] as float)
	return {"have": have, "need": need}


static func met(stage: int) -> bool:
	var now: Dictionary = progress(stage)
	return (now["have"] as float) >= (now["need"] as float)


## How far behind the stage's figure the district is, 0 when it is met.
static func gap(stage: int) -> float:
	var now: Dictionary = progress(stage)
	return maxf((now["need"] as float) - (now["have"] as float), 0.0)


static func label() -> String:
	return Localization.content_text(def(), "label", "")


## "1 250 / 2 200" for the goals list and the audit sheet.
static func figures(stage: int) -> String:
	var now: Dictionary = progress(stage)
	return "%d / %d" % [int(now["have"] as float), int(now["need"] as float)]
