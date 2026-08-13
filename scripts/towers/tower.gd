class_name Tower
extends Node2D

## A built tower. Every number it uses comes from the current TowerLevel, so an
## upgrade is nothing more than pointing at a different TowerLevel.
##
## The *weapon model* comes from TowerData.attack_kind, because a tower is not
## obliged to be a gun:
##
##   projectile  looses a homing shot that travels (archer)
##   beam        spins crystals into a core, then hits instantly down a laser
##   mortar      rocks back, slams forward, lobs a shell onto predicted ground
##   ability     never fires by itself; recharges a spell the player clicks
##
## Wind-up is the shared idea that makes all of them feel deliberate. A tower
## commits to a shot, telegraphs it for windup_time, and only then releases.

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/towers/Projectile.tscn")
const MORTAR_SHELL_SCENE: PackedScene = preload("res://scenes/towers/MortarShell.tscn")
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

# --- Mortar carriage ----------------------------------------------------------

## How far the barrel rocks backward while winding up. Backward first is the
## telegraph: it is the only warning the player gets before a shell is in the
## air, so it has to be visible.
const MORTAR_PULL_PX: float = 7.0
## How hard it slams forward as the shell leaves.
const MORTAR_THRUST_PX: float = 10.0
## Seconds the forward slam takes to settle.
const MORTAR_KICK_TIME: float = 0.30

# --- Arcane rig ---------------------------------------------------------------

## Crystals orbiting a beam tower.
const CRYSTALS: int = 3
## Orbit radius at rest, in pixels before sprite_scale.
const ORBIT_RADIUS: float = 36.0
## Orbit speed in radians per second, idle vs fully charged. The gap is large on
## purpose: the whip round just before firing is the tell.
const ORBIT_SPEED_IDLE: float = 0.9
const ORBIT_SPEED_CHARGED: float = 15.0
const CRYSTAL_SIZE: float = 5.5
## The arm draws back as it charges, then lunges as the beam goes out.
const BEAM_PULL_PX: float = 3.5
const BEAM_LUNGE_PX: float = 5.0
const BEAM_KICK_TIME: float = 0.18

# --- Spell rig ----------------------------------------------------------------

## Radians per second the rune ring turns. It never aims at anything.
const RUNE_SPIN: float = 0.35
## Radius of the recharge ring drawn on the tower.
const SPELL_RING_RADIUS: float = 33.0

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

## True between committing to a shot and releasing it.
var _winding: bool = false
var _windup_t: float = 0.0

## 0 = crystals out on their orbits, 1 = merged into the core. Drives the whole
## arcane rig, so charge state is one number rather than a pile of flags.
var _focus: float = 0.0
var _orbit_angle: float = 0.0

## Seconds of spell charge banked, and whether it is spendable.
var _charge: float = 0.0
var _spell_ready: bool = false
var _ready_pulse: float = 0.0
var _ability_button: AbilityButton = null

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

	if data.is_manual():
		_spawn_ability_button()

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

	# A shorter recharge should feel like a reward straight away, so the meter is
	# rescaled to the same fraction rather than reset to empty.
	var lvl := current_level()
	if data.is_manual() and lvl != null and not _spell_ready:
		_charge = minf(_charge, maxf(lvl.recharge_time, 0.1))

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

	_shot_t += delta
	_idle_t += delta

	# Manual towers never target and never fire on their own, so they skip the
	# whole scan-and-shoot path.
	if data.is_manual():
		_advance_spell(delta, lvl)
		queue_redraw()
		return

	if _cooldown > 0.0:
		_cooldown -= delta

	var target := _find_target(lvl)
	# Animated towers repaint every frame; plain ones only when they turn.
	var redraw: bool = lvl.bow_rig or data.attack_kind == "beam" or data.attack_kind == "mortar"

	if target != null:
		var new_angle: float = (target.global_position - global_position).angle()
		if not is_equal_approx(new_angle, _turret_angle):
			_turret_angle = new_angle
			redraw = true

	if _advance_weapon(delta, lvl, target):
		redraw = true

	if lvl.bow_rig:
		_advance_bow_rig(delta, lvl, target != null)

	if redraw:
		queue_redraw()


