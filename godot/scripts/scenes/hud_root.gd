extends Control
## HUD: compact resource bar (3 blocks), right-anchored build menu with category tabs,
## actionable info panel, event popup, toast, and help.

# --- References ---
var _core_label: Label
var _city_label: Label
var _risk_label: Label

var _build_panel: PanelContainer
var _build_scroll: ScrollContainer
var _build_vbox: VBoxContainer
var _category_select: OptionButton
var _active_category: String = ""
var _active_build_type: String = ""

var _info_panel: PanelContainer
var _info_label: Label

var _event_panel: PanelContainer
var _toast_label: Label
var _toast_timer: float = 0.0

var _help_panel: PanelContainer
var _help_visible: bool = false

var _selected_coord: Vector2i = Vector2i(-9999, -9999)

var _build_entries: Array[Dictionary] = []  # {type_id, btn, cost_label}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_resource_bar()
	_build_build_panel()
	_build_info_panel()
	_build_event_panel()
	_build_toast()
	_build_help_panel()
	_connect_signals()
	_set_active_category("Infrastructure")


func _connect_signals() -> void:
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.toast_requested.connect(_on_toast)
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.game_event_spawned.connect(_on_event_spawned)
	EventBus.tick_finished.connect(_on_tick_finished)
	EventBus.city_level_changed.connect(func(_lv: int) -> void: _rebuild_building_list())
	EventBus.build_mode_changed.connect(_on_build_mode_changed)


# ===========================================================
# RESOURCE BAR (top) — 3 compact blocks: Core | City | Risk
# ===========================================================

func _build_resource_bar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(PRESET_TOP_WIDE)
	bar.custom_minimum_size.y = 48
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bar)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(hbox)

	# Core block
	_core_label = Label.new()
	_core_label.add_theme_font_size_override("font_size", 12)
	_core_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_core_label)

	var sep1 := VSeparator.new()
	sep1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(sep1)

	# City block
	_city_label = Label.new()
	_city_label.add_theme_font_size_override("font_size", 12)
	_city_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	_city_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_city_label)

	var sep2 := VSeparator.new()
	sep2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(sep2)

	# Risk block
	_risk_label = Label.new()
	_risk_label.add_theme_font_size_override("font_size", 12)
	_risk_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_risk_label)


func _on_resources_changed(_resources: Dictionary) -> void:
	_update_resource_bar()


func _update_resource_bar() -> void:
	# --- Core ---
	var core_parts: Array[String] = []
	for res_id: String in ["coins", "food", "wood", "stone"]:
		var val: float = GameStateStore.get_resource(res_id)
		var def: Dictionary = ContentDB.get_resource_def(res_id)
		var lbl: String = def.get("label", res_id) as String
		core_parts.append("%s:%d" % [lbl, int(val)])
	_core_label.text = " ".join(core_parts)

	# --- City ---
	var pop: int = GameStateStore.population().total as int
	var happiness: float = GameStateStore.population().happiness as float
	var city_lv: int = GameStateStore.progression().city_level as int
	var lv_def: Dictionary = ContentDB.get_level_def(city_lv)
	var lv_name: String = lv_def.get("name", "?") as String

	var energy: float = GameStateStore.get_resource("energy")
	var city_text: String = "Pop:%d  Happy:%d%%  Energy:%d  Lv%d %s" % [pop, int(happiness), int(energy), city_lv, lv_name]
	# Next level hint
	var next_def: Dictionary = ContentDB.get_level_def(city_lv + 1)
	if not next_def.is_empty():
		var reqs_raw: Variant = next_def.get("requirements", null)
		if reqs_raw is Dictionary:
			var reqs: Dictionary = reqs_raw as Dictionary
			var met: int = 0
			for res_id: String in reqs:
				if GameStateStore.get_resource(res_id) >= (reqs[res_id] as float):
					met += 1
			city_text += "  Next:%d/%d" % [met, reqs.size()]
	_city_label.text = city_text

	# --- Risk ---
	var phase: String = GameStateStore.pressure().phase as String
	var p_idx: float = GameStateStore.pressure().index as float
	var phase_color: Color
	match phase:
		"calm": phase_color = Color(0.5, 0.8, 0.5)
		"tension": phase_color = Color(0.9, 0.8, 0.3)
		"crisis": phase_color = Color(0.9, 0.5, 0.2)
		"emergency": phase_color = Color(0.9, 0.2, 0.2)
		_: phase_color = Color.WHITE
	_risk_label.add_theme_color_override("font_color", phase_color)
	_risk_label.text = "Pressure: %s %.0f" % [phase.capitalize(), p_idx]

	_update_build_list_affordability()


