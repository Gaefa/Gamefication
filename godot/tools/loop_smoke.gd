extends Node
## Full-loop smoke test (RELEASE_PLAN §2.4: the cycle plays from appointment to a finale
## without blockers). Runs the real main scene — real SimulationRunner day timer, real
## evening desk, real critical cards, real HUD — at the game's 300 ticks per day, with an
## auto-player that resolves every desk card with its first affordable option. Logs each
## evening and flags a blocker if the simulation sits paused with nothing to unpause it.
##
## Run: Godot --headless --fixed-fps 60 --path <proj> res://tools/loop_smoke.tscn
## Dev tool, not shipped.

const SPEED := 5.0            # 5 ticks per sim second → a 300-tick day in 60 sim seconds
const MAX_DAY := 34
const STUCK_FRAMES := 600     # 10 sim seconds paused with no desk and no finale → blocker

var _main: Node
var _desk: Control
var _stuck: int = 0
var _evenings: int = 0
var _cards: int = 0
var _ending: String = ""


func _ready() -> void:
	SaveService.set("_autosave_timer", -1.0e12)  # never write over the player's real save slot
	EventBus.ending_triggered.connect(func(eid: String, kind: String) -> void:
		_ending = "%s (%s)" % [eid, kind])
	EventBus.evening_started.connect(func(events: Array) -> void:
		_evenings += 1
		print("  вечер, день %d: %d карт." % [SimulationRunner.day_count, events.size()]))
	EventBus.critical_event_started.connect(func(data: Dictionary) -> void:
		print("  СРОЧНО, день %d: %s" % [SimulationRunner.day_count, data.get("runtime_id", "?") as String]))
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_main)
	_attach.call_deferred()


func _attach() -> void:
	get_tree().current_scene = _main  # effects and HUD look the orchestrator up here
	_desk = _main.get_node("HUDCanvas/DeskUI") as Control
	SimulationRunner.speed_scale = SPEED


func _physics_process(_delta: float) -> void:
	if _desk == null:
		return
	if _ending != "":
		_finish("финал " + _ending)
	elif SimulationRunner.day_count > MAX_DAY:
		_finish("дошли до дня %d без финала" % SimulationRunner.day_count)
	elif _desk.visible:
		_stuck = 0
		_auto_resolve()
	elif SimulationRunner.paused:
		_stuck += 1
		if _stuck > STUCK_FRAMES:
			_finish("БЛОКЕР: пауза без Стола и финала (день %d, фаза %d)" % [SimulationRunner.day_count, SimulationRunner.current_phase])
	else:
		_stuck = 0


func _auto_resolve() -> void:
	if (_desk.get("_finish_btn") as Button).visible:
		_desk.call("_finish_evening")
		return
	if (_desk.get("_next_btn") as Button).visible:
		_desk.call("_show_next_event")
		return
	var events: Array = _desk.get("_events") as Array
	var idx: int = _desk.get("_current_index") as int
	if idx >= events.size():
		return
	var evt: Dictionary = events[idx] as Dictionary
	var options: Array = evt.get("options", []) as Array
	if options.is_empty():
		return
	var pick: int = 0
	for i: int in options.size():
		var cost: Dictionary = (options[i] as Dictionary).get("cost", {})
		if cost.is_empty() or GameStateStore.can_afford(cost):
			pick = i
			break
	var opt: Dictionary = options[pick] as Dictionary
	_cards += 1
	print("    день %d: %s → «%s»" % [SimulationRunner.day_count, evt.get("runtime_id", "?") as String, (opt.get("text", "?") as String).left(40)])
	var preview: String = _desk.call("_consequences_text", opt.get("effects", {}), opt.get("cost", {})) as String
	if preview != "":
		print("      ⓘ " + preview.replace("\n", " | "))
	_desk.call("_select_option", evt.get("runtime_id", "") as String, pick, opt.get("effects", {}), opt.get("cost", {}))


func _finish(result: String) -> void:
	print("=== SMOKE: %s | вечеров %d, карт %d, день %d ===" % [result, _evenings, _cards, SimulationRunner.day_count])
	print((EndingManager.get("_theses_label") as RichTextLabel).get_parsed_text())
	set_physics_process(false)
	get_tree().quit()
