extends Control
## HUD: compact resource bar (3 blocks), right-anchored build menu with category tabs,
## actionable info panel, event popup, toast, and help.

const PlacementRulesRef := preload("res://scripts/core/buildings/placement_rules.gd")

# --- References ---
var _core_label: Label
var _city_label: Label
var _risk_label: Label

var _build_panel: PanelContainer
var _build_title_label: Label
var _build_city_button: Button
var _build_gov_button: Button
var _build_settings_button: Button
var _build_scroll: ScrollContainer
var _build_vbox: VBoxContainer
var _category_select: OptionButton
var _category_buttons: Dictionary = {}
var _active_category: String = ""
var _active_build_type: String = ""

var _info_panel: PanelContainer
var _info_label: Label

var _event_panel: PanelContainer
var _toast_label: Label
var _toast_timer: float = 0.0

var _start_panel: PanelContainer
var _start_visible: bool = true
var _help_panel: PanelContainer
var _help_label: Label
var _help_visible: bool = false
var _governance_panel: PanelContainer
var _governance_visible: bool = false
var _governance_tabs: TabContainer
var _city_panel: PanelContainer
var _city_visible: bool = false
var _settings_panel: PanelContainer
var _settings_visible: bool = false
var _settings_language_select: OptionButton

var _selected_coord: Vector2i = Vector2i(-9999, -9999)

var _build_entries: Array[Dictionary] = []  # {type_id, btn, cost_label}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_resource_bar()
	_build_build_panel()
	_build_info_panel()
	_build_event_panel()
	_build_toast()
	_build_start_panel()
	_build_help_panel()
	_build_city_panel()
	_build_governance_panel()
	_build_settings_panel()
	_connect_signals()
	_set_active_category("Infrastructure")


func _connect_signals() -> void:
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.toast_requested.connect(_on_toast)
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.game_event_spawned.connect(_on_event_spawned)
	EventBus.new_game_started.connect(_on_new_game_started)
	EventBus.tick_finished.connect(_on_tick_finished)
	EventBus.city_level_changed.connect(func(_lv: int) -> void:
		_rebuild_building_list()
		if _city_visible:
			_rebuild_city_panel()
	)
	EventBus.build_mode_changed.connect(_on_build_mode_changed)
	Localization.locale_changed.connect(_on_locale_changed)


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
		var lbl: String = Localization.content_text(def, "label", res_id)
		core_parts.append("%s:%d" % [lbl, int(val)])
	_core_label.text = " ".join(core_parts)

	# --- City ---
	var pop: int = GameStateStore.population().total as int
	var happiness: float = GameStateStore.population().happiness as float
	var city_lv: int = GameStateStore.progression().city_level as int
	var lv_def: Dictionary = ContentDB.get_level_def(city_lv)
	var lv_name: String = Localization.content_text(lv_def, "name", "?")

	var energy: float = GameStateStore.get_resource("energy")
	var city_text: String = "%s:%d  %s:%d%%  %s:%d  %s%d %s" % [
		Localization.t("ui.resource.population", "Pop"),
		pop,
		Localization.t("ui.resource.happiness", "Happy"),
		int(happiness),
		Localization.t("ui.resource.energy", "Energy"),
		int(energy),
		Localization.t("ui.resource.level", "Lv"),
		city_lv,
		lv_name,
	]
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
			city_text += "  %s:%d/%d" % [Localization.t("ui.resource.next", "Next"), met, reqs.size()]
			if met < reqs.size():
				city_text += " %s" % Localization.t("ui.city.open_hint", "(City)")
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
	_risk_label.text = "%s: %s %.0f" % [
		Localization.t("ui.risk.pressure", "Pressure"),
		Localization.t("ui.phase.%s" % phase, phase.capitalize()),
		p_idx,
	]

	_update_build_list_affordability()


# ===========================================================
# BUILD PANEL (right side, expands left)
# ===========================================================

const CATEGORY_ORDER: Array[String] = ["Infrastructure", "Residential", "Production", "Commercial", "Culture", "Advanced"]
const CATEGORY_KEYS := {
	"Infrastructure": "ui.category.infrastructure",
	"Residential": "ui.category.residential",
	"Production": "ui.category.production",
	"Commercial": "ui.category.commercial",
	"Culture": "ui.category.culture",
	"Advanced": "ui.category.advanced",
}
const BUILD_PANEL_W := 280.0

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

	_build_title_label = Label.new()
	_build_title_label.add_theme_font_size_override("font_size", 12)
	_build_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_build_title_label)

	_build_city_button = Button.new()
	_build_city_button.add_theme_font_size_override("font_size", 10)
	_build_city_button.pressed.connect(toggle_city_panel)
	header.add_child(_build_city_button)

	_build_gov_button = Button.new()
	_build_gov_button.add_theme_font_size_override("font_size", 10)
	_build_gov_button.pressed.connect(toggle_governance)
	header.add_child(_build_gov_button)

	_build_settings_button = Button.new()
	_build_settings_button.add_theme_font_size_override("font_size", 10)
	_build_settings_button.pressed.connect(toggle_settings)
	header.add_child(_build_settings_button)

	_category_select = OptionButton.new()
	_category_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_category_select.add_theme_font_size_override("font_size", 10)
	_category_select.item_selected.connect(_on_category_selected)
	_category_select.visible = false
	header.add_child(_category_select)
	_refresh_build_panel_labels()

	var category_grid := GridContainer.new()
	category_grid.columns = 2
	category_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_grid.add_theme_constant_override("h_separation", 4)
	category_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(category_grid)

	_category_buttons.clear()
	for cat: String in CATEGORY_ORDER:
		var cat_btn := Button.new()
		cat_btn.text = _category_label(cat)
		cat_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cat_btn.add_theme_font_size_override("font_size", 9)
		cat_btn.pressed.connect(_set_active_category.bind(cat))
		category_grid.add_child(cat_btn)
		_category_buttons[cat] = cat_btn

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
	_update_category_buttons()
	_rebuild_building_list()


