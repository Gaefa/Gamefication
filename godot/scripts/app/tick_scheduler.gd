class_name TickScheduler
## 8-phase tick pipeline. Called once per game second by SimulationRunner.

var _season: SeasonSystem
var _power: PowerSystem
var _infrastructure: InfrastructureSystem
var _economy: EconomySystem
var _maintenance: MaintenanceSystem
var _issue: IssueSystem
var _progression: ProgressionSystem
var _pressure: PressureSystem


func _init(
	season: SeasonSystem,
	power: PowerSystem,
	infrastructure: InfrastructureSystem,
	economy: EconomySystem,
	maintenance: MaintenanceSystem,
	issue: IssueSystem,
	progression: ProgressionSystem,
	pressure: PressureSystem,
) -> void:
	_season = season
	_power = power
	_infrastructure = infrastructure
	_economy = economy
	_maintenance = maintenance
	_issue = issue
	_progression = progression
	_pressure = pressure


func run_tick() -> void:
	GameStateStore.advance_tick()
	var tick: int = GameStateStore.get_tick()
	EventBus.tick_started.emit(tick)

	# Phase 0: Climate — advance the season day and refresh active modifiers
	# before anything reads them (TDD tick order: season modifiers apply first).
	_season.process_tick()

	# Phase 1: Refresh caches
	_infrastructure.process_tick()

	# Phase 1b: Electricity — decide who is powered before production/happiness read it.
	_power.process_tick()

	# Phase 2: Decay buffs
	_maintenance.process_tick()

	# Phase 3: Economy
	_economy.process_tick()

	# Phase 4: Random issues
	_issue.process_tick()

	# Phase 5: Population & happiness
	_progression.process_tick()

	# Phase 6: Pressure director
	_pressure.process_tick()

	# Phase 7: Events live in the EventManager autoload: it collects them during the day
	# and the Desk presents them in the evening.

	# Phase 8: Update playtime
	GameStateStore.save_meta().playtime_sec = (GameStateStore.save_meta().playtime_sec as float) + 1.0

	EventBus.tick_finished.emit(tick)
