## hud_root.gd -- Root HUD controller.
## Creates the entire HUD procedurally using Control nodes.
## Contains: resource bar, building palette, info panel, message log.
extends Control


var _orchestrator: GameOrchestrator = null

## References to HUD elements (created in _build_hud).
var _resource_labels: Dictionary = {}
var _info_label: RichTextLabel = null
var _message_label: Label = null
var _message_timer: float = 0.0
var _building_buttons: Array = []
var _pause_button: Button = null
var _level_label: Label = null


# ------------------------------------------------------------------
# Setup
# ------------------------------------------------------------------

func setup(orchestrator: GameOrchestrator) -> void:
	_orchestrator = orchestrator
	_build_hud()

	# Connect signals
	EventBus.tick_completed.connect(_on_tick)
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.message_posted.connect(_on_message)
	EventBus.city_level_changed.connect(_on_level_changed)
	EventBus.event_fired.connect(_on_event_fired)


# ------------------------------------------------------------------
# Build HUD programmatically
# ------------------------------------------------------------------

func _build_hud() -> void:
	# ---- Top bar: resources ----
	var top_bar := HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.set_anchors_preset(PRESET_TOP_WIDE)
	top_bar.size = Vector2(get_viewport_rect().size.x, 32)
	top_bar.add_theme_constant_override("separation", 12)
	add_child(top_bar)

	# Add resource labels for key resources
	var display_resources: Array = ["coins", "wood", "stone", "food", "energy", "water_res", "science", "fame"]
	for rid: String in display_resources:
		var lbl := Label.new()
		lbl.name = "Res_" + rid
		lbl.text = "%s: 0" % rid.substr(0, 4).to_upper()
		lbl.add_theme_font_size_override("font_size", 12)
		top_bar.add_child(lbl)
		_resource_labels[rid] = lbl

	# ---- Level & pause in top-right ----
	_level_label = Label.new()
	_level_label.name = "LevelLabel"
	_level_label.text = "Lv.1"
	_level_label.add_theme_font_size_override("font_size", 14)
	top_bar.add_child(_level_label)

	_pause_button = Button.new()
	_pause_button.name = "PauseBtn"
	_pause_button.text = "||"
	_pause_button.custom_minimum_size = Vector2(32, 28)
	_pause_button.pressed.connect(_on_pause_pressed)
	top_bar.add_child(_pause_button)

	# ---- Bottom bar: building palette ----
	var bottom_panel := PanelContainer.new()
	bottom_panel.name = "BottomPanel"
	bottom_panel.set_anchors_preset(PRESET_BOTTOM_WIDE)
	bottom_panel.position = Vector2(0, get_viewport_rect().size.y - 80)
	bottom_panel.size = Vector2(get_viewport_rect().size.x, 80)
	add_child(bottom_panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 72)
	bottom_panel.add_child(scroll)

	var palette := HBoxContainer.new()
	palette.name = "BuildingPalette"
	palette.add_theme_constant_override("separation", 4)
	scroll.add_child(palette)

	# Create a button for each building type
	var buildings: Dictionary = ContentDB.get_all_buildings() if ContentDB.has_method("get_all_buildings") else {}
	var categories: Array = ContentDB.get_categories() if ContentDB.has_method("get_categories") else []

	if buildings.is_empty():
		# Fallback: create buttons from known building types
		var known_types: Array = ["hut", "farm", "lumber", "quarry", "road", "workshop",
			"foundry", "market", "warehouse", "research", "library", "power",
			"water_tower", "park", "apartment", "monument", "trading_post", "bank"]
		for btype: String in known_types:
			_create_building_button(palette, btype, btype.capitalize())
	else:
		for btype: String in buildings:
			var bdef: Dictionary = buildings[btype]
			var label: String = bdef.get("label", btype.capitalize())
			_create_building_button(palette, btype, label)

	# ---- Right panel: building info ----
	var info_panel := PanelContainer.new()
	info_panel.name = "InfoPanel"
	info_panel.position = Vector2(get_viewport_rect().size.x - 240, 40)
	info_panel.size = Vector2(230, 300)
	info_panel.visible = false
	add_child(info_panel)

	_info_label = RichTextLabel.new()
	_info_label.bbcode_enabled = true
	_info_label.fit_content = true
	_info_label.custom_minimum_size = Vector2(220, 280)
	info_panel.add_child(_info_label)

	# ---- Message toast ----
	_message_label = Label.new()
	_message_label.name = "MessageToast"
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.set_anchors_preset(PRESET_CENTER_TOP)
	_message_label.position = Vector2(get_viewport_rect().size.x / 2 - 150, 40)
	_message_label.size = Vector2(300, 30)
	_message_label.add_theme_font_size_override("font_size", 14)
	_message_label.add_theme_color_override("font_color", Color.YELLOW)
	_message_label.visible = false
	add_child(_message_label)


func _create_building_button(parent: Node, type_id: String, label: String) -> void:
	var btn := Button.new()
	btn.name = "Btn_" + type_id
	btn.text = label.substr(0, 6)
	btn.custom_minimum_size = Vector2(56, 56)
	btn.tooltip_text = label
	btn.pressed.connect(func() -> void: _on_building_selected(type_id))
	parent.add_child(btn)
	_building_buttons.append(btn)


# ------------------------------------------------------------------
# Process -- update message toast timer
# ------------------------------------------------------------------

func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message_label.visible = false


# ------------------------------------------------------------------
# Update resource display
# ------------------------------------------------------------------

func _update_resources() -> void:
	for rid: String in _resource_labels:
		var lbl: Label = _resource_labels[rid]
		var val: float = GameStateStore.get_resource(rid)
		var cap: float = float(GameStateStore.get_economy().get("caps", {}).get(rid, 999))
		lbl.text = "%s: %d/%d" % [rid.substr(0, 4).to_upper(), int(val), int(cap)]

	# Update level
	if _level_label:
		var lvl: int = int(GameStateStore.get_progression().get("city_level", 1))
		var stars: int = int(GameStateStore.get_progression().get("prestige_stars", 0))
		_level_label.text = "Lv.%d" % lvl
		if stars > 0:
			_level_label.text += " *%d" % stars


# ------------------------------------------------------------------
# Signal handlers
# ------------------------------------------------------------------

func _on_tick(_tick_num: int) -> void:
	_update_resources()


func _on_resources_changed() -> void:
	_update_resources()


func _on_message(text: String, duration: float) -> void:
	_message_label.text = text
	_message_label.visible = true
	_message_timer = duration


func _on_level_changed(new_level: int) -> void:
	_on_message("City Level Up! Lv.%d" % new_level, 3.0)


func _on_event_fired(event_id: String) -> void:
	_on_message("Event: %s" % event_id, 4.0)


func _on_pause_pressed() -> void:
	if _orchestrator:
		var paused: bool = _orchestrator.toggle_pause()
		_pause_button.text = ">" if paused else "||"
		_on_message("Paused" if paused else "Playing", 1.5)


func _on_building_selected(type_id: String) -> void:
	# Find the Main node and call select_building
	var main_node := get_tree().current_scene
	if main_node and main_node.has_method("select_building"):
		main_node.select_building(type_id)