## Runs the commit → telegraph → release cycle. Returns true if the frame needs
## a repaint. Nothing fires on the frame it decides to: every shot is announced
## by windup_time first, which is what stops a tower reading as a pellet hose.
func _advance_weapon(delta: float, lvl: TowerLevel, target: Enemy) -> bool:
	var fired: bool = false

	if _winding:
		if target == null:
			# Target died or walked out mid-telegraph. Abandon the shot rather than
			# firing into an empty lane, and hold a beat so it cannot immediately
			# re-commit on the next frame.
			_winding = false
			_windup_t = 0.0
			_cooldown = maxf(_cooldown, 0.15)
		else:
			_windup_t += delta
			if _windup_t >= lvl.windup_time:
				_release(target, lvl)
				fired = true
	elif target != null and _cooldown <= 0.0:
		if lvl.windup_time > 0.0:
			_winding = true
			_windup_t = 0.0
		else:
			_release(target, lvl)
			fired = true

	_advance_focus(delta, lvl)
	return fired


## Drives the orbiting crystals. They loiter while idle and whip inward as the
## core fills, so the spin rate alone tells the player a shot is coming.
func _advance_focus(delta: float, lvl: TowerLevel) -> void:
	if data.attack_kind != "beam":
		return

	if _winding and lvl.windup_time > 0.0:
		# Squared, so they hang back and then rush the last part of the charge.
		var k: float = clampf(_windup_t / lvl.windup_time, 0.0, 1.0)
		_focus = k * k
	else:
		# Thrown back out to their orbits once the beam has gone.
		_focus = lerpf(_focus, 0.0, minf(delta * 5.0, 1.0))

	_orbit_angle += lerpf(ORBIT_SPEED_IDLE, ORBIT_SPEED_CHARGED, _focus) * delta


## Fires whatever weapon this tower actually is and starts the cooldown.
func _release(target: Enemy, lvl: TowerLevel) -> void:
	_winding = false
	_windup_t = 0.0
	_cooldown = 1.0 / maxf(lvl.fire_rate, 0.01)
	_shot_t = 0.0
	_drum_target += TAU / 6.0

	match data.attack_kind:
		"beam":
			_fire_beam(target, lvl)
		"mortar":
			_fire_mortar(target, lvl)
		_:
			_fire_projectile(target, lvl)


## Where the business end of the turret currently is, in world space.
func _muzzle_position(lvl: TowerLevel) -> Vector2:
	var reach: float = lvl.muzzle_offset if lvl.muzzle_offset > 0.0 else MUZZLE_OFFSET
	return global_position + Vector2.from_angle(_turret_angle) * reach * lvl.sprite_scale


## A shot with travel time that chases its target.
func _fire_projectile(target: Enemy, lvl: TowerLevel) -> void:
	var root := _projectile_root()
	if root == null:
		return

	var muzzle: Vector2 = _muzzle_position(lvl)

	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	projectile.setup(target, lvl)
	root.add_child(projectile)
	projectile.global_position = muzzle

	Fx.muzzle_flash(muzzle, lvl.projectile_color)


## Instant hit down a laser. There is no travel time to dodge and nothing to
## intercept: the damage lands the moment the core discharges, and the beam is
## the record of it.
func _fire_beam(target: Enemy, lvl: TowerLevel) -> void:
	var muzzle: Vector2 = _muzzle_position(lvl)
	# Read the position before dealing damage, because a killing blow frees the
	# enemy and the beam would then be drawn to a dead node's last transform.
	var hit: Vector2 = target.global_position

	Fx.charge_snap(muzzle, lvl.projectile_color)
	target.take_damage(lvl.damage, lvl.damage_type)
	if lvl.splash_radius > 0.0:
		_splash(hit, lvl, target)

	Fx.beam(muzzle, hit, lvl.projectile_color, lvl.beam_width, lvl.beam_duration)
	Fx.shake(2.4, 0.14)


## Lobbed, not fired. The shell is aimed at where the target will be when it
## lands and then commits to that ground, so leading the shot is the tower's
## job and walking out from under one is the enemy's.
func _fire_mortar(target: Enemy, lvl: TowerLevel) -> void:
	var root := _projectile_root()
	if root == null:
		return

	var muzzle: Vector2 = _muzzle_position(lvl)
	var impact_point: Vector2 = target.predict_position(lvl.flight_time)

	var shell: MortarShell = MORTAR_SHELL_SCENE.instantiate()
	root.add_child(shell)
	shell.setup(muzzle, impact_point, lvl, data.can_hit_flying)

	Fx.mortar_launch(muzzle, _turret_angle)


