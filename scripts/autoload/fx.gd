extends Node

## Central effects spawner, registered as the `Fx` autoload.
##
## Anything that wants a spark, a number or a shake calls Fx directly, so no
## system needs to know where effects live in the scene tree or how they are
## built. Effects are parented to the node in the `fx_root` group so they are
## drawn above enemies and projectiles and die with the level.

const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/fx/DamageNumber.tscn")
const SHOCKWAVE_SCENE: PackedScene = preload("res://scenes/fx/Shockwave.tscn")
const BEAM_SCENE: PackedScene = preload("res://scenes/fx/Beam.tscn")
const LIGHTNING_SCENE: PackedScene = preload("res://scenes/fx/Lightning.tscn")

const PHYSICAL_COLOR: Color = Color(1.0, 0.94, 0.82, 1.0)
const MAGIC_COLOR: Color = Color(0.79, 0.63, 1.0, 1.0)
const KILL_COLOR: Color = Color(1.0, 0.85, 0.35, 1.0)
const DEATH_COLOR: Color = Color(0.85, 0.35, 0.32, 1.0)

## Dust kicked up when a tower slams onto its plot.
const BUILD_DUST_COLOR: Color = Color(0.85, 0.78, 0.62, 1.0)
## Rank-up gold, shared by the rings, the embers and the banner.
const UPGRADE_GOLD: Color = Color(1.0, 0.85, 0.38, 1.0)
## Cordite grey for splash impacts.
const SMOKE_COLOR: Color = Color(0.62, 0.59, 0.56, 1.0)
## Storm blue-white for the spell tower's discharge.
const SPELL_COLOR: Color = Color(0.72, 0.82, 1.0, 1.0)

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


## Floating text with no damage semantics, for callouts like a new tower rank.
func banner(world_position: Vector2, text: String, tint: Color, font_size: int = 24) -> void:
	var root := _root()
	if root == null:
		return

	var number: DamageNumber = DAMAGE_NUMBER_SCENE.instantiate()
	root.add_child(number)
	number.global_position = world_position
	number.play_text(text, tint, font_size, 52.0, 0.9)


## A single expanding ring. Pass start_radius > end_radius to collapse inward
## instead, which reads as something snapping into place.
func shockwave(world_position: Vector2, color: Color, start_radius: float = 8.0, end_radius: float = 74.0, thickness: float = 6.0, lifetime: float = 0.4) -> void:
	var root := _root()
	if root == null:
		return

	var wave: Shockwave = SHOCKWAVE_SCENE.instantiate()
	root.add_child(wave)
	wave.global_position = world_position
	wave.play(color, start_radius, end_radius, thickness, lifetime)


## Small burst where a shot lands.
func hit_spark(world_position: Vector2, color: Color = Color.WHITE) -> void:
	_burst(world_position, color, 8, 150.0, 0.32, 3.0, 40.0)


## Where a shot lands, with the weapon's character. Splash weapons get a ring
## at their true blast radius so the player can read the area they just covered
## instead of inferring it from scattered damage numbers.
func impact(world_position: Vector2, color: Color, damage_type: String = "physical", splash_radius: float = 0.0) -> void:
	if splash_radius > 0.0:
		shockwave(world_position, SMOKE_COLOR, splash_radius * 0.25, splash_radius, 7.0, 0.34)
		# Negative gravity on the smoke so it billows up out of the crater.
		_burst(world_position, SMOKE_COLOR, 18, splash_radius * 3.4, 0.5, 6.0, -30.0)
		_burst(world_position, Color(1.0, 0.72, 0.32, 1.0), 12, splash_radius * 4.2, 0.3, 4.0, 60.0)
		shake(3.2, 0.2)
		return

	if damage_type == "magic":
		shockwave(world_position, MAGIC_COLOR, 3.0, 26.0, 3.5, 0.26)
		_burst(world_position, color, 10, 170.0, 0.34, 3.0, -20.0)
		return

	hit_spark(world_position, color)


## Bigger burst when something dies.
func death_burst(world_position: Vector2, color: Color = DEATH_COLOR) -> void:
	_burst(world_position, color, 22, 260.0, 0.55, 5.0, 260.0)


## Brief spit of light at the barrel tip.
func muzzle_flash(world_position: Vector2, color: Color) -> void:
	_burst(world_position, color, 4, 90.0, 0.16, 2.5, 0.0)


## An instant-hit laser between two points. The damage has already been applied
## by the caller; this is the visual record of it, plus load at both ends.
func beam(from: Vector2, to: Vector2, color: Color, width: float = 7.0, lifetime: float = 0.22) -> void:
	var root := _root()
	if root == null:
		return

	var laser: Beam = BEAM_SCENE.instantiate()
	root.add_child(laser)
	laser.play(from, to, color, width, lifetime)

	# Negative gravity so the spent energy drifts upward off both ends.
	_burst(from, color, 8, 130.0, 0.26, 3.0, -40.0)
	_burst(to, color, 14, 210.0, 0.34, 3.5, -30.0)
	shockwave(to, color, 4.0, 30.0, 4.0, 0.26)


