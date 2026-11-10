extends RefCounted

## Native Godot translation of Atlassian Design System light-mode roles.
## Palette references: Neutral0/100/200/300, Blue100/500/700/800/900,
## Red800, Orange800, Lime800. System font fallback avoids external assets.

const COLOR_TEXT := Color("#172B4D")
const COLOR_TEXT_SUBTLE := Color("#44546F")
const COLOR_TEXT_SUBTLEST := Color("#626F86")
const COLOR_TEXT_DISABLED := Color("#8993A4")
const COLOR_SURFACE := Color("#FFFFFF")
const COLOR_CANVAS := Color("#F7F8F9")
const COLOR_NEUTRAL := Color("#F1F2F4")
const COLOR_NEUTRAL_HOVER := Color("#DFE1E6")
const COLOR_BORDER := Color("#DFE1E6")
const COLOR_BRAND := Color("#0C66E4")
const COLOR_BRAND_HOVER := Color("#0055CC")
const COLOR_BRAND_PRESSED := Color("#09326C")
const COLOR_BRAND_SUBTLE := Color("#E9F2FF")
const COLOR_BRAND_SUBTLE_HOVER := Color("#DEEBFF")
const COLOR_BRAND_SUBTLE_PRESSED := Color("#B3D4FF")
const COLOR_FOCUS := Color("#388BFF")
const COLOR_CHART_BRAND := Color("#1D7AFC")
const COLOR_SUCCESS := Color("#216E4A")
const COLOR_SUCCESS_BG := Color("#D3F1A7")
const COLOR_WARNING := Color("#974F0C")
const COLOR_WARNING_BG := Color("#FFF3C1")
const COLOR_DANGER := Color("#AE2E24")
const COLOR_DANGER_BG := Color("#FFECEB")
const COLOR_INFORMATION := Color("#0055CC")
const COLOR_INFORMATION_BG := Color("#E9F2FF")

const SPACE_050 := 4
const SPACE_100 := 8
const SPACE_150 := 12
const SPACE_200 := 16
const SPACE_300 := 24
const SPACE_400 := 32

const FONT_BODY := 16
const FONT_BODY_SMALL := 14
const FONT_EYEBROW := 12
const FONT_TITLE := 28
const FONT_SECTION := 20
const FONT_METRIC := 24

const TYPE_PRIMARY := "ADSPrimaryButton"
const TYPE_QUIET := "ADSQuietButton"
const TYPE_CHOICE := "ADSChoiceButton"
const TYPE_SELECTED_CHOICE := "ADSSelectedChoiceButton"
const TYPE_PAD_BUTTON := "ADSPadButton"
const TYPE_PAD_BUTTON_ACTIVE := "ADSPadButtonActive"
const TYPE_FIELD_SURFACE := "FieldSurfacePanel"
const TYPE_RESUME_PANEL := "WaitingResumePanel"
const THEME_PATH := "res://game/ui/theme/default_theme.tres"


static func get_shared_theme() -> Theme:
	if ResourceLoader.exists(THEME_PATH):
		var loaded := ResourceLoader.load(THEME_PATH, "Theme", ResourceLoader.CACHE_MODE_IGNORE)
		if loaded is Theme:
			return loaded as Theme
	return _build_theme()


static func field_surface_style() -> StyleBoxFlat:
	return _box(COLOR_SURFACE, COLOR_BORDER, 1, 4, 0, 0)


static func resume_panel_style() -> StyleBoxFlat:
	return _box(COLOR_SURFACE, COLOR_BRAND, 2, 8, 24, 20)


