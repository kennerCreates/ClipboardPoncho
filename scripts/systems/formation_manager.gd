extends Node
class_name FormationManager
## Manages unit formation assignment for group movement
##
## When multiple units are ordered to move to the same location, assigns each
## unit a unique grid position to prevent clustering and create natural movement.

# Formation settings
const GRID_SPACING: float = 2.5  # Distance between units in formation (meters)

# Formation caching (CRITICAL PERFORMANCE FIX)
var formation_cache: Dictionary = {}  # cache_key -> {offsets: Dictionary, timestamp: float}
const CACHE_DURATION: float = 30.0  # Reuse formations for 30 seconds

# Reference to unit data
var unit_data: UnitDataSystem

func initialize(data: UnitDataSystem) -> void:
	unit_data = data

## Generate cache key from unit indices (helper function)
func _generate_cache_key(unit_indices: Array[int]) -> String:
	var sorted = unit_indices.duplicate()
	sorted.sort()
	return str(sorted.hash())

## Assign grid formation positions to a group of units
## Returns Dictionary mapping unit_idx -> target_position
## PERFORMANCE: Caches formation offsets to avoid expensive recalculation
func assign_formation_positions(unit_indices: Array[int], base_target: Vector3) -> Dictionary:
	var positions = {}
	var count = unit_indices.size()

	if count == 0:
		return positions

	var current_time = Time.get_ticks_msec() / 1000.0

	# Generate cache key from sorted unit indices
	var cache_key = _generate_cache_key(unit_indices)

	# Check if we have a valid cached formation for this group
	if formation_cache.has(cache_key):
		var cached = formation_cache[cache_key]
		if current_time - cached.timestamp < CACHE_DURATION:
			# Reuse cached offsets, just update base target (FAST PATH)
			print("[FormationManager] CACHE HIT for %d units" % count)
			for unit_idx in cached.offsets:
				var offset = cached.offsets[unit_idx]
				positions[unit_idx] = base_target + offset
			return positions

	# Cache miss - calculate new formation (SLOW PATH - only runs once per 30 seconds per group)
	print("[FormationManager] CACHE MISS - calculating formation for %d units" % count)
	var cols = int(ceil(sqrt(float(count))))
	var rows = int(ceil(float(count) / float(cols)))

	# Generate grid positions centered on target
	var grid_positions = []
	for i in range(count):
		var row = int(i / cols)
		var col = i % cols

		# Center the grid on the target
		var offset = Vector3(
			(col - (cols - 1) / 2.0) * GRID_SPACING,
			0.0,
			(row - (rows - 1) / 2.0) * GRID_SPACING
		)
		grid_positions.append(base_target + offset)

	# Use SmartCenter assignment if unit_data available
	if unit_data:
		positions = _smart_assignment(unit_indices, grid_positions)
	else:
		# Fallback: simple sequential assignment
		for i in range(count):
			positions[unit_indices[i]] = grid_positions[i]

	# Cache the OFFSETS (not absolute positions) for reuse
	var offsets = {}
	for unit_idx in positions:
		offsets[unit_idx] = positions[unit_idx] - base_target

	formation_cache[cache_key] = {
		"offsets": offsets,
		"timestamp": current_time
	}

	return positions

## SmartCenter: Assign each unit to closest available grid position
## Minimizes total movement distance and prevents path crossing
## OPTIMIZED: O(n² log n) instead of O(n³)
func _smart_assignment(unit_indices: Array[int], grid_positions: Array) -> Dictionary:
	var assignments = {}

	# Build all distance pairs once
	var distances = []
	for unit_idx in unit_indices:
		var unit_pos = unit_data.positions[unit_idx]
		for i in range(grid_positions.size()):
			distances.append({
				"unit_idx": unit_idx,
				"grid_idx": i,
				"distance": unit_pos.distance_squared_to(grid_positions[i])
			})

	# Sort all pairs by distance (O(n² log n))
	distances.sort_custom(func(a, b): return a.distance < b.distance)

	# Greedily assign closest pairs
	var used_units = {}
	var used_positions = {}

	for pair in distances:
		if not used_units.has(pair.unit_idx) and not used_positions.has(pair.grid_idx):
			assignments[pair.unit_idx] = grid_positions[pair.grid_idx]
			used_units[pair.unit_idx] = true
			used_positions[pair.grid_idx] = true

			# Early exit when all units assigned
			if assignments.size() == unit_indices.size():
				break

	return assignments
