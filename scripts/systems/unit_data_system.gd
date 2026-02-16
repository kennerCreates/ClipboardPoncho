extends Node
class_name UnitDataSystem
## Core data storage for all units using Structure of Arrays (SoA) pattern
##
## Uses packed arrays for cache-friendly sequential access and memory efficiency.
## All arrays share the same index - index 42 across all arrays = unit 42's data.
##
## Memory: ~240 bytes per unit vs 2KB+ for Node3D approach

# Unit states
enum UnitState {
	IDLE,
	MOVING,
	ATTACKING,
	ABILITY_CASTING,
	GATHERING,  # For workers only
	BUILDING,   # For workers only
	DEAD
}

# Unit types - extend as you add more units
enum UnitType {
	WORKER,   # Can gather, can build, cannot attack (or minimal attack)
	MARINE,   # Combat unit - attacks
	TANK,     # Heavy combat unit - attacks
	# Add more unit types here
}

signal unit_spawned(unit_idx: int)
signal unit_removed(unit_idx: int)

# === CORE DATA ARRAYS (Structure of Arrays) ===
# All arrays use same index = same unit

# Transform data
var positions: PackedVector3Array = []
var velocities: PackedVector3Array = []
var rotations: PackedFloat32Array = []  # Y-axis rotation only (units face direction)

# Combat data
var health: PackedFloat32Array = []
var max_health: PackedFloat32Array = []

# Unit classification
var unit_types: PackedInt32Array = []  # UnitType enum
var player_ids: PackedInt32Array = []  # 0 = player 1, 1 = player 2/AI

# State machine
var states: PackedInt32Array = []  # UnitState enum

# Command/target data
var target_positions: PackedVector3Array = []  # Where unit is moving to
var target_unit_ids: PackedInt32Array = []  # Which unit is being attacked (-1 if none)
var target_resource_ids: PackedInt32Array = []  # Which resource node (for workers, -1 if none)

# Selection and visibility
var selection_flags: PackedInt32Array = []  # Bitfield: bit 0 = selected, bit 1 = hovered

# Worker-specific data (only relevant for worker units)
var carried_resources: PackedInt32Array = []  # Amount of resources being carried

# Test movement data (for random wandering behavior)
var next_move_times: PackedFloat32Array = []  # Time when unit should pick new random destination

# Unit capacity
var unit_count: int = 0
const MAX_CAPACITY: int = 1000

# Free list for recycling slots when units die
var free_slots: Array[int] = []

func _ready() -> void:
	_initialize_arrays()

func _initialize_arrays() -> void:
	# Pre-allocate all arrays to MAX_CAPACITY
	positions.resize(MAX_CAPACITY)
	velocities.resize(MAX_CAPACITY)
	rotations.resize(MAX_CAPACITY)
	health.resize(MAX_CAPACITY)
	max_health.resize(MAX_CAPACITY)
	unit_types.resize(MAX_CAPACITY)
	player_ids.resize(MAX_CAPACITY)
	states.resize(MAX_CAPACITY)
	target_positions.resize(MAX_CAPACITY)
	target_unit_ids.resize(MAX_CAPACITY)
	target_resource_ids.resize(MAX_CAPACITY)
	selection_flags.resize(MAX_CAPACITY)
	carried_resources.resize(MAX_CAPACITY)
	next_move_times.resize(MAX_CAPACITY)

	# Initialize all to default values
	for i in range(MAX_CAPACITY):
		positions[i] = Vector3.ZERO
		velocities[i] = Vector3.ZERO
		rotations[i] = 0.0
		health[i] = 0.0
		max_health[i] = 100.0
		unit_types[i] = UnitType.MARINE
		player_ids[i] = 0
		states[i] = UnitState.DEAD  # All start dead
		target_positions[i] = Vector3.ZERO
		target_unit_ids[i] = -1
		target_resource_ids[i] = -1
		selection_flags[i] = 0
		carried_resources[i] = 0
		next_move_times[i] = 0.0

## Spawns a new unit and returns its index
func spawn_unit(player_id: int, unit_type: UnitType, spawn_pos: Vector3) -> int:
	var idx: int

	# Reuse slot from free list or increment count
	if free_slots.size() > 0:
		idx = free_slots.pop_back()
	else:
		if unit_count >= MAX_CAPACITY:
			push_error("Max unit capacity reached!")
			return -1
		idx = unit_count
		unit_count += 1

	# Initialize unit data
	positions[idx] = spawn_pos
	velocities[idx] = Vector3.ZERO
	rotations[idx] = 0.0
	player_ids[idx] = player_id
	unit_types[idx] = unit_type
	states[idx] = UnitState.IDLE
	target_positions[idx] = spawn_pos
	target_unit_ids[idx] = -1
	target_resource_ids[idx] = -1
	selection_flags[idx] = 0
	carried_resources[idx] = 0

	# Set health based on unit type
	var stats = _get_unit_stats(unit_type)
	health[idx] = stats.max_health
	max_health[idx] = stats.max_health

	unit_spawned.emit(idx)
	return idx