func _refresh_build_panel_labels() -> void:
	if _build_title_label:
		_build_title_label.text = Localization.t("ui.build.title", "Build")
	if _build_city_button:
		_build_city_button.text = Localization.t("ui.city.short", "City")
		_build_city_button.tooltip_text = Localization.t("ui.city.tooltip", "City level requirements and upgrade")
	if _build_gov_button:
		_build_gov_button.text = Localization.t("ui.governance.short", "Gov")
		_build_gov_button.tooltip_text = Localization.t("ui.governance.tooltip", "Governance (G): tech tree and policies")
	if _build_settings_button:
		_build_settings_button.text = Localization.t("ui.settings.short", "Opt")
		_build_settings_button.tooltip_text = Localization.t("ui.settings.tooltip", "Options (O): language and settings")
	if _category_select:
		var selected_category := _active_category
		_category_select.clear()
		for cat: String in CATEGORY_ORDER:
			_category_select.add_item(_category_label(cat))
		var idx: int = CATEGORY_ORDER.find(selected_category)
		if idx >= 0:
			_category_select.select(idx)
	for cat: String in _category_buttons:
		var btn: Button = _category_buttons[cat] as Button
		btn.text = _category_label(cat)
	_update_category_buttons()


func _update_category_buttons() -> void:
	for cat: String in _category_buttons:
		var btn: Button = _category_buttons[cat] as Button
		btn.modulate = Color(0.8, 1.0, 0.5) if cat == _active_category else Color.WHITE


func _category_label(category: String) -> String:
	return Localization.t(CATEGORY_KEYS.get(category, ""), category)


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
		var label_name: String = Localization.content_text(def, "label", type_id)
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
		btn.tooltip_text = Localization.content_text(def, "description", "")
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
				cost_parts.append("%s:%d" % [Localization.content_text(rdef, "label", res_id), int(build_cost[res_id] as float)])
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
		parts.append("+%.0f %s" % [produces[r] as float, Localization.content_text(rdef, "label", r)])
	var consumes: Dictionary = ldata.get("consumes", {})
	for r: String in consumes:
		var rdef: Dictionary = ContentDB.get_resource_def(r)
		parts.append("-%.0f %s" % [consumes[r] as float, Localization.content_text(rdef, "label", r)])
	var bld_pop: int = ldata.get("population", 0) as int
	if bld_pop > 0:
		parts.append("+%d %s" % [bld_pop, Localization.t("ui.effect.population", "pop")])
	var storage: int = ldata.get("storage", 0) as int
	if storage > 0:
		parts.append("+%d %s" % [storage, Localization.t("ui.effect.storage", "storage")])
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
	_info_label.text = _build_build_mode_info_text(type_id)
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
	if _info_label and type_id != "":
		_info_label.text = _build_build_mode_info_text(type_id)
	# Update button highlights when build mode changes externally (e.g. RMB cancel)
	for entry: Dictionary in _build_entries:
		var btn: Button = entry.btn
		if not btn.disabled:
			if (entry.type_id as String) == type_id:
				btn.modulate = Color(0.8, 1.0, 0.5)
			else:
				btn.modulate = Color.WHITE


func _build_build_mode_info_text(type_id: String) -> String:
	var def: Dictionary = ContentDB.get_building_def(type_id)
	if def.is_empty():
		return Localization.t("ui.command.unknown_building", "Unknown building: %s") % type_id

	var ldata: Dictionary = ContentDB.building_level_data(type_id, 0)
	var lines: Array[String] = []
	lines.append("%s: %s" % [Localization.t("ui.build.selected", "Selected"), Localization.content_text(def, "label", type_id)])
	lines.append("%s: %s" % [Localization.t("ui.meta.cost", "Cost"), _format_cost(def.get("build_cost", {}))])
	var effect: String = _format_key_effect(ldata)
	if effect != "":
		lines.append("%s: %s" % [Localization.t("ui.meta.effects", "Effects"), effect])

	var req_level: int = def.get("unlock_level", 1) as int
	if (GameStateStore.progression().city_level as int) < req_level:
		lines.append(Localization.t("ui.command.requires_city_level", "Requires city level %d") % req_level)
	elif not GameStateStore.can_afford(def.get("build_cost", {})):
		lines.append("%s: %s" % [
			Localization.t("ui.command.not_enough_resources", "Not enough resources"),
			PlacementRulesRef.missing_cost_text(def.get("build_cost", {})),
		])
	else:
		lines.append(Localization.t("ui.placement.preview_hint", "Move over the map: green can build, red cannot."))

	if def.get("requires_road", false) as bool:
		lines.append(Localization.t("ui.placement.road_hint", "Road access affects efficiency."))
	var desc: String = Localization.content_text(def, "description", "")
	if desc != "":
		lines.append("")
		lines.append(desc.substr(0, 140) + ("..." if desc.length() > 140 else ""))
	return "\n".join(lines)


func _on_locale_changed(_locale: String) -> void:
	_refresh_build_panel_labels()
	_update_resource_bar()
	_rebuild_building_list()
	if _selected_coord == Vector2i(-9999, -9999):
		_info_label.text = _get_welcome_text()
	else:
		_update_info()
	if _help_label:
		_help_label.text = _get_help_text()
	if _governance_visible:
		_rebuild_governance_panel()
	if _city_visible:
		_rebuild_city_panel()
	if _settings_visible:
		_rebuild_settings_panel()
	if _start_visible:
		_rebuild_start_panel()


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
	_info_panel.offset_right = 360
	_info_panel.offset_top = -190
	_info_panel.offset_bottom = 0
	add_child(_info_panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	_info_panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.custom_minimum_size = Vector2(340, 174)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	_info_label = Label.new()
	_info_label.text = _get_welcome_text()
	_info_label.custom_minimum_size.x = 330
	_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override("font_size", 12)
	_info_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.85))
	_info_label.add_theme_constant_override("line_spacing", 3)
	_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_info_label)


