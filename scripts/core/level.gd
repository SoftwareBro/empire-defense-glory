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
@onready var upgrade_panel: UpgradePanel = $UpgradePanel
@onready var wave_manager: WaveManager = $WaveManager


func _ready() -> void:
	# The campaign chooses the level. The exported value is only a fallback for
	# running this scene straight from the editor.
	if Campaign.current_node != null and Campaign.current_node.level != null:
		data = Campaign.current_node.level

	if data == null:
		push_error("Level has no LevelData assigned.")
		return

	Events.level_won.connect(_on_level_won)

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

	# Economy first, so the HUD shows real numbers before the countdown ticks.
	GameState.setup(data)

	wave_manager.setup(data.waves, spawn_enemy)
	wave_manager.start()


func _spawn_plots() -> void:
	for point in data.plot_points:
		var plot: BuildPlot = BUILD_PLOT_SCENE.instantiate()
		plot.position = point
		plot.pressed.connect(_on_plot_pressed)
		plots.add_child(plot)


## Empty plot opens the build menu; a built one opens the upgrade panel.
func _on_plot_pressed(plot: BuildPlot) -> void:
	if plot.is_occupied():
		build_menu.close()
		upgrade_panel.open(plot.tower)
	else:
		upgrade_panel.close()
		build_menu.open(plot, data.available_towers)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		wave_manager.call_wave_early()
		return

	# Any click not caught by a plot or a menu button dismisses both menus.
	if event is InputEventMouseButton and event.pressed:
		build_menu.close()
		upgrade_panel.close()


## Passed to WaveManager as a Callable so waves never touch enemy scenes.
func spawn_enemy(enemy_data: EnemyData) -> void:
	if enemy_data == null or enemy_scene == null:
		return

	var enemy := enemy_scene.instantiate() as Enemy
	enemy.setup(enemy_data, path)
	enemies.add_child(enemy)
	Events.enemy_spawned.emit(enemy)


func _on_level_won() -> void:
	Campaign.complete_current_level(GameState.stars_earned())
