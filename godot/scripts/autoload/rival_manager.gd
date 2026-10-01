extends Node
## RivalManager (Autoload)
## Первый соперник (GAME_DESIGN_BIBLE §21, LORE_BIBLE §12.1): соседний район Мары Восс,
## Гражданский Директорат. Не AI-город, а несколько чисел, которые живут с сезоном, —
## чтобы покровитель сравнивал, грант на Пыль был спорным, а у отзыва было лицо.
##
## Показатель района 0–100 — одна мерка для обоих: люди остаются, город за администратором,
## воды хватает на сезон. Восс держит порядок и жёстко нормирует воду: в Окне тянется к
## высокой цели, в Пыль проседает меньше, чем неподготовленный город.
##
## Self-contained autoload; state lives in GameStateStore.rival() and rides the save.
## Updated from SeasonSystem's daily signal inside the tick pipeline, so it is tick-exact.

const NAME := "Мара Восс"
const DISTRICT := "Сухой Лог"
const NAME_EN := "Mara Voss"
const DISTRICT_EN := "Dry Gully"
## Tuned so preparation wins the grant (prepared ≈58 vs 56 on day 14) and neglect loses it.
const TARGETS := { "season_window": 56.0, "season_dust": 50.0 }
const DRIFT_PER_DAY := 1.5
const GRANT_DAY := 14               # end of the Window: the grant that pays for the Dust
const GRANT_MONEY := 150.0
const AUDIT_EDGE := 5.0             # a gap the patron actually notices (HUD colour + audit)
const WATER_DAYS_FULL := 10.0       # water autonomy counted as fully ready


func _ready() -> void:
	EventBus.season_day_advanced.connect(_on_day_advanced)


func _on_day_advanced(season_id: String, _day_in_season: int, _length: int) -> void:
	# SeasonSystem also emits this when a save is loaded; only a new day may move the rival.
	var rival: Dictionary = GameStateStore.rival()
	var day: int = GameStateStore.climate().get("total_day", 1) as int
	if day <= (rival.get("last_day", 0) as int):
		return
	rival["last_day"] = day
	var target: float = TARGETS.get(season_id, 58.0) as float
	rival["score"] = move_toward(rival.get("score", 55.0) as float, target, DRIFT_PER_DAY)
	if day >= GRANT_DAY and not (rival.get("grant_decided", false) as bool):
		rival["grant_decided"] = true
		_raise_grant_card()


func rival_score() -> float:
	return GameStateStore.rival().get("score", 55.0) as float


## The same yardstick the patron uses for both districts.
func player_score() -> float:
	var happiness: float = GameStateStore.population().get("happiness", 50.0) as float
	var support: float = GameStateStore.mandate().get("support", 50.0) as float
	var days: float = WaterPanel.water_days()
	var water: float = 100.0 if is_inf(days) else clampf(days / WATER_DAYS_FULL, 0.0, 1.0) * 100.0
	return (happiness + support + water) / 3.0


func _raise_grant_card() -> void:
	var directorate: bool = (GameStateStore.mandate().get("patron_id", "") as String) == "civic_directorate"
	var patron: String = "Директорат" if directorate else "Лига"
	var patron_en: String = "The Directorate" if directorate else "The League"
	var ours: int = int(player_score())
	var theirs: int = int(rival_score())
	var card: Dictionary
	if ours >= theirs:
		card = {
			"runtime_id": "rival.grant_result",
			"title": "Грант на Пыль — Ржавой Норе",
			"title_en": "The Dust grant goes to the Rust Pit",
			"body": "%s распределил грант на Пыль: %d в казну Ржавой Норы. Ваш показатель — %d, у района %s (%s) — %d.\n\nДеньги зачислены в казну района." % [patron, int(GRANT_MONEY), ours, NAME, DISTRICT, theirs],
			"body_en": "%s has awarded the Dust grant: %d to the Rust Pit treasury. Your score: %d; %s's district (%s): %d.\n\nThe money has been credited to the district treasury." % [patron_en, int(GRANT_MONEY), ours, NAME_EN, DISTRICT_EN, theirs],
			"options": [
				{ "text": "Принять грант", "text_en": "Accept the grant", "effects": { "add_resources": { "res_money": GRANT_MONEY }, "stat_league_trust": 3, "message": "Грант получен.", "message_en": "The grant has been received." } },
			],
		}
	else:
		card = {
			"runtime_id": "rival.grant_result",
			"title": "Грант на Пыль ушёл району Восс",
			"title_en": "The Dust grant went to Voss's district",
			"body": "%s распределил грант на Пыль: он уходит району %s (%s). Её показатель — %d, ваш — %d.\n\nВ докладе покровителю отмечено, что соседний район подготовлен лучше." % [patron, NAME, DISTRICT, theirs, ours],
			"body_en": "%s has awarded the Dust grant to %s's district (%s). Her score: %d; yours: %d.\n\nThe report to your patron notes that the neighboring district is better prepared." % [patron_en, NAME_EN, DISTRICT_EN, theirs, ours],
			"options": [
				{ "text": "Принять к сведению", "text_en": "Noted", "effects": { "stat_league_trust": -4, "message": "Грант получил соседний район.", "message_en": "The grant went to the neighboring district." } },
			],
		}
	EventManager.pending_events.append(card)
