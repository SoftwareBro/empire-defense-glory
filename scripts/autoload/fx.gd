extends Node

## Central effects spawner, registered as the `Fx` autoload.
##
## Anything that wants a spark, a number or a shake calls Fx directly, so no
## system needs to know where effects live in the scene tree or how they are
## built. Effects are parented to the node in the `fx_root` group so they are
## drawn above enemies and projectiles and die with the level.

const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/fx/DamageNumber.tscn")

const PHYSICAL_COLOR: Color = Color(1.0, 0.94, 0.82, 1.0)
const MAGIC_COLOR: Color = Color(0.79, 0.63, 1.0, 1.0)
const KILL_COLOR: Color = Color(1.0, 0.85, 0.35, 1.0)
const DEATH_COLOR: Color = Color(0.85, 0.35, 0.32, 1.0)

var _shake_strength: float = 0.0
var _shake_decay: float = 1.0


func _ready() -> void:
	# Keep settling the camera even while the win/lose overlay pauses the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	var cam := _camera()
	if cam == null:
		return

	if _shake_strength <= 0.0:
		if cam.offset != Vector2.ZERO:
			cam.offset = Vector2.ZERO
		return

	_shake_strength = maxf(0.0, _shake_strength - _shake_decay * delta)
	cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength


# --- Public API ---------------------------------------------------------------

## Floating combat text. `amount` is post-resist damage actually dealt.
func damage_number(world_position: Vector2, amount: float, damage_type: String = "physical", is_kill: bool = false) -> void:
	var root := _root()
	if root == null:
		return

	var number: DamageNumber = DAMAGE_NUMBER_SCENE.instantiate()
	root.add_child(number)
	number.global_position = world_position + Vector2(randf_range(-8.0, 8.0), -18.0)

	var tint: Color = KILL_COLOR
	if not is_kill:
		tint = MAGIC_COLOR if damage_type == "magic" else PHYSICAL_COLOR

	number.play(int(round(amount)), tint, is_kill)


## Small burst where a shot lands.
func hit_spark(world_position: Vector2, color: Color = Color.WHITE) -> void:
	_burst(world_position, color, 8, 150.0, 0.32, 3.0, 40.0)


## Bigger burst when something dies.
func death_burst(world_position: Vector2, color: Color = DEATH_COLOR) -> void:
	_burst(world_position, color, 22, 260.0, 0.55, 5.0, 260.0)


## Brief spit of light at the barrel tip.
func muzzle_flash(world_position: Vector2, color: Color) -> void:
	_burst(world_position, color, 4, 90.0, 0.16, 2.5, 0.0)


## Kicks the camera. Repeated calls take the strongest, they do not stack.
func shake(strength: float, duration: float = 0.3) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_decay = strength / maxf(duration, 0.05)


# --- Internals ----------------------------------------------------------------

func _camera() -> Camera2D:
	return get_tree().get_first_node_in_group(&"game_camera") as Camera2D


func _root() -> Node:
	var root := get_tree().get_first_node_in_group(&"fx_root")
	return root if root != null else get_tree().current_scene


## CPUParticles2D rather than GPUParticles2D: the web export runs on the
## Compatibility renderer, where CPU particles are the dependable option.
func _burst(world_position: Vector2, color: Color, amount: int, speed: float, lifetime: float, size: float, gravity: float) -> void:
	var root := _root()
	if root == null:
		return

	var particles := CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = lifetime
	particles.direction = Vector2.RIGHT
	particles.spread = 180.0
	particles.initial_velocity_min = speed * 0.35
	particles.initial_velocity_max = speed
	particles.gravity = Vector2(0.0, gravity)
	particles.scale_amount_min = size * 0.5
	particles.scale_amount_max = size
	particles.damping_min = speed * 0.5
	particles.damping_max = speed * 1.2

	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	particles.color_ramp = gradient

	root.add_child(particles)
	particles.global_position = world_position
	particles.emitting = true

	_free_after(particles, lifetime + 0.25)


func _free_after(node: Node, seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(node):
		node.queue_free()
