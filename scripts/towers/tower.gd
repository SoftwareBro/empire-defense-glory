class_name Tower
extends Node2D

## A built tower: picks a target in range, respects its fire rate, and launches
## projectiles. Every number it uses comes from the current TowerLevel, so an
## upgrade is nothing more than pointing at a different TowerLevel.

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/towers/Projectile.tscn")
## Fallback muzzle distance for levels that never set one.
const MUZZLE_OFFSET: float = 22.0
## Art is authored oversized so it stays crisp when zoomed. This scales it back
## down to game pixels: a 256px canvas renders at 64px.
const ART_SCALE: float = 0.25
## Fraction of everything invested that a sale returns.
const SELL_REFUND_RATIO: float = 0.7

## Art convention: every sprite is authored on a square canvas over a 96-unit
## viewBox with the pivot dead centre. These two let code draw moving parts
## using the very same coordinates the SVG uses, so they line up exactly.
const ART_VIEWBOX: float = 96.0
const ART_CENTRE: Vector2 = Vector2(48.0, 48.0)

# --- Crossbow rig ------------------------------------------------------------
# The bowstring, nocked bolt and magazine bolt ends are drawn here rather than
# baked into turret_l1.svg, because they have to move. All coordinates below are
# in that file's viewBox units.

const LIMB_TIP_A: Vector2 = Vector2(83.5, 26.0)
const LIMB_TIP_B: Vector2 = Vector2(83.5, 70.0)
const DRUM_CENTRE: Vector2 = Vector2(40.0, 48.0)
const DRUM_RADIUS: float = 5.0
## String apex, snapped forward vs hauled back and cocked.
const STRING_REST_X: float = 78.0
const STRING_DRAW_X: float = 53.5
## Bolt nock, freshly fed vs pulled back under tension.
const BOLT_REST_X: float = 63.0
const BOLT_DRAW_X: float = 55.0
## Seconds the string takes to snap forward after a shot.
const RELEASE_TIME: float = 0.07
## Seconds the weapon spends kicking backward and settling.
const RECOIL_TIME: float = 0.16
const RECOIL_PX: float = 3.0
## Cocking never drags on longer than this, so slow towers sit visibly ready
## instead of creeping through the whole reload.
const MAX_COCK_TIME: float = 0.45
## Radians of idle drift while the tower has nothing to shoot at.
const IDLE_SWAY: float = 0.05

const OUTLINE_COLOR: Color = Color(0.129, 0.102, 0.086)
const STRING_COLOR: Color = Color(0.937, 0.902, 0.804)
const BOLT_WOOD_COLOR: Color = Color(0.71, 0.514, 0.29)
const BOLT_STEEL_COLOR: Color = Color(0.796, 0.843, 0.878)
const BRASS_DARK_COLOR: Color = Color(0.557, 0.392, 0.086)
const BRASS_LIGHT_COLOR: Color = Color(0.941, 0.761, 0.373)

# --- Build and upgrade juice --------------------------------------------------

## Seconds the tower takes to settle onto its plot.
const BUILD_TIME: float = 0.42
## Scale a freshly placed tower grows from.
const BUILD_FROM_SCALE: float = 0.35
## Seconds the gold rank-up flare lingers after an upgrade.
const UPGRADE_FLARE_TIME: float = 0.7
## How hard the tower punches outward the instant it ranks up.
const UPGRADE_PUNCH_SCALE: float = 1.28
const UPGRADE_GOLD: Color = Color(1.0, 0.85, 0.38, 1.0)

@export var data: TowerData

## Index into data.levels. 0 = level 1.
var level_index: int = 0
## Shown while hovering.
var show_range: bool = false
## Held on while the upgrade panel is open.
var range_pinned: bool = false

var _cooldown: float = 0.0
var _turret_angle: float = 0.0

## Seconds since the last shot. Starts high so a newly built tower reads as
## loaded and ready rather than mid-reload.
var _shot_t: float = 99.0
## How long the cocking stroke is allowed to take, derived from the fire rate.
var _cock_span: float = 0.5
var _idle_t: float = 0.0
var _sway_amount: float = 1.0
var _sway_offset: float = 0.0
var _drum_angle: float = 0.0
var _drum_target: float = 0.0