## Splash for weapons that resolve their own damage. `exclude` is the enemy that
## already took the direct hit.
func _splash(centre: Vector2, lvl: TowerLevel, exclude: Enemy) -> void:
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy == exclude or enemy.is_dead() or enemy.data == null:
			continue
		if enemy.data.is_flying and not data.can_hit_flying:
			continue
		if enemy.global_position.distance_to(centre) <= lvl.splash_radius:
			enemy.take_damage(lvl.damage, lvl.damage_type)


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


## Projectiles live under the level, not under the tower, so they keep flying
## straight if the tower is ever sold or upgraded mid-shot.
func _projectile_root() -> Node:
	var root := get_tree().get_first_node_in_group(&"projectile_root")
	return root if root != null else get_tree().current_scene


# --- Manual spell ------------------------------------------------------------

## How full the spell is, 0..1. Read by the rune and the upgrade panel.
func spell_charge() -> float:
	var lvl := current_level()
	if lvl == null:
		return 0.0
	return clampf(_charge / maxf(lvl.recharge_time, 0.1), 0.0, 1.0)


func is_spell_ready() -> bool:
	return _spell_ready


## Spell towers never pick targets. They fill a meter, raise a button when it is
## full, and then wait for the player to decide the moment.
func _advance_spell(delta: float, lvl: TowerLevel) -> void:
	var full: float = maxf(lvl.recharge_time, 0.1)

	if _spell_ready:
		_ready_pulse += delta
	else:
		_charge = minf(_charge + delta, full)
		if _charge >= full:
			_spell_ready = true
			_ready_pulse = 0.0
			Fx.spell_ready(global_position, data.accent_color)
			Fx.banner(global_position + Vector2(0.0, -62.0), "READY", data.accent_color, 18)

	# The rune ring turns under its own power. It has nothing to aim at.
	_turret_angle = _idle_t * RUNE_SPIN

	if _ability_button != null:
		_ability_button.set_state(spell_charge(), _spell_ready)


func _spawn_ability_button() -> void:
	_ability_button = AbilityButton.new()
	# Clear of the tower art and of the rank pips, and well clear of the build
	# plot's own click area underneath.
	_ability_button.position = Vector2(0.0, -56.0)
	_ability_button.activated.connect(cast_spell)
	add_child(_ability_button)


## Called by the rune above the tower. Picks the point that catches the most
## enemies rather than simply striking its own centre, so a click is always
## worth making — and refuses to spend a full charge on an empty map.
func cast_spell() -> void:
	if not _spell_ready:
		return

	var lvl := current_level()
	if lvl == null:
		return

	var strike := _best_strike_target(lvl)
	if strike == null:
		# Nothing in reach. Shake the rune and keep the charge: a mistimed click
		# should be corrected, not punished.
		if _ability_button != null:
			_ability_button.reject()
		return

	var centre: Vector2 = strike.global_position
	_spell_ready = false
	_charge = 0.0
	_ready_pulse = 0.0

	# Effects first, so the bolt still lands even though the damage below may
	# free every enemy that was standing under it.
	Fx.lightning_strike(centre, lvl.splash_radius, data.accent_color)

	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead() or enemy.data == null:
			continue
		if enemy.data.is_flying and not data.can_hit_flying:
			continue
		if enemy.global_position.distance_to(centre) <= lvl.splash_radius:
			enemy.take_damage(lvl.damage, lvl.damage_type)

	if _ability_button != null:
		_ability_button.set_state(0.0, false)
	queue_redraw()


