extends Node
## P5 renderer/diagnostic regression check. Run without --headless:
## Godot --path godot res://tools/pins_smoke.tscn -- out=/abs/existing/dir
## The catalog freezes separately evaluated states: empty global stock and weak
## pressure cannot coexist under the production diagnostic priority rules.

const Overlay = preload("res://scripts/scenes/overlay_layer.gd")
const Buildings = preload("res://scripts/scenes/building_layer.gd")
const LABELS := ["repair", "issue", "road", "power", "water", "stock", "pressure"]

class CatalogPin extends Overlay:
	var diagnostic: Dictionary
	func _draw_diagnostic_pins() -> void:
		_has_blinking_pin = false
		_draw_diagnostic_pin(Vector2i.ZERO, diagnostic)

class BuildingProbe extends Buildings:
	var alerts: int = 0
	var cracks: int = 0
	var dots: int = 0
	func _draw_alert(c: Vector2) -> void:
		alerts += 1
		super(c)
	func _draw_crack(c: Vector2) -> void:
		cracks += 1
		super(c)
	func _draw_level_dots(c: Vector2, level: int) -> void:
		dots += 1
		super(c, level)

var _failures: int = 0
var _draws: int = 0
var _orch: GameOrchestrator
var _viewport: SubViewport
var _overlay: Node2D
var _dir: String = "user://"
var _diagnostics: Array[Dictionary] = []
var _buildings: Array[Dictionary] = []


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("pins_smoke needs a real renderer (omit --headless)")
		get_tree().quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_dir = arg.trim_prefix("out=")
	SaveService.set("_autosave_timer", -1.0e12)
	SimulationRunner.paused = true
	GameStateStore.reset()
	_orch = GameOrchestrator.new()
	_orch.build()
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(256, 256)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_overlay = Overlay.new()
	_overlay.position = Vector2(128, 160)
	_overlay.draw.connect(func() -> void: _draws += 1)
	_viewport.add_child(_overlay)
	_run.call_deferred()


func get_orchestrator() -> GameOrchestrator:
	return _orch


func _fixture(label: String) -> Dictionary:
	GameStateStore.get_buildings().clear()
	GameStateStore.set_resource("res_water_stockpile", 100.0)
	var bld := {"type": "bld_shelter", "level": 1, "powered": true}
	if label == "repair":
		bld.merge({"damaged": true, "has_issue": true, "powered": false}, true)
	elif label == "issue":
		bld.merge({"has_issue": true, "powered": false}, true)
	elif label == "power":
		bld.powered = false
	GameStateStore.set_building(Vector2i.ZERO, bld)
	if label not in ["repair", "issue", "road"]:
		GameStateStore.set_building(Vector2i(0, -1), {"type": "bld_road", "level": 0})
	if label in ["stock", "pressure", "healthy"]:
		var source := Vector2i(4, 0) if label == "pressure" else Vector2i(1, 0)
		GameStateStore.set_building(source, {"type": "bld_well_pump", "level": 0})
	if label == "stock":
		GameStateStore.set_resource("res_water_stockpile", 0.0)
	_orch.coverage.invalidate()
	return bld


