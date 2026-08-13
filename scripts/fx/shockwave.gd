class_name Shockwave
extends Node2D

## A single expanding ring, drawn rather than textured.
##
## Drawing it keeps it free of any art dependency, lets it tint to whatever
## fired it, and keeps it dependable on the Compatibility renderer the web
## export uses. Spawned only by Fx - nothing else should instantiate it.
##
## start_radius may be larger than end_radius, in which case the ring collapses
## inward. Fx uses that for the "snap into place" accent on builds and upgrades.

var _color: Color = Color.WHITE
var _start_radius: float = 8.0
var _end_radius: float = 74.0
var _thickness: float = 6.0
var _lifetime: float = 0.4

var _elapsed: float = 0.0
var _radius: float = 8.0
var _fade: float = 1.0


func play(color: Color, start_radius: float, end_radius: float, thickness: float, lifetime: float) -> void:
	_color = color
	_start_radius = start_radius
	_end_radius = end_radius
	_thickness = thickness
	_lifetime = maxf(lifetime, 0.05)
	_radius = start_radius
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	var t: float = clampf(_elapsed / _lifetime, 0.0, 1.0)

	# Ease out cubic: a hard punch outward that coasts to a stop, which is what
	# makes the ring feel like released pressure rather than a growing circle.
	var eased: float = 1.0 - pow(1.0 - t, 3.0)
	_radius = lerpf(_start_radius, _end_radius, eased)

	# Squared falloff so the ring is still bright while it is still moving fast.
	_fade = (1.0 - t) * (1.0 - t)

	queue_redraw()

	if t >= 1.0:
		queue_free()


func _draw() -> void:
	if _fade <= 0.002 or _radius <= 0.5:
		return

	# The ring thins as it fades, so it dissipates instead of just going
	# transparent at full width.
	var width: float = maxf(_thickness * _fade, 0.8)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 56, Color(_color.r, _color.g, _color.b, _fade * 0.85), width, true)

	# A white echo just inside gives the ring a hot leading edge.
	draw_arc(Vector2.ZERO, _radius * 0.84, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, _fade * 0.25), width * 0.5, true)
