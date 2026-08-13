class_name BuildPlot
extends Area2D

## A fixed tower slot on the map. Kingdom Rush uses fixed plots rather than
## free placement — it is the genre standard and removes a whole class of
## pathing and overlap problems.

signal pressed(plot: BuildPlot)

const TOWER_SCENE: PackedScene = preload("res://scenes/towers/TowerBase.tscn")
const RADIUS: float = 26.0

var tower: Tower = null

var _hovered: bool = false


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func is_occupied() -> bool:
	return tower != null and is_instance_valid(tower)


func build_tower(tower_data: TowerData) -> Tower:
	if is_occupied() or tower_data == null:
		return null

	var new_tower: Tower = TOWER_SCENE.instantiate()
	new_tower.data = tower_data
	add_child(new_tower)
	tower = new_tower
	queue_redraw()
	Events.tower_built.emit(new_tower, tower_data.build_cost)
	return new_tower


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_occupied():
			pressed.emit(self)
			# Stops Level._unhandled_input from closing the menu we just opened.
			get_viewport().set_input_as_handled()


func _on_mouse_entered() -> void:
	_hovered = true
	if is_occupied():
		tower.set_range_visible(true)
	queue_redraw()


func _on_mouse_exited() -> void:
	_hovered = false
	if is_occupied():
		tower.set_range_visible(false)
	queue_redraw()


func _draw() -> void:
	if is_occupied():
		return

	var fill: Color = Color(1.0, 0.9, 0.5, 0.28) if _hovered else Color(0.0, 0.0, 0.0, 0.30)
	var ring: Color = Color(1.0, 0.95, 0.6, 1.0) if _hovered else Color(0.85, 0.8, 0.55, 0.65)
	draw_circle(Vector2.ZERO, RADIUS, fill)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, ring, 3.0)
