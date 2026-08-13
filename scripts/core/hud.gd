extends CanvasLayer

## Reads only from the Events bus. It never touches towers or enemies directly.

@onready var gold_label: Label = %GoldLabel
@onready var lives_label: Label = %LivesLabel
@onready var wave_label: Label = %WaveLabel
@onready var status_label: Label = %StatusLabel
@onready var bonus_label: Label = %BonusLabel
@onready var overlay: Control = %Overlay
@onready var overlay_title: Label = %OverlayTitle
@onready var overlay_subtitle: Label = %OverlaySubtitle
@onready var restart_button: Button = %RestartButton


func _ready() -> void:
	Events.gold_changed.connect(_on_gold_changed)
	Events.lives_changed.connect(_on_lives_changed)
	Events.wave_changed.connect(_on_wave_changed)
	Events.wave_countdown_changed.connect(_on_countdown_changed)
	Events.early_call_bonus.connect(_on_early_call_bonus)
	Events.level_won.connect(_on_level_won)
	Events.level_lost.connect(_on_level_lost)

	restart_button.pressed.connect(_on_restart_pressed)
	overlay.visible = false
	bonus_label.visible = false

	_on_gold_changed(GameState.gold)
	_on_lives_changed(GameState.lives)
	_on_wave_changed(GameState.current_wave, GameState.total_waves)


func _on_gold_changed(amount: int) -> void:
	gold_label.text = "Gold: %d" % amount


func _on_lives_changed(amount: int) -> void:
	lives_label.text = "Lives: %d" % amount


func _on_wave_changed(current: int, total: int) -> void:
	wave_label.text = "Wave: %d / %d" % [current, total]


func _on_countdown_changed(seconds_left: float) -> void:
	if seconds_left <= 0.0:
		status_label.text = "Wave incoming — hold the line."
		return

	var bonus: int = int(floor(seconds_left)) * WaveManager.EARLY_CALL_GOLD_PER_SECOND
	status_label.text = "Next wave in %.1fs   ·   SPACE to call it early (+%d gold)" % [seconds_left, bonus]


func _on_early_call_bonus(amount: int) -> void:
	bonus_label.text = "+%d gold  ·  called early" % amount
	bonus_label.visible = true
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(bonus_label):
		bonus_label.visible = false


func _on_level_won() -> void:
	_show_overlay("Victory", "All waves cleared with %d lives remaining." % GameState.lives)


func _on_level_lost() -> void:
	_show_overlay("Defeat", "The enemy broke through.")


func _show_overlay(title: String, subtitle: String) -> void:
	overlay_title.text = title
	overlay_subtitle.text = subtitle
	status_label.text = ""
	overlay.visible = true
	# The overlay node is set to process while paused, so its button still works.
	get_tree().paused = true


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
