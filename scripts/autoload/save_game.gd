extends Node

## Three independent save slots written to user:// as JSON.
##
## A slot only ever stores results: { "levels": { "m1_v1": 3, "m1_v2": 2 } }.
## Unlock state is derived from that at runtime, so adding levels later never
## invalidates an existing save.

const SLOT_COUNT: int = 3

var current_slot: int = -1
var data: Dictionary = {}


func slot_path(slot: int) -> String:
	return "user://slot_%d.json" % slot


func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## Reads a slot without making it current. Used by the main menu.
func peek_slot(slot: int) -> Dictionary:
	if not slot_exists(slot):
		return {}

	var file := FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


## { completed, stars } for the menu, or {} when the slot is empty.
func slot_summary(slot: int) -> Dictionary:
	var raw := peek_slot(slot)
	if raw.is_empty():
		return {}

	var levels: Dictionary = raw.get("levels", {})
	var stars: int = 0
	for key in levels:
		stars += int(levels[key])

	return { "completed": levels.size(), "stars": stars }


## Opens a slot, creating it if it does not exist yet.
func load_slot(slot: int) -> void:
	current_slot = slot
	var loaded := peek_slot(slot)
	data = loaded if not loaded.is_empty() else { "levels": {} }
	if not data.has("levels"):
		data["levels"] = {}
	save()


func delete_slot(slot: int) -> void:
	if slot_exists(slot):
		DirAccess.remove_absolute(slot_path(slot))
	if current_slot == slot:
		current_slot = -1
		data = {}


func save() -> void:
	if current_slot < 0:
		return

	var file := FileAccess.open(slot_path(current_slot), FileAccess.WRITE)
	if file == null:
		push_error("Could not write save slot %d." % current_slot)
		return
	file.store_string(JSON.stringify(data))
	file.close()


func stars_for(level_id: StringName) -> int:
	var levels: Dictionary = data.get("levels", {})
	return int(levels.get(String(level_id), 0))


func is_completed(level_id: StringName) -> bool:
	var levels: Dictionary = data.get("levels", {})
	return levels.has(String(level_id))


## Keeps the best run. A worse replay never downgrades an earned rating.
func record_result(level_id: StringName, stars: int) -> void:
	if current_slot < 0 or stars <= 0:
		return

	var levels: Dictionary = data.get("levels", {})
	var key := String(level_id)
	levels[key] = maxi(int(levels.get(key, 0)), stars)
	data["levels"] = levels
	save()


func total_stars() -> int:
	var total: int = 0
	var levels: Dictionary = data.get("levels", {})
	for key in levels:
		total += int(levels[key])
	return total


func reset_progress() -> void:
	data = { "levels": {} }
	save()
