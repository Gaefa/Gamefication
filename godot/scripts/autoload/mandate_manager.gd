extends Node
## MandateManager (Autoload)
## The audit is the mandate's concrete checkpoint (GDD §13.5). On the control day
## Inspector Coyle reviews the district — water reserve, food, whether people are
## staying — and the result moves patron trust up or down. Low trust then drives the
## existing escalation (grant_freeze ≤40, recall_ultimatum ≤25) and the endings.
##
## Foreshadowed by patron.letter.audit_warning (day 15); audit dates come from scenario.json.
## Presented as a dynamic result card via the critical-card path (DeskUI critical mode).
## Self-contained autoload — no orchestrator/tick-pipeline changes.

const WATER_OK := 60.0              # reserve considered "ready" (tuning)
const FOOD_OK := 30.0
const HAPPINESS_OK := 40.0          # people are staying, not fleeing


func _ready() -> void:
	EventBus.tick_finished.connect(_on_tick_finished)


func _on_tick_finished(_tick: int) -> void:
	var mandate: Dictionary = GameStateStore.mandate()
	var next_day: int = next_audit_day()
	if next_day == 0:
		return
	if (mandate.get("patron_id", "") as String) == "":
		return  # a founder has no patron to audit them
	if (GameStateStore.climate().get("total_day", 1) as int) < next_day:
		return
	_run_audit()


func _run_audit() -> void:
	var mandate: Dictionary = GameStateStore.mandate()
	var second: bool = (mandate.get("audits_done", 0) as int) == 1
	mandate["audits_done"] = (mandate.get("audits_done", 0) as int) + 1

	var water: float = GameStateStore.get_resource("res_water_stockpile")
	var food: float = GameStateStore.get_resource("res_food")
	var happiness: float = GameStateStore.population().get("happiness", 50.0) as float

	var water_ok: bool = water >= WATER_OK
	var food_ok: bool = food >= FOOD_OK
	var people_ok: bool = happiness >= HAPPINESS_OK
	var score: int = (1 if water_ok else 0) + (1 if food_ok else 0) + (1 if people_ok else 0)

	var trust_delta: float
	var spoilage_ok: bool = food_preserved()
	if second:
		score += 1 if spoilage_ok else 0
	match score - (1 if second else 0):
		3: trust_delta = 12
		2: trust_delta = 5
		1: trust_delta = -6
		_: trust_delta = -15
	# The patron measures against the neighbour (RivalManager): a clear gap moves trust too.
	var gap: float = RivalManager.player_score() - RivalManager.rival_score()
	if gap <= -RivalManager.AUDIT_EDGE:
		trust_delta -= 4
	elif gap >= RivalManager.AUDIT_EDGE:
		trust_delta += 3
	if second:
		trust_delta *= 1.5
	else:
		mandate["first_audit_score"] = score
	mandate["patron_trust"] = clampf((mandate.get("patron_trust", 50) as float) + float(trust_delta), 0.0, 100.0)

	var passed: bool = score >= (3 if second else 2)
	EventBus.audit_completed.emit(passed, score)

	# Pause and show the dynamic result card through the critical-card path.
	SimulationRunner.paused = true
	EventBus.critical_event_started.emit(_build_card(score, water_ok, food_ok, people_ok, trust_delta))


