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
	_hud.call("_set_active_category", "Infrastructure")
	Localization.set_locale("ru", true, false)
	var core: RichTextLabel = _hud.get("_core_label")
	UiIcons._cache["res://assets/ui/icons/money.svg"] = null
	_hud.call("_update_resource_bar")
	_check(not core.text.contains("money.svg") and core.get_parsed_text().contains("Деньги:"), "missing resource image preserves name and value")
	UiIcons._cache.erase("res://assets/ui/icons/money.svg")

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
	WaterPanel.call("_toggle")
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
		await _save("ui_" + locale + "_960.png")
	print("UI ICONS SMOKE: %d failures" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _check_layout(context: String) -> void:
	var viewport: Rect2 = get_viewport().get_visible_rect()
	var bar: Control = _hud.get("_resource_bar")
	_check(viewport.encloses(bar.get_global_rect()), context + ": bar inside viewport")
	for field: String in ["_core_label", "_utility_label", "_city_label", "_risk_label"]:
		var control: Control = _hud.get(field)
		_check(bar.get_global_rect().encloses(control.get_global_rect()), context + ": " + field + " inside bar")
		if control is RichTextLabel:
			_check(control.get_content_height() <= control.size.y + 1 and control.get_content_width() <= control.size.x + 1, context + ": " + field + " fully visible")
	var build: Control = _hud.get("_build_panel")
	var minimap: Control = _hud.get("_minimap_panel")
	_check(build.position.y >= bar.get_global_rect().end.y and minimap.position.y >= bar.get_global_rect().end.y, context + ": panels below bar")
	var core: RichTextLabel = _hud.get("_core_label")
	var risk: RichTextLabel = _hud.get("_risk_label")
	_check(core.text.count("[img=") == 6 and risk.text.count("[img=") == 4, context + ": six resource / four pressure icons")


func _settle() -> void:
	for frame: int in 12:
		await get_tree().process_frame
	RenderingServer.force_draw(true)
	await RenderingServer.frame_post_draw


func _save(filename: String) -> void:
	RenderingServer.force_draw(true)
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(_dir.path_join(filename)) == OK, "screenshot " + filename)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		push_error(message)
