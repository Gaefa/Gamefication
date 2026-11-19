extends "res://tools/player_bot.gd"
## The campaign end to end: the bot plays chapter one, presses "Next chapter" on the finale,
## and goes on until the last chapter's finale. Every other tool starts a chapter cold from
## the command line; this is the only one that walks the road a player walks, and checks
## what that road is supposed to carry:
##   - the title screen opens on the next chapter after the finale's button;
##   - the finished chapter's result is in the campaign file;
##   - the decision flags it left are in the new run's mandate from the first tick;
##   - the first evening brings the letter about how the last chapter ended;
##   - the last finale carries the campaign epilogue and offers no further chapter.
##
## Run: Godot --headless --fixed-fps 60 --path <proj> res://tools/campaign_smoke.tscn --quit-after 2000000 [-- seed=N lean=patron|city]
## Dev tool, not shipped. Writes user://campaign_tools.cfg, never the player's campaign.

var _failures: int = 0
var _switching: bool = false
var _chapters_done: Array[String] = []
var _expect_interlude: bool = false
var _first_evening_seen: bool = false


func _ready() -> void:
	Campaign.reset_campaign()  # the tools' own file (Campaign picks it for res://tools/ scenes)
	EventBus.evening_started.connect(_on_first_evening)
	super._ready()


func _physics_process(delta: float) -> void:
	if _switching:
		return
	super._physics_process(delta)


func _on_first_evening(events: Array) -> void:
	if _first_evening_seen:
		return
	_first_evening_seen = true
	if not _expect_interlude:
		return
	var has_letter: bool = events.any(func(e: Dictionary) -> bool: return e.get("interlude", false) as bool)
	_check(has_letter, "[%s] the first evening brings the letter about the last chapter" % ContentDB.active_chapter)


func _finish(result: String) -> void:
	var chapter: String = ContentDB.active_chapter
	print(_summary(result))
	print("=== CHAPTER %s: %s | вечеров %d, карт %d, день %d ===" % [chapter, result, _evenings, _cards, SimulationRunner.day_count])
	if _ending == "":
		_check(false, "[%s] the chapter reaches a finale (%s)" % [chapter, result])
		_done()
		return
	_chapters_done.append(chapter)
	var recorded: Dictionary = Campaign.result_of(chapter)
	_check(_ending.begins_with(recorded.get("ending", "?") as String), "[%s] the finale is recorded in the campaign (%s)" % [chapter, str(recorded.get("ending", "—"))])
	var next: String = ContentDB.next_chapter_id(chapter)
	var next_btn: Button = EndingManager.get("_next_btn") as Button
	if next == "":
		_check(not next_btn.visible, "the last finale offers no next chapter")
		var theses: String = (EndingManager.get("_body_label") as RichTextLabel).get_parsed_text() if EndingManager.get("_body_label") != null else ""
		_check(theses.contains("ДОРОГА") or theses.contains("THE ROAD"), "the last finale carries the campaign epilogue")
		_check(_chapters_done.size() == ContentDB.get_chapter_ids().size(), "every chapter was played (%d of %d)" % [_chapters_done.size(), ContentDB.get_chapter_ids().size()])
		_done()
		return
	_check(next_btn.visible, "[%s] the finale offers the next chapter" % chapter)
	_check(Campaign.is_unlocked(next), "[%s] %s is unlocked after the finale" % [chapter, next])
	_switching = true
	_go_next(next)


func _go_next(next: String) -> void:
	EndingManager.call("_on_next_chapter_pressed")  # what the finale's button does: reload onto the title screen
	await get_tree().process_frame
	await get_tree().process_frame
	_main = get_tree().current_scene
	_desk = _main.get_node("HUDCanvas/DeskUI") as Control
	var hud: Node = _main.get_node("HUDCanvas/HUD")
	_check((hud.get("_selected_chapter") as String) == next, "the title screen opens on %s (picked: %s)" % [next, hud.get("_selected_chapter") as String])
	var carried: Dictionary = Campaign.carried_flags()
	# A new run, the way the title screen's button starts it.
	_ending = ""
	_evenings = 0
	_cards = 0
	_pop_min = 999
	_stuck = 0
	_frame = 0
	_built.clear()
	_bought = 0
	_feasts = 0
	_built_today.clear()
	_net.clear()
	_upgrades = 0
	_salvaged = 0
	_day_twelve = -1
	_hungry_evenings = 0
	_dry_evenings = 0
	_low_mood_evenings = 0
	_first_evening_seen = false
	_expect_interlude = true
	hud.set("_selected_legacy", "")
	hud.call("_start_new_run", "appointed_administrator")
	SimulationRunner.speed_scale = SPEED
	_check(ContentDB.active_chapter == next, "the run started in %s (active: %s)" % [next, ContentDB.active_chapter])
	_check((GameStateStore.save_meta().get("chapter_id", "") as String) == next, "the save knows its chapter (%s)" % (GameStateStore.save_meta().get("chapter_id", "") as String))
	var flags: Dictionary = GameStateStore.mandate().get("flags", {}) as Dictionary
	var missing: Array[String] = []
	for flag: String in carried:
		if not (flags.get(flag, false) as bool):
			missing.append(flag)
	_check(missing.is_empty(), "[%s] decisions carried from the road are in the mandate (%d carried, missing %s)" % [next, carried.size(), str(missing)])
	_check((GameStateStore.population().get("total", 0) as int) > 0 or GameStateStore.get_all_building_coords().size() > 0, "[%s] the district is on the map" % next)
	_switching = false


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
	print(("PASS: " if ok else "FAIL: ") + what)


func _done() -> void:
	print("дорога: %s" % ", ".join(_chapters_done.map(func(c: String) -> String: return "%s → %s" % [c, str(Campaign.result_of(c).get("ending", "—"))])))
	print("перенесённые флаги: %s" % str(Campaign.carried_flags().keys()))
	print("=== CAMPAIGN SMOKE: %d failures ===" % _failures)
	set_physics_process(false)
	get_tree().quit(1 if _failures > 0 else 0)
