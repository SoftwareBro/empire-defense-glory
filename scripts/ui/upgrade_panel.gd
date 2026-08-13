class_name UpgradePanel
extends Node2D

## Opens on a built tower. Shows current stats, the next rung with a before/after
## preview, the two specializations once the ladder is topped out, and sell.
## Every number is read live from the tower's TowerData — nothing is hardcoded.

const PANEL_WIDTH: float = 264.0
## Panels flip to the tower's left past this x so they never run off screen.
const FLIP_X: float = 960.0

var _tower: Tower = null


func _ready() -> void:
	visible = false


func open(tower: Tower) -> void:
	if tower == null or tower.data == null:
		return

	_tower = tower
	_tower.set_range_pinned(true)
	global_position = tower.global_position
	_rebuild()
	visible = true


func close() -> void:
	if not visible:
		return
	if _tower != null and is_instance_valid(_tower):
		_tower.set_range_pinned(false)
	visible = false
	_tower = null
	_clear()


func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _rebuild() -> void:
	_clear()
	if _tower == null or _tower.data == null:
		return

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	var flip: bool = global_position.x > FLIP_X
	panel.position = Vector2(-PANEL_WIDTH - 44.0 if flip else 44.0, -86.0)
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)

	var level := _tower.current_level()

	_add_label(box, "%s  —  %s" % [_tower.data.display_name, _tower.level_label()], 16)
	_add_label(box, _stat_line(level), 13)

	if _tower.can_upgrade():
		var next_level := _tower.next_level()
		var cost: int = _tower.upgrade_cost()
		_add_label(box, "Next:  %s" % _stat_line(next_level), 13)

		var upgrade_button := Button.new()
		upgrade_button.text = "Upgrade to Lv %d   ·   %d g" % [_tower.level_index + 2, cost]
		upgrade_button.disabled = not GameState.can_afford(cost)
		upgrade_button.pressed.connect(_on_upgrade_pressed)
		box.add_child(upgrade_button)
	elif _tower.can_specialize():
		_add_label(box, "Choose one — permanent:", 13)
		_add_branch_button(box, &"a", _tower.data.branch_a_name, _tower.data.branch_a)
		_add_branch_button(box, &"b", _tower.data.branch_b_name, _tower.data.branch_b)
	else:
		_add_label(box, "Fully upgraded.", 13)

	var sell_button := Button.new()
	sell_button.text = "Sell   ·   +%d g" % _tower.sell_value()
	sell_button.pressed.connect(_on_sell_pressed)
	box.add_child(sell_button)


func _add_label(box: VBoxContainer, text: String, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)


func _add_branch_button(box: VBoxContainer, which: StringName, label: String, level: TowerLevel) -> void:
	if level == null:
		return
	var button := Button.new()
	button.text = "%s   ·   %d g" % [label, level.upgrade_cost]
	button.disabled = not GameState.can_afford(level.upgrade_cost)
	button.pressed.connect(_on_branch_pressed.bind(which))
	box.add_child(button)


func _stat_line(level: TowerLevel) -> String:
	if level == null:
		return ""
	var line: String = "DMG %d   ·   RNG %d   ·   %.1f/s   ·   %s" % [
		int(level.damage),
		int(level.attack_range),
		level.fire_rate,
		level.damage_type,
	]
	if level.splash_radius > 0.0:
		line += "   ·   splash %d" % int(level.splash_radius)
	return line


func _on_upgrade_pressed() -> void:
	if _tower == null or not _tower.can_upgrade():
		return
	var cost: int = _tower.upgrade_cost()
	if not GameState.spend_gold(cost):
		return
	_tower.upgrade()
	# Stay open so upgrades can be chained without re-clicking.
	_rebuild()


func _on_branch_pressed(which: StringName) -> void:
	if _tower == null or not _tower.can_specialize():
		return

	var level: TowerLevel = _tower.data.branch_a if which == &"a" else _tower.data.branch_b
	if level == null:
		return
	if not GameState.spend_gold(level.upgrade_cost):
		return

	_tower.specialize(which)
	_rebuild()


func _on_sell_pressed() -> void:
	if _tower == null:
		return

	var refund: int = _tower.sell_value()
	var plot := _tower.get_parent() as BuildPlot
	GameState.add_gold(refund)
	Events.tower_sold.emit(_tower, refund)

	close()
	if plot != null:
		plot.remove_tower()