## Removes a unit (marks as dead and adds to free list)
func remove_unit(unit_idx: int) -> void:
	if unit_idx < 0 or unit_idx >= unit_count:
		return

	states[unit_idx] = UnitState.DEAD
	free_slots.append(unit_idx)
	unit_removed.emit(unit_idx)

## Apply damage to a unit, returns true if unit died
func damage_unit(unit_idx: int, damage: float) -> bool:
	if states[unit_idx] == UnitState.DEAD:
		return false

	health[unit_idx] -= damage

	if health[unit_idx] <= 0.0:
		health[unit_idx] = 0.0
		remove_unit(unit_idx)
		return true

	return false

## Heal a unit (clamped to max health)
func heal_unit(unit_idx: int, amount: float) -> void:
	if states[unit_idx] == UnitState.DEAD:
		return

	health[unit_idx] = min(health[unit_idx] + amount, max_health[unit_idx])

## Check if unit is alive
func is_alive(unit_idx: int) -> bool:
	return unit_idx >= 0 and unit_idx < unit_count and states[unit_idx] != UnitState.DEAD

## Get unit stats based on type
func _get_unit_stats(unit_type: UnitType) -> Dictionary:
	match unit_type:
		UnitType.WORKER:
			return {
				"max_health": 60.0,
				"speed": 4.0,
				"can_attack": false,
				"can_gather": true,
				"can_build": true,
				"gather_rate": 5.0,  # Resources per second
				"carry_capacity": 10
			}
		UnitType.MARINE:
			return {
				"max_health": 100.0,
				"speed": 5.0,
				"can_attack": true,
				"can_gather": false,
				"can_build": false,
				"attack_damage": 10.0,
				"attack_range": 8.0,
				"attack_cooldown": 1.0
			}
		UnitType.TANK:
			return {
				"max_health": 200.0,
				"speed": 3.0,
				"can_attack": true,
				"can_gather": false,
				"can_build": false,
				"attack_damage": 30.0,
				"attack_range": 15.0,
				"attack_cooldown": 2.0
			}
		_:
			return {
				"max_health": 100.0,
				"speed": 5.0,
				"can_attack": true,
				"can_gather": false,
				"can_build": false,
				"attack_damage": 10.0,
				"attack_range": 5.0,
				"attack_cooldown": 1.0
			}

## Capability checks
func can_attack(unit_idx: int) -> bool:
	if not is_alive(unit_idx):
		return false
	return _get_unit_stats(unit_types[unit_idx]).get("can_attack", false)

func can_gather(unit_idx: int) -> bool:
	if not is_alive(unit_idx):
		return false
	return _get_unit_stats(unit_types[unit_idx]).get("can_gather", false)

func can_build(unit_idx: int) -> bool:
	if not is_alive(unit_idx):
		return false
	return _get_unit_stats(unit_types[unit_idx]).get("can_build", false)

## Get unit speed based on type
func get_unit_speed(unit_idx: int) -> float:
	if not is_alive(unit_idx):
		return 0.0
	return _get_unit_stats(unit_types[unit_idx]).speed

## Get attack stats (only valid for combat units)
func get_attack_damage(unit_idx: int) -> float:
	return _get_unit_stats(unit_types[unit_idx]).get("attack_damage", 0.0)

func get_attack_range(unit_idx: int) -> float:
	return _get_unit_stats(unit_types[unit_idx]).get("attack_range", 0.0)

func get_attack_cooldown(unit_idx: int) -> float:
	return _get_unit_stats(unit_types[unit_idx]).get("attack_cooldown", 0.0)

## Get gather stats (only valid for workers)
func get_gather_rate(unit_idx: int) -> float:
	return _get_unit_stats(unit_types[unit_idx]).get("gather_rate", 0.0)

func get_carry_capacity(unit_idx: int) -> int:
	return _get_unit_stats(unit_types[unit_idx]).get("carry_capacity", 0)

## Selection helpers
func set_selected(unit_idx: int, selected: bool) -> void:
	if selected:
		selection_flags[unit_idx] |= 1  # Set bit 0
	else:
		selection_flags[unit_idx] &= ~1  # Clear bit 0

func is_selected(unit_idx: int) -> bool:
	return (selection_flags[unit_idx] & 1) != 0

func set_hovered(unit_idx: int, hovered: bool) -> void:
	if hovered:
		selection_flags[unit_idx] |= 2  # Set bit 1
	else:
		selection_flags[unit_idx] &= ~2  # Clear bit 1

func is_hovered(unit_idx: int) -> bool:
	return (selection_flags[unit_idx] & 2) != 0
