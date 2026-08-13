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

@export_group("Targeting")
## first    = furthest along the path (the classic tower defense default)
## last     = least far along, good for cleanup towers
## closest  = nearest to the tower
## strongest = highest current health
@export_enum("first", "last", "closest", "strongest") var targeting_mode: String = "first"
## Ground-only towers (barracks, artillery) cannot shoot flyers.
@export var can_hit_flying: bool = true

## Array of TowerLevel. Index 0 is level 1. The last entry is the tower's
## ceiling — there is no branching tier past it.
@export var levels: Array = []


func max_level_index() -> int:
	return maxi(0, levels.size() - 1)
