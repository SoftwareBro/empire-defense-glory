class_name BuildMenu
extends Node2D

## Radial tower picker that pops up on an empty build plot.
## Buttons are generated from the level's available_towers list, so adding a
## fifth tower later needs no UI work at all.

const RADIUS: float = 84.0
const BUTTON_SIZE: Vector2 = Vector2(78, 58)

var _plot: BuildPlot = null
var _towers: Array = []


func _ready() -> void:
	visible = false


func open(plot: BuildPlot, towers: Array) -> void:
	if plot == null or towers.is_empty():
		return
	_plot = plot
	_towers = towers
	global_position = plot.global_position
	_rebuild_buttons()
	visible = true
	Events.build_menu_opened.emit(plot)


func close() -> void:
	if not visible:
		return
	visible = false
	_plot = null
	_clear_buttons()
	Events.build_menu_closed.emit()


func _clear_buttons() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _rebuild_buttons() -> void:
	_clear_buttons()

	var count: int = _towers.size()
	for i in count:
		var tower_data: TowerData = _towers[i]
		if tower_data == null:
			continue

		# Start at the top and go clockwise.
		var angle: float = -PI / 2.0 + TAU * float(i) / float(count)
		var button := Button.new()
		button.text = "%s\n%d g" % [tower_data.short_name, tower_data.build_cost]
		button.custom_minimum_size = BUTTON_SIZE
		button.size = BUTTON_SIZE
		button.position = Vector2(cos(angle), sin(angle)) * RADIUS - BUTTON_SIZE * 0.5
		button.disabled = not GameState.can_afford(tower_data.build_cost)
		button.pressed.connect(_on_tower_chosen.bind(tower_data))
		add_child(button)


func _on_tower_chosen(tower_data: TowerData) -> void:
	if _plot == null or _plot.is_occupied():
		close()
		return
	if not GameState.spend_gold(tower_data.build_cost):
		return
	_plot.build_tower(tower_data)
	close()
