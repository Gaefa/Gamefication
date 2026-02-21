extends Control
## Top-level HUD: resource bar, building palette, info panel, event popup, toast.

var _resource_label: Label
var _info_label: Label
var _toast_label: Label
var _toast_timer: float = 0.0
var _build_panel: VBoxContainer
var _event_panel: PanelContainer
var _selected_coord: Vector2i = Vector2i(-9999, -9999)


func _ready() -> void:
	# Root Control ignores mouse — children handle their own
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_resource_bar()
	_build_building_palette()
	_build_info_panel()
	_build_event_panel()
	_build_toast()
	_connect_signals()


func _connect_signals() -> void:
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.toast_requested.connect(_on_toast)
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.game_event_spawned.connect(_on_event_spawned)
	EventBus.tick_finished.connect(_on_tick_finished)


# --- Resource bar (top) ---

func _build_resource_bar() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(PRESET_TOP_WIDE)
	panel.custom_minimum_size.y = 40
	panel.mouse_filter = Control.MOUSE_FILTER_STOP  # block clicks on the bar itself
	add_child(panel)

	_resource_label = Label.new()
	_resource_label.text = "Resources loading..."
	_resource_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_resource_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_resource_label)


func _on_resources_changed(resources: Dictionary) -> void:
	var parts: Array[String] = []
	var show_res: Array = ["coins", "food", "wood", "stone", "energy", "science"]
	for res_id: String in show_res:
		var val: float = resources.get(res_id, 0.0) as float
		var def: Dictionary = ContentDB.get_resource_def(res_id)
		var label_text: String = def.get("label", res_id) as String
		parts.append("%s: %d" % [label_text, int(val)])
	var pop: int = GameStateStore.population().total as int
	var happiness: float = GameStateStore.population().happiness as float
	parts.append("Pop: %d" % pop)
	parts.append("Happy: %d%%" % int(happiness))
	parts.append("Lv%d" % (GameStateStore.progression().city_level as int))
	_resource_label.text = " | ".join(parts)


# --- Building palette (left) ---

func _build_building_palette() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 50)
	scroll.size = Vector2(160, 500)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP  # block clicks behind palette
	add_child(scroll)

	_build_panel = VBoxContainer.new()
	_build_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(_build_panel)

	for type_id: String in ContentDB.get_building_ids():
		var def: Dictionary = ContentDB.get_building_def(type_id)
		var btn := Button.new()
		btn.text = "%s (Lv%d)" % [def.get("label", type_id), def.get("unlock_level", 1)]
		btn.tooltip_text = def.get("description", "") as String
		btn.pressed.connect(_on_build_button.bind(type_id))
		_build_panel.add_child(btn)


func _on_build_button(type_id: String) -> void:
	EventBus.build_mode_changed.emit(type_id)


# --- Info panel (bottom-right) ---

func _build_info_panel() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# Position manually at bottom-right
	panel.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT)
	panel.offset_left = -300
	panel.offset_top = -200
	add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	_info_label = Label.new()
	_info_label.text = "Click a tile for info"
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_info_label)


func _on_selection_changed(coord: Vector2i) -> void:
	_selected_coord = coord
	_update_info()


func _update_info() -> void:
	if _selected_coord == Vector2i(-9999, -9999):
		return
	var bld: Dictionary = GameStateStore.get_building(_selected_coord)
	if bld.is_empty():
		var terrain_id: int = GameStateStore.get_terrain(_selected_coord)
		var tdef: Dictionary = ContentDB.get_terrain_def(terrain_id)
		_info_label.text = "Terrain: %s\nCoord: (%d, %d)" % [
			tdef.get("label", "Unknown"),
			_selected_coord.x, _selected_coord.y
		]
		return

	var type_id: String = bld.get("type", "") as String
	var level: int = bld.get("level", 0) as int
	var def: Dictionary = ContentDB.get_building_def(type_id)
	var ldata: Dictionary = ContentDB.building_level_data(type_id, level)
	var stage: String = ldata.get("stage", "?") as String

	var text: String = "%s (%s)\nLevel %d\n" % [def.get("label", type_id), stage, level]
	var produces: Dictionary = ldata.get("produces", {})
	if not produces.is_empty():
		text += "Produces: "
		var pp: Array = []
		for r: String in produces:
			pp.append("%s: %.1f" % [r, produces[r] as float])
		text += ", ".join(pp) + "\n"
	var consumes: Dictionary = ldata.get("consumes", {})
	if not consumes.is_empty():
		text += "Consumes: "
		var cc: Array = []
		for r: String in consumes:
			cc.append("%s: %.1f" % [r, consumes[r] as float])
		text += ", ".join(cc) + "\n"
	if bld.get("damaged", false) as bool:
		text += "[DAMAGED]\n"
	if bld.get("has_issue", false) as bool:
		text += "[ISSUE]\n"

	# Keyboard shortcuts hint
	text += "\n[U] Upgrade  [R] Repair  [B] Bulldoze"
	_info_label.text = text


# --- Event popup ---

func _build_event_panel() -> void:
	_event_panel = PanelContainer.new()
	_event_panel.set_anchors_preset(PRESET_CENTER)
	_event_panel.size = Vector2(400, 250)
	_event_panel.position = Vector2(-200, -125)
	_event_panel.visible = false
	_event_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_event_panel)


func _on_event_spawned(event_data: Dictionary) -> void:
	_event_panel.visible = true
	# Clear previous children
	for c: Node in _event_panel.get_children():
		c.queue_free()

	var vbox := VBoxContainer.new()
	_event_panel.add_child(vbox)

	var title := Label.new()
	title.text = event_data.get("title", "Event") as String
	title.add_theme_font_size_override("font_size", 18)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	var body := Label.new()
	body.text = event_data.get("body", "") as String
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(body)

	var btn_row := HBoxContainer.new()
	vbox.add_child(btn_row)

	var ev_id: String = event_data.get("id", "") as String

	var accept_btn := Button.new()
	accept_btn.text = event_data.get("accept_label", "Accept") as String
	accept_btn.pressed.connect(_resolve_event.bind(ev_id, true))
	btn_row.add_child(accept_btn)

	var decline_btn := Button.new()
	decline_btn.text = event_data.get("decline_label", "Decline") as String
	decline_btn.pressed.connect(_resolve_event.bind(ev_id, false))
	btn_row.add_child(decline_btn)


func _resolve_event(ev_id: String, accept: bool) -> void:
	var main_node: Node = get_tree().current_scene
	if main_node and main_node.has_method("get_orchestrator"):
		var orch: GameOrchestrator = main_node.call("get_orchestrator") as GameOrchestrator
		var cmd := ResolveEventCommand.new(ev_id, accept)
		orch.command_bus.execute(cmd)
	_event_panel.visible = false


# --- Toast ---

func _build_toast() -> void:
	_toast_label = Label.new()
	_toast_label.set_anchors_preset(PRESET_BOTTOM_WIDE)
	_toast_label.offset_top = -60
	_toast_label.offset_bottom = -30
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 14)
	_toast_label.modulate.a = 0.0
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_label)


func _on_toast(text: String, duration: float) -> void:
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	_toast_timer = duration


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast_label.modulate.a = 0.0
		elif _toast_timer < 1.0:
			_toast_label.modulate.a = _toast_timer


func _on_tick_finished(_tick: int) -> void:
	_update_info()
