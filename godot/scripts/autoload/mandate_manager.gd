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
	mandate["patron_trust"] = clampf((mandate.get("patron_trust", 50) as float) + float(trust_delta), 0.0, 100.0)

	var passed: bool = score >= 2
	EventBus.audit_completed.emit(passed, score)

	# Pause and show the dynamic result card through the critical-card path.
	SimulationRunner.paused = true
	EventBus.critical_event_started.emit(_build_card(score, water_ok, food_ok, people_ok, trust_delta))


func _build_card(score: int, water_ok: bool, food_ok: bool, people_ok: bool, trust_delta: int) -> Dictionary:
	var directorate: bool = (GameStateStore.mandate().get("patron_id", "") as String) == "civic_directorate"
	var verdict: String
	if directorate:
		match score:
			3: verdict = "Комиссар кивнул и что-то отметил в планшете. «Порядок соблюдён. Директорат это учтёт.»"
			2: verdict = "Комиссар не поднял глаз. «Приемлемо. Но отклонения накапливаются, администратор.»"
			1: verdict = "Комиссар долго молчал. «Показатели ниже нормы. Директорат не любит объяснений — он любит цифры.»"
			_: verdict = "Комиссар закрыл планшет. «Это не управление, это беспорядок. Дальше будет комиссия.»"
	else:
		match score:
			3: verdict = "Койл уехала с хорошими новостями, как любит. «Так и держите. Я доложу наверх, что мандат в надёжных руках.»"
			2: verdict = "Койл кивнула без улыбки. «Сойдёт. Но я приеду снова, и в следующий раз этого будет мало.»"
			1: verdict = "Койл говорила тихо и долго смотрела на пустые полки. «Я пока держу вашу сторону. Пока.»"
			_: verdict = "Койл не повышала голос — это было хуже крика. «Вода по часам, склады пусты. Я не смогу защищать это наверху.»"

	var checklist: String = "\n".join([
		"— Запас воды: %s" % ("в порядке" if water_ok else "недостаточно"),
		"— Запас еды: %s" % ("в порядке" if food_ok else "недостаточно"),
		"— Люди остаются: %s" % ("да" if people_ok else "нет, настроение низкое"),
	])
	var authority: String = "Директората" if directorate else "Лиги"
	var trust_line: String = ("Доверие %s %+d." % [authority, trust_delta])
	var title: String = "Проверка Директората — Комиссар" if directorate else "Аудит Лиги — Инспектор Койл"

	return {
		"runtime_id": "audit.result",
		"title": title,
		"body": "Проверка проведена.\n\n%s\n\n%s\n\n%s" % [checklist, verdict, trust_line],
		"options": [
			{ "text": "Принять к сведению", "effects": {} }
		],
	}