## Counts down after an upgrade and drives the gold rings in _draw().
var _flare_t: float = 0.0


func _ready() -> void:
	if data == null:
		push_error("Tower placed without TowerData.")
		queue_free()
		return
	# Stagger the idle drift so a row of towers never sways in lockstep.
	_idle_t = randf() * 10.0
	# _process only exists to animate the rank-up flare, so leave it off until
	# there is a flare to animate.
	set_process(false)
	_play_build_animation()
	queue_redraw()


func _process(delta: float) -> void:
	_flare_t = maxf(0.0, _flare_t - delta)
	queue_redraw()
	if _flare_t <= 0.0:
		set_process(false)


# --- Level model -------------------------------------------------------------

func current_level() -> TowerLevel:
	if data == null or data.levels.is_empty():
		return null
	return data.levels[clampi(level_index, 0, data.levels.size() - 1)]


func is_max_level() -> bool:
	return data == null or level_index >= data.max_level_index()


func can_upgrade() -> bool:
	return not is_max_level()


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
	if is_max_level():
		return "Lv %d  ·  Max" % (level_index + 1)
	return "Lv %d" % (level_index + 1)


func upgrade() -> void:
	if not can_upgrade():
		return

	level_index += 1

	Fx.upgrade_flourish(global_position, data.accent_color, level_index + 1)
	_play_upgrade_animation()

	Events.tower_upgraded.emit(self, level_index + 1)
	queue_redraw()


# --- Presentation ------------------------------------------------------------

## Drops the tower onto its plot: it fades in undersized and overshoots past
## full size before settling, timed to land with Fx's dust ring.
func _play_build_animation() -> void:
	Fx.build_flourish(global_position, data.accent_color)

	scale = Vector2(BUILD_FROM_SCALE, BUILD_FROM_SCALE)
	# Alpha 0 with the colour pushed past white, so it resolves out of a flash.
	modulate = Color(1.4, 1.32, 1.12, 0.0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, BUILD_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color.WHITE, BUILD_TIME * 0.9)


## A hard elastic punch, which is the whole "that just got stronger" read.
func _play_upgrade_animation() -> void:
	_flare_t = UPGRADE_FLARE_TIME
	set_process(true)

	scale = Vector2(UPGRADE_PUNCH_SCALE, UPGRADE_PUNCH_SCALE)
	modulate = Color(1.65, 1.48, 1.06, 1.0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color.WHITE, 0.45)


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

	_shot_t += delta
	_idle_t += delta

	var target := _find_target(lvl)
	# Animated towers repaint every frame; plain ones only when they turn.
	var redraw: bool = lvl.bow_rig

	if target != null:
		var new_angle: float = (target.global_position - global_position).angle()
		if not is_equal_approx(new_angle, _turret_angle):
			_turret_angle = new_angle
			redraw = true

		if _cooldown <= 0.0:
			_fire(target, lvl)
			_cooldown = 1.0 / maxf(lvl.fire_rate, 0.01)
			_shot_t = 0.0
			_drum_target += TAU / 6.0
			redraw = true

	if lvl.bow_rig:
		_advance_bow_rig(delta, lvl, target != null)

	if redraw:
		queue_redraw()


## Keeps the animated crossbow parts moving. Cocking is stretched to fill
## whatever is left of the firing cycle, so a fast tower reloads frantically
## while a level 1 tower finishes early and holds the shot.
func _advance_bow_rig(delta: float, lvl: TowerLevel, has_target: bool) -> void:
	var cycle: float = 1.0 / maxf(lvl.fire_rate, 0.01)
	_cock_span = clampf(cycle * 0.8, RELEASE_TIME + 0.06, RELEASE_TIME + MAX_COCK_TIME)

	# The magazine steps one chamber per shot and eases into place.
	_drum_angle = lerpf(_drum_angle, _drum_target, minf(delta * 12.0, 1.0))

	# Idle drift fades out the moment something walks into range.
	_sway_amount = lerpf(_sway_amount, 0.0 if has_target else 1.0, minf(delta * 4.0, 1.0))
	_sway_offset = sin(_idle_t * 1.7) * IDLE_SWAY * _sway_amount


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
			# "first" - furthest along the path, the genre default.
			return enemy.progress