# ===========================================================
# BUILD PANEL (right side, expands left)
# ===========================================================

const CATEGORY_ORDER: Array[String] = ["Infrastructure", "Residential", "Production", "Commercial", "Culture", "Advanced"]
const BUILD_PANEL_W := 220.0

func _build_build_panel() -> void:
	_build_panel = PanelContainer.new()
	_build_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# Anchor to top-right, expand downward
	_build_panel.anchor_left = 1.0
	_build_panel.anchor_right = 1.0
	_build_panel.anchor_top = 0.0
	_build_panel.anchor_bottom = 1.0
	_build_panel.offset_left = -BUILD_PANEL_W
	_build_panel.offset_top = 52
	_build_panel.offset_bottom = 0
	add_child(_build_panel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_build_panel.add_child(vbox)

	# Header row
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(header)

	var title := Label.new()
	title.text = "Build"
	title.add_theme_font_size_override("font_size", 12)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title)

	_category_select = OptionButton.new()
	_category_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_category_select.add_theme_font_size_override("font_size", 10)
	for cat: String in CATEGORY_ORDER:
		_category_select.add_item(cat)
	_category_select.item_selected.connect(_on_category_selected)
	header.add_child(_category_select)

	# Scrollable building list
	_build_scroll = ScrollContainer.new()
	_build_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_build_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_build_scroll)

	_build_vbox = VBoxContainer.new()
	_build_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_build_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_scroll.add_child(_build_vbox)


func _on_category_selected(index: int) -> void:
	if index < 0 or index >= CATEGORY_ORDER.size():
		return
	_set_active_category(CATEGORY_ORDER[index] as String)


func _set_active_category(cat: String) -> void:
	_active_category = cat
	if _category_select:
		var idx: int = CATEGORY_ORDER.find(cat)
		if idx >= 0 and _category_select.selected != idx:
			_category_select.select(idx)
	_rebuild_building_list()


func _rebuild_building_list() -> void:
	for c: Node in _build_vbox.get_children():
		c.queue_free()
	_build_entries.clear()

	var city_lv: int = GameStateStore.progression().city_level as int

	for type_id: String in ContentDB.get_building_ids():
		var def: Dictionary = ContentDB.get_building_def(type_id)
		var cat: String = def.get("category", "") as String
		if cat != _active_category:
			continue

		var unlock_lv: int = def.get("unlock_level", 1) as int
		var is_locked: bool = city_lv < unlock_lv
		var label_name: String = def.get("label", type_id) as String
		var ldata: Dictionary = ContentDB.building_level_data(type_id, 0)

		# Button — compact: name only (tooltip has description)
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if is_locked:
			btn.text = "%s [Lv%d]" % [label_name, unlock_lv]
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5)
		else:
			btn.text = label_name
			# Active build highlight
			if type_id == _active_build_type:
				btn.modulate = Color(0.8, 1.0, 0.5)
		btn.add_theme_font_size_override("font_size", 12)
		btn.tooltip_text = def.get("description", "") as String
		btn.pressed.connect(_on_build_button.bind(type_id))
		_build_vbox.add_child(btn)

		# 1-line key effect
		var effect_text: String = _format_key_effect(ldata)
		if effect_text != "":
			var eff_lbl := Label.new()
			eff_lbl.text = "  " + effect_text
			eff_lbl.add_theme_font_size_override("font_size", 10)
			eff_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
			eff_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_build_vbox.add_child(eff_lbl)

		# Cost line
		var build_cost: Dictionary = def.get("build_cost", {})
		var cost_lbl: Label = null
		if not build_cost.is_empty():
			var cost_parts: Array[String] = []
			for res_id: String in build_cost:
				var rdef: Dictionary = ContentDB.get_resource_def(res_id)
				cost_parts.append("%s:%d" % [rdef.get("label", res_id), int(build_cost[res_id] as float)])
			cost_lbl = Label.new()
			cost_lbl.text = "  " + ", ".join(cost_parts)
			cost_lbl.add_theme_font_size_override("font_size", 10)
			cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_build_vbox.add_child(cost_lbl)

		_build_entries.append({"type_id": type_id, "btn": btn, "cost_label": cost_lbl})


