extends Control
## Full-featured HUD: resource bar, categorized build menu, info panel, event popup, toast,
## terrain legend, game tips, and city level progress.

# --- References ---
var _resource_bar: PanelContainer
var _resource_label: Label
var _level_label: Label
var _pressure_label: Label

var _build_scroll: ScrollContainer
var _build_vbox: VBoxContainer
var _build_category_buttons: Dictionary = {}  # cat_name → Button
var _active_category: String = ""

var _info_panel: PanelContainer
var _info_label: Label

var _event_panel: PanelContainer
var _toast_label: Label
var _toast_timer: float = 0.0

var _help_panel: PanelContainer
var _help_visible: bool = false

var _selected_coord: Vector2i = Vector2i(-9999, -9999)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_resource_bar()
	_build_category_tabs()
	_build_building_list()
	_build_info_panel()
	_build_event_panel()
	_build_toast()
	_build_help_panel()
	_connect_signals()
	# Start with first category open
	_set_active_category("Production")


func _connect_signals() -> void:
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.toast_requested.connect(_on_toast)
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.game_event_spawned.connect(_on_event_spawned)
	EventBus.tick_finished.connect(_on_tick_finished)
	EventBus.city_level_changed.connect(func(_lv: int) -> void: _rebuild_building_list())


# ===========================================================
# RESOURCE BAR (top)
# ===========================================================

func _build_resource_bar() -> void:
	_resource_bar = PanelContainer.new()
	_resource_bar.set_anchors_preset(PRESET_TOP_WIDE)
	_resource_bar.custom_minimum_size.y = 72
	_resource_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_resource_bar)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resource_bar.add_child(vbox)

	_resource_label = Label.new()
	_resource_label.text = "Loading..."
	_resource_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_resource_label.add_theme_font_size_override("font_size", 13)
	_resource_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_resource_label)

	_level_label = Label.new()
	_level_label.text = ""
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override("font_size", 11)
	_level_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_level_label)

	_pressure_label = Label.new()
	_pressure_label.text = ""
	_pressure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pressure_label.add_theme_font_size_override("font_size", 10)
	_pressure_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	_pressure_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_pressure_label)


func _on_resources_changed(_resources: Dictionary) -> void:
	_update_resource_bar()


func _update_resource_bar() -> void:
	var parts: Array[String] = []
	# Core resources with production rate
	var show_res: Array[String] = ["coins", "food", "wood", "stone", "planks", "bricks", "tools",
		"metal", "energy", "science", "culture", "fame"]
	for res_id: String in show_res:
		var val: float = GameStateStore.get_resource(res_id)
		if val < 0.5 and res_id not in ["coins", "food", "wood", "stone"]:
			continue  # Only show non-zero advanced resources
		var prod: float = GameStateStore.economy().production.get(res_id, 0.0) as float
		var def: Dictionary = ContentDB.get_resource_def(res_id)
		var lbl: String = def.get("label", res_id) as String
		if absf(prod) > 0.01:
			var sign_str: String = "+" if prod > 0 else ""
			parts.append("%s:%d(%s%.1f)" % [lbl, int(val), sign_str, prod])
		else:
			parts.append("%s:%d" % [lbl, int(val)])

	var pop: int = GameStateStore.population().total as int
	var happiness: float = GameStateStore.population().happiness as float
	parts.append("Pop:%d" % pop)
	parts.append("Happy:%d%%" % int(happiness))

	var city_lv: int = GameStateStore.progression().city_level as int
	var lv_def: Dictionary = ContentDB.get_level_def(city_lv)
	var lv_name: String = lv_def.get("name", "?") as String
	parts.append("Lv%d %s" % [city_lv, lv_name])
	_resource_label.text = " | ".join(parts)

	# Next level requirements
	_update_level_requirements(city_lv)

	# Pressure phase
	var phase: String = GameStateStore.pressure().phase as String
	var p_idx: float = GameStateStore.pressure().index as float
	var phase_color: Color
	match phase:
		"calm": phase_color = Color(0.5, 0.8, 0.5)
		"tension": phase_color = Color(0.9, 0.8, 0.3)
		"crisis": phase_color = Color(0.9, 0.5, 0.2)
		"emergency": phase_color = Color(0.9, 0.2, 0.2)
		_: phase_color = Color.WHITE
	_pressure_label.add_theme_color_override("font_color", phase_color)
	_pressure_label.text = "Pressure: %s (%.0f) | [H] Help | [Space] Pause | [1-3] Speed" % [phase.capitalize(), p_idx]

	# Update build list availability coloring
	_update_build_list_affordability()


