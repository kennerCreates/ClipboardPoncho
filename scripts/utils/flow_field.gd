extends RefCounted
class_name FlowField
## Flow field pathfinding grid for efficient group pathfinding
##
## Calculates a cost field (distance to goal) and flow vectors (direction to goal)
## that multiple units can share. Much more efficient than A* per unit.

# Grid parameters
var grid_size: Vector2i  # Number of cells (e.g., 128x128)
var cell_size: float = 2.0  # Size of each cell in world units (2 meters)
var world_offset: Vector3  # World position of grid origin (bottom-left)

# Flow field data
var cost_field: PackedFloat32Array  # Cost (distance) to reach goal at each cell
var flow_vectors: PackedVector2Array  # Direction to move at each cell (normalized)
var target_position: Vector3  # World position of the goal

# Cache management
var expiration_time: float = 0.0  # Time when this flow field expires
const CACHE_DURATION: float = 5.0  # Flow fields are valid for 5 seconds

# Constants
const COST_IMPASSABLE: float = INF  # Cost for blocked cells
const COST_CARDINAL: float = 1.0  # Cost for cardinal movement (N, S, E, W)
const COST_DIAGONAL: float = 1.414  # Cost for diagonal movement (√2 ≈ 1.414)

func _init(grid_width: int, grid_height: int, world_min: Vector3, _cell_size: float = 2.0) -> void:
	grid_size = Vector2i(grid_width, grid_height)
	cell_size = _cell_size
	world_offset = world_min

	# Pre-allocate arrays
	var total_cells = grid_width * grid_height
	cost_field.resize(total_cells)
	flow_vectors.resize(total_cells)

	# Initialize with impassable costs
	for i in range(total_cells):
		cost_field[i] = COST_IMPASSABLE
		flow_vectors[i] = Vector2.ZERO

## Generate flow field to a target world position
## Uses breadth-first search with distance-corrected costs
func generate_to_target(target_world_pos: Vector3, current_time: float) -> void:
	target_position = target_world_pos
	expiration_time = current_time + CACHE_DURATION

	# Clear previous data
	for i in range(cost_field.size()):
		cost_field[i] = COST_IMPASSABLE
		flow_vectors[i] = Vector2.ZERO

	# Convert target to grid coordinates
	var target_cell = world_to_grid(target_world_pos)
	if not is_valid_cell(target_cell):
		push_warning("FlowField: Target position outside grid bounds")
		return

	# Breadth-first search from goal
	_generate_cost_field(target_cell)

	# Generate flow vectors from cost gradients
	_generate_flow_vectors()

## Generate cost field using breadth-first search
## Each cell stores the distance cost to reach the goal
func _generate_cost_field(start_cell: Vector2i) -> void:
	var queue: Array[Vector2i] = []

	# Start at goal with cost 0
	var start_idx = cell_to_index(start_cell)
	cost_field[start_idx] = 0.0
	queue.append(start_cell)

	# BFS expansion
	while queue.size() > 0:
		var current = queue.pop_front()
		var current_cost = cost_field[cell_to_index(current)]

		# Check all 8 neighbors (cardinal + diagonal)
		for neighbor_offset in [
			Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0),  # Cardinal
			Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)  # Diagonal
		]:
			var neighbor = current + neighbor_offset

			if not is_valid_cell(neighbor):
				continue

			# Determine cost based on movement type
			var is_cardinal = (neighbor_offset.x == 0) or (neighbor_offset.y == 0)
			var movement_cost = COST_CARDINAL if is_cardinal else COST_DIAGONAL
			var new_cost = current_cost + movement_cost

			var neighbor_idx = cell_to_index(neighbor)

			# Update if we found a cheaper path
			if new_cost < cost_field[neighbor_idx]:
				cost_field[neighbor_idx] = new_cost
				queue.append(neighbor)

## Generate flow vectors from cost field gradients
## Each cell points toward its lowest-cost neighbor
func _generate_flow_vectors() -> void:
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var cell = Vector2i(x, y)
			var cell_idx = cell_to_index(cell)

			# Skip impassable cells
			if cost_field[cell_idx] == COST_IMPASSABLE:
				continue

			# Find lowest-cost neighbor
			var best_neighbor = cell
			var best_cost = cost_field[cell_idx]

			for neighbor_offset in [
				Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0),
				Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
			]:
				var neighbor = cell + neighbor_offset

				if not is_valid_cell(neighbor):
					continue

				var neighbor_idx = cell_to_index(neighbor)
				var neighbor_cost = cost_field[neighbor_idx]

				if neighbor_cost < best_cost:
					best_cost = neighbor_cost
					best_neighbor = neighbor

			# Calculate direction to best neighbor
			if best_neighbor != cell:
				var direction = Vector2(best_neighbor - cell).normalized()
				flow_vectors[cell_idx] = direction
			else:
				# Already at goal or local minimum
				flow_vectors[cell_idx] = Vector2.ZERO

## Get flow direction at a world position
## Returns normalized 2D direction (XZ plane)
func get_flow_at_position(world_pos: Vector3) -> Vector2:
	var cell = world_to_grid(world_pos)
	if not is_valid_cell(cell):
		return Vector2.ZERO

	return flow_vectors[cell_to_index(cell)]

## Get cost at a world position
func get_cost_at_position(world_pos: Vector3) -> float:
	var cell = world_to_grid(world_pos)
	if not is_valid_cell(cell):
		return COST_IMPASSABLE

	return cost_field[cell_to_index(cell)]

## Check if flow field is still valid (not expired)
func is_valid(current_time: float) -> bool:
	return current_time < expiration_time

## Convert world position to grid cell coordinates
func world_to_grid(world_pos: Vector3) -> Vector2i:
	var local_pos = world_pos - world_offset
	return Vector2i(
		int(local_pos.x / cell_size),
		int(local_pos.z / cell_size)
	)

## Convert grid cell to world position (center of cell)
func grid_to_world(cell: Vector2i) -> Vector3:
	return world_offset + Vector3(
		cell.x * cell_size + cell_size * 0.5,
		0.0,
		cell.y * cell_size + cell_size * 0.5
	)

## Check if cell coordinates are within grid bounds
func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_size.x and cell.y >= 0 and cell.y < grid_size.y

## Convert 2D cell coordinates to 1D array index
func cell_to_index(cell: Vector2i) -> int:
	return cell.y * grid_size.x + cell.x

## Convert 1D array index to 2D cell coordinates
func index_to_cell(index: int) -> Vector2i:
	return Vector2i(index % grid_size.x, int(index / grid_size.x))
