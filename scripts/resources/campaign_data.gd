class_name CampaignData
extends Resource

## The ordered list of world-map nodes. Node N unlocks when node N-1 is beaten,
## so progression is implied by order rather than hand-wired per level.

@export var nodes: Array = []


func node_by_id(node_id: StringName) -> CampaignNode:
	for entry in nodes:
		var node := entry as CampaignNode
		if node != null and node.id == node_id:
			return node
	return null


func index_of(node_id: StringName) -> int:
	for i in nodes.size():
		var node := nodes[i] as CampaignNode
		if node != null and node.id == node_id:
			return i
	return -1
