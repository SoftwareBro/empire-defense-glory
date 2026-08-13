extends Node

## Global signal bus. Autoloaded as `Events`.
##
## Any system can emit or listen without holding a reference to any other
## system. This is what keeps towers, enemies, HUD and waves decoupled.

signal enemy_spawned(enemy: Node2D)
signal enemy_died(enemy: Node2D, bounty: int)
signal enemy_leaked(enemy: Node2D, damage: int)

signal gold_changed(amount: int)
signal lives_changed(amount: int)
signal wave_changed(current: int, total: int)

signal level_won()
signal level_lost()
