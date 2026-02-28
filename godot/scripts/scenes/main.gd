extends Node2D
## Root scene. Bootstraps the game, handles global input, and routes UI events.

var _orchestrator: GameOrchestrator
var _build_mode: String = ""  # "" = none, otherwise building type_id
var _hud: Control
var _selected_coord: Vector2i = Vector2i(-9999, -9999)
var _show_ranges: bool = false


func _ready() -> void:
	_orchestrator = GameOrchestrator.new()
	_orchestrator.new_game()
	_setup_scene_tree()
	_connect_signals()


func _setup_scene_tree() -> void:
	# World root (terrain + buildings). Isometric Y-squish is in HexCoords.ISO_Y.
	var world := Node2D.new()
	world.name = "World"
	add_child(world)

	var terrain_layer := Node2D.new()
	terrain_layer.name = "TerrainLayer"
	terrain_layer.set_script(load("res://scripts/scenes/hex_terrain_layer.gd"))
	world.add_child(terrain_layer)

	var building_layer := Node2D.new()
	building_layer.name = "BuildingLayer"
	building_layer.set_script(load("res://scripts/scenes/building_layer.gd"))
	world.add_child(building_layer)

	var overlay_layer := Node2D.new()
	overlay_layer.name = "OverlayLayer"
	overlay_layer.set_script(load("res://scripts/scenes/overlay_layer.gd"))
	world.add_child(overlay_layer)

	var fx_layer := Node2D.new()
	fx_layer.name = "FXLayer"
	fx_layer.set_script(load("res://scripts/scenes/fx_layer.gd"))
	world.add_child(fx_layer)

	# Camera
	var cam := Camera2D.new()
	cam.name = "Camera"
	cam.set_script(load("res://scripts/scenes/camera_controller.gd"))
	cam.zoom = Vector2(1.5, 1.5)
	add_child(cam)

	# HUD (CanvasLayer)
	var canvas := CanvasLayer.new()
	canvas.name = "HUDCanvas"
	add_child(canvas)

	_hud = Control.new()
	_hud.name = "HUD"
	_hud.set_script(load("res://scripts/scenes/hud_root.gd"))
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_hud)

	# Initialize rendering
	terrain_layer.call("render_terrain", _orchestrator.hex_grid)
	building_layer.call("set_hex_grid", _orchestrator.hex_grid)


func _connect_signals() -> void:
	EventBus.build_mode_changed.connect(_on_build_mode_changed)
	EventBus.building_placed.connect(_on_building_changed)
	EventBus.building_removed.connect(_on_building_changed)
	EventBus.building_upgraded.connect(func(_c: Vector2i, _l: int) -> void: _refresh_buildings())
	EventBus.building_repaired.connect(func(_c: Vector2i) -> void: _refresh_buildings())


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			# Use real hit-test: check if any MOUSE_FILTER_STOP Control is under cursor
			if _is_click_on_ui(mb.position):
				return
			_handle_click()
			get_viewport().set_input_as_handled()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			_build_mode = ""
			EventBus.build_mode_changed.emit("")
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed:
			_handle_key(ke)


func _is_click_on_ui(screen_pos: Vector2) -> bool:
	## Real hit-test: walk all Control children in HUDCanvas and check rect overlap.
	var canvas_node: Node = get_node_or_null("HUDCanvas")
	if canvas_node == null:
		return false
	return _check_control_hit(canvas_node, screen_pos)


func _check_control_hit(node: Node, pos: Vector2) -> bool:
	## Recursively checks if pos hits any visible MOUSE_FILTER_STOP Control.
	if node is Control:
		var ctrl := node as Control
		if not ctrl.visible:
			return false
		if ctrl.mouse_filter == Control.MOUSE_FILTER_STOP:
			if ctrl.get_global_rect().has_point(pos):
				return true
	for child: Node in node.get_children():
		if _check_control_hit(child, pos):
			return true
	return false


func _handle_click() -> void:
	var world_pos: Vector2 = get_global_mouse_position()
	var coord: Vector2i = HexCoords.pixel_to_axial(world_pos)

	if _build_mode != "":
		var cmd := PlaceBuildingCommand.new(coord, _build_mode)
		_orchestrator.command_bus.execute(cmd)
	else:
		_selected_coord = coord
		EventBus.selection_changed.emit(coord)
		_refresh_overlay_state()


func _handle_key(ke: InputEventKey) -> void:
	if ke.keycode == KEY_ESCAPE:
		_build_mode = ""
		EventBus.build_mode_changed.emit("")
	elif Input.is_action_just_pressed("toggle_ranges"):
		_show_ranges = not _show_ranges
		_refresh_overlay_state()
	elif ke.keycode == KEY_H:
		if _hud and _hud.has_method("toggle_help"):
			_hud.call("toggle_help")
	elif Input.is_action_just_pressed("upgrade_building"):
		if _selected_coord != Vector2i(-9999, -9999):
			var cmd := UpgradeBuildingCommand.new(_selected_coord)
			_orchestrator.command_bus.execute(cmd)
	elif Input.is_action_just_pressed("repair_building"):
		if _selected_coord != Vector2i(-9999, -9999):
			var cmd := RepairBuildingCommand.new(_selected_coord)
			_orchestrator.command_bus.execute(cmd)
	elif Input.is_action_just_pressed("bulldoze"):
		if _selected_coord != Vector2i(-9999, -9999):
			var cmd := BulldozeCommand.new(_selected_coord)
			_orchestrator.command_bus.execute(cmd)
	elif ke.keycode == KEY_SPACE:
		SimulationRunner.toggle_pause()
	elif ke.keycode == KEY_1:
		SimulationRunner.set_speed(1.0)
	elif ke.keycode == KEY_2:
		SimulationRunner.set_speed(2.0)
	elif ke.keycode == KEY_3:
		SimulationRunner.set_speed(3.0)


func _on_build_mode_changed(type_id: String) -> void:
	_build_mode = type_id


func _on_building_changed(_coord: Vector2i, _type_id: String) -> void:
	_refresh_buildings()


func _refresh_buildings() -> void:
	var bl: Node = get_node_or_null("World/BuildingLayer")
	if bl:
		bl.call("refresh")
	_refresh_overlay_state()


func _refresh_overlay_state() -> void:
	var overlay: Node = get_node_or_null("World/OverlayLayer")
	if overlay and overlay.has_method("set_show_ranges"):
		overlay.call("set_show_ranges", _show_ranges, _selected_coord)


func get_orchestrator() -> GameOrchestrator:
	return _orchestrator
