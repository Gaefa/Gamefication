extends Node
## Real HUD/cursor P6 checks; run without --headless.
## Godot --path godot --resolution 1280x720 res://tools/ui_icons_smoke.tscn -- out=/abs/existing/dir

const UiIcons = preload("res://scripts/scenes/ui_icons.gd")
var _main: Node
var _hud: Control
var _failures: int = 0
var _dir: String = "user://"


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("ui_icons_smoke requires a real renderer")
		get_tree().quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_dir = arg.trim_prefix("out=")
	SaveService.set("_autosave_timer", -1.0e12)
	seed(12345)
	_main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_main)
	_run.call_deferred()


func _run() -> void:
	get_tree().current_scene = _main
	SimulationRunner.paused = true
	_hud = _main.get("_hud") as Control
	_hud.call("_close_start_panel")
	OnboardingManager.suppressed = true
	Input.warp_mouse(Vector2(600, 400))
	await _settle()
	for icon: String in ["money", "food", "water", "wood", "stone", "tools", "people", "mandate", "infrastructure", "residential", "production", "commercial", "culture", "advanced"]:
		var texture: Texture2D = UiIcons.texture(icon)
		_check(texture != null and texture.get_size() == Vector2(64, 64), icon + " vector loads")
		_check(texture == UiIcons.texture(icon), icon + " is cached")
	for kind: String in ["inspect", "build", "blocked", "pan"]:
		var cursor: Texture2D = UiIcons.texture(kind, "cursors")
		_check(cursor != null and cursor.get_size() == Vector2(32, 32), kind + " cursor loads at 32px")
	_check(UiIcons.texture("missing_icon") == null and UiIcons.bb("missing_icon") == "", "missing art leaves text-only fallback")
	_check(UiIcons._cache.has("res://assets/ui/icons/missing_icon.svg"), "missing art cached")

	for locale: String in ["ru", "en"]:
		Localization.set_locale(locale, true, false)
		await _settle()
		_check_layout(locale + " / 1280px")
		await _save("ui_" + locale + ".png")
		var buttons: Dictionary = _hud.get("_category_buttons")
		for category: String in UiIcons.CATEGORIES:
			var button: Button = buttons[category]
			_check(button.icon != null and not button.text.is_empty(), category + " icon keeps localized label")
			button.pressed.emit()
			_check(_hud.get("_active_category") == category, category + " selection still works")
			await _settle()
			_check_build_list(locale + " / " + category)
	_hud.call("_set_active_category", "Infrastructure")
	Localization.set_locale("ru", true, false)
	# Chips keep the number and the resource name (tooltip) whatever happens to the icon.
	_hud.call("_update_resource_bar")
	var money: Dictionary = (_hud.get("_res_chips") as Dictionary)["res_money"] as Dictionary
	_check((money["value"] as Label).text.is_valid_int() and (money["panel"] as Control).tooltip_text.contains("Деньги"), "resource chip shows a number and names itself in the tooltip")

	# The production cursor uses the same placement rules as the click command.
	var world_screen := Vector2(600, 400)
	var test_coord := Vector2i(12, 12)
	GameStateStore.set_terrain(test_coord, 0)
	var world_pos: Vector2 = HexCoords.axial_to_pixel(test_coord)
	_check(_main.call("_cursor_for_pointer", world_screen, world_pos, false) == "inspect", "world inspection cursor")
	_check(_main.call("_cursor_for_pointer", world_screen, world_pos, true) == "pan", "middle-drag cursor")
	EventBus.build_mode_changed.emit("bld_road")
	_check(_main.call("_cursor_for_pointer", world_screen, world_pos, false) == "build", "valid placement cursor")
	GameStateStore.set_building(test_coord, {"type": "bld_road", "level": 0})
	_check(_main.call("_cursor_for_pointer", world_screen, world_pos, false) == "blocked", "occupied placement cursor")
	GameStateStore.remove_building(test_coord)
	GameStateStore.set_resource("res_stone", 0.0)
	_check(_main.call("_cursor_for_pointer", world_screen, world_pos, false) == "blocked", "unaffordable placement cursor")
	_check(_main.call("_cursor_for_pointer", Vector2(20, 10), world_pos, false) == "", "HUD retains normal OS cursor")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	_main.call("_handle_key", escape)
	_check(_main.get("_build_mode") == "", "Escape cancels build mode")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	(_hud.get("_utility_label") as Label).gui_input.emit(click)
	_check(WaterPanel.get("_visible"), "water panel click target preserved")
	Input.warp_mouse(Vector2(640, 360))
	await _settle()
	_check(_main.get("_cursor_kind") == "", "autoload modal uses normal OS cursor")
	var selection_before: Vector2i = _main.get("_selected_coord")
	await _click_at(Vector2(640, 360))
	_check(_main.get("_selected_coord") == selection_before, "modal click does not select the map behind it")
	var coord: Vector2i = HexCoords.pixel_to_axial((_main as Node2D).get_canvas_transform().affine_inverse() * Vector2(640, 360))
	var original_building: Dictionary = GameStateStore.get_building(coord).duplicate(true)
	var original_terrain: int = GameStateStore.get_terrain(coord)
	var original_stone: float = GameStateStore.get_resource("res_stone")
	GameStateStore.remove_building(coord)
	GameStateStore.set_terrain(coord, 0)
	GameStateStore.set_resource("res_stone", 100.0)
	EventBus.build_mode_changed.emit("bld_road")
	await _click_at(Vector2(640, 360))
	_check(not GameStateStore.has_building(coord) and GameStateStore.get_resource("res_stone") == 100.0, "modal click does not build or spend resources behind it")
	EventBus.build_mode_changed.emit("")
	WaterPanel.call("_toggle")
	await _click_at(Vector2(640, 360))
	_check(_main.get("_selected_coord") == coord, "closing modal restores map selection")
	EventBus.build_mode_changed.emit("bld_road")
	await _click_at(Vector2(640, 360))
	_check(GameStateStore.get_building(coord).get("type") == "bld_road" and GameStateStore.get_resource("res_stone") < 100.0, "closing modal restores construction")
	GameStateStore.remove_building(coord)
	await _check_touch()
	if not original_building.is_empty():
		GameStateStore.set_building(coord, original_building)
	GameStateStore.set_terrain(coord, original_terrain)
	GameStateStore.set_resource("res_stone", original_stone)
	EventBus.build_mode_changed.emit("")
	_main.call("_refresh_buildings")
	_main.set("_selected_coord", selection_before)
	EventBus.selection_changed.emit(selection_before)
	(_hud.get("_toast_label") as Label).text = ""
	(_hud.get("_city_label") as Label).gui_input.emit(click)
	_check(SeasonPanel.get("_visible"), "season panel click target preserved")
	SeasonPanel.call("_toggle")

	# Stress layout with large values, pressure warnings, and a narrower logical viewport.
	for resource: String in ["res_money", "res_food", "res_water_stockpile", "res_wood", "res_stone", "res_tools"]:
		GameStateStore.set_cap(resource, 999999)
		GameStateStore.set_resource(resource, 999999)
	GameStateStore.pressure()["categories"] = {"food": 75.0, "water": 45.0, "happiness": 20.0, "mandate": 90.0}
	get_tree().root.content_scale_size = Vector2i(960, 720)
	get_tree().root.size = Vector2i(960, 720)
	for locale: String in ["ru", "en"]:
		Localization.set_locale(locale, true, false)
		await _settle()
		_check_layout(locale + " / 960px / large values")
		_check_build_list(locale + " / 960px")
		await _save("ui_" + locale + "_960.png")
	print("UI ICONS SMOKE: %d failures" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _check_layout(context: String) -> void:
	var viewport: Rect2 = get_viewport().get_visible_rect()
	var bar: Control = _hud.get("_resource_bar")
	_check(viewport.encloses(bar.get_global_rect()), context + ": bar inside viewport")
	for field: String in ["_utility_label", "_city_label", "_trust_bar", "_support_bar", "_rival_label"]:
		var control: Control = _hud.get(field)
		_check(bar.get_global_rect().encloses(control.get_global_rect()), context + ": " + field + " inside bar")
		if control is RichTextLabel:
			_check(control.get_content_height() <= control.size.y + 1 and control.get_content_width() <= control.size.x + 1, context + ": " + field + " fully visible")
	var build: Control = _hud.get("_build_panel")
	var minimap: Control = _hud.get("_minimap_panel")
	_check(build.position.y >= bar.get_global_rect().end.y and minimap.position.y >= bar.get_global_rect().end.y, context + ": panels below bar")
	_check((_hud.get("_res_chips") as Dictionary).size() == 6 and (_hud.get("_pressure_bars") as Dictionary).size() == 4, context + ": six resource chips / four pressure gauges")


func _check_build_list(context: String) -> void:
	var scroll: ScrollContainer = _hud.get("_build_scroll")
	var list: VBoxContainer = _hud.get("_build_vbox")
	_check(not scroll.get_h_scroll_bar().visible, context + ": no horizontal scroll")
	_check(list.size.x <= scroll.size.x + 1, context + ": building cards fit menu width")
	for child: Control in list.get_children():
		_check(child.size.x <= scroll.size.x + 1, context + ": card fits width")
		for label: Node in child.find_children("*", "Label", true, false):
			_check((label as Label).get_visible_line_count() == (label as Label).get_line_count(), context + ": all card lines visible")


func _settle() -> void:
	for frame: int in 12:
		await get_tree().process_frame
	RenderingServer.force_draw(true)


## A finger: the first tap aims, the second builds, a drag pans and builds nothing, and the
## building's card pressed again leaves build mode (a phone has no right button or Escape).
func _check_touch() -> void:
	var none := Vector2i(-9999, -9999)
	var at := Vector2(640, 360)
	var camera: Node2D = _main.get_node("Camera") as Node2D
	var camera_home: Vector2 = camera.global_position
	var cell: Vector2i = HexCoords.pixel_to_axial((_main as Node2D).get_canvas_transform().affine_inverse() * at)
	var was_building: Dictionary = GameStateStore.get_building(cell).duplicate(true)
	var was_terrain: int = GameStateStore.get_terrain(cell)
	GameStateStore.remove_building(cell)
	GameStateStore.set_terrain(cell, 0)
	GameStateStore.set_resource("res_stone", 100.0)
	var overlay: Node = _main.get_node("World/OverlayLayer")
	EventBus.build_mode_changed.emit("bld_road")
	await _tap_at(at)
	_check(_main.get("touch") == true and overlay.get("touch") == true, "a finger switches the map to touch")
	_check(not GameStateStore.has_building(cell) and _main.get("_aim") == cell and overlay.get("preview_cell") == cell, "the first tap aims and builds nothing")
	_check((_hud.get("_toast_label") as Label).text != "", "the first tap says what the second will do")
	await _tap_at(at, at + Vector2(80, 0))
	_check(not GameStateStore.has_building(cell), "a dragged finger builds nothing")
	_check(not camera.global_position.is_equal_approx(camera_home), "a dragged finger pans the map")
	camera.global_position = camera_home
	await _settle()
	await _tap_at(at)
	_check(GameStateStore.get_building(cell).get("type") == "bld_road", "the second tap on the aimed cell builds")
	_check(_main.get("_aim") == none and overlay.get("preview_cell") == null, "the aim is gone after the build")
	_hud.call("_on_build_button", "bld_road")
	_check(_main.get("_build_mode") == "", "on touch the same card again leaves build mode")
	GameStateStore.remove_building(cell)
	# Two fingers: the map zooms by how far they part, and nothing is built or moved.
	EventBus.build_mode_changed.emit("bld_road")
	var zoom_home: Vector2 = camera.get("zoom")
	camera.global_position = camera_home
	await _finger(0, at - Vector2(100, 0), true)
	await _finger(1, at + Vector2(100, 0), true)
	var spread := InputEventScreenDrag.new()
	spread.index = 1
	spread.position = at + Vector2(200, 0)
	spread.relative = Vector2(100, 0)
	Input.parse_input_event(spread)
	await get_tree().process_frame
	await _finger(1, at + Vector2(200, 0), false)
	await _finger(0, at - Vector2(100, 0), false)
	_check(((camera.get("zoom") as Vector2) / zoom_home).is_equal_approx(Vector2(1.5, 1.5)), "two fingers parting by half zoom the map by half")
	_check(not GameStateStore.has_building(cell) and _main.get("_aim") == none and camera.global_position.is_equal_approx(camera_home), "a pinch builds nothing, aims nothing and does not move the map")
	camera.set("zoom", zoom_home)
	await _tap_at(at, at + Vector2(80, 0))
	_check((camera.get("zoom") as Vector2).is_equal_approx(zoom_home) and not camera.global_position.is_equal_approx(camera_home), "after a pinch one finger pans again and does not zoom")
	camera.global_position = camera_home
	EventBus.build_mode_changed.emit("")
	# The tutorial and the help say nothing of keys, a wheel or a right button to a finger.
	var desktop_only := RegEx.create_from_string("WASD|колес|wheel|ПКМ|RMB|Esc|Пробел|Space|[Кк]лик|[Cc]lick|\\[b\\][A-Z0-9]\\[/b\\]")
	var deaf: Array[int] = []
	var steps: Array = TutorialManager.call("_make_steps")
	for i: int in steps.size():
		var step: Dictionary = steps[i]
		if desktop_only.search(step.get("touch", step.get("text", "")) as String) != null:
			deaf.append(i)
	_check(deaf.is_empty(), "every tutorial step that names a key or the mouse has a text for a finger (steps %s)" % str(deaf))
	_check((_hud.call("_get_help_text") as String).begins_with(Localization.ru_en("НА СЕНСОРНОМ ЭКРАНЕ", "ON A TOUCH SCREEN")), "on touch the help opens with the touch controls")
	if not was_building.is_empty():
		GameStateStore.set_building(cell, was_building)
	GameStateStore.set_terrain(cell, was_terrain)
	var selected: Vector2i = _main.get("_selected_coord")
	await _click_at(at)
	_check(not (_hud.call("_get_help_text") as String).begins_with(Localization.ru_en("НА СЕНСОРНОМ ЭКРАНЕ", "ON A TOUCH SCREEN")), "with a mouse the help has no touch paragraph")
	_check(_main.get("touch") == false and overlay.get("touch") == false, "a mouse click switches back")
	_main.set("_selected_coord", selected)
	_hud.call("_on_build_button", "bld_road")
	_hud.call("_on_build_button", "bld_road")
	_check(_main.get("_build_mode") == "bld_road", "with a mouse the same card again keeps build mode")
	EventBus.build_mode_changed.emit("")


func _tap_at(at: Vector2, lift_at: Vector2 = Vector2.INF) -> void:
	var down := InputEventScreenTouch.new()
	down.position = at
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var end: Vector2 = at
	if lift_at != Vector2.INF:
		end = lift_at
		var drag := InputEventScreenDrag.new()
		drag.position = end
		drag.relative = end - at
		Input.parse_input_event(drag)
		await get_tree().process_frame
	var up := InputEventScreenTouch.new()
	up.position = end
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _finger(index: int, at: Vector2, pressed: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.position = at
	touch.pressed = pressed
	Input.parse_input_event(touch)
	await get_tree().process_frame


func _click_at(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = at
		click.global_position = at
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		Input.parse_input_event(click)
		await get_tree().process_frame


func _save(filename: String) -> void:
	RenderingServer.force_draw(true)
	_check(get_viewport().get_texture().get_image().save_png(_dir.path_join(filename)) == OK, "screenshot " + filename)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		push_error(message)
