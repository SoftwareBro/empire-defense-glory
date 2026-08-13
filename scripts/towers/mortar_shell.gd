class_name MortarShell
extends Node2D

## A lobbed shell.
##
## Unlike Projectile this does not home. It is fired at a point on the ground
## and commits to it, which is what makes a siege tower feel like artillery
## rather than a slow rifle: shells land where they were aimed, and something
## quick can walk out from under one.
##
## The arc is faked in one dimension. The shell travels straight from muzzle to
## impact while being lifted off that line by a parabola, so height is purely a
## drawing concern and nothing else in the game has to learn about it.

## Turns per second while in flight.
const SPIN: float = 2.4
## Ground shadow radius at ground level. Tightens as the shell climbs.
const SHADOW_RADIUS: float = 7.0
## Vertical squash on ground-plane circles, so they lie flat instead of facing
## the camera.
const GROUND_SQUASH: float = 0.42
## Shell art is authored oversized like every other sprite in the game.
const ART_SCALE: float = 0.25
## The projectile_radius the shell art was drawn for. Others scale off this.
const REFERENCE_RADIUS: float = 9.0
## Damage kept at the very rim of the blast. A direct hit should be worth
## aiming for, but a clipped enemy should not shrug the shell off either.
const RIM_DAMAGE: float = 0.55

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _flight: float = 1.15
var _apex: float = 200.0
var _elapsed: float = 0.0

var _damage: float = 0.0
var _damage_type: String = "physical"
var _splash: float = 80.0
var _hits_flying: bool = false
var _color: Color = Color.WHITE
var _radius: float = 9.0
var _texture: Texture2D = null

var _height: float = 0.0
var _spin: float = 0.0
var _landed: bool = false


## Call this straight after add_child(). `to` is the impact point, already led
## ahead of the target by the tower.
func setup(from: Vector2, to: Vector2, level: TowerLevel, hits_flying: bool) -> void:
	_from = from
	_to = to
	_flight = maxf(level.flight_time, 0.15)
	_apex = maxf(level.arc_height, 0.0)
	_damage = level.damage
	_damage_type = level.damage_type
	_splash = level.splash_radius
	_hits_flying = hits_flying
	_color = level.projectile_color
	_radius = maxf(level.projectile_radius, 1.0)
	_texture = level.projectile_texture
	_spin = randf() * TAU
	global_position = from


func _physics_process(delta: float) -> void:
	if _landed:
		return

	_elapsed += delta
	var t: float = clampf(_elapsed / _flight, 0.0, 1.0)

	# 4t(1-t) peaks at exactly 1.0 when t is 0.5, so _apex is a real pixel height.
	_height = _apex * 4.0 * t * (1.0 - t)
	global_position = _from.lerp(_to, t) - Vector2(0.0, _height)
	_spin += SPIN * TAU * delta
	queue_redraw()

	if t >= 1.0:
		_land()


func _land() -> void:
	_landed = true

	var connected: int = 0
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead() or enemy.data == null:
			continue
		if enemy.data.is_flying and not _hits_flying:
			continue

		var distance: float = enemy.global_position.distance_to(_to)
		if distance > _splash:
			continue

		# Full damage at the centre, tapering toward the rim.
		var falloff: float = lerpf(1.0, RIM_DAMAGE, distance / maxf(_splash, 1.0))
		enemy.take_damage(_damage * falloff, _damage_type)
		connected += 1

	Fx.mortar_impact(_to, _color, _splash, connected > 0)
	queue_free()


func _draw() -> void:
	var t: float = clampf(_elapsed / _flight, 0.0, 1.0)
	var lift: float = 0.0 if _apex <= 0.0 else clampf(_height / _apex, 0.0, 1.0)

	# Impact reticle: telegraphs where the shell is going to land and tightens
	# as it falls, so the player can read the threat instead of guessing at it.
	if _splash > 0.0:
		var mark: Vector2 = _to - global_position
		var reticle: float = lerpf(_splash, _splash * 0.62, t)
		var mark_alpha: float = 0.10 + 0.28 * t
		draw_set_transform(mark, 0.0, Vector2(1.0, GROUND_SQUASH))
		draw_arc(Vector2.ZERO, reticle, 0.0, TAU, 40, Color(1.0, 0.55, 0.30, mark_alpha), 2.4)
		draw_arc(Vector2.ZERO, reticle * 0.35, 0.0, TAU, 24, Color(1.0, 0.70, 0.40, mark_alpha * 0.8), 1.6)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Shadow on the ground directly beneath the shell. Tightens and darkens on
	# the way down, which is the only cue that reads as altitude in 2D.
	draw_set_transform(Vector2(0.0, _height), 0.0, Vector2(1.0, GROUND_SQUASH))
	draw_circle(Vector2.ZERO, SHADOW_RADIUS * lerpf(1.0, 0.55, lift), Color(0.0, 0.0, 0.0, lerpf(0.35, 0.12, lift)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# The shell, swelling while it is high so it reads as nearer the camera.
	var swell: float = 1.0 + 0.32 * lift
	if _texture != null:
		var size: Vector2 = Vector2(float(_texture.get_width()), float(_texture.get_height())) * ART_SCALE * (_radius / REFERENCE_RADIUS) * swell
		draw_set_transform(Vector2.ZERO, _spin, Vector2.ONE)
		draw_texture_rect(_texture, Rect2(-size * 0.5, size), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_circle(Vector2.ZERO, _radius * swell, _color)