## The instant a charging core reaches full: a ring collapsing onto the muzzle.
func charge_snap(world_position: Vector2, color: Color) -> void:
	shockwave(world_position, color, 34.0, 6.0, 3.5, 0.18)


## A mortar throwing its shell: cordite out of the muzzle along the line of
## fire, and a solid thump. Artillery should be felt before it is seen.
func mortar_launch(world_position: Vector2, angle: float) -> void:
	var direction := Vector2.from_angle(angle)
	_burst(world_position, SMOKE_COLOR, 16, 210.0, 0.5, 5.5, -40.0, direction, 42.0)
	_burst(world_position, Color(1.0, 0.78, 0.36, 1.0), 10, 260.0, 0.24, 3.5, 20.0, direction, 30.0)
	shockwave(world_position, SMOKE_COLOR, 4.0, 34.0, 5.0, 0.26)
	shake(4.0, 0.24)


## A shell coming down: dirt ring at the true blast radius, a fireball inside
## it, and debris thrown up out of the crater. A shell that hit nothing still
## throws dirt, but it does not get to kick the camera as hard.
func mortar_impact(world_position: Vector2, color: Color, splash_radius: float, connected: bool = true) -> void:
	var r: float = maxf(splash_radius, 24.0)
	shockwave(world_position, SMOKE_COLOR, r * 0.18, r, 8.0, 0.38)
	shockwave(world_position, Color(1.0, 0.72, 0.32, 1.0), r * 0.10, r * 0.55, 6.0, 0.24)
	_burst(world_position, SMOKE_COLOR, 24, r * 3.6, 0.62, 7.0, -50.0)
	_burst(world_position, Color(1.0, 0.70, 0.30, 1.0), 16, r * 4.4, 0.32, 4.5, 90.0)
	_burst(world_position, color, 10, r * 2.4, 0.5, 3.5, 300.0)
	shake(6.0 if connected else 3.0, 0.3)


## A spell tower finishing its recharge. Deliberately restrained — this is a
## prompt telling the player something is available, not an event in itself.
func spell_ready(world_position: Vector2, accent: Color) -> void:
	shockwave(world_position, accent, 20.0, 62.0, 4.0, 0.42)
	_burst(world_position, accent, 12, 120.0, 0.5, 3.0, -80.0)


## The spell going off: a bolt out of the sky, a blast ring at the radius it
## actually covers, and the hardest camera kick any tower gets.
func lightning_strike(world_position: Vector2, blast_radius: float, accent: Color) -> void:
	var root := _root()
	if root == null:
		return

	var bolt: Lightning = LIGHTNING_SCENE.instantiate()
	root.add_child(bolt)
	bolt.global_position = world_position
	bolt.play(SPELL_COLOR, 0.5)

	var r: float = maxf(blast_radius, 24.0)
	shockwave(world_position, SPELL_COLOR, 6.0, r, 9.0, 0.42)
	shockwave(world_position, accent, r, r * 0.35, 5.0, 0.30)
	_burst(world_position, SPELL_COLOR, 30, r * 4.0, 0.5, 5.0, -60.0)
	_burst(world_position, Color(1.0, 1.0, 1.0, 1.0), 14, r * 2.2, 0.3, 3.5, 0.0)
	shake(9.0, 0.42)


## A tower landing on its plot: dust punching outward, an accent ring snapping
## inward behind it, thrown grit, and a short thump on the camera.
func build_flourish(world_position: Vector2, accent: Color) -> void:
	shockwave(world_position, BUILD_DUST_COLOR, 6.0, 76.0, 7.5, 0.42)
	shockwave(world_position, accent, 46.0, 26.0, 5.0, 0.30)
	_burst(world_position, BUILD_DUST_COLOR, 22, 200.0, 0.52, 4.5, 220.0)
	_burst(world_position, accent, 10, 130.0, 0.36, 3.0, 40.0)
	shake(3.0, 0.22)


## A rank-up: stacked gold rings, embers that rise instead of fall, an accent
## ring in the tower's own colour, and the new level called out over the top.
func upgrade_flourish(world_position: Vector2, accent: Color, new_level: int) -> void:
	shockwave(world_position, UPGRADE_GOLD, 10.0, 96.0, 8.0, 0.5)
	shockwave(world_position, UPGRADE_GOLD, 4.0, 60.0, 5.0, 0.36)
	shockwave(world_position, accent, 52.0, 30.0, 4.5, 0.32)
	_burst(world_position, UPGRADE_GOLD, 26, 240.0, 0.6, 4.0, 200.0)
	_burst(world_position, Color(1.0, 0.98, 0.86, 1.0), 12, 120.0, 0.45, 3.0, -70.0)
	banner(world_position + Vector2(0.0, -30.0), "LV %d" % new_level, UPGRADE_GOLD, 26)
	shake(4.5, 0.28)


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
##
## `direction` and `spread` default to a uniform ball. Narrow the spread and
## point the direction to throw particles the way a barrel is aimed.
func _burst(world_position: Vector2, color: Color, amount: int, speed: float, lifetime: float, size: float, gravity: float, direction: Vector2 = Vector2.RIGHT, spread: float = 180.0) -> void:
	var root := _root()
	if root == null:
		return

	var particles := CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = lifetime
	particles.direction = direction
	particles.spread = spread
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
