extends Node
class_name PathfindingSystem
## Manages flow field generation and caching for efficient group pathfinding
##
## Creates flow fields on-demand and caches them for reuse. Multiple units
## targeting the same area can share a single flow field, reducing computation.

# Flow field cache
# Key: target position hash (rounded to grid), Value: FlowField
var active_flow_fields: Dictionary = {}

# Flow field grid settings
const GRID_CELL_SIZE: float = 4.0  # 4 meters per cell (increased for performance)
const GRID_WIDTH: int = 64  # 64 cells = 256 meters wide
const GRID_HEIGHT: int = 64  # 64 cells = 256 meters tall

# World bounds (will cover 256x256 meter area centered at origin)
var world_min: Vector3
var world_max: Vector3

# Cache management
const MAX_ACTIVE_FLOW_FIELDS: int = 10  # Limit to prevent memory bloat
const TARGET_SNAP_DISTANCE: float = 30.0  # Targets within 30m share same flow field (increased for better sharing)
const MAX_NEW_FIELDS_PER_FRAME: int = 2  # Only generate 2 new flow fields per frame max

# Frame tracking for generation limiting
var fields_generated_this_frame: int = 0
var last_frame_count: int = 0

func _ready() -> void:
	# Calculate world bounds (centered at origin)
	var half_width = (GRID_WIDTH * GRID_CELL_SIZE) / 2.0
	var half_height = (GRID_HEIGHT * GRID_CELL_SIZE) / 2.0
	world_min = Vector3(-half_width, 0, -half_height)
	world_max = Vector3(half_width, 0, half_height)

## Request a flow field to a target position
## Returns existing cached field if available, or creates new one
## Returns null if generation limit reached this frame
func request_flow_field(target_pos: Vector3) -> FlowField:
	var current_time = Time.get_ticks_msec() / 1000.0
	var current_frame = Engine.get_frames_drawn()

	# Reset frame counter if we're on a new frame
	if current_frame != last_frame_count:
		fields_generated_this_frame = 0
		last_frame_count = current_frame

	# Snap target to grid to improve cache hits
	var snapped_target = _snap_to_grid(target_pos, TARGET_SNAP_DISTANCE)
	var field_key = _position_to_hash(snapped_target)

	# Check if we have a valid cached flow field
	if active_flow_fields.has(field_key):
		var field: FlowField = active_flow_fields[field_key]
		if field.is_valid(current_time):
			return field
		else:
			# Expired - remove it
			active_flow_fields.erase(field_key)

	# Check if we've hit the generation limit for this frame
	if fields_generated_this_frame >= MAX_NEW_FIELDS_PER_FRAME:
		return null  # Can't generate more this frame

	# Need to create new flow field
	# First, clean up expired fields if we're at capacity
	if active_flow_fields.size() >= MAX_ACTIVE_FLOW_FIELDS:
		_cleanup_expired_fields(current_time)

	# If still at capacity, remove oldest field
	if active_flow_fields.size() >= MAX_ACTIVE_FLOW_FIELDS:
		_remove_oldest_field()

	# Create new flow field
	var new_field = FlowField.new(GRID_WIDTH, GRID_HEIGHT, world_min, GRID_CELL_SIZE)
	new_field.generate_to_target(snapped_target, current_time)

	# Cache it
	active_flow_fields[field_key] = new_field
	fields_generated_this_frame += 1

	return new_field

## Get flow direction for a unit at a position trying to reach a target
## Returns 3D direction vector (XZ plane), or Vector3.ZERO if flow field unavailable
func get_flow_direction(unit_pos: Vector3, target_pos: Vector3) -> Vector3:
	var field = request_flow_field(target_pos)

	# If field generation was rate-limited, return zero (will fall back to direct path)
	if field == null:
		return Vector3.ZERO

	# Get 2D flow direction
	var flow_2d = field.get_flow_at_position(unit_pos)

	# Convert to 3D (XZ plane)
	return Vector3(flow_2d.x, 0, flow_2d.y)

## Check if a position is within pathfinding bounds
func is_in_bounds(pos: Vector3) -> bool:
	return pos.x >= world_min.x and pos.x <= world_max.x and \
	       pos.z >= world_min.z and pos.z <= world_max.z

## Snap position to grid for better cache hits
func _snap_to_grid(pos: Vector3, snap_distance: float) -> Vector3:
	return Vector3(
		round(pos.x / snap_distance) * snap_distance,
		0,
		round(pos.z / snap_distance) * snap_distance
	)

## Convert position to hash key for cache lookup
func _position_to_hash(pos: Vector3) -> String:
	return "%d_%d" % [int(pos.x), int(pos.z)]

## Remove expired flow fields from cache
func _cleanup_expired_fields(current_time: float) -> void:
	var keys_to_remove: Array = []

	for key in active_flow_fields.keys():
		var field: FlowField = active_flow_fields[key]
		if not field.is_valid(current_time):
			keys_to_remove.append(key)

	for key in keys_to_remove:
		active_flow_fields.erase(key)

## Remove oldest flow field (by expiration time)
func _remove_oldest_field() -> void:
	if active_flow_fields.is_empty():
		return

	var oldest_key = ""
	var oldest_time = INF

	for key in active_flow_fields.keys():
		var field: FlowField = active_flow_fields[key]
		if field.expiration_time < oldest_time:
			oldest_time = field.expiration_time
			oldest_key = key

	if oldest_key != "":
		active_flow_fields.erase(oldest_key)

## Debug: Get number of active flow fields
func get_active_field_count() -> int:
	return active_flow_fields.size()

## Debug: Clear all cached flow fields
func clear_cache() -> void:
	active_flow_fields.clear()