func _get_welcome_text() -> String:
	return Localization.t("ui.welcome.text", """Inspect: click a tile
Camera: WASD
Zoom: mouse wheel
Build: LMB select
Cancel: RMB / Esc
Menus: G Gov, O Options
Help/Ranges: H Help, V Ranges""")


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
	var t_label: String = Localization.content_text(tdef, "label", Localization.t("ui.common.unknown", "Unknown"))
	var buildable: bool = tdef.get("buildable", true) as bool

	var text: String = "%s (%d,%d)" % [t_label, coord.x, coord.y]
	if not buildable:
		text += "\n" + Localization.t("ui.tile.cannot_build", "Cannot build here")
	else:
		# Show terrain bonuses compactly
		var bonuses: Array[String] = []
		for btype_id: String in ContentDB.get_building_ids():
			var bdef: Dictionary = ContentDB.get_building_def(btype_id)
			var tb: Dictionary = bdef.get("terrain_bonus", {})
			if tb.has(str(terrain_id)):
				var bonus: float = tb[str(terrain_id)] as float
				if bonus > 0:
					bonuses.append("+%d%% %s" % [int(bonus * 100), Localization.content_text(bdef, "label", btype_id)])
		if not bonuses.is_empty():
			text += "\n%s: %s" % [Localization.t("ui.tile.bonus", "Bonus"), ", ".join(bonuses)]
	return text


func _build_building_info_text(coord: Vector2i, bld: Dictionary) -> String:
	var type_id: String = bld.get("type", "") as String
	var level: int = bld.get("level", 0) as int
	var def: Dictionary = ContentDB.get_building_def(type_id)
	var ldata: Dictionary = ContentDB.building_level_data(type_id, level)
	var stage: String = Localization.content_text(ldata, "stage", "?")

	# --- Status ---
	var text: String = "%s (%s) %s%d\n" % [
		Localization.content_text(def, "label", type_id),
		stage,
		Localization.t("ui.common.level_short", "Lv"),
		level,
	]

	var effect: String = _format_key_effect(ldata)
	if effect != "":
		text += effect + "\n"

	var needs_text: String = _build_building_needs_text(coord, type_id, def, ldata)
	if needs_text != "":
		text += needs_text + "\n"

	var flow_text: String = _build_flow_diagnostics(coord, type_id, def, ldata, bld)
	if flow_text != "":
		text += flow_text + "\n"

	# --- Problem ---
	if bld.get("damaged", false) as bool:
		text += "\n" + Localization.t("ui.building.damaged", "DAMAGED - press R to repair")
	elif bld.get("has_issue", false) as bool:
		text += "\n" + Localization.t("ui.building.issue", "ISSUE - press R to fix")

	# --- Next Action ---
	var max_level: int = ContentDB.max_building_level(type_id)
	if level + 1 < max_level:
		var next_ldata: Dictionary = ContentDB.building_level_data(type_id, level + 1)
		var next_stage: String = Localization.content_text(next_ldata, "stage", "?")
		var cost_raw: Variant = next_ldata.get("cost", null)
		var cost: Dictionary = cost_raw as Dictionary if cost_raw is Dictionary else {}
		if not cost.is_empty():
			var affordable: bool = GameStateStore.can_afford(cost)
			if affordable:
				text += "\n%s %s" % [Localization.t("ui.building.upgrade_to", "[U] Upgrade to"), next_stage]
			else:
				# Show what's missing
				var missing: Array[String] = []
				for res_id: String in cost:
					var needed: float = cost[res_id] as float
					var have: float = GameStateStore.get_resource(res_id)
					if have < needed:
						var rdef: Dictionary = ContentDB.get_resource_def(res_id)
						missing.append("%s %d/%d" % [Localization.content_text(rdef, "label", res_id), int(have), int(needed)])
				text += "\n%s: %s" % [Localization.t("ui.building.upgrade_need", "Upgrade: need"), ", ".join(missing)]
	else:
		text += "\n" + Localization.t("ui.building.max_level", "MAX LEVEL")

	text += "\n" + Localization.t("ui.building.actions", "[U]Up [R]Fix [B]Del [V]Range")
	return text


func _build_building_needs_text(coord: Vector2i, type_id: String, def: Dictionary, ldata: Dictionary) -> String:
	var orch := _get_orchestrator()
	if orch == null or orch.coverage == null:
		return ""

	var needs: Array[String] = []
	if def.get("requires_road", false) as bool:
		needs.append("%s %s" % [Localization.t("ui.flow.road", "Road"), _ok_missing(orch.coverage.is_road_connected(coord))])
	if (def.get("category", "") as String) == "Residential":
		needs.append("%s %s" % [Localization.t("ui.flow.water", "Water"), _ok_missing(orch.coverage.is_water_covered(coord))])

	var consumes: Dictionary = ldata.get("consumes", {})
	if consumes.has("energy") and type_id != "power":
		needs.append("%s %s" % [Localization.t("ui.flow.power", "Power"), _ok_missing(orch.coverage.is_power_covered(coord))])
	if not consumes.is_empty():
		needs.append("%s: %s" % [Localization.t("ui.flow.inputs", "Inputs"), _format_cost(consumes)])

	if needs.is_empty():
		return ""
	return "%s:\n%s" % [Localization.t("ui.needs.title", "Needs"), "\n".join(needs)]


