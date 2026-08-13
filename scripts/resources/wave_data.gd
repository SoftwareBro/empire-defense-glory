class_name WaveData
extends Resource

## A single wave. Holds one or more WaveEntry groups that spawn concurrently.

## Array of WaveEntry. Kept untyped so hand-authored .tres files stay simple;
## the inspector still lets you add WaveEntry resources.
@export var entries: Array = []
## Seconds of breathing room before this wave may start.
@export var delay_before: float = 2.0
