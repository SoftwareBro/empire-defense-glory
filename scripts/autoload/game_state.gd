extends Node

## Run-scoped state for the level currently being played. Autoloaded as `GameState`.

var gold: int = 0
var lives: int = 0
var current_wave: int = 0
var total_waves: int = 0
var is_game_over: bool = false


func setup(level_data: LevelData) -> void:
	gold = level_data.starting_gold
	lives = level_data.starting_lives
	current_wave = 0
	total_waves = level_data.waves.size()
	is_game_over = false
	Events.gold_changed.emit(gold)
	Events.lives_changed.emit(lives)
	Events.wave_changed.emit(current_wave, total_waves)


func add_gold(amount: int) -> void:
	gold += amount
	Events.gold_changed.emit(gold)


func can_afford(cost: int) -> bool:
	return gold >= cost


## Returns false and changes nothing if the player cannot afford it.
func spend_gold(amount: int) -> bool:
	if not can_afford(amount):
		return false
	gold -= amount
	Events.gold_changed.emit(gold)
	return true


func lose_lives(amount: int) -> void:
	if is_game_over:
		return
	lives = maxi(0, lives - amount)
	Events.lives_changed.emit(lives)
	if lives == 0:
		is_game_over = true
		Events.level_lost.emit()