func _update_level_requirements(city_lv: int) -> void:
	var next_def: Dictionary = ContentDB.get_level_def(city_lv + 1)
	if next_def.is_empty():
		_level_label.text = "Max city level!"
		return
	var next_name: String = next_def.get("name", "?") as String
	var reqs_raw: Variant = next_def.get("requirements", null)
	if reqs_raw == null or not (reqs_raw is Dictionary):
		_level_label.text = "Next: %s" % next_name
		return
	var reqs: Dictionary = reqs_raw as Dictionary
	var req_parts: Array[String] = []
	var met_count: int = 0
	for res_id: String in reqs:
		var needed: float = reqs[res_id] as float
		var have: float = GameStateStore.get_resource(res_id)
		var def: Dictionary = ContentDB.get_resource_def(res_id)
		var lbl: String = def.get("label", res_id) as String
		if have >= needed:
			req_parts.append("%s OK" % lbl)
			met_count += 1
		else:
			req_parts.append("%s %d/%d" % [lbl, int(have), int(needed)])
	_level_label.text = "Next: %s (%d/%d) [%s]" % [next_name, met_count, reqs.size(), ", ".join(req_parts)]


# ===========================================================
# CATEGORY TABS (left sidebar top)
# ===========================================================

const CATEGORY_ORDER: Array[String] = ["Production", "Residential", "Commercial", "Culture", "Infrastructure", "Advanced"]

func _build_category_tabs() -> void:
	var tab_panel := PanelContainer.new()
	tab_panel.position = Vector2(0, 75)
	tab_panel.size = Vector2(240, 32)
	tab_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(tab_panel)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	tab_panel.add_child(hbox)

	for cat: String in CATEGORY_ORDER:
		var btn := Button.new()
		btn.text = cat.left(4)  # Short: Prod, Resi, Comm, Cult, Infr, Adva
		btn.custom_minimum_size.x = 38
		btn.add_theme_font_size_override("font_size", 10)
		btn.tooltip_text = cat
		btn.pressed.connect(_on_category_pressed.bind(cat))
		hbox.add_child(btn)
		_build_category_buttons[cat] = btn


func _on_category_pressed(cat: String) -> void:
	_set_active_category(cat)


func _set_active_category(cat: String) -> void:
	_active_category = cat
	for c: String in _build_category_buttons:
		var btn: Button = _build_category_buttons[c]
		if c == cat:
			btn.modulate = Color(1.2, 1.2, 0.8)
		else:
			btn.modulate = Color.WHITE
	_rebuild_building_list()


# ===========================================================
# BUILDING LIST (left sidebar)
# ===========================================================

var _build_entries: Array[Dictionary] = []  # {container, type_id, btn, cost_label}

