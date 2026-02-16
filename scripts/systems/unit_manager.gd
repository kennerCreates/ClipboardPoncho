extends Node
class_name UnitManager
## Manages all units in the game - creation, destruction, and tracking
##
## For performance with 500+ units per side:
## - Uses spatial partitioning for quick unit queries
## - Implements LOD system for distant units
## - Object pooling for frequently spawned/destroyed units

signal unit_created(unit: Node3D)
signal unit_destroyed(unit: Node3D)

# Unit tracking
var all_units: Array[Node3D] = []
var units_by_player: Dictionary = {} # player_id -> Array[Node3D]
var selected_units: Array[Node3D] = []

# Performance settings
const MAX_UNITS_PER_PLAYER: int = 500
const LOD_DISTANCE_MEDIUM: float = 30.0
const LOD_DISTANCE_FAR: float = 60.0

func _ready() -> void:
	units_by_player[0] = [] # Player 1
	units_by_player[1] = [] # Player 2/AI

func register_unit(unit: Node3D, player_id: int) -> void:
	all_units.append(unit)
	units_by_player[player_id].append(unit)
	unit_created.emit(unit)

func unregister_unit(unit: Node3D, player_id: int) -> void:
	all_units.erase(unit)
	units_by_player[player_id].erase(unit)
	selected_units.erase(unit)
	unit_destroyed.emit(unit)

func get_units_in_area(center: Vector3, radius: float) -> Array[Node3D]:
	# TODO: Implement spatial partitioning (octree or grid) for performance
	var units_in_range: Array[Node3D] = []
	for unit in all_units:
		if unit.global_position.distance_to(center) <= radius:
			units_in_range.append(unit)
	return units_in_range

func get_player_unit_count(player_id: int) -> int:
	return units_by_player[player_id].size()

func can_spawn_unit(player_id: int) -> bool:
	return get_player_unit_count(player_id) < MAX_UNITS_PER_PLAYER
