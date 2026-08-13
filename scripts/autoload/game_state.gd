extends Node

## Per-level economy and outcome. Reset by setup() at the start of every level.

## Absolute life count needed for two stars, tuned for a 20-life level.
const TWO_STAR_MIN_LIVES: int = 14

var gold: int = 0
var lives: int = 0
var starting_lives: int = 0
var current_wave: int = 0
var total_waves: int = 0
var is_game_over: bool = false


func setup(level_data: LevelData) -> void:
	gold = level_data.starting_gold
	lives = level_data.starting_lives
	starting_lives = level_data.starting_lives
	current_wave = 0
	total_waves = level_data.waves.size()
	is_game_over = false
	Events.gold_changed.emit(gold)
	Events.lives_changed.emit(lives)
	Events.wave_changed.emit(current_wave, total_waves)


## 3 = flawless, 2 = 14 lives or more, 1 = survived at all, 0 = lost.
func stars_earned() -> int:
	if lives <= 0:
		return 0
	if lives >= starting_lives:
		return 3
	if lives >= TWO_STAR_MIN_LIVES:
		return 2
	return 1


func add_gold(amount: int) -> void:
	gold += amount
	Events.gold_changed.emit(gold)


func can_afford(cost: int) -> bool:
	return gold >= cost


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


func win_level() -> void:
	if is_game_over:
		return
	is_game_over = true
	Events.level_won.emit()
