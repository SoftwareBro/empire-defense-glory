extends CanvasLayer

## Reads only from the Events bus. It never touches towers or enemies directly.
## The whole layer processes while paused so the pause and result menus work.

@onready var gold_label: Label = %GoldLabel
@onready var lives_label: Label = %LivesLabel
@onready var wave_label: Label = %WaveLabel
@onready var status_label: Label = %StatusLabel
@onready var bonus_label: Label = %BonusLabel
@onready var pause_button: Button = %PauseButton

@onready var overlay: Control = %Overlay
@onready var overlay_title: Label = %OverlayTitle
@onready var overlay_stars: Label = %OverlayStars
@onready var overlay_subtitle: Label = %OverlaySubtitle
@onready var primary_button: Button = %PrimaryButton
@onready var secondary_button: Button = %SecondaryButton

@onready var pause_menu: Control = %PauseMenu
@onready var resume_button: Button = %ResumeButton
@onready var sound_button: Button = %SoundButton
@onready var map_button: Button = %MapButton
@onready var exit_button: Button = %ExitButton

var _won: bool = false


func _ready() -> void:
	Events.gold_changed.connect(_on_gold_changed)
	Events.lives_changed.connect(_on_lives_changed)
	Events.wave_changed.connect(_on_wave_changed)
	Events.wave_countdown_changed.connect(_on_countdown_changed)
	Events.early_call_bonus.connect(_on_early_call_bonus)
	Events.level_won.connect(_on_level_won)
	Events.level_lost.connect(_on_level_lost)

	primary_button.pressed.connect(_on_primary_pressed)
	secondary_button.pressed.connect(_on_secondary_pressed)

	pause_button.pressed.connect(_toggle_pause_menu)
	resume_button.pressed.connect(_close_pause_menu)
	sound_button.pressed.connect(_on_sound_pressed)
	map_button.pressed.connect(Campaign.go_to_world_map)
	exit_button.pressed.connect(Campaign.go_to_main_menu)

	overlay.visible = false
	pause_menu.visible = false
	bonus_label.visible = false
	_refresh_sound_label()

	_on_gold_changed(GameState.gold)
	_on_lives_changed(GameState.lives)
	_on_wave_changed(GameState.current_wave, GameState.total_waves)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# A finished level owns the screen; Escape must not stack a menu on it.
	if overlay.visible:
		return
	_toggle_pause_menu()
	get_viewport().set_input_as_handled()


func _on_gold_changed(amount: int) -> void:
	gold_label.text = "Gold: %d" % amount
	_pop(gold_label)


func _on_lives_changed(amount: int) -> void:
	lives_label.text = "Lives: %d" % amount
	_pop(lives_label)


func _on_wave_changed(current: int, total: int) -> void:
	wave_label.text = "Wave: %d / %d" % [current, total]


func _on_countdown_changed(seconds_left: float) -> void:
	if seconds_left <= 0.0:
		status_label.text = "Wave incoming — hold the line."
		return

	# Whole seconds only. ceili keeps it reading "1s" until the wave actually lands.
	var whole: int = ceili(seconds_left)
	var bonus: int = WaveManager.early_call_bonus_for(seconds_left)
	status_label.text = "Next wave in %ds   ·   SPACE to call it early (+%d gold)" % [whole, bonus]


func _on_early_call_bonus(amount: int) -> void:
	bonus_label.text = "+%d gold  ·  called early" % amount
	bonus_label.visible = true
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(bonus_label):
		bonus_label.visible = false


# --- Result screens ------------------------------------------------------------

func _on_level_won() -> void:
	_won = true
	var stars: int = GameState.stars_earned()
	overlay_stars.text = _star_string(stars)
	primary_button.text = "World Map"
	secondary_button.text = "Replay"
	_show_overlay("Victory", "Finished with %d of %d lives." % [GameState.lives, GameState.starting_lives])


func _on_level_lost() -> void:
	_won = false
	overlay_stars.text = _star_string(0)
	primary_button.text = "Retry"
	secondary_button.text = "World Map"
	_show_overlay("Defeat", "The enemy broke through.")


func _show_overlay(title: String, subtitle: String) -> void:
	pause_menu.visible = false
	overlay_title.text = title
	overlay_subtitle.text = subtitle
	status_label.text = ""
	overlay.visible = true
	get_tree().paused = true


func _on_primary_pressed() -> void:
	if _won:
		Campaign.go_to_world_map()
	else:
		Campaign.restart_level()


func _on_secondary_pressed() -> void:
	if _won:
		Campaign.restart_level()
	else:
		Campaign.go_to_world_map()


func _star_string(stars: int) -> String:
	var out: String = ""
	for i in 3:
		out += "★" if i < stars else "☆"
	return out


# --- Pause ---------------------------------------------------------------------

func _toggle_pause_menu() -> void:
	if overlay.visible:
		return
	var opening: bool = not pause_menu.visible
	pause_menu.visible = opening
	get_tree().paused = opening


func _close_pause_menu() -> void:
	pause_menu.visible = false
	get_tree().paused = false


## Real mute on the master bus, so it already works before any sounds exist.
func _on_sound_pressed() -> void:
	AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
	_refresh_sound_label()


func _refresh_sound_label() -> void:
	sound_button.text = "Sound: Off" if AudioServer.is_bus_mute(0) else "Sound: On"


## Small scale punch so counter changes are noticed without reading them.
func _pop(label: Label) -> void:
	if not is_instance_valid(label):
		return
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(1.22, 1.22)
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
