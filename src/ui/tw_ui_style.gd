extends RefCounted
class_name TWUIStyle

# ── Font paths ─────────────────────────────────────────────────────────────
const FONT_REGULAR  := "res://For Cursor/Inter/Inter_18pt-Regular.ttf"
const FONT_MEDIUM   := "res://For Cursor/Inter/Inter_18pt-Medium.ttf"
const FONT_SEMIBOLD := "res://For Cursor/Inter/Inter_18pt-SemiBold.ttf"
const FONT_BOLD     := "res://For Cursor/Inter/Inter_24pt-SemiBold.ttf"

# ── Palette ────────────────────────────────────────────────────────────────
# Deep navy-black + military brass gold. Every interactive element wears gold.
const COLOR_DEEP_BG     := Color(0.040, 0.050, 0.075, 1.00)  # Screen bg
const COLOR_CARD        := Color(0.070, 0.090, 0.130, 0.97)  # Card surface
const COLOR_SURFACE     := Color(0.110, 0.135, 0.185, 1.00)  # Elevated surface
const COLOR_GOLD        := Color(0.780, 0.640, 0.380, 1.00)  # Military brass
const COLOR_GOLD_DIM    := Color(0.780, 0.640, 0.380, 0.28)  # Fill tint
const COLOR_TEXT        := Color(0.915, 0.930, 0.960, 1.00)  # Off-white body
const COLOR_MUTED       := Color(0.490, 0.535, 0.615, 1.00)  # Secondary text
const COLOR_BORDER      := Color(0.155, 0.195, 0.268, 1.00)  # Subtle border
const COLOR_BORDER_MED  := Color(0.195, 0.245, 0.328, 1.00)  # Medium border
const COLOR_ACCENT_RED  := Color(0.875, 0.295, 0.295, 1.00)  # Attacker
const COLOR_ACCENT_BLUE := Color(0.320, 0.600, 0.920, 1.00)  # Defender

static var _font_regular:  Font = null
static var _font_medium:   Font = null
static var _font_semibold: Font = null
static var _font_bold:     Font = null

static func _load_fonts() -> void:
	if _font_regular  == null: _font_regular  = load(FONT_REGULAR)
	if _font_medium   == null: _font_medium   = load(FONT_MEDIUM)
	if _font_semibold == null: _font_semibold = load(FONT_SEMIBOLD)
	if _font_bold     == null: _font_bold     = load(FONT_BOLD)

# ── StyleBoxes ─────────────────────────────────────────────────────────────

static func make_card_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color               = COLOR_CARD
	sb.border_color           = COLOR_BORDER
	sb.border_width_top       = 1
	sb.border_width_bottom    = 1
	sb.border_width_left      = 1
	sb.border_width_right     = 1
	sb.corner_radius_top_left     = 4
	sb.corner_radius_top_right    = 4
	sb.corner_radius_bottom_left  = 4
	sb.corner_radius_bottom_right = 4
	sb.shadow_color  = Color(0.0, 0.0, 0.0, 0.55)
	sb.shadow_size   = 7
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left   = 18
	sb.content_margin_top    = 15
	sb.content_margin_right  = 18
	sb.content_margin_bottom = 15
	return sb

# Identical to card, but with a 3-px gold left border — marks "active" panels.
static func make_card_accent_stylebox() -> StyleBoxFlat:
	var sb            := make_card_stylebox()
	sb.border_width_left   = 3
	sb.border_width_top    = 0
	sb.border_width_right  = 0
	sb.border_width_bottom = 0
	sb.border_color        = COLOR_GOLD
	sb.content_margin_left = 20
	return sb

# Elevated surface — used for LineEdit and raised sub-containers.
static func make_surface_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color               = COLOR_SURFACE
	sb.border_color           = COLOR_BORDER_MED
	sb.border_width_top       = 1
	sb.border_width_bottom    = 1
	sb.border_width_left      = 1
	sb.border_width_right     = 1
	sb.corner_radius_top_left     = 4
	sb.corner_radius_top_right    = 4
	sb.corner_radius_bottom_left  = 4
	sb.corner_radius_bottom_right = 4
	sb.shadow_color  = Color(0.0, 0.0, 0.0, 0.25)
	sb.shadow_size   = 2
	sb.shadow_offset = Vector2(0, 1)
	sb.content_margin_left   = 10
	sb.content_margin_top    = 8
	sb.content_margin_right  = 10
	sb.content_margin_bottom = 8
	return sb

# Buttons: transparent until hovered; hover = gold left bar + surface bg.
static func make_button_normal() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color               = Color(0.0, 0.0, 0.0, 0.0)
	sb.border_color           = Color(0.0, 0.0, 0.0, 0.0)
	sb.corner_radius_top_left     = 2
	sb.corner_radius_top_right    = 2
	sb.corner_radius_bottom_left  = 2
	sb.corner_radius_bottom_right = 2
	sb.content_margin_left   = 18
	sb.content_margin_top    = 12
	sb.content_margin_right  = 18
	sb.content_margin_bottom = 12
	return sb

static func make_button_hover() -> StyleBoxFlat:
	var sb             := make_button_normal()
	sb.bg_color         = COLOR_SURFACE
	sb.border_color     = COLOR_GOLD
	sb.border_width_left = 3
	sb.content_margin_left = 15
	return sb

