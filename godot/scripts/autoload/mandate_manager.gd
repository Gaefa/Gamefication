extends Node
## MandateManager (Autoload)
## The audit is the mandate's concrete checkpoint (GDD §13.5). On the control day
## Inspector Coyle reviews the district — water reserve, food, whether people are
## staying — and the result moves patron trust up or down. Low trust then drives the
## existing escalation (grant_freeze ≤40, recall_ultimatum ≤25) and the endings.
##
## Foreshadowed by patron.letter.audit_warning (day 8); the audit lands on day 10.
## Presented as a dynamic result card via the critical-card path (DeskUI critical mode).
## Self-contained autoload — no orchestrator/tick-pipeline changes.

const AUDIT_DAY := 20               # control date — mid-Пыль, so it tests preparation (tuning)
const WATER_OK := 60.0              # reserve considered "ready" (tuning)
const FOOD_OK := 30.0
const HAPPINESS_OK := 40.0          # people are staying, not fleeing


func _ready() -> void:
	EventBus.tick_finished.connect(_on_tick_finished)


func _on_tick_finished(_tick: int) -> void:
	var mandate: Dictionary = GameStateStore.mandate()
	if mandate.get("audit_done", false) as bool:
		return
	if (GameStateStore.climate().get("total_day", 1) as int) < AUDIT_DAY:
		return
	_run_audit()


func _run_audit() -> void:
	var mandate: Dictionary = GameStateStore.mandate()
	mandate["audit_done"] = true

	var water: float = GameStateStore.get_resource("res_water_stockpile")
	var food: float = GameStateStore.get_resource("res_food")
	var happiness: float = GameStateStore.population().get("happiness", 50.0) as float

	var water_ok: bool = water >= WATER_OK
	var food_ok: bool = food >= FOOD_OK
	var people_ok: bool = happiness >= HAPPINESS_OK
	var score: int = (1 if water_ok else 0) + (1 if food_ok else 0) + (1 if people_ok else 0)

	var trust_delta: int
	match score:
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
	mandate["patron_trust"] = clampf((mandate.get("patron_trust", 50) as float) + float(trust_delta), 0.0, 100.0)

	var passed: bool = score >= 2
	EventBus.audit_completed.emit(passed, score)

	# Pause and show the dynamic result card through the critical-card path.
	SimulationRunner.paused = true
	EventBus.critical_event_started.emit(_build_card(score, water_ok, food_ok, people_ok, trust_delta))


func _build_card(score: int, water_ok: bool, food_ok: bool, people_ok: bool, trust_delta: int) -> Dictionary:
	var directorate: bool = (GameStateStore.mandate().get("patron_id", "") as String) == "civic_directorate"
	var verdict: String
	var verdict_en: String
	if directorate:
		match score:
			3:
				verdict = "Комиссар кивнул и что-то отметил в планшете. «Порядок соблюдён. Директорат это учтёт.»"
				verdict_en = "The Commissar nodded and noted something on his tablet. \"Order maintained. The Directorate will take note.\""
			2:
				verdict = "Комиссар не поднял глаз. «Приемлемо. Но отклонения накапливаются, администратор.»"
				verdict_en = "The Commissar didn't look up. \"Acceptable. But the deviations are adding up, administrator.\""
			1:
				verdict = "Комиссар долго молчал. «Показатели ниже нормы. Директорат не любит объяснений — он любит цифры.»"
				verdict_en = "The Commissar was silent a long time. \"Figures below standard. The Directorate doesn't like explanations. It likes numbers.\""
			_:
				verdict = "Комиссар закрыл планшет. «Это не управление, это беспорядок. Дальше будет комиссия.»"
				verdict_en = "The Commissar closed his tablet. \"This isn't administration, it's disorder. A commission comes next.\""
	else:
		match score:
			3:
				verdict = "Койл уехала с хорошими новостями, как любит. «Так и держите. Я доложу наверх, что мандат в надёжных руках.»"
				verdict_en = "Coyle left with good news, the way she likes it. \"Keep it up. I'll report upstairs that the mandate is in safe hands.\""
			2:
				verdict = "Койл кивнула без улыбки. «Сойдёт. Но я приеду снова, и в следующий раз этого будет мало.»"
				verdict_en = "Coyle nodded without a smile. \"It'll do. But I'll be back, and next time this won't be enough.\""
			1:
				verdict = "Койл говорила тихо и долго смотрела на пустые полки. «Я пока держу вашу сторону. Пока.»"
				verdict_en = "Coyle spoke quietly and stared at the empty shelves. \"I'm still on your side. For now.\""
			_:
				verdict = "Койл не повышала голос — это было хуже крика. «Вода по часам, склады пусты. Я не смогу защищать это наверху.»"
				verdict_en = "Coyle didn't raise her voice, which was worse than shouting. \"Water by the hour, empty stores. I can't defend this upstairs.\""

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
	var authority: String = "Директората" if directorate else "Лиги"
	var authority_en: String = "Directorate" if directorate else "League"
	var trust_line: String = ("Доверие %s %+d." % [authority, trust_delta])
	var trust_line_en: String = ("%s trust %+d." % [authority_en, trust_delta])
	var title: String = "Проверка Директората — Комиссар" if directorate else "Аудит Лиги — Инспектор Койл"
	var title_en: String = "Directorate Inspection — the Commissar" if directorate else "League Audit — Inspector Coyle"
	var comparison: String = "Для сравнения — район %s: %d, ваш: %d." % [
		RivalManager.NAME, int(RivalManager.rival_score()), int(RivalManager.player_score())]
	var comparison_en: String = "For comparison — %s's district: %d, yours: %d." % [
		RivalManager.NAME_EN, int(RivalManager.rival_score()), int(RivalManager.player_score())]

	return {
		"runtime_id": "audit.result",
		"title": title,
		"title_en": title_en,
		"body": "Проверка проведена.\n\n%s\n\n%s\n\n%s\n\n%s" % [checklist, comparison, verdict, trust_line],
		"body_en": "Inspection complete.\n\n%s\n\n%s\n\n%s\n\n%s" % [checklist_en, comparison_en, verdict_en, trust_line_en],
		"options": [
			{ "text": "Принять к сведению", "text_en": "Noted", "effects": {} }
		],
	}
