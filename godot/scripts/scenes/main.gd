## main.gd -- Root scene script.
## Owns the GameOrchestrator and wires UI signals.
extends Node2D


## The game orchestrator (owns all runtime objects).
var orchestrator: GameOrchestrator = null

## Currently selected building type for placement (null = nothing selected).
var selected_building_type: String = ""

## Currently hovered hex coordinate.
var hovered_hex: Vector2i = Vector2i(-1, -1)

## Hex size for rendering (pixels from center to corner, flat-top).
const HEX_SIZE: float = 32.0


# ------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------

func _ready() -> void:
	orchestrator = GameOrchestrator.new()
	add_child(orchestrator)

	# Start a new game immediately for now (will be replaced with menu later)
	orchestrator.start_new_game()

	# Pass references to child layers
	var world_root := $WorldRoot
	if world_root:
		world_root.setup(orchestrator, HEX_SIZE)

	var hud_root := $CanvasLayer/HudRoot
	if hud_root:
		hud_root.setup(orchestrator)

	# Connect tick signal to refresh visuals
	EventBus.tick_completed.connect(_on_tick_completed)
	EventBus.building_placed.connect(_on_building_placed)
	EventBus.building_removed.connect(_on_building_removed)


func _unhandled_input(event: InputEvent) -> void:
	if not orchestrator or not GameStateStore.is_playing:
		return

	# Mouse click for building placement / selection
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(event.global_position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Deselect
			selected_building_type = ""
			EventBus.message_posted.emit("Deselected", 1.0)

	# Keyboard shortcuts
	if event is InputEventKey and event.pressed:
		if Input.is_action_just_pressed("upgrade_building"):
			_handle_upgrade()
		elif Input.is_action_just_pressed("repair_building"):
			_handle_repair()
		elif Input.is_action_just_pressed("bulldoze"):
			_handle_bulldoze()

	# Track hovered hex
	if event is InputEventMouseMotion:
		var camera := $Camera2D as Camera2D
		if camera:
			var world_pos: Vector2 = camera.get_global_mouse_position()
			hovered_hex = HexCoords.pixel_to_axial(world_pos.x, world_pos.y, HEX_SIZE)


# ------------------------------------------------------------------
# Click handlers
# ------------------------------------------------------------------

func _handle_left_click(screen_pos: Vector2) -> void:
	var camera := $Camera2D as Camera2D
	if not camera:
		return

	var world_pos: Vector2 = camera.get_global_mouse_position()
	var hex: Vector2i = HexCoords.pixel_to_axial(world_pos.x, world_pos.y, HEX_SIZE)

	if selected_building_type != "":
		# Place building
		var cmd := PlaceBuildingCommand.new()
		cmd.q = hex.x
		cmd.r = hex.y
		cmd.building_type = selected_building_type
		var ok: bool = orchestrator.execute_command(cmd)
		if ok:
			AudioManager.play_build()
		else:
			EventBus.message_posted.emit("Cannot place here!", 2.0)
	else:
		# Select building at hex (for info display)
		hovered_hex = hex
		var bld = orchestrator.hex_grid.get_building(hex.x, hex.y) if orchestrator.hex_grid else null
		if bld != null:
			# Emit selection info (HUD will pick it up)
			pass


func _handle_upgrade() -> void:
	if hovered_hex == Vector2i(-1, -1):
		return
	var cmd := UpgradeBuildingCommand.new()
	cmd.q = hovered_hex.x
	cmd.r = hovered_hex.y
	var ok: bool = orchestrator.execute_command(cmd)
	if ok:
		AudioManager.play_upgrade()
	else:
		EventBus.message_posted.emit("Cannot upgrade!", 2.0)


func _handle_repair() -> void:
	if hovered_hex == Vector2i(-1, -1):
		return
	var cmd := RepairBuildingCommand.new()
	cmd.q = hovered_hex.x
	cmd.r = hovered_hex.y
	var ok: bool = orchestrator.execute_command(cmd)
	if ok:
		AudioManager.play_repair()


func _handle_bulldoze() -> void:
	if hovered_hex == Vector2i(-1, -1):
		return
	var cmd := BulldozeCommand.new()
	cmd.q = hovered_hex.x
	cmd.r = hovered_hex.y
	var ok: bool = orchestrator.execute_command(cmd)
	if ok:
		AudioManager.play_bulldoze()


# ------------------------------------------------------------------
# Signal handlers
# ------------------------------------------------------------------

func _on_tick_completed(_tick_num: int) -> void:
	# Refresh rendering layers
	var world_root := $WorldRoot
	if world_root and world_root.has_method("refresh"):
		world_root.refresh()


func _on_building_placed(_coord: Vector2i, _type_id: String) -> void:
	var world_root := $WorldRoot
	if world_root and world_root.has_method("refresh"):
		world_root.refresh()


func _on_building_removed(_coord: Vector2i) -> void:
	var world_root := $WorldRoot
	if world_root and world_root.has_method("refresh"):
		world_root.refresh()


## Select a building type for placement (called from HUD buttons).
func select_building(type_id: String) -> void:
	selected_building_type = type_id
	EventBus.message_posted.emit("Selected: %s" % type_id, 2.0)
