class_name Enemy
extends Area2D

## A single enemy walking the level route.
##
## The enemy is NOT parented to the Path2D. It keeps its own `progress` value
## and samples the curve every frame. That keeps it a flat top-level node,
## which makes targeting, pooling and death effects far simpler later on.

## Towers find their targets through this group.
const GROUP: StringName = &"enemies"

@export var data: EnemyData

var health: float = 1.0
## Distance travelled along the curve, in pixels. Used for "first" targeting.
var progress: float = 0.0
## Set below 1.0 by slow effects, above 1.0 by haste. Used from M6 onward.
var speed_multiplier: float = 1.0

var _curve: Curve2D
var _path_transform: Transform2D = Transform2D.IDENTITY
var _path_length: float = 0.0
var _is_dead: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar


## Called by Level.spawn_enemy() BEFORE the node enters the tree.
func setup(enemy_data: EnemyData, path: Path2D) -> void:
	data = enemy_data
	if path.curve != null:
		_curve = path.curve
		_path_transform = path.global_transform
		_path_length = _curve.get_baked_length()


func _ready() -> void:
	if data == null:
		push_error("Enemy spawned without EnemyData.")
		queue_free()
		return

	add_to_group(GROUP)

	health = data.max_health
	if data.texture != null:
		sprite.texture = data.texture
	sprite.scale = Vector2.ONE * data.sprite_scale

	health_bar.max_value = data.max_health
	health_bar.value = health
	health_bar.visible = false

	if _curve != null:
		_move_to(0.0)


func is_dead() -> bool:
	return _is_dead


func _physics_process(delta: float) -> void:
	if _is_dead or _curve == null or _path_length <= 0.0:
		return

	progress += data.speed * speed_multiplier * delta
	if progress >= _path_length:
		_leak()
		return

	_move_to(progress)


func _move_to(offset: float) -> void:
	var target := _path_transform * _curve.sample_baked(offset)
	var delta_pos := target - global_position
	if delta_pos.length_squared() > 0.01:
		sprite.flip_h = delta_pos.x < 0.0
	global_position = target


## damage_type is "physical" or "magic".
func take_damage(amount: float, damage_type: String = "physical") -> void:
	if _is_dead:
		return

	var resist: float = data.magic_resist if damage_type == "magic" else data.physical_resist
	health -= amount * (1.0 - resist)

	health_bar.visible = true
	health_bar.value = health

	if health <= 0.0:
		_die()


func _die() -> void:
	_is_dead = true
	# Leave the group immediately so towers stop targeting a corpse. queue_free
	# is deferred, so without this the node lingers for the rest of the frame.
	remove_from_group(GROUP)
	GameState.add_gold(data.bounty)
	Events.enemy_died.emit(self, data.bounty)
	queue_free()


func _leak() -> void:
	_is_dead = true
	remove_from_group(GROUP)
	GameState.lose_lives(data.leak_damage)
	Events.enemy_leaked.emit(self, data.leak_damage)
	queue_free()
