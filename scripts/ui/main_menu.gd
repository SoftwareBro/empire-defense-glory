extends Control

## Title screen and save-slot picker. Slot rows are generated so the slot count
## is a constant, not a scene layout.

@onready var slots_box: VBoxContainer = %Slots
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	quit_button.pressed.connect(_on_quit_pressed)
	_rebuild()


func _rebuild() -> void:
	for child in slots_box.get_children():
		slots_box.remove_child(child)
		child.queue_free()

	for slot in range(1, SaveGame.SLOT_COUNT + 1):
		slots_box.add_child(_make_row(slot))


func _make_row(slot: int) -> HBoxContainer:
	var summary := SaveGame.slot_summary(slot)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var play := Button.new()
	play.custom_minimum_size = Vector2(0, 54)
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.text = _slot_text(slot, summary)
	play.pressed.connect(_on_slot_pressed.bind(slot))
	row.add_child(play)

	var erase := Button.new()
	erase.custom_minimum_size = Vector2(112, 54)
	erase.text = "Delete"
	erase.disabled = summary.is_empty()
	erase.pressed.connect(_on_delete_pressed.bind(slot))
	row.add_child(erase)

	return row


func _slot_text(slot: int, summary: Dictionary) -> String:
	if summary.is_empty():
		return "Slot %d   ·   New Game" % slot
	return "Slot %d   ·   %d / %d levels   ·   %d ★" % [
		slot,
		int(summary.get("completed", 0)),
		Campaign.playable_count(),
		int(summary.get("stars", 0)),
	]


func _on_slot_pressed(slot: int) -> void:
	SaveGame.load_slot(slot)
	Campaign.go_to_world_map()


func _on_delete_pressed(slot: int) -> void:
	SaveGame.delete_slot(slot)
	_rebuild()


func _on_quit_pressed() -> void:
	get_tree().quit()
