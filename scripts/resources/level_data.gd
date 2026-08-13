class_name LevelData
extends Resource

## One playable level. A "map variation" is just a new .tres with the same
## biome background but different path points, plots and waves.

@export var display_name: String = "Level 1"
## The hand-painted background illustration for this level.
@export var background: Texture2D

@export_group("Route")
## Enemy route in level-local coordinates. Needs at least 2 points.
## Leave empty to use the Path2D drawn by hand in the scene instead.
@export var path_points: PackedVector2Array = PackedVector2Array()

@export_group("Economy")
@export var starting_gold: int = 200
@export var starting_lives: int = 20

@export_group("Waves")
## Array of WaveData, played in order.
@export var waves: Array = []