## The enemy whose position would catch the most others inside the blast. Ties
## go to whoever is furthest along the path, since that is the bigger threat.
func _best_strike_target(lvl: TowerLevel) -> Enemy:
	var reachable: Array = []
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead() or enemy.data == null:
			continue
		if enemy.data.is_flying and not data.can_hit_flying:
			continue
		if global_position.distance_to(enemy.global_position) > lvl.attack_range:
			continue
		reachable.push_back(enemy)

	if reachable.is_empty():
		return null

	var best: Enemy = null
	var best_caught: int = -1
	for i in reachable.size():
		var candidate: Enemy = reachable[i]
		var caught: int = 0
		for j in reachable.size():
			var other: Enemy = reachable[j]
			if candidate.global_position.distance_to(other.global_position) <= lvl.splash_radius:
				caught += 1

		if best == null or caught > best_caught or (caught == best_caught and candidate.progress > best.progress):
			best_caught = caught
			best = candidate

	return best


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
		# Area weapons also show the blast they actually cover, because reach alone
		# says nothing useful about a mortar or a spell.
		if lvl != null and lvl.splash_radius > 0.0:
			draw_arc(Vector2.ZERO, lvl.splash_radius, 0.0, TAU, 48, Color(1.0, 0.62, 0.34, 0.45), 1.6)

	var base_tex: Texture2D = lvl.texture if lvl != null else null
	var turret_tex: Texture2D = lvl.turret_texture if lvl != null else null

	# Static half: foundation, deck, mount.
	if base_tex != null:
		_blit(base_tex, s)
	else:
		draw_circle(Vector2.ZERO, 24.0 * s, Color(0.07, 0.07, 0.09, 0.95))
		draw_circle(Vector2.ZERO, 19.0 * s, data.accent_color)

	# Moving half: authored pointing right, spun to face the target and shoved
	# along the line of fire by whatever this weapon's kick looks like.
	if turret_tex != null:
		var angle: float = _turret_angle + _sway_offset
		var kick: float = _turret_kick(lvl, s)

		draw_set_transform(Vector2.from_angle(angle) * kick, angle, Vector2.ONE)
		_blit(turret_tex, s)
		if lvl != null and lvl.bow_rig:
			_draw_bow_rig(float(turret_tex.get_width()) * ART_SCALE * s / ART_VIEWBOX)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif base_tex == null:
		draw_line(Vector2.ZERO, Vector2.from_angle(_turret_angle) * 26.0 * s, Color(0.07, 0.07, 0.09, 0.95), 8.0)
		draw_circle(Vector2.ZERO, 9.0 * s, data.accent_color.lightened(0.3))

	# Weapon rigs sit in front of the turret, since both are things happening in
	# the air around the tower rather than parts of it.
	if lvl != null:
		match data.attack_kind:
			"beam":
				_draw_arcane_rig(lvl, s)
			"ability":
				_draw_spell_rig(s)

	_draw_rank(s)
	_draw_upgrade_flare(s)


## How far along the line of fire the moving half is shoved, in pixels. Negative
## is backward. Each weapon has its own signature here, and it is most of what
## separates them by feel before a single effect plays.
func _turret_kick(lvl: TowerLevel, s: float) -> float:
	if lvl == null:
		return 0.0

	match data.attack_kind:
		"mortar":
			# Rocks back on the carriage as it winds up, then slams forward as the
			# shell leaves and settles out of the recoil.
			if _winding and lvl.windup_time > 0.0:
				var wind: float = clampf(_windup_t / lvl.windup_time, 0.0, 1.0)
				return -MORTAR_PULL_PX * wind * wind * s
			if _shot_t < MORTAR_KICK_TIME:
				var thrust: float = 1.0 - _shot_t / MORTAR_KICK_TIME
				return MORTAR_THRUST_PX * thrust * thrust * s
			return 0.0
		"beam":
			# Draws back as the core fills, then lunges as the beam goes out.
			if _winding:
				return -BEAM_PULL_PX * _focus * s
			if _shot_t < BEAM_KICK_TIME:
				var lunge: float = 1.0 - _shot_t / BEAM_KICK_TIME
				return BEAM_LUNGE_PX * lunge * lunge * s
			return 0.0
		"ability":
			# The rune ring is not a weapon and never recoils.
			return 0.0
		_:
			if _shot_t < RECOIL_TIME:
				var recoil: float = 1.0 - _shot_t / RECOIL_TIME
				return -RECOIL_PX * recoil * recoil * s
			return 0.0


