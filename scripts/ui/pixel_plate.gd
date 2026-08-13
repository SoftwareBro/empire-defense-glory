class_name PixelPlate
extends PanelContainer

## A hard-edged panel plate.
##
## StyleBoxFlat only supports one border colour, so the two-tone bevel is
## painted here rather than faked with nested containers: light along the top and
## left, dark along the bottom and right. A Control draws before its children,
## so all of this lands behind the panel's contents.

## Border thickness. Integers only — this is pixel art.
const EDGE: float = 2.0
## Shadow offset, down and right to match the key light the sprites are lit by.
const SHADOW_OFFSET: float = 4.0

var fill: Color = PixelTheme.INK
var light: Color = PixelTheme.BEVEL_LIGHT
var dark: Color = PixelTheme.BEVEL_DARK


func _ready() -> void:
	# The container's own style is emptied so nothing paints over the bevel; it
	# survives only to reserve the inner padding.
	var padding := StyleBoxEmpty.new()
	padding.content_margin_left = 12.0
	padding.content_margin_right = 12.0
	padding.content_margin_top = 10.0
	padding.content_margin_bottom = 12.0
	add_theme_stylebox_override("panel", padding)

	# The plate is sized by its contents, so it has to repaint when they change.
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y

	draw_rect(Rect2(SHADOW_OFFSET, SHADOW_OFFSET, w, h), Color(0.0, 0.0, 0.0, 0.35), true)
	draw_rect(Rect2(0.0, 0.0, w, h), fill, true)

	draw_rect(Rect2(0.0, 0.0, w, EDGE), light, true)
	draw_rect(Rect2(0.0, 0.0, EDGE, h), light, true)
	draw_rect(Rect2(0.0, h - EDGE, w, EDGE), dark, true)
	draw_rect(Rect2(w - EDGE, 0.0, EDGE, h), dark, true)

	# Corner studs. The one flourish that reads as a bolted plate rather than a
	# rectangle with an outline.
	var stud := Vector2(EDGE * 2.0, EDGE * 2.0)
	var far_x: float = w - EDGE * 3.0
	var far_y: float = h - EDGE * 3.0
	draw_rect(Rect2(Vector2(EDGE, EDGE), stud), dark, true)
	draw_rect(Rect2(Vector2(far_x, EDGE), stud), dark, true)
	draw_rect(Rect2(Vector2(EDGE, far_y), stud), dark, true)
	draw_rect(Rect2(Vector2(far_x, far_y), stud), dark, true)
