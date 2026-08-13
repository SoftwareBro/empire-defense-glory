class_name AbilityButton
extends Area2D

## The clickable rune that floats above a tower with a manually fired spell.
##
## Deliberately knows nothing about Tower. The owner pushes charge state in with
## set_state() and listens for `activated`, which keeps this reusable for any
## future clicked ability and avoids a circular dependency between a tower and
## its own interface.

signal activated

## Hit radius in pixels. Generous on purpose — this gets clicked under pressure.
const RADIUS: float = 17.0
## Radians per second the rim sparks travel once charged.
const SPIN: float = 1.6
## Pips around the rim. Discrete steps rather than a smooth sweep.
const PIPS: int = 10

var charge: float = 0.0
var is_charged: bool = false

var _pulse: float = 0.0
var _reject_t: float = 0.0
var _hovered: bool = false


func _ready() -> void:
	# Above the build plot underneath, so the rune wins the click.
	z_index = 30
	input_pickable = true

	# Built in code rather than in a .tscn: this node is spawned by the tower, so
	# a scene file would be one more thing to keep in sync for no gain.
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _process(delta: float) -> void:
	_pulse += delta
	_reject_t = maxf(0.0, _reject_t - delta)
	queue_redraw()


## Called by the owner every frame. `value` is 0..1.
func set_state(value: float, charged: bool) -> void:
	charge = clampf(value, 0.0, 1.0)
	is_charged = charged


## Charged and clicked, but there was nothing worth spending it on. Shakes the
## rune so a refused click reads as "not that" instead of as a dead button.
func reject() -> void:
	_reject_t = 0.35


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	# Swallowed whether or not it fires, so clicking the rune never falls through
	# to Level and closes whatever menu is open behind it.
	get_viewport().set_input_as_handled()
	if is_charged:
		activated.emit()


func _on_mouse_entered() -> void:
	_hovered = true


func _on_mouse_exited() -> void:
	_hovered = false


func _draw() -> void:
	var shove: Vector2 = Vector2.ZERO
	if _reject_t > 0.0:
		shove = Vector2(sin(_reject_t * 60.0) * _reject_t * 14.0, 0.0)

	draw_set_transform(shove, 0.0, Vector2.ONE)
	if is_charged:
		_draw_charged()
	else:
		_draw_charging()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Filling up: a dark socket ringed with pips that light one at a time.
func _draw_charging() -> void:
	_draw_frame(Color(0.10, 0.09, 0.14, 0.88), Color(0.35, 0.33, 0.45, 1.0))

	var lit: int = int(floor(charge * float(PIPS)))
	for i in PIPS:
		var angle: float = -PI / 2.0 + float(i) * TAU / float(PIPS)
		var at: Vector2 = Vector2.from_angle(angle) * (RADIUS - 4.0)
		if i < lit:
			_draw_pixel(at, 2.0, Color(0.72, 0.82, 1.0, 1.0))
		else:
			_draw_pixel(at, 1.5, Color(0.28, 0.27, 0.36, 1.0))

	# A core that swells with the charge, so progress is legible even when the
	# tower is small on screen and the pips blur together.
	_draw_pixel(Vector2.ZERO, 1.5 + 3.5 * charge, Color(0.45, 0.55, 0.85, 0.55 + 0.35 * charge))


## Ready to spend: haloed, pulsing, with a bolt glyph and travelling sparks.
func _draw_charged() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_pulse * 5.5)
	var glow: float = 0.35 + 0.35 * pulse

	draw_circle(Vector2.ZERO, RADIUS * (1.35 + 0.16 * pulse), Color(0.72, 0.82, 1.0, 0.12 + 0.10 * pulse))

	var rim: Color = Color(1.0, 0.93, 0.62, 1.0) if _hovered else Color(0.72, 0.82, 1.0, 1.0)
	_draw_frame(Color(0.16, 0.20, 0.34, 0.95), rim)

	var bolt := PackedVector2Array([
		Vector2(2.0, -10.0),
		Vector2(-5.0, 1.0),
		Vector2(-0.5, 1.0),
		Vector2(-2.5, 10.0),
		Vector2(5.0, -2.0),
		Vector2(0.5, -2.0),
	])
	draw_colored_polygon(bolt, Color(1.0, 1.0, 1.0, 0.75 + 0.25 * pulse))
	_draw_outline(bolt, Color(0.30, 0.42, 0.72, 0.9), 1.4)

	for i in 4:
		var angle: float = _pulse * SPIN + float(i) * TAU / 4.0
		_draw_pixel(Vector2.from_angle(angle) * (RADIUS + 3.0), 1.5, Color(1.0, 1.0, 1.0, glow))


## An octagonal plate with a hard edge. Straight cuts, no curves and no
## antialiasing, which is the pixel-art vocabulary the rest of the UI uses.
func _draw_frame(fill: Color, edge: Color) -> void:
	var r: float = RADIUS
	var c: float = r * 0.42
	var plate := PackedVector2Array([
		Vector2(-r + c, -r),
		Vector2(r - c, -r),
		Vector2(r, -r + c),
		Vector2(r, r - c),
		Vector2(r - c, r),
		Vector2(-r + c, r),
		Vector2(-r, r - c),
		Vector2(-r, -r + c),
	])
	draw_colored_polygon(plate, fill)
	_draw_outline(plate, edge, 2.0)


## draw_polyline does not close a loop, so the first point is repeated.
func _draw_outline(points: PackedVector2Array, color: Color, width: float) -> void:
	if points.size() < 2:
		return
	var closed := PackedVector2Array(points)
	closed.push_back(points[0])
	draw_polyline(closed, color, width, false)


## A square "pixel" centred on a point. Rectangles rather than circles keep the
## whole rune free of soft edges.
func _draw_pixel(at: Vector2, half: float, color: Color) -> void:
	draw_rect(Rect2(at - Vector2(half, half), Vector2(half * 2.0, half * 2.0)), color, true)