## Crystals circling the tower, hauled into the focus core as the charge builds.
## Drawn in tower space rather than turret space, because they orbit the whole
## building rather than riding on the arm.
func _draw_arcane_rig(lvl: TowerLevel, s: float) -> void:
	var reach: float = lvl.muzzle_offset if lvl.muzzle_offset > 0.0 else MUZZLE_OFFSET
	var core: Vector2 = Vector2.from_angle(_turret_angle) * reach * s
	var tint: Color = lvl.projectile_color

	# The orbit centre slides from the tower onto the core while the radius
	# collapses, so the crystals spiral in instead of sliding down a straight
	# line. Two lerps is all it takes to read as a proper convergence.
	var centre: Vector2 = Vector2.ZERO.lerp(core, _focus)
	var radius: float = lerpf(ORBIT_RADIUS * s, 2.5 * s, _focus)

	if _focus > 0.01:
		draw_circle(core, (12.0 + 16.0 * _focus) * s, Color(tint.r, tint.g, tint.b, 0.10 + 0.18 * _focus))
		draw_circle(core, (5.0 + 9.0 * _focus) * s, Color(tint.r, tint.g, tint.b, 0.25 + 0.45 * _focus))
		draw_circle(core, (1.5 + 5.0 * _focus) * s, Color(1.0, 1.0, 1.0, 0.35 + 0.60 * _focus))

	for i in CRYSTALS:
		var angle: float = _orbit_angle + float(i) * TAU / float(CRYSTALS)
		var at: Vector2 = centre + Vector2.from_angle(angle) * radius
		# A short tail trailing back along the orbit. Without it, fast crystals
		# read as three stuttering dots rather than as motion.
		var tail: Vector2 = centre + Vector2.from_angle(angle - 0.45) * radius
		draw_line(tail, at, Color(tint.r, tint.g, tint.b, 0.18 + 0.40 * _focus), maxf(2.2 * s, 1.0), true)
		_draw_crystal(at, angle, CRYSTAL_SIZE * s * lerpf(1.0, 0.6, _focus), tint)


## One four-point shard: dark rim, body, and a lit facet catching the key light.
func _draw_crystal(at: Vector2, angle: float, size: float, tint: Color) -> void:
	var forward: Vector2 = Vector2.from_angle(angle) * size
	var side: Vector2 = Vector2(-forward.y, forward.x) * 0.5
	var shard := PackedVector2Array([
		at + forward,
		at + side,
		at - forward,
		at - side,
	])
	draw_colored_polygon(shard, Color(tint.r * 0.85, tint.g * 0.80, tint.b, 0.95))

	var rim := PackedVector2Array(shard)
	rim.push_back(shard[0])
	draw_polyline(rim, Color(0.14, 0.11, 0.20, 0.9), maxf(size * 0.22, 0.8), true)

	draw_colored_polygon(PackedVector2Array([at + forward, at + side, at]), Color(1.0, 0.98, 1.0, 0.55))


## The recharge read-out, drawn on the tower itself so the player can judge the
## spell at a glance instead of hunting for a bar somewhere in the HUD.
func _draw_spell_rig(s: float) -> void:
	var accent: Color = data.accent_color
	var radius: float = SPELL_RING_RADIUS * s
	var fill: float = spell_charge()

	# Dark socket, then the charge sweeping clockwise from the top.
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.08, 0.07, 0.12, 0.75), 5.0)
	if fill > 0.001:
		var start: float = -PI / 2.0
		draw_arc(Vector2.ZERO, radius, start, start + TAU * fill, 48, Color(accent.r, accent.g, accent.b, 0.95), 4.2)

	if not _spell_ready:
		return

	# Charged: a breathing halo, and arcs snapping between the rune stones.
	var pulse: float = 0.5 + 0.5 * sin(_ready_pulse * 5.0)
	draw_circle(Vector2.ZERO, radius * (1.05 + 0.12 * pulse), Color(accent.r, accent.g, accent.b, 0.10 + 0.10 * pulse))
	draw_arc(Vector2.ZERO, radius * (1.14 + 0.10 * pulse), 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.20 + 0.30 * pulse), 2.0)

	for i in 4:
		# Only some arcs fire on any given frame, so the crackle is irregular
		# rather than four spokes blinking in time.
		if randf() > 0.28:
			continue
		var a: Vector2 = Vector2.from_angle(_turret_angle + float(i) * TAU / 4.0) * radius * 0.82
		var b: Vector2 = Vector2.from_angle(_turret_angle + float(i + 1) * TAU / 4.0) * radius * 0.82
		var mid: Vector2 = (a + b) * 0.5 + Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0))
		draw_polyline(PackedVector2Array([a, mid, b]), Color(1.0, 1.0, 1.0, 0.85), 1.6, true)


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
