class_name TowerData
extends Resource

## A tower type. Add a tower by creating a .tres in `data/towers/` — never by
## writing code. The build menu, costs and upgrade panel all read from here.

@export var id: StringName = &"archer"
@export var display_name: String = "Archer Tower"
## Short label shown on the radial build button.
@export var short_name: String = "Archer"
@export var build_cost: int = 70
@export var icon: Texture2D
## Placeholder tint until real art lands.
@export var accent_color: Color = Color.WHITE

## Array of TowerLevel. Index 0 is level 1.
@export var levels: Array = []

@export_group("Specializations")
## Unlocked once the tower reaches max level. Pick one, permanently.
@export var branch_a: TowerLevel
@export var branch_a_name: String = ""
@export var branch_b: TowerLevel
@export var branch_b_name: String = ""


func max_level_index() -> int:
	return maxi(0, levels.size() - 1)