func _run() -> void:
	for label: String in LABELS:
		var bld: Dictionary = _fixture(label)
		var diag: Dictionary = _overlay.call("_primary_diagnostic", Vector2i.ZERO, bld)
		_check(diag.get("label") == label, "primary diagnostic: " + label)
		_diagnostics.append(diag.duplicate(true))
		_buildings.append(bld.duplicate(true))
	for label: String in LABELS + ["event"]:
		var texture: Texture2D = _overlay.call("_pin_texture", label)
		_check(texture != null and texture.get_size() == Vector2(128, 128), label + " texture loads at 128px")
		_check(texture == _overlay.call("_pin_texture", label), label + " texture cached")
	_check(_overlay.call("_pin_texture", "missing_pin") == null, "missing texture returns null")
	_check((_overlay.get("_pin_cache") as Dictionary).has("missing_pin"), "missing texture cached")
	var healthy: Dictionary = _fixture("healthy")
	_check((_overlay.call("_primary_diagnostic", Vector2i.ZERO, healthy) as Dictionary).is_empty(), "healthy building has no diagnostic")

	_fixture("repair")
	_overlay.call("_invalidate_diagnostics")  # the game invalidates via building signals and ticks
	var red_a: Image = await _capture()
	var before: int = _draws
	await get_tree().create_timer(0.25).timeout
	var red_b: Image = await _capture()
	_check(_draws > before and _overlay.get("_has_blinking_pin"), "red pin schedules redraws")
	_check(red_a.get_data() != red_b.get_data(), "blink changes rendered pixels")
	_fixture("issue")
	_overlay.call("_invalidate_diagnostics")  # the game invalidates via building signals and ticks
	var textured: Image = await _capture()
	before = _draws
	await _capture()
	_check(not _overlay.get("_has_blinking_pin") and _draws == before, "warning stops continuous redraws")
	(_overlay.get("_pin_cache") as Dictionary)["issue"] = null
	_overlay.call("_invalidate_diagnostics")  # the game invalidates via building signals and ticks
	var fallback: Image = await _capture()
	_check(fallback.get_used_rect().has_area() and fallback.get_data() != textured.get_data(), "missing texture renders old letter badge")
	(_overlay.get("_pin_cache") as Dictionary).erase("issue")
	GameStateStore.get_buildings().clear()
	_overlay.call("_invalidate_diagnostics")  # the game invalidates via building signals and ticks
	var empty: Image = await _capture()
	before = _draws
	await _capture()
	_check(not empty.get_used_rect().has_area() and _draws == before, "empty world clears pins and stays idle")
	_overlay.call("set_show_logistics", true)
	await _capture()
	before = _draws
	await _capture()
	_check(_draws > before, "logistics lens still redraws without pins")
	_overlay.call("set_show_logistics", false)
	_overlay.hide()

	var probe := BuildingProbe.new()
	probe.position = Vector2(128, 160)
	_viewport.add_child(probe)
	GameStateStore.set_building(Vector2i.ZERO, {"type": "bld_shelter", "level": 1, "has_issue": true})
	probe.queue_redraw()
	await _capture()
	_check(probe.alerts == 0 and probe.dots > 0, "sprite issue has no duplicate alert; level dots retained")
	GameStateStore.get_building(Vector2i.ZERO)["damaged"] = true
	probe.queue_redraw()
	await _capture()
	_check(probe.cracks > 0, "damaged sprite retains crack")
	GameStateStore.set_building(Vector2i.ZERO, {"type": "missing_building", "level": 0, "has_issue": true})
	probe.queue_redraw()
	await _capture()
	_check(probe.alerts > 0, "polygon fallback retains alert")
	_viewport.queue_free()
	await _catalog()
	print("PINS SMOKE: %d failures" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _capture() -> Image:
	await get_tree().process_frame
	RenderingServer.force_draw(true)
	await RenderingServer.frame_post_draw
	return _viewport.get_texture().get_image()


func _catalog() -> void:
	# Snapshot each tested state into its own card using the actual building/pin renderers.
	var board := SubViewport.new()
	board.size = Vector2i(1280, 470)
	board.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(board)
	var background := ColorRect.new()
	background.color = Color("252b32")
	background.size = Vector2(1280, 470)
	board.add_child(background)
	_caption(board, "P5 / BUILDING DIAGNOSTICS", Vector2(28, 20), 26)
	_caption(board, "7 captured gameplay states / real building + overlay renderers / upper row at 3x, lower row at 1x", Vector2(28, 59), 16)
	for i: int in LABELS.size():
		var x: float = 92.0 + i * 182.0
		GameStateStore.get_buildings().clear()
		GameStateStore.set_building(Vector2i.ZERO, _buildings[i])
		for scale_factor: float in [3.0, 1.0]:
			var card := SubViewport.new()
			card.size = Vector2i(180, 220) if scale_factor == 3.0 else Vector2i(180, 100)
			card.transparent_bg = true
			card.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			add_child(card)
			var buildings := Buildings.new()
			buildings.position = Vector2(75, 190 if scale_factor == 3.0 else 70)
			buildings.scale = Vector2.ONE * scale_factor
			card.add_child(buildings)
			var pin := CatalogPin.new()
			pin.diagnostic = _diagnostics[i]
			pin.position = buildings.position
			pin.scale = buildings.scale
			pin.set_process(false)
			card.add_child(pin)
			await get_tree().process_frame
			RenderingServer.force_draw(true)
			await RenderingServer.frame_post_draw
			var card_image: Image = card.get_texture().get_image()
			_check(card_image.get_used_rect().has_area(), "%s catalog card rendered at %dx" % [LABELS[i], int(scale_factor)])
			var shot := TextureRect.new()
			shot.texture = ImageTexture.create_from_image(card_image)
			shot.position = Vector2(x - 90, 90 if scale_factor == 3.0 else 330)
			board.add_child(shot)
			card.queue_free()
		_caption(board, LABELS[i], Vector2(x - 38, 310), 18)
	_caption(board, "Catalog combines independent states: stock = 0 masks pressure in a live city. Red pins use live blink alpha.", Vector2(28, 438), 15)
	await get_tree().process_frame
	RenderingServer.force_draw(true)
	await RenderingServer.frame_post_draw
	var path: String = _dir.path_join("pins_states.png")
	_check(board.get_texture().get_image().save_png(path) == OK, "catalog screenshot saved: " + path)


func _caption(parent: Node, text: String, at: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		push_error(message)
