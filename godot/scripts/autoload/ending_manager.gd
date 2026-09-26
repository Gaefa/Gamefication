extends Node
## EndingManager (Autoload)
## Detects MVP end-states (GDD §17/§19) and shows a finale screen with the
## canonical text from CONTENT_BIBLE §9 (content/base/endings.json).
##
## Self-contained: owns its own CanvasLayer + finale UI, so it needs no changes
## to main.gd. Evaluates conditions on each finished tick; fires once per game,
## resets on new game. All thresholds are first-pass tuning.

# --- Tuning thresholds ---
const WIN_DAY := 30                 # survive the whole Пыль and out the other side → win
const WIN_HAPPINESS := 40.0         # ...and the city is actually stable, not in ruins
const EXODUS_PEAK_MIN := 12         # only call it an exodus if the city was sizeable
const EXODUS_FRACTION := 0.4        # ...and shrank to ≤40% of its peak

var _active: bool = false
var _ended: bool = false
var _peak_pop: int = 0

# UI (built in code)
var _layer: CanvasLayer
var _root: Control
var _title_label: Label
var _body_label: RichTextLabel
var _theses_label: RichTextLabel
var _menu_btn: Button

const PRESSURE_LABELS := { "food": "еда", "water": "вода", "happiness": "люди", "mandate": "мандат" }


func _ready() -> void:
	_build_ui()
	EventBus.new_game_started.connect(_on_new_game_started)
	EventBus.game_loaded.connect(_on_game_loaded)
	EventBus.tick_finished.connect(_on_tick_finished)


func _on_new_game_started() -> void:
	_active = true
	_ended = false
	_peak_pop = 0
	if _layer:
		_layer.visible = false


func _on_game_loaded(_slot: int) -> void:
	_active = true
	_ended = false
	_peak_pop = GameStateStore.population().get("peak", 0) as int
	if _layer:
		_layer.visible = false


func _on_tick_finished(_tick: int) -> void:
	if not _active or _ended:
		return
	_evaluate()


func _evaluate() -> void:
	var climate: Dictionary = GameStateStore.climate()
	var day: int = climate.get("total_day", 1) as int
	var pop: int = GameStateStore.population().get("total", 0) as int
	_peak_pop = maxi(_peak_pop, pop)
	GameStateStore.population()["peak"] = _peak_pop  # exodus detection survives a load

	var mandate: Dictionary = GameStateStore.mandate()
	var trust: float = mandate.get("patron_trust", 50) as float
	var support: float = mandate.get("support", 50) as float
	var disclosure: bool = (mandate.get("flags", {}) as Dictionary).get("disclosure", false) as bool
	var happiness: float = GameStateStore.population().get("happiness", 50.0) as float

	# Losses take priority over wins.
	if trust <= 0.0:
		# Recall method is the patron's, not hardcoded: Конвой is the cross-faction emergency
		# tool (any patron, if the player tried to expose them); otherwise each patron has
		# its own procedure — Лига's Социальная изоляция, Директорат's Чрезвычайный комиссар.
		if disclosure:
			_trigger("ending.lose.convoy")
		else:
			_trigger(_patron_recall_ending())
	elif support <= 0.0:
		# The other master: the city withdraws all backing → it comes for you (bunt).
		# Symmetric to trust ≤ 0 → recall; together they are the vice the player walks.
		_trigger("ending.lose.riot")
	elif _peak_pop >= EXODUS_PEAK_MIN and pop <= int(float(_peak_pop) * EXODUS_FRACTION):
		_trigger("ending.lose.exodus")
	elif _peak_pop >= 4 and pop <= 0:
		# Total desertion — even a small district emptying out is an exodus.
		_trigger("ending.lose.exodus")
	elif day >= WIN_DAY and happiness >= WIN_HAPPINESS:
		# Survived to the end AND the city is stable — a real win, not a hollow one.
		# A devastated city (low happiness) simply doesn't win yet; it must recover.
		# Which win shade depends on how the player governed (style flags), with the
		# trust-vs-support balance as a fallback when no strong style emerged.
		var style: String = GameStateStore.dominant_style("")
		var protector_side: bool = style == "protector" or style == "autonomist" \
			or (style == "" and support > trust)
		_trigger(_patron_win_ending(protector_side))


func _patron_win_ending(protector_side: bool) -> String:
	# The win shade (loyal-to-patron vs the city's protector) is told in the patron's
	# own voice, so a Directorate victory doesn't read as if Coyle signed it.
	match GameStateStore.mandate().get("patron_id", "restoration_league") as String:
		"civic_directorate":
			return "ending.win.directorate_defiant" if protector_side else "ending.win.directorate_order"
		_:
			return "ending.win.protector" if protector_side else "ending.win.loyal"


func _patron_recall_ending() -> String:
	match GameStateStore.mandate().get("patron_id", "restoration_league") as String:
		"civic_directorate":
			return "ending.lose.commissar"
		_:
			return "ending.lose.isolation"