static func _build_theme() -> Theme:
	var result := Theme.new()
	var regular_font := _system_font(400)
	var heading_font := _system_font(600)
	result.default_font = regular_font
	result.default_font_size = FONT_BODY

	result.set_type_variation("PageTitle", "Label")
	result.set_type_variation("SectionTitle", "Label")
	result.set_type_variation("BodyText", "Label")
	result.set_type_variation("EyebrowLabel", "Label")
	result.set_type_variation("SubtleLabel", "Label")
	result.set_type_variation("SubtlestLabel", "Label")
	result.set_type_variation("MetricLabel", "Label")
	result.set_type_variation("InfoStateLabel", "Label")
	result.set_type_variation("WarningStateLabel", "Label")
	result.set_type_variation("SuccessStateLabel", "Label")
	result.set_type_variation("DangerStateLabel", "Label")
	result.set_type_variation("SuccessMessage", "Label")
	result.set_type_variation("DangerMessage", "Label")
	result.set_type_variation("SignalValueLabel", "Label")
	_set_label(result, "PageTitle", heading_font, FONT_TITLE, COLOR_TEXT)
	_set_label(result, "SectionTitle", heading_font, FONT_SECTION, COLOR_TEXT)
	_set_label(result, "BodyText", regular_font, FONT_BODY, COLOR_TEXT)
	_set_label(result, "EyebrowLabel", heading_font, FONT_EYEBROW, COLOR_BRAND)
	_set_label(result, "SubtleLabel", regular_font, FONT_BODY_SMALL, COLOR_TEXT_SUBTLE)
	_set_label(result, "SubtlestLabel", regular_font, FONT_BODY_SMALL, COLOR_TEXT_SUBTLEST)
	_set_label(result, "MetricLabel", heading_font, FONT_METRIC, COLOR_TEXT)
	_set_label(result, "InfoStateLabel", heading_font, FONT_METRIC, COLOR_INFORMATION)
	_set_label(result, "WarningStateLabel", heading_font, FONT_METRIC, COLOR_WARNING)
	_set_label(result, "SuccessStateLabel", heading_font, FONT_METRIC, COLOR_SUCCESS)
	_set_label(result, "DangerStateLabel", heading_font, FONT_METRIC, COLOR_DANGER)
	_set_label(result, "SuccessMessage", regular_font, FONT_BODY_SMALL, COLOR_SUCCESS)
	_set_label(result, "DangerMessage", regular_font, FONT_BODY_SMALL, COLOR_DANGER)
	_set_label(result, "SignalValueLabel", heading_font, FONT_SECTION, COLOR_BRAND)
	result.set_color("font_color", "Label", COLOR_TEXT)
	result.set_font_size("font_size", "Label", FONT_BODY)

	result.set_type_variation(TYPE_PRIMARY, "Button")
	result.set_type_variation(TYPE_QUIET, "Button")
	result.set_type_variation(TYPE_CHOICE, "Button")
	result.set_type_variation(TYPE_SELECTED_CHOICE, "Button")
	result.set_type_variation(TYPE_PAD_BUTTON, "Button")
	result.set_type_variation(TYPE_PAD_BUTTON_ACTIVE, "Button")
	_set_button(result, "Button", COLOR_SURFACE, COLOR_NEUTRAL, COLOR_NEUTRAL_HOVER, COLOR_NEUTRAL, COLOR_TEXT, COLOR_BORDER)
	_set_button(result, TYPE_PRIMARY, COLOR_BRAND, COLOR_BRAND_HOVER, COLOR_BRAND_PRESSED, COLOR_NEUTRAL, COLOR_SURFACE, COLOR_BRAND)
	_set_button(result, TYPE_QUIET, Color(0, 0, 0, 0), COLOR_NEUTRAL, COLOR_NEUTRAL_HOVER, COLOR_NEUTRAL, COLOR_TEXT, Color(0, 0, 0, 0))
	_set_button(result, TYPE_CHOICE, COLOR_NEUTRAL, COLOR_NEUTRAL_HOVER, COLOR_NEUTRAL_HOVER, COLOR_NEUTRAL, COLOR_TEXT, COLOR_BORDER)
	_set_button(result, TYPE_SELECTED_CHOICE, COLOR_BRAND_SUBTLE, COLOR_BRAND_SUBTLE_HOVER, COLOR_BRAND_SUBTLE_PRESSED, COLOR_NEUTRAL, COLOR_BRAND, COLOR_BRAND)
	_set_pad_button(result, TYPE_PAD_BUTTON, COLOR_NEUTRAL, COLOR_NEUTRAL_HOVER, COLOR_BRAND_SUBTLE, COLOR_TEXT, COLOR_BORDER, 1, 6, 12, 8)
	_set_pad_button(result, TYPE_PAD_BUTTON_ACTIVE, COLOR_BRAND_SUBTLE_HOVER, COLOR_BRAND_SUBTLE_PRESSED, COLOR_BRAND_SUBTLE_PRESSED, COLOR_BRAND_PRESSED, COLOR_BRAND, 3, 6, 12, 8)
	result.set_font("font", TYPE_PAD_BUTTON, heading_font)
	result.set_font("font", TYPE_PAD_BUTTON_ACTIVE, heading_font)
	result.set_font_size("font_size", TYPE_PAD_BUTTON, FONT_BODY_SMALL)
	result.set_font_size("font_size", TYPE_PAD_BUTTON_ACTIVE, FONT_BODY_SMALL)
	result.set_type_variation(TYPE_FIELD_SURFACE, "PanelContainer")
	result.set_stylebox("panel", TYPE_FIELD_SURFACE, field_surface_style())
	result.set_type_variation(TYPE_RESUME_PANEL, "PanelContainer")
	result.set_stylebox("panel", TYPE_RESUME_PANEL, resume_panel_style())
	result.set_stylebox("panel", "PanelContainer", field_surface_style())
	result.set_font_size("font_size", "Button", FONT_BODY)
	result.set_constant("h_separation", "Button", SPACE_100)
	result.set_constant("separation", "VBoxContainer", SPACE_100)
	result.set_constant("separation", "HBoxContainer", SPACE_100)
	result.set_constant("separation", "GridContainer", SPACE_200)
	result.set_color("font_color", "OptionButton", COLOR_TEXT)
	result.set_color("font_hover_color", "OptionButton", COLOR_TEXT)
	result.set_color("font_pressed_color", "OptionButton", COLOR_TEXT)
	result.set_color("font_disabled_color", "OptionButton", COLOR_TEXT_DISABLED)
	result.set_stylebox("normal", "OptionButton", _box(COLOR_SURFACE, COLOR_BORDER, 1, 4, 12, 10))
	result.set_stylebox("hover", "OptionButton", _box(COLOR_CANVAS, COLOR_FOCUS, 1, 4, 12, 10))
	result.set_stylebox("pressed", "OptionButton", _box(COLOR_BRAND_SUBTLE, COLOR_BRAND, 1, 4, 12, 10))
	result.set_stylebox("disabled", "OptionButton", _box(COLOR_NEUTRAL, COLOR_BORDER, 1, 4, 12, 10))
	result.set_stylebox("focus", "OptionButton", _focus_box())
	result.set_stylebox("slider", "HSlider", _box(COLOR_NEUTRAL_HOVER, COLOR_BORDER, 1, 4, 0, 4))
	result.set_stylebox("grabber_area", "HSlider", _box(COLOR_BRAND, Color(0, 0, 0, 0), 0, 4, 0, 4))
	result.set_stylebox("grabber_area_highlight", "HSlider", _box(COLOR_BRAND_HOVER, Color(0, 0, 0, 0), 0, 4, 0, 4))
	result.set_stylebox("focus", "HSlider", _focus_box())
	return result


