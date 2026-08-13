class_name CampaignNode
extends Resource

## One node on the world map. A node with no `level` is a placeholder: it draws
## locked and can never be entered, which is how unbuilt content is staged.

@export var id: StringName = &""
@export var display_name: String = ""
## Short label drawn on the map button.
@export var map_label: String = ""
@export var level: LevelData
@export var map_position: Vector2 = Vector2.ZERO
@export var is_boss: bool = false
