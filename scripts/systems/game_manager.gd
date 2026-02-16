extends Node
## Main game manager that coordinates all game systems
##
## This singleton manages the core game loop, coordinates between different
## systems (units, resources, AI, etc.), and handles game state transitions.

# References to major game systems
var unit_manager: Node
var resource_manager: Node
var pathfinding_manager: Node
var ai_manager: Node

# Game state
enum GameState { MENU, LOADING, PLAYING, PAUSED, GAME_OVER }
var current_state: GameState = GameState.MENU

# Game settings
var max_units_per_player: int = 500
var simulation_speed: float = 1.0

func _ready() -> void:
	# Initialize game systems
	_initialize_managers()

func _initialize_managers() -> void:
	# TODO: Initialize all manager systems
	# unit_manager = UnitManager.new()
	# resource_manager = ResourceManager.new()
	# pathfinding_manager = PathfindingManager.new()
	# ai_manager = AIManager.new()
	pass

func _process(delta: float) -> void:
	if current_state != GameState.PLAYING:
		return

	# Update game systems
	# Apply simulation speed for game speed controls
	var adjusted_delta = delta * simulation_speed
	_update_game_systems(adjusted_delta)

func _update_game_systems(delta: float) -> void:
	# TODO: Update all manager systems with delta
	pass

func start_game() -> void:
	current_state = GameState.PLAYING

func pause_game() -> void:
	current_state = GameState.PAUSED

func resume_game() -> void:
	current_state = GameState.PLAYING
