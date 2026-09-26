extends "res://tools/loop_smoke.gd"
## English coverage sweep: plays the loop in English and fails on any Cyrillic text in a
## visible Label/Button/RichTextLabel/tooltip. Before the loop it walks every desk card,
## every finale and every panel. The player's saved language setting is restored on exit.
##
## Run: Godot --headless --fixed-fps 60 --path <proj> res://tools/i18n_smoke.tscn
## Dev tool, not shipped.

var _cyrillic := RegEx.create_from_string("[А-Яа-яЁё]")
var _found: Dictionary = {}  # text → where it was seen
var _saved_locale: String = ""
var _frame: int = 0


func _ready() -> void:
	_saved_locale = Localization.current_locale
	Localization.set_locale("en", true, false)
	super._ready()


func _attach() -> void:
	super._attach()
	await get_tree().process_frame
	_scan("start")
	# Every desk card from content.
	var events: Array = []
	for event_id: String in ContentDB.get_event_ids():
		var evt: Dictionary = ContentDB.get_event_def(event_id).duplicate(true)
		evt["runtime_id"] = event_id
		events.append(evt)
	_desk.call("_on_evening_started", events)
	for i: int in events.size():
		_desk.call("_show_event", i)
		_scan("desk " + (events[i] as Dictionary).get("runtime_id", "") as String)
	_desk.visible = false
	# Every panel.
	var hud: Node = _main.get_node("HUDCanvas/HUD")
	for panel: String in ["toggle_help", "toggle_city_panel", "toggle_settings", "toggle_governance"]:
		hud.call(panel)
		_scan(panel)
		hud.call(panel)
	for autoload: Node in [SeasonPanel, WaterPanel]:
		autoload.call("open")
		_scan(autoload.name)
		autoload.call("_toggle")
	# Every finale.
	for ending_id: String in ["ending.win.loyal", "ending.win.protector", "ending.win.directorate_order",
			"ending.win.directorate_defiant", "ending.lose.isolation", "ending.lose.commissar",
			"ending.lose.convoy", "ending.lose.riot", "ending.lose.exodus"]:
		EndingManager.call("_show_finale", ContentDB.get_ending_def(ending_id), ending_id)
		_scan(ending_id)
	(EndingManager.get("_layer") as CanvasLayer).visible = false
	print("sweep (cards, panels, finales): %d untranslated so far" % _found.size())
	# Back to a clean run for the loop.
	EventManager.clear_pending()
	_main.get_node("HUDCanvas/HUD").call("_start_new_run", "appointed_administrator")


func _physics_process(delta: float) -> void:
	_frame += 1
	if _frame % 30 == 0:
		_scan("loop day %d" % SimulationRunner.day_count)
	super._physics_process(delta)


func _finish(result: String) -> void:
	_scan("finale")
	for text: String in _found:
		print("CYRILLIC [%s]: %s" % [_found[text], text.replace("\n", " ⏎ ").left(160)])
	print("=== I18N SMOKE: %d untranslated strings ===" % _found.size())
	Localization.set_locale(_saved_locale if _saved_locale != "" else "ru", false, true)
	super._finish(result)


func _scan(where: String) -> void:
	_scan_node(get_tree().root, where)


func _scan_node(node: Node, where: String) -> void:
	if node is CanvasLayer and not (node as CanvasLayer).visible:
		return
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	var texts: Array[String] = []
	if node is Label:
		texts.append((node as Label).text)
	elif node is Button:
		texts.append((node as Button).text)
	elif node is RichTextLabel:
		texts.append((node as RichTextLabel).get_parsed_text())
	if node is Control:
		texts.append((node as Control).tooltip_text)
	for text: String in texts:
		if _cyrillic.search(text) != null and not _found.has(text):
			_found[text] = where
	for child: Node in node.get_children():
		_scan_node(child, where)
