class_name TickScheduler
## 8-phase tick pipeline. Called once per game second by SimulationRunner.

var _infrastructure: InfrastructureSystem
var _economy: EconomySystem
var _maintenance: MaintenanceSystem
var _issue: IssueSystem
var _progression: ProgressionSystem
var _event: EventSystem
var _pressure: PressureSystem


func _init(
	infrastructure: InfrastructureSystem,
	economy: EconomySystem,
	maintenance: MaintenanceSystem,
	issue: IssueSystem,
	progression: ProgressionSystem,
	event_sys: EventSystem,
	pressure: PressureSystem,
) -> void:
	_infrastructure = infrastructure
	_economy = economy
	_maintenance = maintenance
	_issue = issue
	_progression = progression
	_event = event_sys
	_pressure = pressure


func run_tick() -> void:
	GameStateStore.advance_tick()
	var tick: int = GameStateStore.get_tick()
	EventBus.tick_started.emit(tick)

	# Phase 1: Refresh caches
	_infrastructure.process_tick()

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

	# Phase 7: Events
	_event.process_tick()

	# Phase 8: Update playtime
	GameStateStore.save_meta().playtime_sec = (GameStateStore.save_meta().playtime_sec as float) + 1.0

	EventBus.tick_finished.emit(tick)