func _build_card(score: int, water_ok: bool, food_ok: bool, people_ok: bool, trust_delta: float) -> Dictionary:
	var directorate: bool = (GameStateStore.mandate().get("patron_id", "") as String) == "civic_directorate"
	var verdict: String
	var verdict_en: String
	if directorate:
		match score:
			3:
				verdict = "Заключение комиссара: нормы выполнены, замечаний нет."
				verdict_en = "Commissar's conclusion: the targets are met, no remarks."
			2:
				verdict = "Заключение комиссара: приемлемо. Одна норма не выполнена и внесена в дело."
				verdict_en = "Commissar's conclusion: acceptable. One target was missed and entered in the file."
			1:
				verdict = "Заключение комиссара: показатели ниже нормы. Объяснения к делу не приобщаются."
				verdict_en = "Commissar's conclusion: figures below standard. Explanations are not added to the file."
			_:
				verdict = "Заключение комиссара: район не управляется. Вопрос передан комиссии Директората."
				verdict_en = "Commissar's conclusion: the district is not under control. The matter goes to a Directorate commission."
	else:
		match score:
			3:
				verdict = "Заключение Койл: район готов. Наверх уходит доклад без замечаний."
				verdict_en = "Coyle's conclusion: the district is ready. The report goes up with no remarks."
			2:
				verdict = "Заключение Койл: приемлемо. Одна норма не выполнена; к следующей проверке её нужно закрыть."
				verdict_en = "Coyle's conclusion: acceptable. One target was missed; it must be met by the next inspection."
			1:
				verdict = "Заключение Койл: две нормы из трёх не выполнены. В докладе она просит дать вам ещё срок."
				verdict_en = "Coyle's conclusion: two targets out of three were missed. In her report she asks to give you more time."
			_:
				verdict = "Заключение Койл: ни одна норма не выполнена. Защищать ваш мандат наверху ей нечем."
				verdict_en = "Coyle's conclusion: none of the targets is met. She has nothing to defend your mandate with."

	var checklist: String = "\n".join([
		"— Запас воды: %s" % ("в порядке" if water_ok else "недостаточно"),
		"— Запас еды: %s" % ("в порядке" if food_ok else "недостаточно"),
		"— Люди остаются: %s" % ("да" if people_ok else "нет, настроение низкое"),
	])
	var checklist_en: String = "\n".join([
		"— Water reserve: %s" % ("OK" if water_ok else "insufficient"),
		"— Food reserve: %s" % ("OK" if food_ok else "insufficient"),
		"— People are staying: %s" % ("yes" if people_ok else "no, morale is low"),
	])
	var second: bool = (GameStateStore.mandate().get("audits_done", 0) as int) >= 2
	if second:
		checklist += "\n— Потери еды <25%% начального запаса: %s" % ("да" if food_preserved() else "нет")
		checklist_en += "\n— Food lost <25%% of starting reserve: %s" % ("yes" if food_preserved() else "no")
		var first: Variant = GameStateStore.mandate().get("first_audit_score", null)
		var prior: String = "%d/3" % int(first) if first != null else "результат в прежнем деле"
		var prior_en: String = "%d/3" % int(first) if first != null else "result in the previous file"
		verdict = "Повторная проверка: выполнено %d из 4 норм. Первый аудит: %s." % [score, prior]
		verdict_en = "Second inspection: %d of 4 targets met. First audit: %s." % [score, prior_en]
	var authority: String = "Директората" if directorate else "Лиги"
	var authority_en: String = "Directorate" if directorate else "League"
	var trust_line: String = ("Доверие %s %+.1f." if second else "Доверие %s %+d.") % [authority, trust_delta]
	var trust_line_en: String = ("%s trust %+.1f." if second else "%s trust %+d.") % [authority_en, trust_delta]
	var title: String = "Проверка Директората — Комиссар" if directorate else "Аудит Лиги — Инспектор Койл"
	var title_en: String = "Directorate Inspection — the Commissar" if directorate else "League Audit — Inspector Coyle"
	var comparison: String = "Для сравнения — район %s: %d, ваш: %d." % [
		RivalManager.NAME, int(RivalManager.rival_score()), int(RivalManager.player_score())]
	var comparison_en: String = "For comparison — %s's district: %d, yours: %d." % [
		RivalManager.NAME_EN, int(RivalManager.rival_score()), int(RivalManager.player_score())]

	return {
		"runtime_id": "audit.result2" if second else "audit.result",
		"title": title,
		"title_en": title_en,
		"body": "Проверка проведена.\n\n%s\n\n%s\n\n%s\n\n%s" % [checklist, comparison, verdict, trust_line],
		"body_en": "Inspection complete.\n\n%s\n\n%s\n\n%s\n\n%s" % [checklist_en, comparison_en, verdict_en, trust_line_en],
		"options": [
			{ "text": "Принять к сведению", "text_en": "Noted", "effects": {} }
		],
	}


func next_audit_day() -> int:
	var days: Array = ContentDB.get_audit_days()
	var done: int = GameStateStore.mandate().get("audits_done", 0) as int
	return int(days[done]) if done < days.size() else 0


func food_preserved() -> bool:
	var climate: Dictionary = GameStateStore.climate()
	var start: float = climate.get("heat_food_start", 0.0) as float
	var lost: float = climate.get("heat_food_spoiled", 0.0) as float
	# An empty incoming reserve with no loss counts as no waste, not division by zero.
	return lost < start * 0.25 if start > 0.0 else is_zero_approx(lost)
