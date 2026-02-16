extends Node
class_name MovementSystem
## Handles unit movement, steering behaviors, and collision avoidance
##
## Updates unit positions based on velocities and applies steering forces
## to avoid collisions with nearby units (using spatial grid).

# Collision avoidance settings
const AVOIDANCE_RADIUS: float = 2.0  # How close before units try to avoid each other
const AVOIDANCE_STRENGTH: float = 5.0  # How strongly units push away from each other
const SEPARATION_DISTANCE: float = 1.5  # Preferred distance between units

# Movement smoothing
const MAX_STEERING_FORCE: float = 10.0  # Maximum steering force per frame
const ARRIVAL_THRESHOLD: float = 0.5  # Distance at which unit "arrives" at target

# References
var unit_data: UnitDataSystem
var spatial_grid: SpatialGrid

func initialize(data: UnitDataSystem, grid: SpatialGrid) -> void:
	unit_data = data
	spatial_grid = grid

## Update all units - apply movement and steering
func update(delta: float, camera_frustum: Array[Plane]) -> void:
	if not unit_data or not spatial_grid:
		return

	# Rebuild spatial grid for this frame
	spatial_grid.clear()
	for i in range(unit_data.unit_count):
		if unit_data.is_alive(i):
			spatial_grid.insert(i, unit_data.positions[i])

	# Update each unit
	for i in range(unit_data.unit_count):
		if not unit_data.is_alive(i):
			continue

		# Only apply full updates to on-screen units
		# Off-screen units get simplified movement
		var is_visible = _is_in_frustum(camera_frustum, unit_data.positions[i])

		if is_visible:
			_update_unit_full(i, delta)
		else:
			_update_unit_simple(i, delta)

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

	# Check if arrived
	if distance_to_target < ARRIVAL_THRESHOLD:
		unit_data.states[unit_idx] = UnitDataSystem.UnitState.IDLE
		unit_data.velocities[unit_idx] = Vector3.ZERO
		return

	# Calculate desired velocity
	var speed = unit_data.get_unit_speed(unit_idx)
	var desired_velocity = to_target.normalized() * speed

	# Apply collision avoidance
	var avoidance_force = _calculate_avoidance(unit_idx, pos)

	# Combine forces
	var steering = desired_velocity + avoidance_force - velocity
	steering = steering.limit_length(MAX_STEERING_FORCE)

	# Apply steering
	velocity += steering * delta
	velocity = velocity.limit_length(speed)

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
func _calculate_avoidance(unit_idx: int, pos: Vector3) -> Vector3:
	var avoidance = Vector3.ZERO

	# Query nearby units using spatial grid (much faster than checking all units)
	var nearby = spatial_grid.query_radius(pos, AVOIDANCE_RADIUS)

	for other_idx in nearby:
		if other_idx == unit_idx:
			continue

		if not unit_data.is_alive(other_idx):
			continue

		var other_pos = unit_data.positions[other_idx]
		var to_other = other_pos - pos
		var distance = to_other.length()

		# Apply separation force if too close
		if distance < SEPARATION_DISTANCE and distance > 0.01:
			# Push away from other unit
			var push_force = (pos - other_pos).normalized() / distance
			avoidance += push_force * AVOIDANCE_STRENGTH

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
	for plane in frustum_planes:
		if plane.distance_to(pos) < -2.0:
			return false
	return true