func _format_key_effect(ldata: Dictionary) -> String:
	## Single-line summary of what the building does.
	var parts: Array[String] = []
	var produces: Dictionary = ldata.get("produces", {})
	for r: String in produces:
		var rdef: Dictionary = ContentDB.get_resource_def(r)
		parts.append("+%.0f %s" % [produces[r] as float, rdef.get("label", r)])
	var consumes: Dictionary = ldata.get("consumes", {})
	for r: String in consumes:
		var rdef: Dictionary = ContentDB.get_resource_def(r)
		parts.append("-%.0f %s" % [consumes[r] as float, rdef.get("label", r)])
	var bld_pop: int = ldata.get("population", 0) as int
	if bld_pop > 0:
		parts.append("+%d pop" % bld_pop)
	var storage: int = ldata.get("storage", 0) as int
	if storage > 0:
		parts.append("+%d storage" % storage)
	if parts.is_empty():
		return ""
	return ", ".join(parts)


func _update_build_list_affordability() -> void:
	for entry: Dictionary in _build_entries:
		var cost_lbl: Variant = entry.get("cost_label", null)
		if cost_lbl == null or not (cost_lbl is Label):
			continue
		var etype_id: String = entry.type_id
		var edef: Dictionary = ContentDB.get_building_def(etype_id)
		var cost: Dictionary = edef.get("build_cost", {})
		var affordable: bool = GameStateStore.can_afford(cost)
		if affordable:
			(cost_lbl as Label).add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		else:
			(cost_lbl as Label).add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))


func _on_build_button(type_id: String) -> void:
	_active_build_type = type_id
	EventBus.build_mode_changed.emit(type_id)
	# Refresh button highlights
	for entry: Dictionary in _build_entries:
		var btn: Button = entry.btn
		if not btn.disabled:
			if (entry.type_id as String) == type_id:
				btn.modulate = Color(0.8, 1.0, 0.5)
			else:
				btn.modulate = Color.WHITE


func _on_build_mode_changed(type_id: String) -> void:
	_active_build_type = type_id
	# Update button highlights when build mode changes externally (e.g. RMB cancel)
	for entry: Dictionary in _build_entries:
		var btn: Button = entry.btn
		if not btn.disabled:
			if (entry.type_id as String) == type_id:
				btn.modulate = Color(0.8, 1.0, 0.5)
			else:
				btn.modulate = Color.WHITE


# ===========================================================
# INFO PANEL (bottom-left) — Status / Problem / Next Action
# ===========================================================

func _build_info_panel() -> void:
	_info_panel = PanelContainer.new()
	_info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_info_panel.anchor_left = 0.0
	_info_panel.anchor_right = 0.0
	_info_panel.anchor_top = 1.0
	_info_panel.anchor_bottom = 1.0
	_info_panel.offset_left = 0
	_info_panel.offset_right = 280
	_info_panel.offset_top = -200
	_info_panel.offset_bottom = 0
	add_child(_info_panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 4)
	_info_panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	_info_label = Label.new()
	_info_label.text = _get_welcome_text()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override("font_size", 11)
	_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_info_label)


