extends Node

## Owns campaign progression and every scene change between menu, map and level.
## Nothing else calls change_scene_to_file, so flow stays in one place.

const DATA_PATH: String = "res://data/campaign/campaign.tres"
const LEVEL_SCENE: String = "res://scenes/core/Level.tscn"
const WORLD_MAP_SCENE: String = "res://scenes/ui/WorldMap.tscn"
const MAIN_MENU_SCENE: String = "res://scenes/ui/MainMenu.tscn"

var data: CampaignData

## The node currently being played. Null when running Level.tscn directly.
var current_node: CampaignNode = null
## Set on a win so the world map can animate the step to the next level.
var just_completed_id: StringName = &""
var just_unlocked_id: StringName = &""
var campaign_just_finished: bool = false


func _ready() -> void:
	data = load(DATA_PATH) as CampaignData
	if data == null:
		push_error("Campaign data failed to load from %s" % DATA_PATH)


func nodes() -> Array:
	return data.nodes if data != null else []


func node_by_id(node_id: StringName) -> CampaignNode:
	return data.node_by_id(node_id) if data != null else null


## Playable when the level exists and the previous node has been cleared.
func is_unlocked(node: CampaignNode) -> bool:
	if node == null or node.level == null or data == null:
		return false

	var index := data.index_of(node.id)
	if index <= 0:
		return true

	var previous := data.nodes[index - 1] as CampaignNode
	return previous == null or SaveGame.is_completed(previous.id)


## How many nodes actually have a level built behind them.
func playable_count() -> int:
	var count: int = 0
	for entry in nodes():
		var node := entry as CampaignNode
		if node != null and node.level != null:
			count += 1
	return count


func is_campaign_complete() -> bool:
	var built: int = 0
	var done: int = 0
	for entry in nodes():
		var node := entry as CampaignNode
		if node == null or node.level == null:
			continue
		built += 1
		if SaveGame.is_completed(node.id):
			done += 1
	return built > 0 and done == built


func start_level(node: CampaignNode) -> void:
	current_node = node
	just_completed_id = &""
	just_unlocked_id = &""
	campaign_just_finished = false
	get_tree().paused = false
	get_tree().change_scene_to_file(LEVEL_SCENE)


## Records the result and works out what the world map should animate next.
func complete_current_level(stars: int) -> void:
	if current_node == null:
		return

	var was_complete := is_campaign_complete()
	SaveGame.record_result(current_node.id, stars)
	just_completed_id = current_node.id
	just_unlocked_id = &""

	var index := data.index_of(current_node.id) if data != null else -1
	if index >= 0 and index + 1 < nodes().size():
		var next_node := nodes()[index + 1] as CampaignNode
		if next_node != null and next_node.level != null:
			just_unlocked_id = next_node.id

	campaign_just_finished = (not was_complete) and is_campaign_complete()


func go_to_world_map() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(WORLD_MAP_SCENE)


func go_to_main_menu() -> void:
	get_tree().paused = false
	current_node = null
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func restart_level() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