func _build_flow_diagnostics(coord: Vector2i, type_id: String, def: Dictionary, ldata: Dictionary, bld: Dictionary) -> String:
	var orch := _get_orchestrator()
	if orch == null or orch.coverage == null or orch.resource_flow == null:
		return ""

	var lines: Array[String] = []
	var consumes: Dictionary = ldata.get("consumes", {})
	var produces: Dictionary = ldata.get("produces", {})
	var input_eff: float = orch.resource_flow.input_efficiency_for(coord, consumes)
	var condition_eff: float = 0.5 if (bld.get("has_issue", false) as bool) else 1.0

	if _uses_road_flow(def, produces, consumes):
		lines.append("%s: %s" % [Localization.t("ui.flow.road", "Road"), _ok_missing(orch.coverage.is_road_connected(coord))])

	if _uses_water_flow(def, type_id, produces, consumes):
		lines.append("%s: %s" % [Localization.t("ui.flow.water", "Water"), _ok_missing(orch.coverage.is_water_covered(coord))])

	if _uses_power_flow(type_id, produces, consumes):
		lines.append("%s: %s" % [Localization.t("ui.flow.power", "Power"), _ok_missing(orch.coverage.is_power_covered(coord))])

	if not consumes.is_empty():
		var missing_inputs: Array[String] = _missing_inputs(coord, consumes, orch.resource_flow)
		if missing_inputs.is_empty():
			lines.append("%s: %s" % [Localization.t("ui.flow.inputs", "Inputs"), _ok_missing(true)])
		else:
			lines.append("%s: %s %s" % [Localization.t("ui.flow.inputs", "Inputs"), Localization.t("ui.flow.missing", "missing"), ", ".join(missing_inputs)])

	if not produces.is_empty():
		var blocked_outputs: Array[String] = _blocked_outputs(coord, type_id, produces, orch.resource_flow)
		if blocked_outputs.is_empty():
			lines.append("%s: %s" % [Localization.t("ui.flow.outputs", "Outputs"), _ok_missing(true)])
		else:
			lines.append("%s: %s %s" % [Localization.t("ui.flow.outputs", "Outputs"), Localization.t("ui.flow.blocked", "blocked"), ", ".join(blocked_outputs)])

	var final_eff: float = input_eff * condition_eff
	if final_eff < 1.0:
		lines.append("%s: %d%%" % [Localization.t("ui.flow.efficiency", "Efficiency"), int(final_eff * 100.0)])
	else:
		lines.append("%s: 100%%" % Localization.t("ui.flow.efficiency", "Efficiency"))

	if lines.is_empty():
		return ""
	return "\n" + "\n".join(lines)


func _get_orchestrator() -> GameOrchestrator:
	var main_node: Node = get_tree().current_scene
	if main_node and main_node.has_method("get_orchestrator"):
		return main_node.call("get_orchestrator") as GameOrchestrator
	return null


func _ok_missing(ok: bool) -> String:
	return Localization.t("ui.flow.ok", "OK") if ok else Localization.t("ui.flow.missing_caps", "MISSING")


func _uses_road_flow(def: Dictionary, produces: Dictionary, consumes: Dictionary) -> bool:
	if def.get("requires_road", false) as bool:
		return true
	return _has_transport(produces, "road") or _has_transport(consumes, "road")


func _uses_water_flow(def: Dictionary, type_id: String, produces: Dictionary, consumes: Dictionary) -> bool:
	if (def.get("category", "") as String) == "Residential":
		return true
	if type_id == "water_tower":
		return true
	return produces.has("water_res") or consumes.has("water_res")


func _uses_power_flow(type_id: String, produces: Dictionary, consumes: Dictionary) -> bool:
	if type_id == "power":
		return true
	return produces.has("energy") or consumes.has("energy")


func _has_transport(resources: Dictionary, transport: String) -> bool:
	for res_id: String in resources:
		var rdef: Dictionary = ContentDB.get_resource_def(res_id)
		if (rdef.get("transport", "global") as String) == transport:
			return true
	return false


func _missing_inputs(coord: Vector2i, consumes: Dictionary, flow: ResourceFlow) -> Array[String]:
	var missing: Array[String] = []
	for res_id: String in consumes:
		if flow.delivery_efficiency(res_id, coord) >= 1.0:
			continue
		var rdef: Dictionary = ContentDB.get_resource_def(res_id)
		missing.append(Localization.content_text(rdef, "label", res_id))
	return missing


func _blocked_outputs(coord: Vector2i, type_id: String, produces: Dictionary, flow: ResourceFlow) -> Array[String]:
	var blocked: Array[String] = []
	for res_id: String in produces:
		if flow.output_efficiency_for(res_id, coord, type_id) >= 1.0:
			continue
		var rdef: Dictionary = ContentDB.get_resource_def(res_id)
		blocked.append(Localization.content_text(rdef, "label", res_id))
	return blocked


# ===========================================================
# HELP PANEL (center, toggled with H)
# ===========================================================

func _build_help_panel() -> void:
	_help_panel = PanelContainer.new()
	_help_panel.set_anchors_preset(PRESET_CENTER)
	_help_panel.size = Vector2(560, 420)
	_help_panel.position = Vector2(-280, -210)
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
	scroll.custom_minimum_size = Vector2(530, 390)
	margin.add_child(scroll)

	_help_label = Label.new()
	_help_label.custom_minimum_size.x = 510
	_help_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_label.add_theme_font_size_override("font_size", 13)
	_help_label.add_theme_constant_override("line_spacing", 4)
	_help_label.add_theme_color_override("font_color", Color(0.92, 0.95, 0.88))
	_help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help_label.text = _get_help_text()
	scroll.add_child(_help_label)


func _get_help_text() -> String:
	return Localization.t("ui.help.text", """Quick start
1. Pick a category in the right build panel.
2. Build Roads first, then Huts, Farms and Lumber Mills.
3. Select a building to see its needs and next action.
4. Use V to show service ranges for the selected building.

Hotkeys
WASD - camera
Mouse wheel - zoom
LMB - select/build
RMB or Esc - cancel build mode
G - governance
O - options
H - help
V - ranges
U/R/B - upgrade/repair/bulldoze selected building

Rule of thumb
Roads connect production. Water and power are local coverage.
Pressure rises when the city grows or problems stay unresolved.""")