func _get_welcome_text() -> String:
	return """Click tile for info
WASD-Move Scroll-Zoom LMB-Select
RMB/Esc-Cancel U-Upgrade R-Repair
B-Bulldoze V-Range H-Help"""


func _on_selection_changed(coord: Vector2i) -> void:
	_selected_coord = coord
	_update_info()


func _update_info() -> void:
	if _selected_coord == Vector2i(-9999, -9999):
		return

	var bld: Dictionary = GameStateStore.get_building(_selected_coord)
	if bld.is_empty():
		_info_label.text = _build_tile_info_text(_selected_coord)
		return

	_info_label.text = _build_building_info_text(_selected_coord, bld)


func _build_tile_info_text(coord: Vector2i) -> String:
	var terrain_id: int = GameStateStore.get_terrain(coord)
	var tdef: Dictionary = ContentDB.get_terrain_def(terrain_id)
	var t_label: String = tdef.get("label", "Unknown") as String
	var buildable: bool = tdef.get("buildable", true) as bool

	var text: String = "%s (%d,%d)" % [t_label, coord.x, coord.y]
	if not buildable:
		text += "\nCannot build here"
	else:
		# Show terrain bonuses compactly
		var bonuses: Array[String] = []
		for btype_id: String in ContentDB.get_building_ids():
			var bdef: Dictionary = ContentDB.get_building_def(btype_id)
			var tb: Dictionary = bdef.get("terrain_bonus", {})
			if tb.has(str(terrain_id)):
				var bonus: float = tb[str(terrain_id)] as float
				if bonus > 0:
					bonuses.append("+%d%% %s" % [int(bonus * 100), bdef.get("label", btype_id)])
		if not bonuses.is_empty():
			text += "\nBonus: " + ", ".join(bonuses)
	return text


func _build_building_info_text(coord: Vector2i, bld: Dictionary) -> String:
	var type_id: String = bld.get("type", "") as String
	var level: int = bld.get("level", 0) as int
	var def: Dictionary = ContentDB.get_building_def(type_id)
	var ldata: Dictionary = ContentDB.building_level_data(type_id, level)
	var stage: String = ldata.get("stage", "?") as String

	# --- Status ---
	var text: String = "%s (%s) Lv%d\n" % [def.get("label", type_id), stage, level]

	var effect: String = _format_key_effect(ldata)
	if effect != "":
		text += effect + "\n"

	# --- Problem ---
	if bld.get("damaged", false) as bool:
		text += "\nDAMAGED - press R to repair"
	elif bld.get("has_issue", false) as bool:
		text += "\nISSUE - press R to fix"

	# --- Next Action ---
	var max_level: int = ContentDB.max_building_level(type_id)
	if level + 1 < max_level:
		var next_ldata: Dictionary = ContentDB.building_level_data(type_id, level + 1)
		var next_stage: String = next_ldata.get("stage", "?") as String
		var cost_raw: Variant = next_ldata.get("cost", null)
		var cost: Dictionary = cost_raw as Dictionary if cost_raw is Dictionary else {}
		if not cost.is_empty():
			var affordable: bool = GameStateStore.can_afford(cost)
			if affordable:
				text += "\n[U] Upgrade to %s" % next_stage
			else:
				# Show what's missing
				var missing: Array[String] = []
				for res_id: String in cost:
					var needed: float = cost[res_id] as float
					var have: float = GameStateStore.get_resource(res_id)
					if have < needed:
						var rdef: Dictionary = ContentDB.get_resource_def(res_id)
						missing.append("%s %d/%d" % [rdef.get("label", res_id), int(have), int(needed)])
				text += "\nUpgrade: need " + ", ".join(missing)
	else:
		text += "\nMAX LEVEL"

	text += "\n[U]Up [R]Fix [B]Del [V]Range"
	return text