static func make_button_pressed() -> StyleBoxFlat:
	var sb     := make_button_hover()
	sb.bg_color = COLOR_CARD
	return sb

static func make_button_disabled() -> StyleBoxFlat:
	var sb := make_button_normal()
	return sb

# Gold-tinted accent button — primary actions (Create World, Confirm Orders).
static func make_button_accent_normal() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color               = COLOR_GOLD_DIM
	sb.border_color           = COLOR_GOLD
	sb.border_width_top       = 1
	sb.border_width_bottom    = 1
	sb.border_width_left      = 1
	sb.border_width_right     = 1
	sb.corner_radius_top_left     = 3
	sb.corner_radius_top_right    = 3
	sb.corner_radius_bottom_left  = 3
	sb.corner_radius_bottom_right = 3
	sb.content_margin_left   = 20
	sb.content_margin_top    = 13
	sb.content_margin_right  = 20
	sb.content_margin_bottom = 13
	return sb

static func make_button_accent_hover() -> StyleBoxFlat:
	var sb     := make_button_accent_normal()
	sb.bg_color = Color(0.780, 0.640, 0.380, 0.50)
	return sb

static func make_gold_separator_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.780, 0.640, 0.380, 0.38)
	return sb

# ── Apply helpers ──────────────────────────────────────────────────────────

static func style_label(label: Label, bold := false) -> void:
	_load_fonts()
	label.add_theme_font_override("font", _font_bold if bold else _font_regular)
	label.add_theme_color_override("font_color", COLOR_TEXT)

# Tiny all-caps section header (e.g. "ARMIES", "BUDGET REMAINING").
static func style_label_muted(label: Label) -> void:
	_load_fonts()
	label.add_theme_font_override("font", _font_medium)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", COLOR_MUTED)

# Large bold label rendered in gold — for big numbers and key stats.
static func style_label_gold(label: Label, font_size := 0) -> void:
	_load_fonts()
	label.add_theme_font_override("font", _font_bold)
	label.add_theme_color_override("font_color", COLOR_GOLD)
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)

# Splash title, e.g. "TURKEY WARS".
static func style_game_title(label: Label) -> void:
	_load_fonts()
	label.add_theme_font_override("font", _font_bold)
	label.add_theme_font_size_override("font_size", 46)
	label.add_theme_color_override("font_color", COLOR_GOLD)

static func style_rich_text(rich: RichTextLabel) -> void:
	_load_fonts()
	rich.add_theme_color_override("default_color", COLOR_TEXT)
	rich.add_theme_font_override("normal_font", _font_regular)
	rich.add_theme_font_override("bold_font", _font_bold)
	rich.add_theme_font_size_override("normal_font_size", 15)

static func style_line_edit(le: LineEdit) -> void:
	_load_fonts()
	le.add_theme_font_override("font", _font_regular)
	le.add_theme_color_override("font_color", COLOR_TEXT)
	le.add_theme_color_override("placeholder_color", COLOR_MUTED)
	le.add_theme_stylebox_override("normal", make_surface_stylebox())
	le.add_theme_stylebox_override("focus",  make_surface_stylebox())

static func style_panel_container(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", make_card_stylebox())

static func style_panel_container_accent(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", make_card_accent_stylebox())

static func style_tooltip(panel: PanelContainer) -> void:
	var sb            := make_card_stylebox()
	sb.bg_color        = Color(0.050, 0.065, 0.100, 0.97)
	sb.border_width_left = 3
	sb.border_color    = COLOR_GOLD
	panel.add_theme_stylebox_override("panel", sb)

# Standard button: invisible at rest, gold left-bar on hover.
static func style_button(btn: BaseButton) -> void:
	_load_fonts()
	btn.add_theme_font_override("font", _font_semibold)
	btn.add_theme_color_override("font_color",          COLOR_TEXT)
	btn.add_theme_color_override("font_hover_color",    COLOR_GOLD)
	btn.add_theme_color_override("font_pressed_color",  COLOR_GOLD)
	btn.add_theme_color_override("font_disabled_color", COLOR_MUTED)
	btn.add_theme_stylebox_override("normal",   make_button_normal())
	btn.add_theme_stylebox_override("hover",    make_button_hover())
	btn.add_theme_stylebox_override("pressed",  make_button_pressed())
	btn.add_theme_stylebox_override("disabled", make_button_disabled())

# Gold-fill accent button for primary actions.
static func style_button_accent(btn: BaseButton) -> void:
	_load_fonts()
	btn.add_theme_font_override("font", _font_bold)
	btn.add_theme_color_override("font_color",          COLOR_GOLD)
	btn.add_theme_color_override("font_hover_color",    COLOR_TEXT)
	btn.add_theme_color_override("font_pressed_color",  COLOR_TEXT)
	btn.add_theme_color_override("font_disabled_color", COLOR_MUTED)
	btn.add_theme_stylebox_override("normal",   make_button_accent_normal())
	btn.add_theme_stylebox_override("hover",    make_button_accent_hover())
	btn.add_theme_stylebox_override("pressed",  make_button_accent_hover())
	btn.add_theme_stylebox_override("disabled", make_button_disabled())

static func style_texture_button(btn: TextureButton) -> void:
	style_button(btn)
