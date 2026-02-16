extends Node
class_name UnitManager
## Manages all units in the game - creation, destruction, and tracking
##
## NEW ARCHITECTURE: Uses data-oriented design with MultiMesh rendering
## - UnitDataSystem: Stores all unit data in packed arrays
## - UnitRenderSystem: Renders using MultiMesh with frustum culling
## - MovementSystem: Handles movement and collision avoidance
## - SpatialGrid: Fast spatial queries for nearby units

signal unit_created(unit_idx: int)  # Now emits unit index instead of Node3D
signal unit_destroyed(unit_idx: int)

# Core systems
var unit_data: UnitDataSystem
var unit_render: UnitRenderSystem
var movement: MovementSystem
var spatial_grid: SpatialGrid

# Unit tracking by player
var units_by_player: Dictionary = {}  # player_id -> Array[int] (unit indices)
var selected_units: Array[int] = []  # Array of selected unit indices

# Performance settings
const MAX_UNITS_PER_PLAYER: int = 500

# Camera reference (set by GameManager)
var camera: Camera3D

func _ready() -> void:
	# Initialize systems
	unit_data = UnitDataSystem.new()
	add_child(unit_data)

	unit_render = UnitRenderSystem.new()
	add_child(unit_render)
	unit_render.initialize(unit_data)

	spatial_grid = SpatialGrid.new()
	add_child(spatial_grid)

	movement = MovementSystem.new()
	add_child(movement)
	movement.initialize(unit_data, spatial_grid)

	# Initialize player tracking
	units_by_player[0] = []  # Player 1
	units_by_player[1] = []  # Player 2/AI

	# Connect signals
	unit_data.unit_spawned.connect(_on_unit_spawned)
	unit_data.unit_removed.connect(_on_unit_removed)

## Spawn a new unit
func spawn_unit(player_id: int, unit_type: UnitDataSystem.UnitType, spawn_pos: Vector3) -> int:
	if not can_spawn_unit(player_id):
		return -1

	var unit_idx = unit_data.spawn_unit(player_id, unit_type, spawn_pos)
	return unit_idx

## Remove a unit
func remove_unit(unit_idx: int) -> void:
	unit_data.remove_unit(unit_idx)

## Get units in an area (returns array of unit indices)
func get_units_in_area(center: Vector3, radius: float) -> Array[int]:
	return spatial_grid.query_radius(center, radius)

## Get player unit count
func get_player_unit_count(player_id: int) -> int:
	return units_by_player[player_id].size()

## Can spawn more units?
func can_spawn_unit(player_id: int) -> bool:
	return get_player_unit_count(player_id) < MAX_UNITS_PER_PLAYER

## Command units to move
func command_move(unit_indices: Array[int], target_pos: Vector3) -> void:
	movement.command_move_group(unit_indices, target_pos)

## Update all systems (called from GameManager)
func update(delta: float) -> void:
	if not camera:
		return

	var frustum = camera.get_frustum()

	# Update movement
	movement.update(delta, frustum)

	# Update rendering
	unit_render.update(camera)

## Set camera reference
func set_camera(cam: Camera3D) -> void:
	camera = cam

## Signal handlers
func _on_unit_spawned(unit_idx: int) -> void:
	var player_id = unit_data.player_ids[unit_idx]
	units_by_player[player_id].append(unit_idx)
	unit_created.emit(unit_idx)

func _on_unit_removed(unit_idx: int) -> void:
	var player_id = unit_data.player_ids[unit_idx]
	units_by_player[player_id].erase(unit_idx)
	selected_units.erase(unit_idx)
	unit_destroyed.emit(unit_idx)

## Debug: Get total unit count
func get_total_unit_count() -> int:
	return unit_data.unit_count - unit_data.free_slots.size()

## Debug: Get visible unit count
func get_visible_unit_count() -> int:
	return unit_render.get_visible_unit_count()
