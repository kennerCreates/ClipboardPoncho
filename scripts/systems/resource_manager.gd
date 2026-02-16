extends Node
class_name ResourceManager
## Manages player resources, worker assignments, and resource gathering
##
## Typical RTS resources: minerals/gas (StarCraft-style) or
## gold/wood/food (Age of Empires-style)

signal resources_changed(player_id: int, resource_type: String, amount: int)
signal supply_changed(player_id: int, current: int, maximum: int)

# Resource types
enum ResourceType { MINERALS, VESPENE, SUPPLY }

# Player resources - player_id -> resource_type -> amount
var player_resources: Dictionary = {}
var player_supply: Dictionary = {} # player_id -> {current: int, max: int}

# Workers assigned to resource nodes
var worker_assignments: Dictionary = {} # worker_node -> resource_node

func _ready() -> void:
	_initialize_player_resources(0) # Player 1
	_initialize_player_resources(1) # Player 2/AI

func _initialize_player_resources(player_id: int) -> void:
	player_resources[player_id] = {
		ResourceType.MINERALS: 50,
		ResourceType.VESPENE: 0,
	}
	player_supply[player_id] = {
		"current": 0,
		"max": 10
	}

func add_resources(player_id: int, resource_type: ResourceType, amount: int) -> void:
	player_resources[player_id][resource_type] += amount
	resources_changed.emit(player_id, ResourceType.keys()[resource_type],
						   player_resources[player_id][resource_type])

func spend_resources(player_id: int, resource_type: ResourceType, amount: int) -> bool:
	if player_resources[player_id][resource_type] >= amount:
		player_resources[player_id][resource_type] -= amount
		resources_changed.emit(player_id, ResourceType.keys()[resource_type],
							   player_resources[player_id][resource_type])
		return true
	return false

func can_afford(player_id: int, costs: Dictionary) -> bool:
	for resource_type in costs:
		if player_resources[player_id][resource_type] < costs[resource_type]:
			return false
	return true

func modify_supply(player_id: int, current_delta: int = 0, max_delta: int = 0) -> void:
	player_supply[player_id]["current"] += current_delta
	player_supply[player_id]["max"] += max_delta
	supply_changed.emit(player_id,
						player_supply[player_id]["current"],
						player_supply[player_id]["max"])

func has_supply_available(player_id: int, required: int = 1) -> bool:
	var supply = player_supply[player_id]
	return (supply["current"] + required) <= supply["max"]