func _build_building_list() -> void:
	_build_scroll = ScrollContainer.new()
	_build_scroll.position = Vector2(0, 110)
	_build_scroll.size = Vector2(240, 500)
	_build_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_build_scroll)

	_build_vbox = VBoxContainer.new()
	_build_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_build_scroll.add_child(_build_vbox)


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

		var entry := VBoxContainer.new()
		_build_vbox.add_child(entry)

		# Button
		var btn := Button.new()
		if is_locked:
			btn.text = "%s [Locked Lv%d]" % [label_name, unlock_lv]
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5)
		else:
			btn.text = label_name
		btn.tooltip_text = def.get("description", "") as String
		btn.pressed.connect(_on_build_button.bind(type_id))
		entry.add_child(btn)

		# Production/Consumption summary
		var produces: Dictionary = ldata.get("produces", {})
		var consumes: Dictionary = ldata.get("consumes", {})
		var bld_pop: int = ldata.get("population", 0) as int
		var happy: float = ldata.get("happiness", 0.0) as float

		var info_parts: Array[String] = []
		if not produces.is_empty():
			var pp: Array[String] = []
			for r: String in produces:
				var rdef: Dictionary = ContentDB.get_resource_def(r)
				pp.append("+%.1f %s" % [produces[r] as float, rdef.get("label", r)])
			info_parts.append(", ".join(pp))
		if not consumes.is_empty():
			var cc: Array[String] = []
			for r: String in consumes:
				var rdef: Dictionary = ContentDB.get_resource_def(r)
				cc.append("-%.1f %s" % [consumes[r] as float, rdef.get("label", r)])
			info_parts.append(", ".join(cc))
		if bld_pop > 0:
			info_parts.append("+%d pop" % bld_pop)
		if happy > 0:
			info_parts.append("+%.0f happy" % happy)

		if not info_parts.is_empty():
			var info_lbl := Label.new()
			info_lbl.text = "  " + " | ".join(info_parts)
			info_lbl.add_theme_font_size_override("font_size", 10)
			info_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
			info_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			entry.add_child(info_lbl)

		# Cost
		var build_cost: Dictionary = def.get("build_cost", {})
		var cost_lbl: Label = null
		if not build_cost.is_empty():
			var cost_parts: Array[String] = []
			for res_id: String in build_cost:
				var rdef: Dictionary = ContentDB.get_resource_def(res_id)
				cost_parts.append("%s:%d" % [rdef.get("label", res_id), int(build_cost[res_id] as float)])
			cost_lbl = Label.new()
			cost_lbl.text = "  Cost: " + ", ".join(cost_parts)
			cost_lbl.add_theme_font_size_override("font_size", 10)
			cost_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
			cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			entry.add_child(cost_lbl)

		if cost_lbl != null:
			_build_entries.append({"container": entry, "type_id": type_id, "btn": btn, "cost_label": cost_lbl})

		# Terrain bonus hint
		var terrain_bonus: Dictionary = def.get("terrain_bonus", {})
		if not terrain_bonus.is_empty():
			var tb_parts: Array[String] = []
			for tid: String in terrain_bonus:
				var tdef: Dictionary = ContentDB.get_terrain_def(int(tid))
				var bonus: float = terrain_bonus[tid] as float
				var sign_str: String = "+" if bonus > 0 else ""
				tb_parts.append("%s%d%% on %s" % [sign_str, int(bonus * 100), tdef.get("label", tid)])
			var tb_lbl := Label.new()
			tb_lbl.text = "  " + ", ".join(tb_parts)
			tb_lbl.add_theme_font_size_override("font_size", 9)
			tb_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
			tb_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			entry.add_child(tb_lbl)

		# Requires road hint
		if def.get("requires_road", false) as bool:
			var road_lbl := Label.new()
			road_lbl.text = "  Requires road (-70% without)"
			road_lbl.add_theme_font_size_override("font_size", 9)
			road_lbl.add_theme_color_override("font_color", Color(0.8, 0.6, 0.5))
			road_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			entry.add_child(road_lbl)

		var sep := HSeparator.new()
		sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(sep)


func _update_build_list_affordability() -> void:
	for entry: Dictionary in _build_entries:
		var etype_id: String = entry.type_id
		var edef: Dictionary = ContentDB.get_building_def(etype_id)
		var cost: Dictionary = edef.get("build_cost", {})
		var ecost_lbl: Label = entry.cost_label
		var affordable: bool = GameStateStore.can_afford(cost)
		if affordable:
			ecost_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		else:
			ecost_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))


func _on_build_button(type_id: String) -> void:
	EventBus.build_mode_changed.emit(type_id)


# ===========================================================
# INFO PANEL (bottom-right)
# ===========================================================

func _build_info_panel() -> void:
	_info_panel = PanelContainer.new()
	_info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_info_panel.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT)
	_info_panel.offset_left = -320
	_info_panel.offset_top = -260
	add_child(_info_panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	_info_panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.custom_minimum_size = Vector2(300, 240)
	margin.add_child(scroll)

	_info_label = Label.new()
	_info_label.text = _get_welcome_text()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override("font_size", 12)
	_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_info_label)


