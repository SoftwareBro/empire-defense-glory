class_name UpgradePanel
extends Node2D

## Opens on a built tower. Shows what it does now, what the next rung would add,
## and sell. Every number is read live from the tower's TowerData — nothing here
## is hardcoded.
##
## Stats are drawn as segmented bars measured against the tower's *own* top
## level, so a bar answers "how far up this ladder am I" rather than inviting a
## meaningless comparison between an archer and a mortar. The upgrade is
## previewed as extra segments inside the same bar, which is far easier to read
## at a glance than a second row of numbers.

const PANEL_WIDTH: float = 276.0
## Panels flip to the tower's left past this x so they never run off screen.
const FLIP_X: float = 960.0
## Segments in a stat bar.
const BAR_CELLS: int = 12
const CELL_SIZE: Vector2 = Vector2(7.0, 9.0)

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

	var accent: Color = _tower.data.accent_color

	var plate := PixelPlate.new()
	plate.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	var flip: bool = global_position.x > FLIP_X
	plate.position = Vector2(-PANEL_WIDTH - 44.0 if flip else 44.0, -96.0)
	add_child(plate)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	plate.add_child(box)

	_add_header(box, accent)
	box.add_child(PixelTheme.divider())
	_add_stats(box, accent)
	box.add_child(PixelTheme.divider())
	_add_actions(box, accent)


## Tower name, and the rank as pips rather than as text, so it matches the pips
## drawn on the tower itself.
func _add_header(box: VBoxContainer, accent: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)

	var name_label := PixelTheme.make_label(_tower.data.display_name.to_upper(), 16, PixelTheme.GOLD)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 3)
	pips.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(pips)

	var maxed: bool = _tower.is_max_level()
	for i in _tower.data.levels.size():
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(8.0, 8.0)
		if i <= _tower.level_index:
			pip.color = PixelTheme.GOLD if maxed else accent
		else:
			pip.color = PixelTheme.SOCKET
		pips.add_child(pip)

	var caption: String = "MAX RANK" if maxed else "RANK %d" % (_tower.level_index + 1)
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 8)
	box.add_child(sub)

	var caption_label := PixelTheme.make_label(caption, 11, PixelTheme.MUTED)
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.add_child(caption_label)
	sub.add_child(PixelTheme.make_label(_weapon_line(), 11, PixelTheme.MUTED))


## Which rows to show depends on the weapon. Reach and recharge matter for a
## spell; rate of fire does not, because it never fires on its own.
func _add_stats(box: VBoxContainer, accent: Color) -> void:
	var now := _tower.current_level()
	var soon := _tower.next_level()
	var top := _tower.data.levels[_tower.data.max_level_index()] as TowerLevel
	if now == null or top == null:
		return

	var kind: String = _tower.data.attack_kind

	if kind == "ability":
		_add_row(box, "POWER", now.damage, _next_of(soon, now, "damage"), top.damage, 0, "", accent, false)
		_add_row(box, "REACH", now.attack_range, _next_of(soon, now, "attack_range"), top.attack_range, 0, "", accent, false)
		_add_row(box, "BLAST", now.splash_radius, _next_of(soon, now, "splash_radius"), top.splash_radius, 0, "", accent, false)
		_add_row(box, "CYCLE", now.recharge_time, _next_of(soon, now, "recharge_time"), top.recharge_time, 0, "s", accent, true)
		return

	_add_row(box, "DMG", now.damage, _next_of(soon, now, "damage"), top.damage, 0, "", accent, false)
	_add_row(box, "RANGE", now.attack_range, _next_of(soon, now, "attack_range"), top.attack_range, 0, "", accent, false)
	_add_row(box, "RATE", now.fire_rate, _next_of(soon, now, "fire_rate"), top.fire_rate, 2, "/s", accent, false)

	if now.splash_radius > 0.0:
		_add_row(box, "BLAST", now.splash_radius, _next_of(soon, now, "splash_radius"), top.splash_radius, 0, "", accent, false)
	elif now.windup_time > 0.0:
		_add_row(box, "CHARGE", now.windup_time, _next_of(soon, now, "windup_time"), top.windup_time, 2, "s", accent, true)

	# Sustained output, which is the number that actually decides a purchase and
	# the one players otherwise work out on paper.
	var dps: float = now.damage * now.fire_rate
	var dps_text: String = "SUSTAINED  %s dmg/s" % String.num(dps, 1)
	if soon != null:
		dps_text += "   \u2192  %s" % String.num(soon.damage * soon.fire_rate, 1)
	box.add_child(PixelTheme.make_label(dps_text, 11, PixelTheme.MUTED))


