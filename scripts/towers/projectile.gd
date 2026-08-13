class_name Projectile
extends Node2D

## A homing shot. It tracks its target's live position, but remembers the last
## known position too — so if the target dies mid-flight the shot still lands
## where it was headed instead of vanishing or crashing.

## Matches Tower.ART_SCALE: art is authored oversized and scaled back down.
const ART_SCALE: float = 0.25
## projectile_radius that ART_SCALE was tuned against. Bigger shots draw bigger.
const REFERENCE_RADIUS: float = 4.0

var target: Enemy = null
var damage: float = 10.0
var damage_type: String = "physical"
var speed: float = 520.0
var splash_radius: float = 0.0
var color: Color = Color.WHITE
var radius: float = 5.0
var texture: Texture2D = null

var _aim_point: Vector2 = Vector2.ZERO
var _lifetime: float = 0.0


func setup(enemy: Enemy, level: TowerLevel) -> void:
	target = enemy
	damage = level.damage
	damage_type = level.damage_type
	speed = maxf(level.projectile_speed, 40.0)
	splash_radius = level.splash_radius
	color = level.projectile_color
	radius = level.projectile_radius
	texture = level.projectile_texture
	_aim_point = enemy.global_position


func _physics_process(delta: float) -> void:
	# Fail-safe so a stray shot can never live forever.
	_lifetime += delta
	if _lifetime > 5.0:
		queue_free()
		return

	if target != null and is_instance_valid(target) and not target.is_dead():
		_aim_point = target.global_position

	var to_target: Vector2 = _aim_point - global_position
	var step: float = speed * delta

	if to_target.length() <= step:
		global_position = _aim_point
		_impact()
		return

	rotation = to_target.angle()
	global_position += to_target.normalized() * step
	queue_redraw()


func _impact() -> void:
	# Fires even on a whiffed shot, so impacts always read. Fx picks the effect
	# from the shot's own character: a blast ring at the true splash radius for
	# artillery, a violet ring for magic, sparks for everything else.
	Fx.impact(global_position, color, damage_type, splash_radius)

	if splash_radius > 0.0:
		var splash_sq: float = splash_radius * splash_radius
		for node in get_tree().get_nodes_in_group(Enemy.GROUP):
			var enemy := node as Enemy
			if enemy == null or enemy.is_dead():
				continue
			if global_position.distance_squared_to(enemy.global_position) <= splash_sq:
				enemy.take_damage(damage, damage_type)
	elif target != null and is_instance_valid(target) and not target.is_dead():
		target.take_damage(damage, damage_type)

	queue_free()


func _draw() -> void:
	# The node's rotation already points along the direction of travel, so art
	# authored pointing right lands the right way round for free.
	if texture != null:
		var bulk: float = maxf(radius, 1.0) / REFERENCE_RADIUS
		var size: Vector2 = Vector2(float(texture.get_width()), float(texture.get_height())) * ART_SCALE * bulk
		draw_texture_rect(texture, Rect2(-size * 0.5, size), false)
		return

	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2.ZERO, radius * 0.45, color.lightened(0.5))
