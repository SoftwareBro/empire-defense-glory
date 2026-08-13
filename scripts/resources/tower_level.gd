class_name TowerLevel
extends Resource

## One rung on a tower's upgrade ladder. Levels 1-3 use these, and so do the
## two specialization branches unlocked at max level - a branch is just another
## TowerLevel with bigger numbers and a different name.

@export_group("Combat")
@export var damage: float = 10.0
## Targeting radius in pixels.
@export var attack_range: float = 170.0
## Shots per second.
@export var fire_rate: float = 1.0
@export_enum("physical", "magic") var damage_type: String = "physical"
## 0 = single target. Above 0, the hit also damages enemies within this radius.
@export var splash_radius: float = 0.0

@export_group("Projectile")
## Pixels per second.
@export var projectile_speed: float = 520.0
@export var projectile_color: Color = Color.WHITE
@export var projectile_radius: float = 5.0
## Optional art for the shot. Author it pointing RIGHT with the centre of the
## canvas on the shot's middle; it gets rotated to match the direction of
## travel. When null, the shot falls back to the drawn circle.
@export var projectile_texture: Texture2D

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
## muzzle instead of the middle of the model.
@export var muzzle_offset: float = 22.0
## Draws an animated bowstring, a bolt being cocked, and a spinning magazine
## on top of the turret art. Only meaningful for crossbow-style towers, and it
## expects the geometry of art/towers/autoarcher/turret_l1.svg.
@export var bow_rig: bool = false