func toggle_help() -> void:
	_help_visible = not _help_visible
	_help_panel.visible = _help_visible


# ===========================================================
# START PANEL (center) — start profile / faction background
# ===========================================================

func _build_start_panel() -> void:
	_start_panel = PanelContainer.new()
	_start_panel.set_anchors_preset(PRESET_CENTER)
	_start_panel.size = Vector2(620, 500)
	_start_panel.position = Vector2(-310, -250)
	_start_panel.visible = true
	_start_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_start_panel)
	_rebuild_start_panel()


func _rebuild_start_panel() -> void:
	if _start_panel == null:
		return
	for c: Node in _start_panel.get_children():
		c.queue_free()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_start_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)

	var title := Label.new()
	title.text = Localization.t("ui.start.title", "Choose Your Mandate")
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = Localization.t("ui.start.keep_current", "Keep Current")
	close_btn.tooltip_text = Localization.t("ui.start.keep_current_tooltip", "Close this panel and keep the current default start.")
	close_btn.pressed.connect(_close_start_panel)
	header.add_child(close_btn)

	var intro := Label.new()
	intro.text = Localization.t("ui.start.intro", "Start profile changes your resources, mandate pressure and early strategic identity.")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 11)
	intro.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	root.add_child(intro)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	for profile_id: String in ContentDB.get_start_profile_ids():
		list.add_child(_build_start_profile_row(profile_id))


func _build_start_profile_row(profile_id: String) -> Control:
	var def: Dictionary = ContentDB.get_start_profile_def(profile_id)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 98

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)

	var title := Label.new()
	title.text = Localization.content_text(def, "label", profile_id)
	title.add_theme_font_size_override("font_size", 13)
	text_box.add_child(title)

	var desc := Label.new()
	desc.text = Localization.content_text(def, "description", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 10)
	text_box.add_child(desc)

	var meta := Label.new()
	meta.text = _format_start_profile_meta(def)
	meta.add_theme_font_size_override("font_size", 10)
	meta.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	text_box.add_child(meta)

	var btn := Button.new()
	btn.text = Localization.t("ui.start.begin", "Begin")
	btn.pressed.connect(_start_new_run.bind(profile_id))
	row.add_child(btn)

	return panel


func _format_start_profile_meta(def: Dictionary) -> String:
	var mandate_data: Dictionary = def.get("mandate", {})
	var path_label := Localization.t("ui.start.path.%s" % (def.get("start_path", "appointed") as String), def.get("start_path", "appointed") as String)
	return "%s | %s:%d | %s:%d | %s:%d" % [
		path_label,
		Localization.t("ui.start.trust", "Trust"),
		mandate_data.get("patron_trust", 0) as int,
		Localization.t("ui.start.support", "Support"),
		mandate_data.get("support", 0) as int,
		Localization.t("ui.start.autonomy", "Autonomy"),
		mandate_data.get("autonomy", 0) as int,
	]


func _start_new_run(profile_id: String) -> void:
	var main_node: Node = get_tree().current_scene
	if main_node and main_node.has_method("start_new_run"):
		main_node.call("start_new_run", profile_id)
	_close_start_panel()
	_update_resource_bar()
	_rebuild_building_list()
	_info_label.text = _get_welcome_text()
	var profile_def: Dictionary = ContentDB.get_start_profile_def(profile_id)
	EventBus.toast_requested.emit(
		Localization.t("ui.start.started", "Started: %s") % Localization.content_text(profile_def, "label", profile_id),
		3.0
	)


func _close_start_panel() -> void:
	_start_visible = false
	_start_panel.visible = false


func _on_new_game_started() -> void:
	_update_resource_bar()
	_rebuild_building_list()
	if _city_visible:
		_rebuild_city_panel()


# ===========================================================
# CITY PANEL (center) — Level requirements / manual upgrade
# ===========================================================

func _build_city_panel() -> void:
	_city_panel = PanelContainer.new()
	_city_panel.set_anchors_preset(PRESET_CENTER)
	_city_panel.size = Vector2(560, 540)
	_city_panel.position = Vector2(-280, -270)
	_city_panel.visible = false
	_city_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_city_panel)
	_rebuild_city_panel()


func toggle_city_panel() -> void:
	_city_visible = not _city_visible
	_city_panel.visible = _city_visible
	if _city_visible:
		_rebuild_city_panel()