static func _system_font(weight: int) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Roboto", "Noto Sans", "Arial"])
	font.font_weight = weight
	return font


static func _set_label(theme: Theme, type_name: String, font: Font, size: int, color: Color) -> void:
	theme.set_font("font", type_name, font)
	theme.set_font_size("font_size", type_name, size)
	theme.set_color("font_color", type_name, color)


static func _set_button(theme: Theme, type_name: String, normal: Color, hover: Color, pressed: Color, disabled: Color, text_color: Color, border: Color) -> void:
	theme.set_color("font_color", type_name, text_color)
	theme.set_color("font_hover_color", type_name, text_color)
	theme.set_color("font_pressed_color", type_name, text_color)
	theme.set_color("font_disabled_color", type_name, COLOR_TEXT_DISABLED)
	theme.set_font_size("font_size", type_name, FONT_BODY)
	theme.set_stylebox("normal", type_name, _box(normal, border, 1, 4, 16, 12))
	theme.set_stylebox("hover", type_name, _box(hover, border, 1, 4, 16, 12))
	theme.set_stylebox("pressed", type_name, _box(pressed, border, 1, 4, 16, 12))
	theme.set_stylebox("disabled", type_name, _box(disabled, COLOR_BORDER, 1, 4, 16, 12))
	theme.set_stylebox("focus", type_name, _focus_box())


static func _set_pad_button(theme: Theme, type_name: String, normal: Color, hover: Color, pressed: Color, text_color: Color, border: Color, border_width: int, radius: int, horizontal: int, vertical: int) -> void:
	theme.set_color("font_color", type_name, text_color)
	theme.set_color("font_hover_color", type_name, text_color)
	theme.set_color("font_pressed_color", type_name, text_color)
	theme.set_color("font_disabled_color", type_name, COLOR_TEXT_DISABLED)
	theme.set_stylebox("normal", type_name, _box(normal, border, border_width, radius, horizontal, vertical))
	theme.set_stylebox("hover", type_name, _box(hover, border, border_width, radius, horizontal, vertical))
	theme.set_stylebox("pressed", type_name, _box(pressed, border, border_width, radius, horizontal, vertical))
	theme.set_stylebox("disabled", type_name, _box(COLOR_NEUTRAL, COLOR_BORDER, 1, radius, horizontal, vertical))
	theme.set_stylebox("focus", type_name, _focus_box())


static func _box(fill: Color, border: Color, border_width: int, radius: int, horizontal: int, vertical: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style


static func _focus_box() -> StyleBoxFlat:
	var style := _box(Color(0, 0, 0, 0), COLOR_FOCUS, 2, 4, 14, 10)
	style.draw_center = false
	return style
