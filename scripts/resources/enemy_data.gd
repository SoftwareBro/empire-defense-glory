class_name EnemyData
extends Resource

## Everything that makes one enemy type different from another.
## Add a new enemy by creating a new .tres in `data/enemies/` — never by writing code.

@export var id: StringName = &"grunt"
@export var display_name: String = "Grunt"

@export_group("Stats")
## Hit points.
@export var max_health: float = 100.0
## Pixels travelled per second along the path.
@export var speed: float = 90.0
## Gold awarded to the player on death.
@export var bounty: int = 5
## Lives the player loses if this enemy reaches the exit.
@export var leak_damage: int = 1

@export_group("Defense")
@export_enum("none", "light", "heavy", "magic") var armor_type: String = "none"
## 0.0 = takes full physical damage, 0.9 = takes 10%.
@export_range(0.0, 0.9, 0.05) var physical_resist: float = 0.0
@export_range(0.0, 0.9, 0.05) var magic_resist: float = 0.0
## Flyers ignore ground blockers (barracks soldiers).
@export var is_flying: bool = false
@export var is_boss: bool = false

@export_group("Visuals")
@export var texture: Texture2D
## Multiplier applied to the sprite. Placeholder art is 128px, so 0.25 = 32px.
@export var sprite_scale: float = 1.0