func _rebuild_city_panel() -> void:
	if _city_panel == null:
		return
	for c: Node in _city_panel.get_children():
		c.queue_free()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_city_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)

	var title := Label.new()
	title.text = Localization.t("ui.city.title", "City Level")
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = Localization.t("ui.common.close", "Close")
	close_btn.pressed.connect(toggle_city_panel)
	header.add_child(close_btn)

	var current_level: int = GameStateStore.progression().city_level as int
	var current_def: Dictionary = ContentDB.get_level_def(current_level)
	var current_name: String = Localization.content_text(current_def, "name", "?")
	var current_lbl := Label.new()
	current_lbl.text = "%s: %s %d - %s" % [
		Localization.t("ui.city.current", "Current"),
		Localization.t("ui.resource.level", "Lv"),
		current_level,
		current_name,
	]
	current_lbl.add_theme_font_size_override("font_size", 13)
	current_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	root.add_child(current_lbl)

	var next_def: Dictionary = ContentDB.get_level_def(current_level + 1)
	if next_def.is_empty():
		var max_lbl := Label.new()
		max_lbl.text = Localization.t("ui.city.max_level", "Max city level reached.")
		max_lbl.add_theme_font_size_override("font_size", 13)
		root.add_child(max_lbl)
		return

	var next_name: String = Localization.content_text(next_def, "name", "?")
	var next_lbl := Label.new()
	next_lbl.text = "%s: %s %d - %s" % [
		Localization.t("ui.city.next", "Next"),
		Localization.t("ui.resource.level", "Lv"),
		current_level + 1,
		next_name,
	]
	next_lbl.add_theme_font_size_override("font_size", 14)
	root.add_child(next_lbl)

	var reqs: Dictionary = next_def.get("requirements", {}) as Dictionary
	var req_title := Label.new()
	req_title.text = Localization.t("ui.city.requirements", "Requirements")
	req_title.add_theme_font_size_override("font_size", 13)
	root.add_child(req_title)

	var can_upgrade := true
	for res_id: String in reqs:
		var needed: float = reqs[res_id] as float
		var have: float = GameStateStore.get_resource(res_id)
		var rdef: Dictionary = ContentDB.get_resource_def(res_id)
		var line := Label.new()
		line.text = "%s: %d/%d" % [Localization.content_text(rdef, "label", res_id), int(have), int(needed)]
		line.add_theme_font_size_override("font_size", 12)
		line.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55) if have >= needed else Color(1.0, 0.55, 0.45))
		root.add_child(line)
		if have < needed:
			can_upgrade = false

	var reward: Dictionary = next_def.get("reward", {}) as Dictionary
	var reward_lbl := Label.new()
	reward_lbl.text = "%s: %s" % [Localization.t("ui.city.reward", "Reward"), _format_cost(reward)]
	reward_lbl.add_theme_font_size_override("font_size", 12)
	reward_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	root.add_child(reward_lbl)

	var upgrade_btn := Button.new()
	upgrade_btn.text = Localization.t("ui.city.upgrade", "Upgrade City")
	upgrade_btn.disabled = not can_upgrade
	upgrade_btn.pressed.connect(_upgrade_city_level)
	root.add_child(upgrade_btn)

	var note := Label.new()
	note.text = Localization.t("ui.city.spend_note", "Upgrade spends the required resources and unlocks the next building tier.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	root.add_child(note)

	var sep := HSeparator.new()
	root.add_child(sep)

	var diag_title := Label.new()
	diag_title.text = Localization.t("ui.city.diagnostics", "City Diagnostics")
	diag_title.add_theme_font_size_override("font_size", 14)
	root.add_child(diag_title)

	var diag := Label.new()
	diag.text = _build_city_diagnostics_text()
	diag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	diag.custom_minimum_size.x = 520
	diag.add_theme_font_size_override("font_size", 12)
	diag.add_theme_constant_override("line_spacing", 3)
	diag.add_theme_color_override("font_color", Color(0.9, 0.95, 0.85))
	root.add_child(diag)


func _upgrade_city_level() -> void:
	var orch: GameOrchestrator = _get_orchestrator()
	if orch == null:
		return
	var cmd: CommandBase = load("res://scripts/core/commands/level_up_command.gd").new()
	orch.command_bus.execute(cmd)
	_update_resource_bar()
	_rebuild_building_list()
	_rebuild_city_panel()


func _build_city_diagnostics_text() -> String:
	var orch: GameOrchestrator = _get_orchestrator()
	if orch == null or orch.coverage == null:
		return Localization.t("ui.city.diagnostics_unavailable", "Diagnostics unavailable")

	var total_buildings := 0
	var residential := 0
	var residential_without_water := 0
	var road_required := 0
	var road_missing := 0
	var power_users := 0
	var power_missing := 0
	var issues := 0
	var damaged := 0

	for coord: Vector2i in GameStateStore.get_all_building_coords():
		total_buildings += 1
		var bld: Dictionary = GameStateStore.get_building(coord)
		var type_id: String = bld.get("type", "") as String
		var def: Dictionary = ContentDB.get_building_def(type_id)
		var level: int = bld.get("level", 0) as int
		var ldata: Dictionary = ContentDB.building_level_data(type_id, level)
		var consumes: Dictionary = ldata.get("consumes", {})

		if (def.get("category", "") as String) == "Residential":
			residential += 1
			if not orch.coverage.is_water_covered(coord):
				residential_without_water += 1
		if def.get("requires_road", false) as bool:
			road_required += 1
			if not orch.coverage.is_road_connected(coord):
				road_missing += 1
		if consumes.has("energy"):
			power_users += 1
			if not orch.coverage.is_power_covered(coord):
				power_missing += 1
		if bld.get("has_issue", false) as bool:
			issues += 1
		if bld.get("damaged", false) as bool:
			damaged += 1

	var lines: Array[String] = []
	lines.append("%s: %d" % [Localization.t("ui.city.buildings", "Buildings"), total_buildings])
	lines.append("%s: %d | %s: %d" % [
		Localization.t("ui.city.residential", "Residential"),
		residential,
		Localization.t("ui.city.no_water", "No water"),
		residential_without_water,
	])
	lines.append("%s: %d/%d %s" % [
		Localization.t("ui.city.road_connected", "Road connected"),
		maxi(road_required - road_missing, 0),
		road_required,
		_status_word(road_missing == 0),
	])
	lines.append("%s: %d/%d %s" % [
		Localization.t("ui.city.powered", "Powered"),
		maxi(power_users - power_missing, 0),
		power_users,
		_status_word(power_missing == 0),
	])
	lines.append("%s: %d | %s: %d" % [
		Localization.t("ui.city.issues", "Issues"),
		issues,
		Localization.t("ui.city.damaged", "Damaged"),
		damaged,
	])
	lines.append("%s: %d | %s: %d" % [
		Localization.t("ui.city.water_reserve", "Water Reserve"),
		int(GameStateStore.get_resource("water_res")),
		Localization.t("ui.resource.energy", "Energy"),
		int(GameStateStore.get_resource("energy")),
	])
	lines.append(Localization.t("ui.city.coverage_note", "Water Reserve is a stockpile; water coverage is local."))
	return "\n".join(lines)


func _status_word(ok: bool) -> String:
	return Localization.t("ui.flow.ok", "OK") if ok else Localization.t("ui.flow.missing_caps", "MISSING")


# ===========================================================
# SETTINGS PANEL (center) — Language / options
# ===========================================================

func _build_settings_panel() -> void:
	_settings_panel = PanelContainer.new()
	_settings_panel.set_anchors_preset(PRESET_CENTER)
	_settings_panel.size = Vector2(420, 220)
	_settings_panel.position = Vector2(-210, -110)
	_settings_panel.visible = false
	_settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_settings_panel)
	_rebuild_settings_panel()