func _fire(target: Enemy, lvl: TowerLevel) -> void:
	var root := _projectile_root()
	if root == null:
		return

	var reach: float = lvl.muzzle_offset if lvl.muzzle_offset > 0.0 else MUZZLE_OFFSET
	var muzzle: Vector2 = global_position + Vector2.from_angle(_turret_angle) * reach * lvl.sprite_scale

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

	var base_tex: Texture2D = lvl.texture if lvl != null else null
	var turret_tex: Texture2D = lvl.turret_texture if lvl != null else null

	# Static half: foundation, deck, mount.
	if base_tex != null:
		_blit(base_tex, s)
	else:
		draw_circle(Vector2.ZERO, 24.0 * s, Color(0.07, 0.07, 0.09, 0.95))
		draw_circle(Vector2.ZERO, 19.0 * s, data.accent_color)

	# Moving half: authored pointing right, spun to face the target and shoved
	# backward for a moment after each shot.
	if turret_tex != null:
		var angle: float = _turret_angle + _sway_offset
		var kick: float = 0.0
		if _shot_t < RECOIL_TIME:
			var k: float = 1.0 - _shot_t / RECOIL_TIME
			kick = -RECOIL_PX * k * k * s

		draw_set_transform(Vector2.from_angle(angle) * kick, angle, Vector2.ONE)
		_blit(turret_tex, s)
		if lvl != null and lvl.bow_rig:
			_draw_bow_rig(float(turret_tex.get_width()) * ART_SCALE * s / ART_VIEWBOX)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif base_tex == null:
		draw_line(Vector2.ZERO, Vector2.from_angle(_turret_angle) * 26.0 * s, Color(0.07, 0.07, 0.09, 0.95), 8.0)
		draw_circle(Vector2.ZERO, 9.0 * s, data.accent_color.lightened(0.3))

	_draw_rank(s)
	_draw_upgrade_flare(s)


## Rank read-out: one pip per level, turning gold once the tower is topped out.
func _draw_rank(s: float) -> void:
	var maxed: bool = is_max_level()
	var pip_color: Color = UPGRADE_GOLD if maxed else Color(1.0, 1.0, 1.0, 0.9)

	if maxed:
		draw_arc(Vector2.ZERO, 29.0 * s, 0.0, TAU, 48, Color(UPGRADE_GOLD.r, UPGRADE_GOLD.g, UPGRADE_GOLD.b, 0.45), 1.8)

	var pips: int = level_index + 1
	var start_x: float = -float(pips - 1) * 5.0
	for i in pips:
		var centre := Vector2(start_x + float(i) * 10.0, -32.0 * s)
		if maxed:
			draw_circle(centre, 4.2, Color(0.129, 0.102, 0.086, 0.55))
		draw_circle(centre, 3.0, pip_color)


## Two gold rings chasing each other outward, plus a soft core glow. Drawn on
## the tower rather than in Fx so it scales and fades with the punch animation.
func _draw_upgrade_flare(s: float) -> void:
	if _flare_t <= 0.0:
		return

	var t: float = 1.0 - _flare_t / UPGRADE_FLARE_TIME
	var fade: float = 1.0 - t
	var inner: float = 26.0 * s

	for i in 2:
		# The second ring is held back a beat so they read as a pulse, not a pair.
		var ring_t: float = clampf(t + float(i) * 0.22, 0.0, 1.0)
		var radius: float = inner + ring_t * 46.0 * s
		var strength: float = fade * (1.0 - ring_t)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(UPGRADE_GOLD.r, UPGRADE_GOLD.g, UPGRADE_GOLD.b, strength * 0.8), maxf(3.5 * (1.0 - ring_t), 0.6))

	draw_circle(Vector2.ZERO, inner * (1.0 + 0.16 * fade), Color(1.0, 0.93, 0.62, fade * 0.16))


