extends "res://tools/player_bot.gd"
## Where a tick goes. The bot plays a chapter; on the last days every system of the tick
## pipeline and every listener of tick_finished is timed, and the totals are printed with
## the number of buildings. Run it when TICK COST in qa.sh grows.
##
## Run: Godot --headless --fixed-fps 60 --path <proj> res://tools/perf_probe.tscn --quit-after 400000 -- chapter=<id>
## Dev tool, not shipped.

const SAMPLE_TICKS := 600

var _probed: bool = false


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _probed and _ending == "" and SimulationRunner.day_count >= ContentDB.get_win_day() - 3 and not SimulationRunner.paused and (_desk == null or not _desk.visible):
		_probed = true
		_probe()


func _probe() -> void:
	var orch: GameOrchestrator = _orch()
	var sched: TickScheduler = orch.tick_scheduler
	var parts: Dictionary = {}
	var systems: Array = [["season", sched.get("_season")], ["infrastructure", sched.get("_infrastructure")], ["power", sched.get("_power")],
		["maintenance", sched.get("_maintenance")], ["economy", sched.get("_economy")], ["issue", sched.get("_issue")],
		["progression", sched.get("_progression")], ["pressure", sched.get("_pressure")]]
	for extra: Variant in sched.get("_extras") as Array:
		systems.append([(extra.get_script() as Script).resource_path.get_file().trim_suffix(".gd"), extra])
	var whole_before: int = Time.get_ticks_usec()
	for _i: int in SAMPLE_TICKS:
		for pair: Array in systems:
			var started: int = Time.get_ticks_usec()
			(pair[1] as Object).call("process_tick")
			parts[pair[0]] = (parts.get(pair[0], 0) as int) + Time.get_ticks_usec() - started
		var listeners: int = Time.get_ticks_usec()
		EventBus.tick_finished.emit(GameStateStore.get_tick())
		parts["tick_finished listeners (HUD, events, endings…)"] = (parts.get("tick_finished listeners (HUD, events, endings…)", 0) as int) + Time.get_ticks_usec() - listeners
	var whole_ms: float = float(Time.get_ticks_usec() - whole_before) / 1000.0 / float(SAMPLE_TICKS)
	print("PERF PROBE [%s]: %.2f ms a tick with %d buildings, by part:" % [ContentDB.active_chapter, whole_ms, GameStateStore.get_all_building_coords().size()])
	var names: Array = parts.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return (parts[a] as int) > (parts[b] as int))
	for part_name: String in names:
		print("  %6.3f ms  %s" % [float(parts[part_name] as int) / 1000.0 / float(SAMPLE_TICKS), part_name])
