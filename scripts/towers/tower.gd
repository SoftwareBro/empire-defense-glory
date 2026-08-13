class_name Tower
extends Node2D

## A built tower. In M2 it only exists and shows its range; targeting and
## shooting arrive in M3, upgrades in M5. The level ladder already works.

@export var data: TowerData

## Index into data.levels. Bumped by the upgrade panel in M5.
var level_index: int = 0
var show_range: bool = false


func _ready() -> void:
	if data == null:
		push_error("Tower placed without TowerData.")
		queue_free()
		return
	queue_redraw()


func current_level() -> TowerLevel:
	if data == null or data.levels.is_empty():
		return null
	return data.levels[clampi(level_index, 0, data.levels.size() - 1)]


func get_attack_range() -> float:
	var lvl := current_level()
	return lvl.attack_range if lvl != null else 0.0


func set_range_visible(value: bool) -> void:
	if show_range == value:
		return
	show_range = value
	queue_redraw()


func _draw() -> void:
	if data == null:
		return

	if show_range:
		var r := get_attack_range()
		draw_circle(Vector2.ZERO, r, Color(1.0, 1.0, 1.0, 0.06))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.35), 2.0)

	# Placeholder body. Replaced by painted art in M7.
	draw_circle(Vector2.ZERO, 24.0, Color(0.07, 0.07, 0.09, 0.95))
	draw_circle(Vector2.ZERO, 19.0, data.accent_color)
