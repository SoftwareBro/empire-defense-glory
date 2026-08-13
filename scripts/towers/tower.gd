class_name Tower
extends Node2D

## A built tower: picks a target in range, respects its fire rate, and launches
## projectiles. Every number it uses comes from the current TowerLevel, so an
## upgrade in M5 is just `level_index += 1`.

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/towers/Projectile.tscn")
const MUZZLE_OFFSET: float = 22.0

@export var data: TowerData

## Index into data.levels. Bumped by the upgrade panel in M5.
var level_index: int = 0
var show_range: bool = false

var _cooldown: float = 0.0
var _turret_angle: float = 0.0


func _ready() -> void:
	if data == null:
		push_error("Tower placed without TowerData.")
		queue_free()
		return
	queue_redraw()


func current_level() -> TowerLevel:
	if data == null or data.levels.is_empty():
		return null
	return data.levels[clampi(level_index, 0, data.levels.size() - 1)]


func get_attack_range() -> float:
	var lvl := current_level()
	return lvl.attack_range if lvl != null else 0.0


func set_range_visible(value: bool) -> void:
	if show_range == value:
		return
	show_range = value
	queue_redraw()


func _physics_process(delta: float) -> void:
	var lvl := current_level()
	if lvl == null:
		return

	if _cooldown > 0.0:
		_cooldown -= delta

	var target := _find_target(lvl)
	if target == null:
		return

	var new_angle: float = (target.global_position - global_position).angle()
	if not is_equal_approx(new_angle, _turret_angle):
		_turret_angle = new_angle
		queue_redraw()

	if _cooldown <= 0.0:
		_fire(target, lvl)
		_cooldown = 1.0 / maxf(lvl.fire_rate, 0.01)


## Scans the enemy group and picks one according to data.targeting_mode.
func _find_target(lvl: TowerLevel) -> Enemy:
	var range_sq: float = lvl.attack_range * lvl.attack_range
	var best: Enemy = null
	var best_score: float = -INF

	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead() or enemy.data == null:
			continue
		if enemy.data.is_flying and not data.can_hit_flying:
			continue

		var dist_sq: float = global_position.distance_squared_to(enemy.global_position)
		if dist_sq > range_sq:
			continue

		var score: float = _score_target(enemy, dist_sq)
		if score > best_score:
			best_score = score
			best = enemy

	return best


func _score_target(enemy: Enemy, dist_sq: float) -> float:
	match data.targeting_mode:
		"last":
			return -enemy.progress
		"closest":
			return -dist_sq
		"strongest":
			return enemy.health
		_:
			# "first" — furthest along the path, the genre default.
			return enemy.progress


func _fire(target: Enemy, lvl: TowerLevel) -> void:
	var root := _projectile_root()
	if root == null:
		return

	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	projectile.setup(target, lvl)
	root.add_child(projectile)
	projectile.global_position = global_position + Vector2.from_angle(_turret_angle) * MUZZLE_OFFSET


## Projectiles live under the level, not under the tower, so they keep flying
## straight if the tower is ever sold or upgraded mid-shot.
func _projectile_root() -> Node:
	var root := get_tree().get_first_node_in_group(&"projectile_root")
	return root if root != null else get_tree().current_scene


func _draw() -> void:
	if data == null:
		return

	if show_range:
		var r := get_attack_range()
		draw_circle(Vector2.ZERO, r, Color(1.0, 1.0, 1.0, 0.06))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.35), 2.0)

	# Placeholder body. Replaced by painted art in M8.
	draw_circle(Vector2.ZERO, 24.0, Color(0.07, 0.07, 0.09, 0.95))
	draw_circle(Vector2.ZERO, 19.0, data.accent_color)

	# Barrel, so you can see what it is aiming at.
	draw_line(Vector2.ZERO, Vector2.from_angle(_turret_angle) * 26.0, Color(0.07, 0.07, 0.09, 0.95), 8.0)
	draw_circle(Vector2.ZERO, 9.0, data.accent_color.lightened(0.3))
