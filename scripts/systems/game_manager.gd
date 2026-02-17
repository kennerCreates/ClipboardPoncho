extends Node
## Main game manager that coordinates all game systems
##
## This singleton manages the core game loop, coordinates between different
## systems (units, resources, AI, etc.), and handles game state transitions.

# References to major game systems
var unit_manager: UnitManager
var resource_manager: ResourceManager
var debug_overlay: DebugOverlay

# Camera reference
var camera: Camera3D

# Game state
enum GameState { MENU, LOADING, PLAYING, PAUSED, GAME_OVER }
var current_state: GameState = GameState.PLAYING  # Start in PLAYING for testing

# Game settings
var max_units_per_player: int = 500
var simulation_speed: float = 1.0

# Test movement settings (Phase 2: Group-based movement)
var test_movement_enabled: bool = true
var movement_area_size: float = 150.0  # Groups move within 150x150 area at origin
var move_interval_min: float = 5.0  # Minimum time between group moves (seconds)
var move_interval_max: float = 10.0  # Maximum time between group moves (seconds)
var units_per_group: int = 20  # Units in each group
var num_groups: int = 50  # Total number of groups
var group_next_move_times: Array[float] = []  # Group-level timers (PERFORMANCE FIX)

func _ready() -> void:
	# Find camera in scene
	camera = get_viewport().get_camera_3d()
	if not camera:
		push_error("No camera found in scene!")

	# Initialize game systems
	_initialize_managers()

func _initialize_managers() -> void:
	# Initialize UnitManager
	unit_manager = UnitManager.new()
	unit_manager.name = "UnitManager"
	add_child(unit_manager)
	if camera:
		unit_manager.set_camera(camera)

	# Initialize ResourceManager (existing)
	resource_manager = ResourceManager.new()
	resource_manager.name = "ResourceManager"
	add_child(resource_manager)

	# Initialize Debug Overlay (CanvasLayer - needs to be added to root)
	debug_overlay = DebugOverlay.new()
	debug_overlay.name = "DebugOverlay"
	get_tree().root.add_child.call_deferred(debug_overlay)

	# Pass unit manager reference to debug overlay for unit stats
	debug_overlay.set_unit_manager(unit_manager)
	debug_overlay.set_pathfinding_system(unit_manager.pathfinding)

	# Spawn some test units
	_spawn_test_units()

func _spawn_test_units() -> void:
	# Phase 2: Spawn 50 groups of 20 units (1000 total)
	# Each group starts in a tight cluster, will move together with formations
	var group_spacing = 15.0  # Distance between group spawn points
	var unit_spacing = 2.5  # Distance between units within a group

	# Arrange groups in a grid
	var groups_per_row = int(sqrt(float(num_groups)))

	for group_idx in range(num_groups):
		var group_row = int(group_idx / groups_per_row)
		var group_col = group_idx % groups_per_row

		# Calculate group center position
		var group_center = Vector3(
			(group_col - groups_per_row / 2.0) * group_spacing,
			0,
			(group_row - groups_per_row / 2.0) * group_spacing
		)

		# Spawn units in a tight cluster within the group
		var units_in_group_row = int(sqrt(float(units_per_group)))
		for unit_idx in range(units_per_group):
			var unit_row = int(unit_idx / units_in_group_row)
			var unit_col = unit_idx % units_in_group_row

			var unit_pos = group_center + Vector3(
				(unit_col - units_in_group_row / 2.0) * unit_spacing,
				0,
				(unit_row - units_in_group_row / 2.0) * unit_spacing
			)

			var player_id = 0 if group_idx < int(num_groups / 2) else 1
			var unit_type = UnitDataSystem.UnitType.MARINE if group_idx % 2 == 0 else UnitDataSystem.UnitType.WORKER

			unit_manager.spawn_unit(player_id, unit_type, unit_pos)

	# Initialize group-level timers (PERFORMANCE FIX)
	group_next_move_times.resize(num_groups)
	for i in range(num_groups):
		group_next_move_times[i] = randf_range(move_interval_min, move_interval_max)

	print("Spawned %d test units in %d groups" % [unit_manager.get_total_unit_count(), num_groups])

func _process(delta: float) -> void:
	if current_state != GameState.PLAYING:
		return

	# Apply simulation speed for game speed controls
	var adjusted_delta = delta * simulation_speed
	_update_game_systems(adjusted_delta)

func _update_game_systems(delta: float) -> void:
	# Update unit manager (which updates all unit systems)
	if unit_manager:
		unit_manager.update(delta)

	# Test movement behavior - give units random targets periodically
	if test_movement_enabled and unit_manager:
		_update_test_movement(delta)

	# Debug output (disabled - use F3 overlay instead)
	# if Engine.get_frames_drawn() % 60 == 0:  # Every second
	# 	if unit_manager:
	# 		print("Total units: %d, Visible: %d" % [
	# 			unit_manager.get_total_unit_count(),
	# 			unit_manager.get_visible_unit_count()
	# 		])

func start_game() -> void:
	current_state = GameState.PLAYING

func pause_game() -> void:
	current_state = GameState.PAUSED

func resume_game() -> void:
	current_state = GameState.PLAYING

## Test behavior: Give GROUPS random movement targets (Phase 2)
## Each group of 20 units shares the same target and uses formation positions
func _update_test_movement(_delta: float) -> void:
	var unit_data = unit_manager.unit_data
	var half_size = movement_area_size / 2.0
	var current_time = Time.get_ticks_msec() / 1000.0

	# Process groups instead of individual units
	var groups_moving_this_frame = 0
	for group_idx in range(num_groups):
		# Check group-level timer (PERFORMANCE FIX - prevents calling formation assignment every frame)
		if current_time < group_next_move_times[group_idx]:
			continue

		groups_moving_this_frame += 1

		var group_start = group_idx * units_per_group
		var group_end = min(group_start + units_per_group, unit_data.unit_count)

		if group_start >= unit_data.unit_count:
			continue

		# Check if it's time for this group to pick a new destination
		if true:  # Always true now, timer check above
			# Random target position for entire group
			var group_target = Vector3(
				randf_range(-half_size, half_size),
				0.0,
				randf_range(-half_size, half_size)
			)

			# Collect all alive units in the group
			var group_units: Array[int] = []
			for unit_idx in range(group_start, group_end):
				if unit_data.is_alive(unit_idx):
					group_units.append(unit_idx)

			# Command entire group to move (uses formation manager)
			if not group_units.is_empty():
				unit_manager.command_move(group_units, group_target)

			# Set next move time for this GROUP (not individual units)
			group_next_move_times[group_idx] = current_time + randf_range(move_interval_min, move_interval_max)

	# Debug: Print how many groups moved this frame
	if groups_moving_this_frame > 0:
		print("[GameManager] %d groups moved this frame at time %.2f" % [groups_moving_this_frame, current_time])
