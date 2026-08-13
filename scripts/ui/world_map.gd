extends Node2D

## The open-world level select. Node buttons are generated from CampaignData,
## so adding a level never means touching this scene.

const NODE_SIZE: Vector2 = Vector2(142, 64)

@onready var trail: Line2D = $Trail
@onready var nodes_root: Node2D = $Nodes
@onready var marker: Node2D = $Marker
@onready var header: Label = %Header
@onready var back_button: Button = %BackButton
@onready var win_banner: Control = %WinBanner
@onready var win_label: Label = %WinLabel
@onready var win_button: Button = %WinButton


func _ready() -> void:
	back_button.pressed.connect(Campaign.go_to_main_menu)
	win_button.pressed.connect(_on_play_again)

	win_banner.visible = false
	marker.visible = false

	_build_trail()
	_build_nodes()
	_update_header()
	_play_unlock_step()


func _build_trail() -> void:
	var points := PackedVector2Array()
	for entry in Campaign.nodes():
		var node := entry as CampaignNode
		if node != null:
			points.append(node.map_position)
	trail.points = points


func _build_nodes() -> void:
	for child in nodes_root.get_children():
		nodes_root.remove_child(child)
		child.queue_free()

	for entry in Campaign.nodes():
		var node := entry as CampaignNode
		if node == null:
			continue

		var button := Button.new()
		button.custom_minimum_size = NODE_SIZE
		button.size = NODE_SIZE
		button.position = node.map_position - NODE_SIZE * 0.5
		button.text = _button_text(node)
		button.disabled = not Campaign.is_unlocked(node)
		button.pressed.connect(_on_node_pressed.bind(node))
		nodes_root.add_child(button)


func _button_text(node: CampaignNode) -> String:
	if node.level == null:
		return "%s\nNot built yet" % node.map_label
	if SaveGame.is_completed(node.id):
		return "%s\n%s" % [node.map_label, _stars(SaveGame.stars_for(node.id))]
	if Campaign.is_unlocked(node):
		return "%s\nPlay" % node.map_label
	return "%s\nLocked" % node.map_label


func _stars(count: int) -> String:
	var out: String = ""
	for i in 3:
		out += "★" if i < count else "☆"
	return out


func _update_header() -> void:
	header.text = "Greenwood Campaign   ·   Slot %d   ·   %d ★" % [
		SaveGame.current_slot,
		SaveGame.total_stars(),
	]


func _on_node_pressed(node: CampaignNode) -> void:
	Campaign.start_level(node)


## Walks a marker from the level just cleared to the one it opened up.
func _play_unlock_step() -> void:
	if Campaign.campaign_just_finished:
		_show_win()
		return

	var from_node := Campaign.node_by_id(Campaign.just_completed_id)
	var to_node := Campaign.node_by_id(Campaign.just_unlocked_id)
	Campaign.just_completed_id = &""
	Campaign.just_unlocked_id = &""

	if from_node == null or to_node == null:
		return

	marker.position = from_node.map_position
	marker.visible = true

	var tween := create_tween()
	tween.tween_interval(0.35)
	tween.tween_property(marker, "position", to_node.map_position, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_on_marker_arrived)


func _on_marker_arrived() -> void:
	marker.visible = false
	_build_nodes()


func _show_win() -> void:
	Campaign.campaign_just_finished = false
	Campaign.just_completed_id = &""
	Campaign.just_unlocked_id = &""
	win_label.text = "Every built level cleared with %d stars.\nStarting again resets this slot." % SaveGame.total_stars()
	win_banner.visible = true


func _on_play_again() -> void:
	SaveGame.reset_progress()
	get_tree().reload_current_scene()
