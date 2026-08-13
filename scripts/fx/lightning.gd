class_name Lightning
extends Node2D

## A bolt slamming out of the sky onto one point on the map.
##
## Struck rather than fired: the channel is rebuilt several times across the
## node's life, so it re-strikes the same spot in a few hard flashes. A single
## static zigzag looks like a decal pasted on the map — the reflash is the
## whole reason this reads as a discharge.

## Vertices in the main channel between the sky and the ground.
const SEGMENTS: int = 14
## How far the channel may wander sideways at full altitude, in pixels.
const SPREAD: float = 30.0
## Separate re-strikes across the lifetime.
const FLASHES: int = 4
## How far above the strike point the bolt comes from. Comfortably off-screen.
const DROP_HEIGHT: float = 620.0
## Side branches that fork off the main channel.
const FORKS: int = 3

var _color: Color = Color(0.72, 0.82, 1.0, 1.0)
var _lifetime: float = 0.5
var _elapsed: float = 0.0
var _fade: float = 1.0
var _flash: float = 1.0
var _flash_index: int = -1
var _channel: PackedVector2Array = PackedVector2Array()
var _forks: Array = []


func _ready() -> void:
	set_process(false)


## Position the node on the strike point first, then call this.
func play(color: Color, lifetime: float = 0.5) -> void:
	_color = color
	_lifetime = maxf(lifetime, 0.1)
	_elapsed = 0.0
	_fade = 1.0
	_flash = 1.0
	_flash_index = -1
	_rebuild()
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	var t: float = clampf(_elapsed / _lifetime, 0.0, 1.0)
	_fade = 1.0 - t * t

	# Each flash is a fresh channel at full brightness that decays across its
	# own slice of the lifetime. Stacked, they read as one strike flickering.
	var index: int = mini(int(t * float(FLASHES)), FLASHES - 1)
	if index != _flash_index:
		_flash_index = index
		_rebuild()

	var within: float = t * float(FLASHES) - float(index)
	_flash = 1.0 - within * within

	queue_redraw()
	if t >= 1.0:
		queue_free()


## Builds one strike. The wander widens with altitude so the channel converges
## on the target rather than jittering around it.
func _rebuild() -> void:
	var pts := PackedVector2Array()
	pts.push_back(Vector2.ZERO)
	for i in range(1, SEGMENTS + 1):
		var f: float = float(i) / float(SEGMENTS)
		var wander: float = SPREAD * f
		pts.push_back(Vector2(randf_range(-wander, wander), -DROP_HEIGHT * f))
	_channel = pts

	_forks = []
	for _i in FORKS:
		var at: int = randi_range(2, SEGMENTS - 2)
		var tip: Vector2 = _channel[at]
		var fork := PackedVector2Array([tip])
		var dir := Vector2(randf_range(-0.9, 0.9), -0.5).normalized()
		var step: float = randf_range(26.0, 52.0)
		for _j in 3:
			tip += dir.rotated(randf_range(-0.5, 0.5)) * step
			fork.push_back(tip)
		_forks.push_back(fork)


func _draw() -> void:
	# A floor under the flash keeps a faint channel visible between re-strikes,
	# so the bolt looks like it is holding rather than blinking out entirely.
	var alpha: float = _fade * maxf(_flash, 0.12)
	if alpha <= 0.004 or _channel.size() < 2:
		return

	var haze := Color(_color.r, _color.g, _color.b, alpha * 0.14)
	var body := Color(_color.r, _color.g, _color.b, alpha * 0.5)
	var core := Color(1.0, 1.0, 1.0, alpha * 0.95)

	for i in _forks.size():
		var fork: PackedVector2Array = _forks[i]
		if fork.size() >= 2:
			draw_polyline(fork, body, 3.0, true)
			draw_polyline(fork, core, 1.2, true)

	draw_polyline(_channel, haze, 22.0, true)
	draw_polyline(_channel, body, 9.0, true)
	draw_polyline(_channel, core, 3.4, true)

	# Where it earths out.
	draw_circle(Vector2.ZERO, 34.0 * alpha, Color(_color.r, _color.g, _color.b, alpha * 0.3))
	draw_circle(Vector2.ZERO, 15.0 * alpha, Color(1.0, 1.0, 1.0, alpha * 0.7))