# ===========================================================
# HELP PANEL (center, toggled with H)
# ===========================================================

func _build_help_panel() -> void:
	_help_panel = PanelContainer.new()
	_help_panel.set_anchors_preset(PRESET_CENTER)
	_help_panel.size = Vector2(500, 400)
	_help_panel.position = Vector2(-250, -200)
	_help_panel.visible = false
	_help_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_help_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_help_panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(470, 370)
	margin.add_child(scroll)

	var lbl := Label.new()
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.text = _get_help_text()
	scroll.add_child(lbl)


func _get_help_text() -> String:
	return """=== PIXEL CITY BUILDER ===

QUICK START:
  1. Build Roads (Infrastructure tab)
  2. Build Huts near roads
  3. Build Farms for food
  4. Build Lumber Mills in forests

TERRAIN:
  Green=Grass(+20% farm) Blue=Water
  Yellow=Sand Brown=Hill(+20% quarry)
  DkGreen=Forest(+50% lumber) Gray=Rock(+40% quarry)

WATER & POWER:
  Water Tower: residential need water (60% without)
  Power Plant: production boost in radius

SYNERGIES:
  Farm+Lumber: +15% food, +10% wood
  Market+Residential: +15% coins
  Park: happiness aura | Workshop: upgrade discount
  Research+Library: +20%/+15% science

ROADS:
  No road = 30% production! Higher roads = bigger bonus.

PRESSURE: Calm > Tension > Crisis > Emergency
  More buildings + problems = higher pressure = more events."""


func toggle_help() -> void:
	_help_visible = not _help_visible
	_help_panel.visible = _help_visible


# ===========================================================
# EVENT POPUP (center)
# ===========================================================

func _build_event_panel() -> void:
	_event_panel = PanelContainer.new()
	_event_panel.set_anchors_preset(PRESET_CENTER)
	_event_panel.size = Vector2(400, 260)
	_event_panel.position = Vector2(-200, -130)
	_event_panel.visible = false
	_event_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_event_panel)


func _on_event_spawned(event_data: Dictionary) -> void:
	_event_panel.visible = true
	for c: Node in _event_panel.get_children():
		c.queue_free()

	var vbox := VBoxContainer.new()
	_event_panel.add_child(vbox)

	var title := Label.new()
	title.text = event_data.get("title", "Event") as String
	title.add_theme_font_size_override("font_size", 16)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	var body := Label.new()
	body.text = event_data.get("body", "") as String
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 12)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(body)

	# Show accept cost
	var cost_raw: Variant = event_data.get("accept_cost", null)
	if cost_raw is Dictionary and not (cost_raw as Dictionary).is_empty():
		var cost_label := Label.new()
		var cp: Array[String] = []
		for res_id: String in (cost_raw as Dictionary):
			var rdef: Dictionary = ContentDB.get_resource_def(res_id)
			cp.append("%s: %d" % [rdef.get("label", res_id), int((cost_raw as Dictionary)[res_id] as float)])
		cost_label.text = "Cost: " + ", ".join(cp)
		cost_label.add_theme_font_size_override("font_size", 11)
		cost_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
		cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(cost_label)

	var btn_row := HBoxContainer.new()
	vbox.add_child(btn_row)

	var ev_id: String = event_data.get("id", "") as String

	var accept_btn := Button.new()
	accept_btn.text = event_data.get("accept_label", "Accept") as String
	var accept_cost_raw: Variant = event_data.get("accept_cost", null)
	if accept_cost_raw is Dictionary and not (accept_cost_raw as Dictionary).is_empty():
		if not GameStateStore.can_afford(accept_cost_raw as Dictionary):
			accept_btn.disabled = true
			accept_btn.tooltip_text = "Not enough resources"
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
		if not cmd.success:
			return
	_event_panel.visible = false


# ===========================================================
# TOAST (bottom center)
# ===========================================================

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
	_update_resource_bar()
	_update_info()
