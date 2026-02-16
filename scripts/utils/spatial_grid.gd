extends Node
class_name SpatialGrid
## Fast spatial queries using grid-based hashing
##
## Divides world space into cells for O(1) insertion and O(k) queries,
## where k = units in nearby cells (not all units). Essential for collision
## avoidance and vision checks with 1000 units.
##
## Example: Instead of checking all 1000 units for nearby collisions,
## only check ~20-30 units in the same grid cell and neighbors.

# Grid storage: grid_key -> Array[unit_index]
var grid: Dictionary = {}

# Grid configuration
var cell_size: float = 10.0  # 10 meters per cell

## Clear all units from grid
func clear() -> void:
	grid.clear()

## Insert a unit into the grid
func insert(unit_idx: int, pos: Vector3) -> void:
	var key = _get_grid_key(pos)
	if not key in grid:
		grid[key] = []
	grid[key].append(unit_idx)

## Remove a unit from the grid (must know its position)
func remove(unit_idx: int, pos: Vector3) -> void:
	var key = _get_grid_key(pos)
	if key in grid:
		grid[key].erase(unit_idx)
		if grid[key].is_empty():
			grid.erase(key)

## Update a unit's position in the grid
func update_position(unit_idx: int, old_pos: Vector3, new_pos: Vector3) -> void:
	var old_key = _get_grid_key(old_pos)
	var new_key = _get_grid_key(new_pos)

	# If cell hasn't changed, no need to update
	if old_key == new_key:
		return

	# Remove from old cell
	if old_key in grid:
		grid[old_key].erase(unit_idx)
		if grid[old_key].is_empty():
			grid.erase(old_key)

	# Add to new cell
	if not new_key in grid:
		grid[new_key] = []
	grid[new_key].append(unit_idx)

## Query all units within a radius of a position
## This is much faster than checking all units because it only checks nearby cells
func query_radius(pos: Vector3, radius: float) -> Array[int]:
	var results: Array[int] = []
	var cells_to_check = _get_cells_in_radius(pos, radius)

	for cell_key in cells_to_check:
		if cell_key in grid:
			# Add all units in this cell
			for unit_idx in grid[cell_key]:
				if not unit_idx in results:  # Avoid duplicates
					results.append(unit_idx)

	return results

## Query units in a specific cell
func query_cell(pos: Vector3) -> Array[int]:
	var key = _get_grid_key(pos)
	if key in grid:
		return grid[key].duplicate()
	return []

## Get grid key (cell coordinate) for a world position
## Example: position (45, 0, 23) with cell_size 10 = cell (4, 2)
func _get_grid_key(pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(pos.x / cell_size)),
		int(floor(pos.z / cell_size))
	)

## Get all cells that overlap with a radius around a position
func _get_cells_in_radius(pos: Vector3, radius: float) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var center_cell = _get_grid_key(pos)

	# Calculate how many cells to check in each direction
	var cell_radius = int(ceil(radius / cell_size))

	# Check all cells in a square around the center
	for x in range(center_cell.x - cell_radius, center_cell.x + cell_radius + 1):
		for z in range(center_cell.y - cell_radius, center_cell.y + cell_radius + 1):
			cells.append(Vector2i(x, z))

	return cells

## Debug: Get total number of units in grid
func get_total_units() -> int:
	var total = 0
	for cell in grid.values():
		total += cell.size()
	return total

## Debug: Get number of occupied cells
func get_cell_count() -> int:
	return grid.size()
