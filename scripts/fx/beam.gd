class_name Beam
extends Node2D

## An instant-hit laser. The damage has already landed by the time this node
## exists, so the beam is pure feedback and free to be as loud as it likes.
##
## Drawn in four stacked passes — wide outer haze, mid body, hot white core and
## blooms at both ends — because one flat line reads as a scratch on the screen
## rather than a discharge. The sideways jitter is rebuilt every frame so the
## beam crackles instead of hanging there as a bar.

## Vertices along the beam. Plenty of crackle at the widths towers use.
const SEGMENTS: int = 16
## Peak sideways wander of the core at its midpoint, in pixels.
const JITTER: float = 2.6

var _target_local: Vector2 = Vector2.ZERO
var _color: Color = Color(0.79, 0.63, 1.0, 1.0)
var _width: float = 7.0
var _lifetime: float = 0.22
var _elapsed: float = 0.0
var _fade: float = 1.0
var _points: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	set_process(false)


## `from` and `to` are global positions. Call this straight after add_child().
func play(from: Vector2, to: Vector2, color: Color, width: float, lifetime: float) -> void:
	global_position = from
	_target_local = to - from
	_color = color
	_width = maxf(width, 1.0)
	_lifetime = maxf(lifetime, 0.05)
	_elapsed = 0.0
	_fade = 1.0
	_rebuild()
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	var t: float = clampf(_elapsed / _lifetime, 0.0, 1.0)
	# Holds near full brightness then falls off a cliff, which is how a
	# discharge actually dies. A linear fade looks like a dimmer switch.
	_fade = 1.0 - t * t * t
	_rebuild()
	queue_redraw()

	if t >= 1.0:
		queue_free()


## Lays out the crackle: sideways offsets tapering to nothing at both ends, so
## the beam stays welded to the muzzle and to the enemy it just hit.
func _rebuild() -> void:
	var length: float = _target_local.length()
	if length <= 0.001:
		_points = PackedVector2Array([Vector2.ZERO, _target_local])
		return

	var forward: Vector2 = _target_local / length
	var side: Vector2 = Vector2(-forward.y, forward.x)
	var wander: float = JITTER * _fade

	var pts := PackedVector2Array()
	for i in SEGMENTS + 1:
		var f: float = float(i) / float(SEGMENTS)
		# sin() is 0 at both ends and 1 in the middle: exactly the taper wanted.
		var taper: float = sin(f * PI)
		var offset: float = randf_range(-wander, wander) * taper
		pts.push_back(forward * (length * f) + side * offset)

	_points = pts


func _draw() -> void:
	if _fade <= 0.002 or _points.size() < 2:
		return

	var haze := Color(_color.r, _color.g, _color.b, _fade * 0.16)
	var body := Color(_color.r, _color.g, _color.b, _fade * 0.55)
	# The core runs hotter than the tint it was given, so it reads as white-hot
	# energy in the tower's colour rather than a thick coloured stripe.
	var core := Color(
		minf(1.0, _color.r + 0.45),
		minf(1.0, _color.g + 0.45),
		minf(1.0, _color.b + 0.45),
		_fade * 0.95
	)

	draw_polyline(_points, haze, _width * 2.8, true)
	draw_polyline(_points, body, _width * 1.4, true)
	draw_polyline(_points, core, maxf(_width * 0.42, 1.0), true)

	# Blooms at the muzzle and at the hit, so both ends look like they are under
	# load instead of simply being where the line stops.
	var bloom := Color(_color.r, _color.g, _color.b, _fade * 0.30)
	draw_circle(Vector2.ZERO, _width * 1.9 * _fade, bloom)
	draw_circle(Vector2.ZERO, _width * 0.85 * _fade, core)
	draw_circle(_target_local, _width * 2.4 * _fade, bloom)
	draw_circle(_target_local, _width * 1.05 * _fade, core)
