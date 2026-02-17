extends Node
class_name RouteFollowingSystem
## Level 3: Route Following - Converts flow fields into preferred velocities
##
## This is the critical bridge between pathfinding (Level 4) and collision avoidance (Level 2).
## Takes flow fields or direct paths and produces the velocity the unit WANTS to have,
## which is then adjusted by Level 2 for collision avoidance.

# References
var unit_data: UnitDataSystem
var pathfinding: PathfindingSystem

# Route following settings (Phase 1: Research-based improvements)
const ARRIVAL_SLOWING_RADIUS: float = 10.0  # Start slowing within 10m of target (was 5m)
const MIN_SPEED_FACTOR: float = 0.35  # Don't slow below 35% of max speed (was 20%)

func initialize(data: UnitDataSystem, pathfinding_system: PathfindingSystem) -> void:
	unit_data = data
	pathfinding = pathfinding_system

## Calculate preferred velocity for a unit (Level 3 output)
## This is what the unit WANTS to do, before collision avoidance
func calculate_preferred_velocity(unit_idx: int) -> Vector3:
	var pos = unit_data.positions[unit_idx]
	var target = unit_data.target_positions[unit_idx]
	var desired_speed = unit_data.get_unit_speed(unit_idx)

	# Get direction from flow field (Level 4 output)
	var direction = _get_route_direction(pos, target)

	# Apply arrival behavior - slow down smoothly near target
	var speed = _calculate_arrival_speed(pos, target, desired_speed)

	# Preferred velocity = direction * speed
	return direction * speed

## Get direction from flow field or fall back to direct path
func _get_route_direction(pos: Vector3, target: Vector3) -> Vector3:
	# Try to get flow field direction first (Level 4: Global Route Planning)
	if pathfinding and pathfinding.is_in_bounds(pos):
		var flow_direction = pathfinding.get_flow_direction(pos, target)

		# If we got a valid flow direction, use it
		if flow_direction.length_squared() > 0.01:
			return flow_direction.normalized()

	# Fall back to direct path (straight line to target)
	var to_target = target - pos
	var distance = to_target.length()

	if distance > 0.1:
		return to_target.normalized()
	else:
		return Vector3.ZERO

## Calculate speed with arrival behavior (slow down smoothly near target)
func _calculate_arrival_speed(pos: Vector3, target: Vector3, max_speed: float) -> float:
	var distance_to_target = pos.distance_to(target)

	# Full speed when far away
	if distance_to_target >= ARRIVAL_SLOWING_RADIUS:
		return max_speed

	# Smooth deceleration within slowing radius
	# Speed scales linearly from max_speed to min_speed as we approach target
	var arrival_factor = distance_to_target / ARRIVAL_SLOWING_RADIUS
	arrival_factor = max(arrival_factor, MIN_SPEED_FACTOR)  # Don't go below minimum

	return max_speed * arrival_factor
