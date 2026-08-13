class_name WaveEntry
extends Resource

## One group of identical enemies inside a wave.
## A wave is just a list of these, all running at the same time.

@export var enemy: EnemyData
## How many of this enemy to spawn.
@export var count: int = 5
## Seconds between each spawn within this group.
@export var interval: float = 1.0
## Seconds to wait after the wave starts before this group begins spawning.
@export var start_delay: float = 0.0