func toggle_settings() -> void:
	_settings_visible = not _settings_visible
	_settings_panel.visible = _settings_visible
	if _settings_visible:
		_rebuild_settings_panel()


func _rebuild_settings_panel() -> void:
	if _settings_panel == null:
		return
	for c: Node in _settings_panel.get_children():
		c.queue_free()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_settings_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)

	var title := Label.new()
	title.text = Localization.t("ui.settings.title", "Options")
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = Localization.t("ui.common.close", "Close")
	close_btn.pressed.connect(toggle_settings)
	header.add_child(close_btn)

	var language_row := HBoxContainer.new()
	language_row.add_theme_constant_override("separation", 10)
	root.add_child(language_row)

	var language_label := Label.new()
	language_label.text = Localization.t("ui.settings.language", "Language")
	language_label.custom_minimum_size.x = 120
	language_row.add_child(language_label)

	_settings_language_select = OptionButton.new()
	_settings_language_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_language_select.add_item(Localization.t("ui.language.english", "English"))
	_settings_language_select.set_item_metadata(0, "en")
	_settings_language_select.add_item(Localization.t("ui.language.russian", "Russian"))
	_settings_language_select.set_item_metadata(1, "ru")
	_settings_language_select.select(0 if Localization.current_locale == "en" else 1)
	_settings_language_select.item_selected.connect(_on_settings_language_selected)
	language_row.add_child(_settings_language_select)

	var note := Label.new()
	note.text = Localization.t("ui.settings.language_note", "Language is saved automatically.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	root.add_child(note)


func _on_settings_language_selected(index: int) -> void:
	if _settings_language_select == null:
		return
	var locale := _settings_language_select.get_item_metadata(index) as String
	Localization.set_locale(locale)


# ===========================================================
# GOVERNANCE PANEL (center) — Tech / Policies
# ===========================================================

func _build_governance_panel() -> void:
	_governance_panel = PanelContainer.new()
	_governance_panel.set_anchors_preset(PRESET_CENTER)
	_governance_panel.size = Vector2(620, 500)
	_governance_panel.position = Vector2(-310, -250)
	_governance_panel.visible = false
	_governance_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_governance_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_governance_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)

	var title := Label.new()
	title.text = Localization.t("ui.governance.title", "Governance")
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = Localization.t("ui.common.close", "Close")
	close_btn.pressed.connect(toggle_governance)
	header.add_child(close_btn)

	_governance_tabs = TabContainer.new()
	_governance_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_governance_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_governance_tabs)

	_rebuild_governance_panel()


func toggle_governance() -> void:
	_governance_visible = not _governance_visible
	_governance_panel.visible = _governance_visible
	if _governance_visible:
		_rebuild_governance_panel()


func _rebuild_governance_panel() -> void:
	if _governance_tabs == null:
		return
	for c: Node in _governance_tabs.get_children():
		_governance_tabs.remove_child(c)
		c.queue_free()
	_governance_tabs.add_child(_build_tech_tab())
	_governance_tabs.add_child(_build_policy_tab())
	_governance_tabs.set_tab_title(0, Localization.t("ui.tech.tab", "Tech"))
	_governance_tabs.set_tab_title(1, Localization.t("ui.policy.tab", "Policies"))


func _build_tech_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = Localization.t("ui.tech.tab", "Tech")
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	for tech_id: String in ContentDB.get_technology_ids():
		list.add_child(_build_tech_row(tech_id))

	return scroll


func _build_tech_row(tech_id: String) -> Control:
	var def: Dictionary = ContentDB.get_technology_def(tech_id)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 74

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)

	var researched: bool = GameStateStore.has_technology(tech_id)
	var title := Label.new()
	title.text = "%s%s" % [Localization.content_text(def, "label", tech_id), Localization.t("ui.tech.done_suffix", " [DONE]") if researched else ""]
	title.add_theme_font_size_override("font_size", 13)
	text_box.add_child(title)

	var desc := Label.new()
	desc.text = Localization.content_text(def, "description", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 10)
	text_box.add_child(desc)

	var meta := Label.new()
	meta.text = "%s: %s | %s: %s" % [
		Localization.t("ui.meta.cost", "Cost"),
		_format_cost(def.get("cost", {})),
		Localization.t("ui.meta.effects", "Effects"),
		_format_effects(def.get("effects", {})),
	]
	meta.add_theme_font_size_override("font_size", 10)
	meta.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	text_box.add_child(meta)

	var btn := Button.new()
	btn.text = Localization.t("ui.tech.researched", "Researched") if researched else Localization.t("ui.tech.research", "Research")
	btn.disabled = researched or not _can_research_tech(def)
	btn.pressed.connect(_research_technology.bind(tech_id))
	row.add_child(btn)

	return panel


func _build_policy_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = Localization.t("ui.policy.tab", "Policies")
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var active_summary := Label.new()
	active_summary.text = Localization.t("ui.policy.active_prefix", "Active: ") + _format_active_policies()
	active_summary.add_theme_font_size_override("font_size", 12)
	active_summary.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	list.add_child(active_summary)

	for policy_id: String in ContentDB.get_policy_ids():
		list.add_child(_build_policy_row(policy_id))

	return scroll