## Draws the parts of the crossbow that move. Called inside the turret's
## transform, so everything here is in turret space with +X forward.
## `unit` converts one authored viewBox unit into pixels.
func _draw_bow_rig(unit: float) -> void:
	# cocked: 0 = string snapped fully forward, 1 = hauled back and loaded.
	var cocked: float = 1.0
	var bolt_loaded: bool = true
	var twang: float = 0.0

	if _shot_t < RELEASE_TIME:
		# Mid-release. The bolt has become a real projectile and left the rail,
		# so only the string is left, snapping forward and shivering.
		var r: float = _shot_t / RELEASE_TIME
		cocked = 1.0 - r
		bolt_loaded = false
		twang = sin(r * 26.0) * (1.0 - r) * 2.4
	else:
		# Cocking. A fresh bolt is fed in, then dragged back with the string.
		var span: float = maxf(_cock_span - RELEASE_TIME, 0.05)
		var u: float = clampf((_shot_t - RELEASE_TIME) / span, 0.0, 1.0)
		cocked = u * u * (3.0 - 2.0 * u)

	# The rope, hooked over both steel nocks and pulled into a V.
	var apex_x: float = lerpf(STRING_REST_X, STRING_DRAW_X, cocked)
	var string_pts := PackedVector2Array([
		_art(LIMB_TIP_A, unit),
		_art(Vector2(apex_x, 48.0 + twang), unit),
		_art(LIMB_TIP_B, unit),
	])
	draw_polyline(string_pts, OUTLINE_COLOR, maxf(2.2 * unit, 1.4), true)
	draw_polyline(string_pts, STRING_COLOR, maxf(1.1 * unit, 0.8), true)

	# The bolt waiting on the rail, held back by the string.
	if bolt_loaded:
		var nock: Vector2 = Vector2(lerpf(BOLT_REST_X, BOLT_DRAW_X, cocked), 48.0)
		var tail: Vector2 = _art(nock, unit)
		var head: Vector2 = _art(nock + Vector2(24.0, 0.0), unit)
		draw_line(tail, head, OUTLINE_COLOR, maxf(4.2 * unit, 1.6))
		draw_line(tail, head, BOLT_WOOD_COLOR, maxf(2.2 * unit, 1.0))

		var tip := PackedVector2Array([
			_art(nock + Vector2(22.0, -4.4), unit),
			_art(nock + Vector2(34.0, 0.0), unit),
			_art(nock + Vector2(22.0, 4.4), unit),
		])
		draw_colored_polygon(tip, BOLT_STEEL_COLOR)
		draw_polyline(tip, OUTLINE_COLOR, maxf(1.5 * unit, 1.0), true)

	# Magazine bolt ends, stepping round one chamber per shot.
	var hub: Vector2 = _art(DRUM_CENTRE, unit)
	var ring: float = DRUM_RADIUS * unit
	for i in 6:
		var p: Vector2 = hub + Vector2.from_angle(_drum_angle + float(i) * TAU / 6.0) * ring
		draw_circle(p, maxf(1.6 * unit, 1.0), BRASS_DARK_COLOR)
		draw_circle(p - Vector2(0.35, 0.35) * unit, maxf(0.7 * unit, 0.6), BRASS_LIGHT_COLOR)


## Turns a point authored in the art's 96-unit viewBox into pixels relative to
## the pivot, so code-drawn parts sit exactly where the sprite expects them.
func _art(v: Vector2, unit: float) -> Vector2:
	return (v - ART_CENTRE) * unit


## Draws a texture centred on the tower's origin at the level's sprite scale.
func _blit(tex: Texture2D, s: float) -> void:
	var size: Vector2 = Vector2(float(tex.get_width()), float(tex.get_height())) * ART_SCALE * s
	draw_texture_rect(tex, Rect2(-size * 0.5, size), false)
