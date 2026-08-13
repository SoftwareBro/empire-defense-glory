class_name Level
extends Node2D

## One playable level. All content comes from `data`; this script is the system.

const BUILD_PLOT_SCENE: PackedScene = preload("res://scenes/towers/BuildPlot.tscn")

@export var data: LevelData
@export var enemy_scene: PackedScene

@onready var background: Sprite2D = $Background
@onready var path: Path2D = $Path2D
@onready var path_line: Line2D = $PathLine
@onready var plots: Node2D = $Plots
@onready var enemies: Node2D = $Enemies
@onready var build_menu: BuildMenu = $BuildMenu

var _wave_index: int = 0


func _ready() -> void:
	if data == null:
		push_error("Level has no LevelData assigned.")
		return

	if data.background != null:
		background.texture = data.background

	# Build the route from data when provided, otherwise use the hand-drawn Path2D.
	if data.path_points.size() >= 2:
		var curve := Curve2D.new()
		for point in data.path_points:
			curve.add_point(point)
		path.curve = curve

	# Debug road so the route is visible before real art exists.
	if path.curve != null:
		path_line.points = path.curve.get_baked_points()

	_spawn_plots()

	GameState.setup(data)
	Events.level_lost.connect(_on_level_lost)


func _spawn_plots() -> void:
	for point in data.plot_points:
		var plot: BuildPlot = BUILD_PLOT_SCENE.instantiate()
		plot.position = point
		plot.pressed.connect(_on_plot_pressed)
		plots.add_child(plot)


func _on_plot_pressed(plot: BuildPlot) -> void:
	build_menu.open(plot, data.available_towers)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		start_next_wave()
		return

	# Any click that was not caught by a plot or a menu button dismisses the menu.
	if event is InputEventMouseButton and event.pressed:
		build_menu.close()


func start_next_wave() -> void:
	if data == null or _wave_index >= data.waves.size():
		return

	var wave: WaveData = data.waves[_wave_index]
	_wave_index += 1
	GameState.current_wave = _wave_index
	Events.wave_changed.emit(_wave_index, data.waves.size())

	# Each entry runs as its own coroutine so groups spawn concurrently.
	for entry in wave.entries:
		_run_entry(entry)


func _run_entry(entry: WaveEntry) -> void:
	if entry == null:
		return

	if entry.start_delay > 0.0:
		await get_tree().create_timer(entry.start_delay).timeout

	for i in entry.count:
		if not is_inside_tree():
			return
		spawn_enemy(entry.enemy)
		if i < entry.count - 1:
			await get_tree().create_timer(entry.interval).timeout


func spawn_enemy(enemy_data: EnemyData) -> void:
	if enemy_data == null or enemy_scene == null:
		return

	var enemy := enemy_scene.instantiate() as Enemy
	enemy.setup(enemy_data, path)
	enemies.add_child(enemy)
	Events.enemy_spawned.emit(enemy)


func _on_level_lost() -> void:
	print("Level lost — all lives gone.")
