extends Node

## Global signal bus. Autoloaded as `Events`.
##
## Any system can emit or listen without holding a reference to any other
## system. This is what keeps towers, enemies, HUD and waves decoupled.

signal enemy_spawned(enemy: Node2D)
signal enemy_died(enemy: Node2D, bounty: int)
signal enemy_leaked(enemy: Node2D, damage: int)

signal tower_built(tower: Node2D, cost: int)
signal tower_sold(tower: Node2D, refund: int)
signal tower_upgraded(tower: Node2D, new_level: int)

signal build_menu_opened(plot: Node2D)
signal build_menu_closed()

signal gold_changed(amount: int)
signal lives_changed(amount: int)
signal wave_changed(current: int, total: int)
## Fired every frame while a between-wave countdown is running.
signal wave_countdown_changed(seconds_left: float)
## Fired when the player skips a countdown and earns the time bonus.
signal early_call_bonus(amount: int)

signal level_won()
signal level_lost()
