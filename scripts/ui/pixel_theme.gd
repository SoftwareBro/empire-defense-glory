class_name PixelTheme
extends RefCounted

## Shared look for the in-game menus.
##
## Everything here is deliberately hard-edged: zero corner radius, integer
## border widths and no antialiasing. Colours come in light/dark pairs so a flat
## rectangle can be bevelled — light down the top and left, dark down the bottom
## and right — which is the whole trick behind pixel-art UI. It fakes a raised
## plate without a single gradient.
##
## Static functions rather than a Theme resource, because a .tres theme would
## have to be hand-edited in the editor every time these colours moved.

## Panel body. Deep and slightly blue, so parchment text sits comfortably on it.
const INK: Color = Color(0.086, 0.078, 0.129, 0.96)
## Raised edge and recessed edge.
const BEVEL_LIGHT: Color = Color(0.451, 0.427, 0.588, 1.0)
const BEVEL_DARK: Color = Color(0.043, 0.039, 0.071, 1.0)
## Empty bar cells and other recessed fills.
const SOCKET: Color = Color(0.176, 0.169, 0.235, 1.0)

## Headers, costs and anything to do with rank.
const GOLD: Color = Color(1.0, 0.851, 0.380, 1.0)
## Body text.
const PARCHMENT: Color = Color(0.898, 0.878, 0.815, 1.0)
## Labels and hints that should recede.
const MUTED: Color = Color(0.588, 0.573, 0.651, 1.0)
## What an upgrade would add.
const GAIN: Color = Color(0.475, 0.855, 0.494, 1.0)
## Refunds and warnings.
const LOSS: Color = Color(0.902, 0.408, 0.376, 1.0)

const BUTTON_FILL: Color = Color(0.184, 0.176, 0.259, 1.0)
const BUTTON_FILL_HOVER: Color = Color(0.263, 0.251, 0.361, 1.0)
const BUTTON_FILL_PRESSED: Color = Color(0.129, 0.122, 0.188, 1.0)
const BUTTON_FILL_OFF: Color = Color(0.114, 0.110, 0.153, 1.0)


## A flat box with a hard single-colour border. `sink` pushes the label down a
## pixel, which is what makes a pressed button feel physically pressed.
static func box(fill: Color, border: Color, sink: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 6.0 + float(sink)
	sb.content_margin_bottom = 6.0 - float(sink)
	return sb


## Dresses a Button in the pixel style. The focus ring is removed outright — it
## is the single most placeholder-looking thing in default Godot UI.
static func apply_button(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", box(BUTTON_FILL, BEVEL_LIGHT))
	button.add_theme_stylebox_override("hover", box(BUTTON_FILL_HOVER, accent))
	button.add_theme_stylebox_override("pressed", box(BUTTON_FILL_PRESSED, accent, 1))
	button.add_theme_stylebox_override("disabled", box(BUTTON_FILL_OFF, BEVEL_DARK))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	button.add_theme_color_override("font_color", PARCHMENT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_font_size_override("font_size", 13)


static func make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## A 2px rule. A ColorRect rather than HSeparator, so it cannot pick up theme
## styling from somewhere else and stop being a clean pixel line.
static func divider() -> ColorRect:
	var line := ColorRect.new()
	line.color = BEVEL_DARK
	line.custom_minimum_size = Vector2(0.0, 2.0)
	return line
