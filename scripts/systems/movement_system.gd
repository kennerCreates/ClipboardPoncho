extends Node
class_name MovementSystem
## Handles unit movement, steering behaviors, and collision avoidance
##
## Updates unit positions based on velocities and applies steering forces
## to avoid collisions with nearby units (using spatial grid).

# Collision avoidance settings
const AVOIDANCE_RADIUS: float = 2.5  # How close before units try to avoid each other
const AVOIDANCE_STRENGTH: float = 20.0  # How strongly units push away from each other
const SEPARATION_DISTANCE: float = 1.8  # Preferred distance between units (units are 1m wide)
const MAX_AVOIDANCE_NEIGHBORS: int = 3  # Only avoid N closest units (reduced for performance)

# Movement smoothing (Phase 1: Research-based improvements)
const MAX_STEERING_FORCE: float = 20.0  # Maximum steering force per frame
const ARRIVAL_THRESHOLD: float = 2.5  # Distance at which unit "arrives" at target (was 0.5m)

# References
var unit_data: UnitDataSystem
var spatial_grid: SpatialGrid
var pathfinding: PathfindingSystem
var route_following: RouteFollowingSystem

# Staggered update optimization
var frame_counter: int = 0
const UPDATE_BUCKETS_VISIBLE: int = 4  # Update 25% of visible units per frame (performance)
const UPDATE_BUCKETS_HIDDEN: int = 10  # Update 10% of off-screen units per frame (more aggressive)

# Spatial grid rebuild optimization
const SPATIAL_GRID_REBUILD_INTERVAL: int = 2  # Rebuild grid every N frames (stale but fast)

func initialize(data: UnitDataSystem, grid: SpatialGrid, pathfinding_system: PathfindingSystem = null, route_following_system: RouteFollowingSystem = null) -> void:
	unit_data = data
	spatial_grid = grid
	pathfinding = pathfinding_system
	route_following = route_following_system

## Update all units - apply movement and steering
## Uses staggered updates: only 25% of units updated per frame
func update(delta: float, camera_frustum: Array[Plane]) -> void:
	if not unit_data or not spatial_grid:
		return

	# Increment frame counter for staggered updates
	frame_counter += 1

	# Rebuild spatial grid periodically (not every frame - saves CPU)
	if frame_counter % SPATIAL_GRID_REBUILD_INTERVAL == 0:
		spatial_grid.clear()
		for i in range(unit_data.unit_count):
			if unit_data.is_alive(i):
				spatial_grid.insert(i, unit_data.positions[i])

	# Update each unit with different rates for visible vs off-screen
	for i in range(unit_data.unit_count):
		if not unit_data.is_alive(i):
			continue

		# Check if unit is visible
		var is_visible = _is_in_frustum(camera_frustum, unit_data.positions[i])

		# Staggered updates: visible units update more frequently (smoother)
		if is_visible:
			# Visible units: 25% per frame (every 4 frames)
			if i % UPDATE_BUCKETS_VISIBLE == frame_counter % UPDATE_BUCKETS_VISIBLE:
				_update_unit_full(i, delta * UPDATE_BUCKETS_VISIBLE)
		else:
			# Off-screen units: 10% per frame (every 10 frames)
			if i % UPDATE_BUCKETS_HIDDEN == frame_counter % UPDATE_BUCKETS_HIDDEN:
				_update_unit_simple(i, delta * UPDATE_BUCKETS_HIDDEN)

## Full update for on-screen units (collision avoidance, smooth movement)
func _update_unit_full(unit_idx: int, delta: float) -> void:
	var state = unit_data.states[unit_idx]

	# Only move units in MOVING state
	if state != UnitDataSystem.UnitState.MOVING:
		unit_data.velocities[unit_idx] = Vector3.ZERO
		return

	var pos = unit_data.positions[unit_idx]
	var target = unit_data.target_positions[unit_idx]
	var velocity = unit_data.velocities[unit_idx]

	# Calculate desired velocity towards target
	var to_target = target - pos
	var distance_to_target = to_target.length()

	# Check if arrived (Phase 2: Synchronized stopping)
	if distance_to_target < ARRIVAL_THRESHOLD:
		unit_data.states[unit_idx] = UnitDataSystem.UnitState.IDLE
		unit_data.velocities[unit_idx] = Vector3.ZERO

		# StarCraft 2 technique: Synchronized stop - when one unit arrives,
		# stop nearby units that are also close to their targets
		var nearby = spatial_grid.query_radius(pos, SEPARATION_DISTANCE * 2.0)
		for neighbor_idx in nearby:
			if neighbor_idx == unit_idx:
				continue

			# Only affect units that are moving
			if unit_data.states[neighbor_idx] != UnitDataSystem.UnitState.MOVING:
				continue

			# Check if neighbor is also close to its target
			var neighbor_target = unit_data.target_positions[neighbor_idx]
			var neighbor_pos = unit_data.positions[neighbor_idx]
			var neighbor_dist = neighbor_pos.distance_to(neighbor_target)

			# If within 1.5x threshold, stop it too (creates synchronized group stop)
			if neighbor_dist < ARRIVAL_THRESHOLD * 1.5:
				unit_data.states[neighbor_idx] = UnitDataSystem.UnitState.IDLE
				unit_data.velocities[neighbor_idx] = Vector3.ZERO

		return

	# LEVEL 3: Route Following - Get preferred velocity from flow fields
	var preferred_velocity = Vector3.ZERO
	if route_following:
		preferred_velocity = route_following.calculate_preferred_velocity(unit_idx)
	else:
		# Fallback if route_following not available
		var speed = unit_data.get_unit_speed(unit_idx)
		preferred_velocity = to_target.normalized() * speed

	# LEVEL 2: Local Movement - Apply collision avoidance
	var avoidance_force = _calculate_avoidance(unit_idx, pos)

	# Combine Level 3 (preferred velocity) with Level 2 (avoidance)
	var steering = preferred_velocity + avoidance_force - velocity
	steering = steering.limit_length(MAX_STEERING_FORCE)

	# Apply steering to get actual velocity
	velocity += steering * delta

	# Limit to unit's max speed
	var max_speed = unit_data.get_unit_speed(unit_idx)
	velocity = velocity.limit_length(max_speed)

	# Update data
	unit_data.velocities[unit_idx] = velocity

	# Update position
	var old_pos = pos
	pos += velocity * delta
	unit_data.positions[unit_idx] = pos

	# Update rotation to face movement direction
	if velocity.length() > 0.1:
		unit_data.rotations[unit_idx] = atan2(velocity.x, velocity.z)

	# Update spatial grid
	spatial_grid.update_position(unit_idx, old_pos, pos)

