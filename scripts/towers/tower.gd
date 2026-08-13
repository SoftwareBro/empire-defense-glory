class_name Tower
extends Node2D

## A built tower: picks a target in range, respects its fire rate, and launches
## projectiles. Every number it uses comes from the current TowerLevel, so an
## upgrade is nothing more than pointing at a different TowerLevel.

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/towers/Projectile.tscn")
const MUZZLE_OFFSET: float = 22.0
## Fraction of everything invested that a sale returns.
const SELL_REFUND_RATIO: float = 0.7

@export var data: TowerData

## Index into data.levels. 0 = level 1.
var level_index: int = 0
## "" while on the normal ladder, then &"a" or &"b" once specialized.
var branch: StringName = &""
## Shown while hovering.
var show_range: bool = false
## Held on while the upgrade panel is open.
var range_pinned: bool = false

var _cooldown: float = 0.0
var _turret_angle: float = 0.0


func _ready() -> void:
	if data == null:
		push_error("Tower placed without TowerData.")
		queue_free()
		return
	queue_redraw()


# --- Level model -------------------------------------------------------------

func current_level() -> TowerLevel:
	if data == null:
		return null
	if branch == &"a" and data.branch_a != null:
		return data.branch_a
	if branch == &"b" and data.branch_b != null:
		return data.branch_b
	if data.levels.is_empty():
		return null
	return data.levels[clampi(level_index, 0, data.levels.size() - 1)]


func is_specialized() -> bool:
	return branch != &""


func is_max_level() -> bool:
	return data == null or level_index >= data.max_level_index()


func can_upgrade() -> bool:
	return not is_specialized() and not is_max_level()


## The specialization choice only appears at the top of the normal ladder.
func can_specialize() -> bool:
	if data == null or is_specialized() or not is_max_level():
		return false
	return data.branch_a != null or data.branch_b != null


func next_level() -> TowerLevel:
	if not can_upgrade():
		return null
	return data.levels[level_index + 1]


func upgrade_cost() -> int:
	var nxt := next_level()
	return nxt.upgrade_cost if nxt != null else 0


func level_label() -> String:
	if data == null:
		return ""
	if branch == &"a":
		return data.branch_a_name
	if branch == &"b":
		return data.branch_b_name
	return "Lv %d" % (level_index + 1)


func upgrade() -> void:
	if not can_upgrade():
		return
	level_index += 1
	Events.tower_upgraded.emit(self, level_index + 1)
	queue_redraw()


func specialize(which: StringName) -> void:
	if is_specialized():
		return
	branch = which
	Events.tower_upgraded.emit(self, data.levels.size() + 1)
	queue_redraw()


# --- Economy -----------------------------------------------------------------

## Build cost plus every upgrade actually paid for.
func total_invested() -> int:
	if data == null:
		return 0

	var total: int = data.build_cost
	var top: int = mini(level_index, data.levels.size() - 1)
	for i in range(1, top + 1):
		var lvl := data.levels[i] as TowerLevel
		if lvl != null:
			total += lvl.upgrade_cost

	if branch == &"a" and data.branch_a != null:
		total += data.branch_a.upgrade_cost
	elif branch == &"b" and data.branch_b != null:
		total += data.branch_b.upgrade_cost

	return total


func sell_value() -> int:
	return int(floor(float(total_invested()) * SELL_REFUND_RATIO))


# --- Combat ------------------------------------------------------------------

func get_attack_range() -> float:
	var lvl := current_level()
	return lvl.attack_range if lvl != null else 0.0


func set_range_visible(value: bool) -> void:
	if show_range == value:
		return
	show_range = value
	queue_redraw()


func set_range_pinned(value: bool) -> void:
	if range_pinned == value:
		return
	range_pinned = value
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

	var muzzle: Vector2 = global_position + Vector2.from_angle(_turret_angle) * MUZZLE_OFFSET

	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	projectile.setup(target, lvl)
	root.add_child(projectile)
	projectile.global_position = muzzle

	Fx.muzzle_flash(muzzle, lvl.projectile_color)


## Projectiles live under the level, not under the tower, so they keep flying
## straight if the tower is ever sold or upgraded mid-shot.
func _projectile_root() -> Node:
	var root := get_tree().get_first_node_in_group(&"projectile_root")
	return root if root != null else get_tree().current_scene


# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	if data == null:
		return

	var lvl := current_level()
	var s: float = lvl.sprite_scale if lvl != null else 1.0

	if show_range or range_pinned:
		var r := get_attack_range()
		draw_circle(Vector2.ZERO, r, Color(1.0, 1.0, 1.0, 0.06))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.35), 2.0)

	# Placeholder body. Replaced by painted art in M8.
	draw_circle(Vector2.ZERO, 24.0 * s, Color(0.07, 0.07, 0.09, 0.95))
	draw_circle(Vector2.ZERO, 19.0 * s, data.accent_color)

	# Barrel, so you can see what it is aiming at.
	draw_line(Vector2.ZERO, Vector2.from_angle(_turret_angle) * 26.0 * s, Color(0.07, 0.07, 0.09, 0.95), 8.0)
	draw_circle(Vector2.ZERO, 9.0 * s, data.accent_color.lightened(0.3))

	# Rank read-out: pips while levelling, a gold ring once specialized.
	if is_specialized():
		draw_arc(Vector2.ZERO, 29.0 * s, 0.0, TAU, 48, Color(1.0, 0.85, 0.35, 0.95), 3.0)
	else:
		var pips: int = level_index + 1
		var start_x: float = -float(pips - 1) * 5.0
		for i in pips:
			draw_circle(Vector2(start_x + float(i) * 10.0, -32.0 * s), 3.0, Color(1, 1, 1, 0.9))
