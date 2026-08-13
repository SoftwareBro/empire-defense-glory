extends CanvasLayer

## Reads only from the Events bus. It never touches towers or enemies directly.

@onready var gold_label: Label = %GoldLabel
@onready var lives_label: Label = %LivesLabel
@onready var wave_label: Label = %WaveLabel


func _ready() -> void:
	Events.gold_changed.connect(_on_gold_changed)
	Events.lives_changed.connect(_on_lives_changed)
	Events.wave_changed.connect(_on_wave_changed)

	_on_gold_changed(GameState.gold)
	_on_lives_changed(GameState.lives)
	_on_wave_changed(GameState.current_wave, GameState.total_waves)


func _on_gold_changed(amount: int) -> void:
	gold_label.text = "Gold: %d" % amount


func _on_lives_changed(amount: int) -> void:
	lives_label.text = "Lives: %d" % amount


func _on_wave_changed(current: int, total: int) -> void:
	wave_label.text = "Wave: %d / %d" % [current, total]
