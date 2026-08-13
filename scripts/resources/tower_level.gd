class_name TowerLevel
extends Resource

## One rung on a tower's upgrade ladder. Levels 1-3 use these, and so do the
## two specialization branches unlocked at max level — a branch is just another
## TowerLevel with bigger numbers and a different name.

@export_group("Combat")
@export var damage: float = 10.0
## Targeting radius in pixels.
@export var attack_range: float = 170.0
## Shots per second.
@export var fire_rate: float = 1.0
@export_enum("physical", "magic") var damage_type: String = "physical"

@export_group("Economy")
## Gold to reach this level from the previous one. Level 1 uses TowerData.build_cost.
@export var upgrade_cost: int = 0

@export_group("Visuals")
@export var texture: Texture2D
@export var sprite_scale: float = 1.0
