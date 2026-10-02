extends Node
## UiStyle (Autoload, first in the list): the interface's visual language in one place.
## Colours, fonts and the default look of every standard control are set here, so panels
## built anywhere in the project (HUD, Desk, autoload panels) read as one product.

# --- Palette: dark warm metal, brass accent, paper for documents ---
const BG := Color("14110ef5")          # panel background (near-opaque: the map never shows through text)
const BG_RAISED := Color("221c16")     # cards, chips, buttons
const BG_HOVER := Color("30281e")
const BG_PRESSED := Color("0e0c0a")
const LINE := Color("43392b")          # borders
const LINE_SOFT := Color("2c251c")
const ACCENT := Color("e2b04a")        # brass
const ACCENT_DIM := Color("8f7234")
const TEXT := Color("ece5d5")
const TEXT_DIM := Color("aaa08c")
const TEXT_MUTE := Color("786f5f")
const GOOD := Color("86c45a")
const WARN := Color("e6902b")
const BAD := Color("e5564b")
const WATER := Color("5fb0ee")
const PAPER := Color("e9e0cb")
const PAPER_EDGE := Color("b9ab8c")
const INK := Color("2b241b")
const INK_DIM := Color("6b5f4c")

const FONT_DIR := "res://assets/fonts/"

var font_title: Font     # serif bold — headings
var font_doc: Font       # serif — letters and documents
var font_doc_italic: Font
var font_caps: Font      # spaced capitals — small section labels


func _enter_tree() -> void:
	font_title = _load_font("IBMPlexSerif-Bold.ttf")
	font_doc = _load_font("IBMPlexSerif-Regular.ttf")
	font_doc_italic = _load_font("IBMPlexSerif-Italic.ttf")
	var caps := FontVariation.new()
	caps.base_font = ThemeDB.fallback_font
	caps.spacing_glyph = 1
	font_caps = caps
	_apply_theme(ThemeDB.get_default_theme())


func _load_font(file: String) -> Font:
	var path: String = FONT_DIR + file
	if ResourceLoader.exists(path):
		return load(path) as Font
	return ThemeDB.fallback_font


# --- Building blocks ---

func box(bg: Color, border: Color = LINE, radius: int = 6, margin: int = 10, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	style.anti_aliasing = false  # crisp 1px edges at any UI scale
	return style


## A floating panel: opaque, bordered, with a soft drop shadow so it lifts off the map.
func panel_box(margin: int = 12) -> StyleBoxFlat:
	var style: StyleBoxFlat = box(BG, LINE, 8, margin)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	return style


## A card inside a panel (build entry, mandate, technology row).
func card_box(state: String = "normal") -> StyleBoxFlat:
	match state:
		"hover":
			return box(BG_HOVER, ACCENT_DIM, 6, 8)
		"active":
			return box(Color("3a2f1a"), ACCENT, 6, 8)
		"locked":
			return box(Color("191613"), LINE_SOFT, 6, 8)
	return box(BG_RAISED, LINE, 6, 8)


## A sheet of paper: the Desk's letters and the finale.
func paper_box(margin: int = 28) -> StyleBoxFlat:
	var style: StyleBoxFlat = box(PAPER, PAPER_EDGE, 3, margin)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 6)
	return style


func title(label: Label, size: int = 20, color: Color = TEXT) -> void:
	label.add_theme_font_override("font", font_title)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)


## Small spaced capitals above a block: "ЦЕЛИ", "КАРТА", "СТРОИТЕЛЬСТВО".
func caption(label: Label) -> void:
	label.add_theme_font_override("font", font_caps)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", ACCENT)
	label.uppercase = true


## The one button on a screen the player is expected to press.
func primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", box(ACCENT, ACCENT, 6, 10))
	button.add_theme_stylebox_override("hover", box(ACCENT.lightened(0.15), ACCENT.lightened(0.15), 6, 10))
	button.add_theme_stylebox_override("pressed", box(ACCENT.darkened(0.2), ACCENT, 6, 10))
	button.add_theme_stylebox_override("disabled", box(Color("3a3326"), LINE, 6, 10))
	for item: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(item, Color("1b150b"))
	button.add_theme_font_override("font", font_title)


## A dark-ink button for paper sheets.
func paper_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", box(Color("ded3ba"), PAPER_EDGE, 4, 10))
	button.add_theme_stylebox_override("hover", box(Color("f3ead6"), INK_DIM, 4, 10))
	button.add_theme_stylebox_override("pressed", box(Color("cdbf9f"), INK, 4, 10))
	button.add_theme_stylebox_override("disabled", box(Color("d9cfb9"), Color("c9bda2"), 4, 10))
	for item: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(item, INK)
	button.add_theme_color_override("font_disabled_color", Color("9c917c"))


func hex(color: Color) -> String:
	return "#" + color.to_html(false)


# --- Default look of the standard controls ---