func _trigger(ending_id: String) -> void:
	var def: Dictionary = ContentDB.get_ending_def(ending_id)
	if def.is_empty():
		push_warning("EndingManager: unknown ending %s" % ending_id)
		return
	_ended = true
	_active = false
	SimulationRunner.paused = true
	SimulationRunner.run_active = false
	_show_finale(def, ending_id)
	EventBus.ending_triggered.emit(ending_id, def.get("kind", "") as String)
	if (def.get("kind", "") as String) == "win":
		EventBus.win_condition_met.emit()


# --- UI ---

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 200  # above HUD and the desk
	_layer.visible = false
	add_child(_layer)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(_root)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(1000, 460)
	panel.position = Vector2(-500, -230)
	bg.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_font_size_override("font_size", 26)
	vbox.add_child(_title_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Ending Card (UX_BIBLE §7.1): verdict on the left, consequence bullets on the right.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	vbox.add_child(columns)

	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = true
	_body_label.fit_content = true
	_body_label.scroll_active = false
	_body_label.custom_minimum_size = Vector2(0, 240)
	_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_label.add_theme_font_size_override("normal_font_size", 16)
	columns.add_child(_body_label)

	columns.add_child(VSeparator.new())

	_theses_label = RichTextLabel.new()
	_theses_label.bbcode_enabled = true
	_theses_label.fit_content = true
	_theses_label.scroll_active = false
	_theses_label.custom_minimum_size = Vector2(320, 240)
	_theses_label.add_theme_font_size_override("normal_font_size", 14)
	columns.add_child(_theses_label)

	_menu_btn = Button.new()
	_menu_btn.text = "В главное меню"
	_menu_btn.custom_minimum_size.y = 44
	_menu_btn.pressed.connect(_on_menu_pressed)
	vbox.add_child(_menu_btn)


func _show_finale(def: Dictionary, ending_id: String) -> void:
	var kind: String = def.get("kind", "") as String
	_title_label.text = def.get("title", "Финал") as String
	_title_label.add_theme_color_override(
		"font_color",
		Color(0.6, 0.9, 0.6) if kind == "win" else Color(0.9, 0.55, 0.5)
	)
	_body_label.text = (def.get("body", "") as String) + _replacement_epilogue(ending_id) + _style_epilogue()
	_theses_label.text = _theses()
	_layer.visible = true


func _theses() -> String:
	# The "why" a tester should be able to name after the finale (RELEASE_PLAN §2.4):
	# both masters, the Cistern (GDD §8.3), the first thing that broke, and the people.
	var lines: Array[String] = ["[b]ИТОГИ[/b]"]
	var mandate: Dictionary = GameStateStore.mandate()
	var trust: float = mandate.get("patron_trust", 50) as float
	var support: float = mandate.get("support", 50) as float
	var masters := "оба ещё держатся"
	if trust <= 0.0:
		masters = "покровитель лишил доверия"
	elif support <= 0.0:
		masters = "город отказал в поддержке"
	lines.append("• [b]Два хозяина:[/b] доверие %d · поддержка %d — %s" % [int(trust), int(support), masters])

	var reserve: int = int(GameStateStore.get_resource("res_water_stockpile"))
	var days: float = WaterPanel.water_days()
	var cistern := "пуста"
	if reserve > 0 and (is_inf(days) or days >= 0.1):
		cistern = "%d воды" % reserve if is_inf(days) else "%d воды — на %.1f дн." % [reserve, days]
	lines.append("• [b]Цистерна:[/b] %s" % cistern)

	var first: Dictionary = GameStateStore.pressure().get("first_crisis", {}) as Dictionary
	if first.is_empty():
		lines.append("• [b]Давление:[/b] ни одна беда не дошла до кризиса")
	else:
		lines.append("• [b]Первым сорвалось:[/b] %s, день %d" % [
			PRESSURE_LABELS.get(first.get("category", ""), "?"), first.get("day", 0) as int])

	var pop: int = GameStateStore.population().get("total", 0) as int
	lines.append("• [b]Жители:[/b] было до %d, осталось %d" % [maxi(_peak_pop, pop), pop])
	return "\n\n".join(lines)


const RECALL_ENDINGS := ["ending.lose.isolation", "ending.lose.commissar", "ending.lose.convoy"]


func _replacement_epilogue(ending_id: String) -> String:
	# The recall has a face (LORE_BIBLE §12): the neighbour the patron measured you against.
	if not RECALL_ENDINGS.has(ending_id):
		return ""
	return "\n\n[i]Через неделю в ваш кабинет въехала %s из соседнего района — со своим расписанием воды и своими печатями.[/i]" % RivalManager.NAME


func _style_epilogue() -> String:
	# A closing line naming the political shade the player's decisions added up to.
	var labels := {
		"loyal": "лояльный администратор Лиги",
		"protector": "защитник города",
		"pragmatist": "жёсткий прагматик",
		"autonomist": "будущий автономист",
	}
	var style: String = GameStateStore.dominant_style("")
	if style == "" or not labels.has(style):
		return ""
	return "\n\n[i]Оттенок: %s.[/i]" % labels[style]


func _on_menu_pressed() -> void:
	_layer.visible = false
	# Fresh start → main._ready() runs new_game() → new_game_started resets us.
	get_tree().reload_current_scene()