func _get_welcome_text() -> String:
	return """Click a tile for info

Controls:
  WASD - Move camera
  Scroll - Zoom
  Middle-click - Pan
  LMB - Select/Build
  RMB/Esc - Cancel build
  U-Upgrade R-Repair B-Bulldoze
  V-Toggle range H-Help
  Space-Pause 1/2/3-Speed"""


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
		var t_label: String = tdef.get("label", "Unknown") as String
		var buildable: bool = tdef.get("buildable", true) as bool
		var text: String = "Terrain: %s (%d,%d)\n" % [t_label, _selected_coord.x, _selected_coord.y]
		if not buildable:
			text += "Cannot build here\n"
		else:
			text += "Can build here\n"
		text += "\nTerrain bonuses:\n"
		var found_bonus: bool = false
		for btype_id: String in ContentDB.get_building_ids():
			var bdef: Dictionary = ContentDB.get_building_def(btype_id)
			var tb: Dictionary = bdef.get("terrain_bonus", {})
			if tb.has(str(terrain_id)):
				var bonus: float = tb[str(terrain_id)] as float
				var sign_str: String = "+" if bonus > 0 else ""
				text += "  %s: %s%d%%\n" % [bdef.get("label", btype_id), sign_str, int(bonus * 100)]
				found_bonus = true
		if not found_bonus:
			text += "  None\n"
		_info_label.text = text
		return

	var type_id: String = bld.get("type", "") as String
	var level: int = bld.get("level", 0) as int
	var def: Dictionary = ContentDB.get_building_def(type_id)
	var ldata: Dictionary = ContentDB.building_level_data(type_id, level)
	var stage: String = ldata.get("stage", "?") as String
	var cat: String = def.get("category", "") as String

	var text: String = "%s (%s) [%s]\nLevel %d/%d\n" % [
		def.get("label", type_id), stage, cat, level, ContentDB.max_building_level(type_id) - 1]

	# Production
	var produces: Dictionary = ldata.get("produces", {})
	if not produces.is_empty():
		text += "Produces: "
		var pp: Array = []
		for r: String in produces:
			var rdef: Dictionary = ContentDB.get_resource_def(r)
			pp.append("%.1f %s" % [produces[r] as float, rdef.get("label", r)])
		text += ", ".join(pp) + "\n"

	var consumes: Dictionary = ldata.get("consumes", {})
	if not consumes.is_empty():
		text += "Consumes: "
		var cc: Array = []
		for r: String in consumes:
			var rdef: Dictionary = ContentDB.get_resource_def(r)
			cc.append("%.1f %s" % [consumes[r] as float, rdef.get("label", r)])
		text += ", ".join(cc) + "\n"

	var bld_pop: int = ldata.get("population", 0) as int
	var happy: float = ldata.get("happiness", 0.0) as float
	if bld_pop > 0:
		text += "Population: +%d\n" % bld_pop
	if happy > 0:
		text += "Happiness: +%.0f\n" % happy

	if bld.get("damaged", false) as bool:
		text += "\n[DAMAGED] Press R to repair\n"
	if bld.get("has_issue", false) as bool:
		text += "[ISSUE] Press R to fix\n"

	# Upgrade
	var max_level: int = ContentDB.max_building_level(type_id)
	if level + 1 < max_level:
		var next_ldata: Dictionary = ContentDB.building_level_data(type_id, level + 1)
		var next_stage: String = next_ldata.get("stage", "?") as String
		var cost_raw: Variant = next_ldata.get("cost", null)
		var cost: Dictionary = cost_raw as Dictionary if cost_raw is Dictionary else {}
		if not cost.is_empty():
			text += "\nUpgrade to %s [U]:\n" % next_stage
			for res_id: String in cost:
				var needed: float = cost[res_id] as float
				var have: float = GameStateStore.get_resource(res_id)
				var rdef: Dictionary = ContentDB.get_resource_def(res_id)
				var ok: String = "OK" if have >= needed else "NEED"
				text += "  %s: %d/%d %s\n" % [rdef.get("label", res_id), int(have), int(needed), ok]
	else:
		text += "\n[MAX LEVEL]\n"

	text += "\n[U]Upgrade [R]Repair [B]Bulldoze [V]Range"
	_info_label.text = text


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

TERRAIN COLORS:
  Green = Grass (+20% farms)
  Blue = Water (cannot build)
  Yellow = Sand (no bonuses)
  Brown = Hills (+20% quarries)
  Dark green = Forest (+50% lumber)
  Gray = Rock (+40% quarries)

WATER & POWER:
  Water Tower provides water in radius (4-14 hexes).
  Residential without water = 60% efficiency.
  Power Plant provides powered boost in radius.
  Powered buildings get 10-20% production bonus.

SYNERGIES:
  Farm + Lumber adjacent: +15% food, +10% wood
  Market + Residential: +15% coins
  Park: happiness aura to nearby buildings
  Workshop: upgrade discount aura
  Research + Library: +20%/+15% science
  Foundry + Quarry: +10% metal, +10% glass

ROADS:
  Buildings without roads = 30% production!
  Connect to roads for full efficiency.
  Higher road levels = bigger bonuses (5-25%).

CITY LEVELS:
  Collect required resources to level up.
  Higher levels unlock new buildings.

PRESSURE SYSTEM:
  Rises with city size and problems.
  Phases: Calm > Tension > Crisis > Emergency
  Higher pressure = more frequent events.
  Keep buildings repaired and happy!"""


func toggle_help() -> void:
	_help_visible = not _help_visible
	_help_panel.visible = _help_visible


# ===========================================================
# EVENT POPUP (center)
# ===========================================================

func _build_event_panel() -> void:
	_event_panel = PanelContainer.new()
	_event_panel.set_anchors_preset(PRESET_CENTER)
	_event_panel.size = Vector2(420, 280)
	_event_panel.position = Vector2(-210, -140)
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
	title.add_theme_font_size_override("font_size", 18)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	var body := Label.new()
	body.text = event_data.get("body", "") as String
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
