class_name TowerLevel
extends Resource

## One rung on a tower's upgrade ladder. The last entry in TowerData.levels is
## the tower's ceiling.
##
## Not every field applies to every tower. TowerData.attack_kind decides which
## ones get read: a beam tower ignores projectile_speed, a mortar ignores it
## too and uses flight_time instead, and an ability tower ignores fire_rate.

@export_group("Combat")
@export var damage: float = 10.0
## Targeting radius in pixels. On an "ability" tower this is how far the spell
## can reach, and splash_radius is how much ground the blast itself covers.
@export var attack_range: float = 170.0
## Shots per second. Unused by "ability" towers, which use recharge_time.
@export var fire_rate: float = 1.0
@export_enum("physical", "magic") var damage_type: String = "physical"
## 0 = single target. Above 0, the hit also damages enemies within this radius.
@export var splash_radius: float = 0.0

@export_group("Wind-up")
## Seconds between committing to a shot and the shot actually leaving. This is
## the telegraph: the wizard hauls its crystals into the core across this
## window, the siege tower rocks back on its carriage. 0 fires the instant it
## is loaded, which is what the archer wants.
@export var windup_time: float = 0.0

@export_group("Projectile")
## Pixels per second. Homing shots only.
@export var projectile_speed: float = 520.0
@export var projectile_color: Color = Color.WHITE
@export var projectile_radius: float = 5.0
## Optional art for the shot. Author it pointing RIGHT with the centre of the
## canvas on the shot's middle; it gets rotated to match the direction of
## travel. When null, the shot falls back to the drawn circle.
@export var projectile_texture: Texture2D

@export_group("Beam")
## Seconds the beam stays lit. Damage lands once, the instant it fires — the
## beam itself is pure feedback, so it is free to outlive the hit.
@export var beam_duration: float = 0.22
## Thickness of the hot core in pixels. The glow is drawn wider than this.
@export var beam_width: float = 7.0

@export_group("Mortar")
## Seconds the shell spends in the air. Shells lead their target by this much,
## so a walking enemy still gets hit — and a sprinting one can outrun it.
@export var flight_time: float = 1.15
## How high the shell arcs above the line from muzzle to impact, in pixels.
@export var arc_height: float = 200.0

@export_group("Ability")
## Seconds to rebuild a manually fired spell from empty.
@export var recharge_time: float = 12.0

@export_group("Economy")
## Gold to reach this level from the previous one. Level 1 uses TowerData.build_cost.
@export var upgrade_cost: int = 0

@export_group("Visuals")
## The part that never moves: foundation, deck, mount.
@export var texture: Texture2D
## The part that spins to face the target. Author it pointing RIGHT, with the
## pivot on the exact centre of the canvas.
@export var turret_texture: Texture2D
@export var sprite_scale: float = 1.0
## How far from the tower centre a shot is born. Set this so shots leave the
## muzzle instead of the middle of the model. Beam towers hang their focus
## crystal here too.
@export var muzzle_offset: float = 22.0
## Draws an animated bowstring, a bolt being cocked, and a spinning magazine
## on top of the turret art. Only meaningful for crossbow-style towers, and it
## expects the geometry of art/towers/autoarcher/turret_l1.svg.
@export var bow_rig: bool = false
