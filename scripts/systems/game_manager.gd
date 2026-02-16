extends Node
## Main game manager that coordinates all game systems
##
## This singleton manages the core game loop, coordinates between different
## systems (units, resources, AI, etc.), and handles game state transitions.

# References to major game systems
var unit_manager: UnitManager
var resource_manager: ResourceManager

# Camera reference
var camera: Camera3D

# Game state
enum GameState { MENU, LOADING, PLAYING, PAUSED, GAME_OVER }
var current_state: GameState = GameState.PLAYING  # Start in PLAYING for testing

# Game settings
var max_units_per_player: int = 500
var simulation_speed: float = 1.0

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

	# Spawn some test units
	_spawn_test_units()

func _spawn_test_units() -> void:
	# Spawn a grid of test units to verify the system works
	var grid_size = 10
	var spacing = 3.0

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

	# Debug output
	if Engine.get_frames_drawn() % 60 == 0:  # Every second
		if unit_manager:
			print("Total units: %d, Visible: %d" % [
				unit_manager.get_total_unit_count(),
				unit_manager.get_visible_unit_count()
			])

func start_game() -> void:
	current_state = GameState.PLAYING

func pause_game() -> void:
	current_state = GameState.PAUSED

func resume_game() -> void:
	current_state = GameState.PLAYING