func _add_actions(box: VBoxContainer, accent: Color) -> void:
	if _tower.can_upgrade():
		var cost: int = _tower.upgrade_cost()
		var affordable: bool = GameState.can_afford(cost)

		var upgrade_button := Button.new()
		upgrade_button.text = "UPGRADE TO RANK %d      %d g" % [_tower.level_index + 2, cost]
		upgrade_button.disabled = not affordable
		upgrade_button.pressed.connect(_on_upgrade_pressed)
		PixelTheme.apply_button(upgrade_button, PixelTheme.GOLD)
		box.add_child(upgrade_button)

		if not affordable:
			# Naming the shortfall is more useful than a greyed-out button, which
			# only says "no".
			var short: int = cost - GameState.gold
			box.add_child(PixelTheme.make_label("Short by %d gold." % short, 11, PixelTheme.LOSS))
	else:
		box.add_child(PixelTheme.make_label("Fully upgraded.", 12, PixelTheme.GOLD))

	var sell_button := Button.new()
	sell_button.text = "SELL      +%d g" % _tower.sell_value()
	sell_button.pressed.connect(_on_sell_pressed)
	PixelTheme.apply_button(sell_button, PixelTheme.LOSS)
	box.add_child(sell_button)


## One stat: name, a segmented bar, the current value, and the value after an
## upgrade. `lower_is_better` covers recharge and wind-up, where a smaller
## number is the improvement.
func _add_row(box: VBoxContainer, label_text: String, now: float, soon: float, ceiling: float, decimals: int, suffix: String, accent: Color, lower_is_better: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)

	var name_label := PixelTheme.make_label(label_text, 11, PixelTheme.MUTED)
	name_label.custom_minimum_size = Vector2(48.0, 0.0)
	row.add_child(name_label)

	row.add_child(_make_bar(_fill(now, ceiling, lower_is_better), _fill(soon, ceiling, lower_is_better), accent))

	var value_label := PixelTheme.make_label(_format(now, decimals) + suffix, 12, PixelTheme.PARCHMENT)
	value_label.custom_minimum_size = Vector2(42.0, 0.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	if not is_equal_approx(now, soon):
		row.add_child(PixelTheme.make_label("\u2192 " + _format(soon, decimals), 12, PixelTheme.GAIN))


## Lit cells for the current value, then the upgrade's gain previewed in green
## in the very same bar, then empty sockets.
func _make_bar(fill: float, next_fill: float, accent: Color) -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 2)

	var lit: int = int(round(fill * float(BAR_CELLS)))
	var gain: int = int(round(next_fill * float(BAR_CELLS)))

	for i in BAR_CELLS:
		var cell := ColorRect.new()
		cell.custom_minimum_size = CELL_SIZE
		if i < lit:
			cell.color = accent
		elif i < gain:
			cell.color = Color(PixelTheme.GAIN.r, PixelTheme.GAIN.g, PixelTheme.GAIN.b, 0.55)
		else:
			cell.color = PixelTheme.SOCKET
		bar.add_child(cell)

	return bar


## Reads a property off the next level, falling back to the current value when
## the tower is already topped out, so "no change" needs no special casing.
func _next_of(soon: TowerLevel, now: TowerLevel, property: String) -> float:
	if soon == null:
		return float(now.get(property))
	return float(soon.get(property))


func _fill(value: float, ceiling: float, lower_is_better: bool) -> float:
	if ceiling <= 0.0 or value <= 0.0:
		return 0.0
	# Inverted stats are measured against the best (smallest) value the tower
	# will ever reach, so a shorter recharge still fills the bar up.
	if lower_is_better:
		return clampf(ceiling / value, 0.0, 1.0)
	return clampf(value / ceiling, 0.0, 1.0)


func _format(value: float, decimals: int) -> String:
	if decimals <= 0:
		return str(int(round(value)))
	return String.num(value, decimals)


## One line of plain language about how this tower attacks. Cheaper than a
## tutorial and it stops the spell tower's missing fire rate looking like a bug.
func _weapon_line() -> String:
	match _tower.data.attack_kind:
		"beam":
			return "charges, then strikes"
		"mortar":
			return "lobs shells"
		"ability":
			return "click rune to cast"
		_:
			return "rapid fire"


func _on_upgrade_pressed() -> void:
	if _tower == null or not _tower.can_upgrade():
		return
	var cost: int = _tower.upgrade_cost()
	if not GameState.spend_gold(cost):
		return
	_tower.upgrade()
	# Stay open so upgrades can be chained without re-clicking.
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