func _apply_theme(theme: Theme) -> void:
	theme.default_font_size = 14

	for type: String in ["PanelContainer", "Panel", "PopupPanel"]:
		theme.set_stylebox("panel", type, panel_box())

	for type: String in ["Button", "OptionButton", "MenuButton"]:
		theme.set_stylebox("normal", type, box(BG_RAISED, LINE, 5, 7))
		theme.set_stylebox("hover", type, box(BG_HOVER, ACCENT_DIM, 5, 7))
		theme.set_stylebox("pressed", type, box(Color("3a2f1a"), ACCENT, 5, 7))
		theme.set_stylebox("hover_pressed", type, box(Color("463820"), ACCENT, 5, 7))
		theme.set_stylebox("disabled", type, box(Color("191613"), LINE_SOFT, 5, 7))
		theme.set_stylebox("focus", type, StyleBoxEmpty.new())
		theme.set_color("font_color", type, TEXT)
		theme.set_color("font_hover_color", type, Color.WHITE)
		theme.set_color("font_pressed_color", type, ACCENT)
		theme.set_color("font_hover_pressed_color", type, ACCENT)
		theme.set_color("font_focus_color", type, TEXT)
		theme.set_color("font_disabled_color", type, TEXT_MUTE)
		theme.set_color("icon_normal_color", type, TEXT)
		theme.set_color("icon_hover_color", type, Color.WHITE)
		theme.set_color("icon_pressed_color", type, ACCENT)
		theme.set_color("icon_disabled_color", type, TEXT_MUTE)

	for type: String in ["CheckBox", "CheckButton"]:
		theme.set_stylebox("focus", type, StyleBoxEmpty.new())
		theme.set_color("font_color", type, TEXT)
		theme.set_color("font_hover_color", type, Color.WHITE)
		theme.set_color("font_pressed_color", type, TEXT)
		theme.set_color("font_hover_pressed_color", type, Color.WHITE)

	theme.set_stylebox("panel", "PopupMenu", box(BG, LINE, 6, 6))
	theme.set_stylebox("hover", "PopupMenu", box(BG_HOVER, BG_HOVER, 4, 4))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)

	theme.set_stylebox("panel", "TooltipPanel", box(Color("0f0d0b"), ACCENT_DIM, 5, 8))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_font_size("font_size", "TooltipLabel", 13)

	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("default_color", "RichTextLabel", TEXT)

	var tab_panel: StyleBoxFlat = box(Color("1a1612"), LINE, 6, 10)
	tab_panel.corner_radius_top_left = 0
	theme.set_stylebox("panel", "TabContainer", tab_panel)
	for type: String in ["TabContainer", "TabBar"]:
		var selected: StyleBoxFlat = box(Color("1a1612"), LINE, 6, 9)
		selected.border_color = ACCENT
		selected.set_border_width_all(0)
		selected.border_width_top = 2
		selected.corner_radius_bottom_left = 0
		selected.corner_radius_bottom_right = 0
		theme.set_stylebox("tab_selected", type, selected)
		var unselected: StyleBoxFlat = box(Color("120f0d"), LINE_SOFT, 6, 9)
		unselected.set_border_width_all(0)
		unselected.corner_radius_bottom_left = 0
		unselected.corner_radius_bottom_right = 0
		theme.set_stylebox("tab_unselected", type, unselected)
		var hovered: StyleBoxFlat = unselected.duplicate() as StyleBoxFlat
		hovered.bg_color = BG_HOVER
		theme.set_stylebox("tab_hovered", type, hovered)
		theme.set_stylebox("tab_focus", type, StyleBoxEmpty.new())
		theme.set_color("font_selected_color", type, ACCENT)
		theme.set_color("font_unselected_color", type, TEXT_DIM)
		theme.set_color("font_hovered_color", type, TEXT)

	for type: String in ["VScrollBar", "HScrollBar"]:
		var track: StyleBoxFlat = box(Color("0e0c0a80"), Color.TRANSPARENT, 3, 3, 0)
		theme.set_stylebox("scroll", type, track)
		theme.set_stylebox("scroll_focus", type, track)
		theme.set_stylebox("grabber", type, box(LINE, Color.TRANSPARENT, 3, 3, 0))
		theme.set_stylebox("grabber_highlight", type, box(ACCENT_DIM, Color.TRANSPARENT, 3, 3, 0))
		theme.set_stylebox("grabber_pressed", type, box(ACCENT, Color.TRANSPARENT, 3, 3, 0))

	theme.set_stylebox("background", "ProgressBar", box(Color("0b0a08"), LINE_SOFT, 3, 0))
	theme.set_stylebox("fill", "ProgressBar", box(ACCENT, Color.TRANSPARENT, 3, 0, 0))

	var line := StyleBoxLine.new()
	line.color = LINE
	line.thickness = 1
	theme.set_stylebox("separator", "HSeparator", line)
	theme.set_constant("separation", "HSeparator", 8)