func _build_policy_row(policy_id: String) -> Control:
	var def: Dictionary = ContentDB.get_policy_def(policy_id)
	var category: String = def.get("category", "general") as String
	var active: bool = GameStateStore.get_active_policy(category) == policy_id
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 74

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)

	var title := Label.new()
	title.text = "[%s] %s%s" % [
		category.capitalize(),
		Localization.content_text(def, "label", policy_id),
		Localization.t("ui.policy.active_suffix", " [ACTIVE]") if active else "",
	]
	title.add_theme_font_size_override("font_size", 13)
	text_box.add_child(title)

	var desc := Label.new()
	desc.text = Localization.content_text(def, "description", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 10)
	text_box.add_child(desc)

	var meta := Label.new()
	meta.text = "%s: %s | %s: %s" % [
		Localization.t("ui.meta.switch", "Switch"),
		_format_cost(def.get("switch_cost", {})),
		Localization.t("ui.meta.effects", "Effects"),
		_format_effects(def.get("effects", {})),
	]
	meta.add_theme_font_size_override("font_size", 10)
	meta.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	text_box.add_child(meta)

	var btn := Button.new()
	btn.text = Localization.t("ui.policy.active", "Active") if active else Localization.t("ui.policy.set", "Set")
	btn.disabled = active or not _can_set_policy(def)
	btn.pressed.connect(_set_policy.bind(policy_id))
	row.add_child(btn)

	return panel


func _research_technology(tech_id: String) -> void:
	var orch: GameOrchestrator = _get_orchestrator()
	if orch == null:
		return
	var cmd: CommandBase = load("res://scripts/core/commands/research_technology_command.gd").new(tech_id)
	orch.command_bus.execute(cmd)
	_update_resource_bar()
	_rebuild_governance_panel()


func _set_policy(policy_id: String) -> void:
	var orch: GameOrchestrator = _get_orchestrator()
	if orch == null:
		return
	orch.command_bus.execute(SetPolicyCommand.new(policy_id))
	_update_resource_bar()
	_rebuild_governance_panel()

func _can_research_tech(def: Dictionary) -> bool:
	if not GameStateStore.can_afford(def.get("cost", {})):
		return false
	var requires: Array = def.get("requires", [])
	for req_var: Variant in requires:
		if not GameStateStore.has_technology(req_var as String):
			return false
	return true


func _can_set_policy(def: Dictionary) -> bool:
	if not GameStateStore.can_afford(def.get("switch_cost", {})):
		return false
	var requirements: Dictionary = def.get("requirements", {})
	var city_level: int = requirements.get("city_level", 1) as int
	if (GameStateStore.progression().city_level as int) < city_level:
		return false
	var techs: Array = requirements.get("tech", [])
	for tech_var: Variant in techs:
		if not GameStateStore.has_technology(tech_var as String):
			return false
	return true


func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return Localization.t("ui.common.free", "free")
	var parts: Array[String] = []
	for res_id: String in cost:
		var rdef: Dictionary = ContentDB.get_resource_def(res_id)
		parts.append("%s:%d" % [Localization.content_text(rdef, "label", res_id), int(cost[res_id] as float)])
	return ", ".join(parts)


func _format_effects(effects: Dictionary) -> String:
	if effects.is_empty():
		return Localization.t("ui.common.none", "none")
	var parts: Array[String] = []
	if effects.has("production_mult"):
		var prod: Dictionary = effects.production_mult
		for res_id: String in prod:
			var rdef: Dictionary = ContentDB.get_resource_def(res_id)
			parts.append("%s %+d%%" % [Localization.content_text(rdef, "label", res_id), int((prod[res_id] as float) * 100.0)])
	if effects.has("happiness_add"):
		parts.append("%s %+d" % [Localization.t("ui.effect.happiness", "Happy"), int(effects.happiness_add as float)])
	if effects.has("pressure_delta"):
		parts.append("%s %+d" % [Localization.t("ui.effect.pressure", "Pressure"), int(effects.pressure_delta as float)])
	if effects.has("pressure_mult"):
		parts.append("%s x%.2f" % [Localization.t("ui.effect.pressure", "Pressure"), effects.pressure_mult as float])
	return ", ".join(parts)


func _format_active_policies() -> String:
	var active: Dictionary = GameStateStore.get_active_policies()
	if active.is_empty():
		return Localization.t("ui.common.none", "none")
	var parts: Array[String] = []
	for category: String in active:
		var policy_id: String = active[category] as String
		var def: Dictionary = ContentDB.get_policy_def(policy_id)
		parts.append("%s=%s" % [category, Localization.content_text(def, "label", policy_id)])
	return ", ".join(parts)


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
	title.text = Localization.content_text(event_data, "title", Localization.t("ui.event.title", "Event"))
	title.add_theme_font_size_override("font_size", 16)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	var body := Label.new()
	body.text = Localization.content_text(event_data, "body", "")
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
			cp.append("%s: %d" % [Localization.content_text(rdef, "label", res_id), int((cost_raw as Dictionary)[res_id] as float)])
		cost_label.text = Localization.t("ui.meta.cost", "Cost") + ": " + ", ".join(cp)
		cost_label.add_theme_font_size_override("font_size", 11)
		cost_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
		cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(cost_label)

	var btn_row := HBoxContainer.new()
	vbox.add_child(btn_row)

	var ev_id: String = event_data.get("id", "") as String

	var accept_btn := Button.new()
	accept_btn.text = Localization.content_text(event_data, "accept_label", Localization.t("ui.event.accept", "Accept"))
	var accept_cost_raw: Variant = event_data.get("accept_cost", null)
	if accept_cost_raw is Dictionary and not (accept_cost_raw as Dictionary).is_empty():
		if not GameStateStore.can_afford(accept_cost_raw as Dictionary):
			accept_btn.disabled = true
			accept_btn.tooltip_text = Localization.t("ui.event.not_enough_resources", "Not enough resources")
	accept_btn.pressed.connect(_resolve_event.bind(ev_id, true))
	btn_row.add_child(accept_btn)

	var decline_btn := Button.new()
	decline_btn.text = Localization.content_text(event_data, "decline_label", Localization.t("ui.event.decline", "Decline"))
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
	if _city_visible:
		_rebuild_city_panel()
