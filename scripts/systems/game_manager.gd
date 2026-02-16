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

# Test movement settings
var test_movement_enabled: bool = true
var movement_area_size: float = 150.0  # All units move within shared 150x150 area at origin
var move_interval_min: float = 2.0  # Minimum time between moves (seconds)
var move_interval_max: float = 5.0  # Maximum time between moves (seconds)

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

	# Spawn some test units
	_spawn_test_units()

func _spawn_test_units() -> void:
	# Spawn a grid of test units to test performance and frustum culling
	# 32x32 = 1024 units (close to 1000)
	var grid_size = 32
	var spacing = 5.0

	for x in range(grid_size):
		for z in range(grid_size):
			var pos = Vector3(x * spacing - grid_size * spacing / 2.0, 0, z * spacing - grid_size * spacing / 2.0)
			var player_id = 0 if x < grid_size / 2.0 else 1
			var unit_type = UnitDataSystem.UnitType.MARINE if x % 2 == 0 else UnitDataSystem.UnitType.WORKER

			unit_manager.spawn_unit(player_id, unit_type, pos)

	print("Spawned %d test units" % unit_manager.get_total_unit_count())

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

## Test behavior: Give units random movement targets
## Each unit has its own timer for when to pick a new destination
func _update_test_movement(_delta: float) -> void:
	var unit_data = unit_manager.unit_data
	var half_size = movement_area_size / 2.0
	var current_time = Time.get_ticks_msec() / 1000.0  # Convert to seconds

	for i in range(unit_data.unit_count):
		if not unit_data.is_alive(i):
			continue

		# Check if it's time for this unit to pick a new destination
		if current_time >= unit_data.next_move_times[i]:
			# Random position within the movement area (centered at origin)
			var random_target = Vector3(
				randf_range(-half_size, half_size),
				0.0,
				randf_range(-half_size, half_size)
			)

			# Command unit to move
			unit_manager.movement.command_move(i, random_target)

			# Set next move time with random interval (2-5 seconds from now)
			var next_interval = randf_range(move_interval_min, move_interval_max)
			unit_data.next_move_times[i] = current_time + next_interval