## Simplified update for off-screen units (no collision avoidance)
func _update_unit_simple(unit_idx: int, delta: float) -> void:
	var state = unit_data.states[unit_idx]

	if state != UnitDataSystem.UnitState.MOVING:
		return

	var pos = unit_data.positions[unit_idx]
	var target = unit_data.target_positions[unit_idx]

	# Move directly towards target (no collision avoidance)
	var to_target = target - pos
	var distance = to_target.length()

	if distance < ARRIVAL_THRESHOLD:
		unit_data.states[unit_idx] = UnitDataSystem.UnitState.IDLE
		return

	# Move at full speed
	var speed = unit_data.get_unit_speed(unit_idx)
	var move_distance = min(speed * delta, distance)
	var old_pos = pos
	pos += to_target.normalized() * move_distance
	unit_data.positions[unit_idx] = pos

	# Update rotation
	unit_data.rotations[unit_idx] = atan2(to_target.x, to_target.z)

	# Update spatial grid
	spatial_grid.update_position(unit_idx, old_pos, pos)

## Calculate collision avoidance force using spatial grid
## Improved: velocity prediction + limited neighbors for performance
func _calculate_avoidance(unit_idx: int, pos: Vector3) -> Vector3:
	# Query nearby units using spatial grid
	var nearby = spatial_grid.query_radius(pos, AVOIDANCE_RADIUS)

	# Early exit if no nearby units (common case - saves computation)
	if nearby.size() <= 1:  # Only self or nobody
		return Vector3.ZERO

	var avoidance = Vector3.ZERO
	var velocity = unit_data.velocities[unit_idx]

	# Build list of neighbors with distances for sorting
	# Use squared distances to avoid expensive sqrt()
	const SEPARATION_DISTANCE_SQ = SEPARATION_DISTANCE * SEPARATION_DISTANCE
	var neighbors = []
	for other_idx in nearby:
		if other_idx == unit_idx or not unit_data.is_alive(other_idx):
			continue

		var other_pos = unit_data.positions[other_idx]
		var distance_sq = pos.distance_squared_to(other_pos)

		if distance_sq < SEPARATION_DISTANCE_SQ and distance_sq > 0.0001:
			# Store actual distance only when we need it (for sorting/calculations)
			var distance = sqrt(distance_sq)
			neighbors.append({"idx": other_idx, "pos": other_pos, "distance": distance})

	# Early exit if no close neighbors
	if neighbors.is_empty():
		return Vector3.ZERO

	# Skip sorting if we have few neighbors (performance optimization)
	var max_neighbors = min(neighbors.size(), MAX_AVOIDANCE_NEIGHBORS)
	if neighbors.size() > MAX_AVOIDANCE_NEIGHBORS:
		# Only sort if we have more neighbors than we need
		neighbors.sort_custom(func(a, b): return a.distance < b.distance)

	# Apply avoidance from closest neighbors only
	for i in range(max_neighbors):
		var neighbor = neighbors[i]
		var other_pos = neighbor.pos
		var distance = neighbor.distance

		# Velocity prediction: predict where units will be in 0.5 seconds
		var other_velocity = unit_data.velocities[neighbor.idx]
		var predicted_pos = pos + velocity * 0.5
		var predicted_other_pos = other_pos + other_velocity * 0.5
		var predicted_distance = predicted_pos.distance_to(predicted_other_pos)

		# Use predicted distance if closer (units moving toward each other)
		var effective_distance = min(distance, predicted_distance)

		# Stronger force when very close (prevents overlap)
		var distance_factor = 1.0 / max(effective_distance, 0.1)

		# Push away from other unit
		var push_direction = (pos - other_pos).normalized()
		avoidance += push_direction * AVOIDANCE_STRENGTH * distance_factor

	return avoidance

## Command a unit to move to a position
func command_move(unit_idx: int, target_pos: Vector3) -> void:
	if not unit_data.is_alive(unit_idx):
		return

	unit_data.target_positions[unit_idx] = target_pos
	unit_data.states[unit_idx] = UnitDataSystem.UnitState.MOVING

## Command multiple units to move to a position
func command_move_group(unit_indices: Array[int], target_pos: Vector3) -> void:
	for unit_idx in unit_indices:
		command_move(unit_idx, target_pos)

## Check if position is in frustum
func _is_in_frustum(frustum_planes: Array[Plane], pos: Vector3) -> bool:
	# In Godot, frustum plane normals point INWARD
	# Positive distance = outside frustum, Negative distance = inside frustum
	for plane in frustum_planes:
		# If distance is positive (outside), reject the point
		if plane.distance_to(pos) > 2.0:
			return false
	return true
