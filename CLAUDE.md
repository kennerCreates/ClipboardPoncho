# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ClipboardPoncho is a sci-fi/fantasy RTS game in Godot 4.6, inspired by StarCraft 2. The game targets 500+ units per side with fast-paced gameplay, stylized 3D graphics, and a near-isometric perspective camera.

**Key Design Goals:**
- Large-scale battles (500+ units per side, potentially 1000+ total)
- StarCraft 2-style unit movement and battle excitement
- PvE focused with optional co-op mode
- Full RTS feature set: buildings, upgrades, resources, tech trees, map editor

## Architecture

### Hybrid Data-Oriented Design (NEW!)

ClipboardPoncho uses a **hybrid architecture** that separates rendering from logic for maximum performance with 500+ units per side:

```
┌─────────────────────────────────────────┐
│  RENDERING LAYER (MultiMesh)            │
│  • 3 draw calls total (one per type)   │
│  • Frustum culling (only on-screen)    │
│  • 200-300 units rendered               │
└─────────────────────────────────────────┘
              ↕
┌─────────────────────────────────────────┐
│  LOGIC LAYER (Data-Oriented)            │
│  • Packed arrays (cache-friendly)      │
│  • ~240 bytes per unit                  │
│  • Spatial grid for queries             │
└─────────────────────────────────────────┘
```

### Debug Tools

- **DebugOverlay** (`scripts/systems/debug_overlay.gd`): Performance overlay showing real-time metrics
  - Toggle with **F3** key
  - Displays: FPS, frame time (ms), draw calls, objects drawn, vertices drawn, memory usage
  - Useful for performance profiling and optimization

### Core Systems

The game uses specialized systems coordinated by `GameManager`:

1. **UnitDataSystem** (`scripts/systems/unit_data_system.gd`) - **NEW!**
   - Stores ALL unit data in packed arrays (Structure of Arrays pattern)
   - One unit = one index across all parallel arrays
   - No Node3D overhead - just raw data
   - ~240 bytes per unit vs 2KB+ for traditional Node3D approach
   - Supports: positions, velocities, health, states, targets, etc.

2. **UnitRenderSystem** (`scripts/systems/unit_render_system.gd`) - **NEW!**
   - Renders units using MultiMesh (one per unit type)
   - **Frustum culling**: Only renders on-screen units (200-300 of 1000)
   - 3 draw calls total vs 300+ individual draw calls
   - Updates instance transforms from UnitDataSystem each frame
   - LOD based on camera zoom can be added later

3. **MovementSystem** (`scripts/systems/movement_system.gd`) - **NEW!**
   - Updates unit positions and velocities
   - Collision avoidance using spatial grid
   - Simplified updates for off-screen units
   - Steering behaviors (separation, arrival)

4. **SpatialGrid** (`scripts/utils/spatial_grid.gd`) - **NEW!**
   - Grid-based spatial hashing for fast queries
   - O(1) insertion, O(k) queries where k = nearby units
   - Essential for collision avoidance with 1000 units
   - Example: Instead of checking 1000 units, only check ~20-30 nearby

5. **UnitManager** (`scripts/systems/unit_manager.gd`) - **UPDATED!**
   - Coordinates all unit systems
   - Maintains signal compatibility with existing code
   - Returns unit indices instead of Node3D references
   - Provides high-level commands (spawn, move, attack)

6. **ResourceManager** (`scripts/systems/resource_manager.gd`)
   - Manages player resources (minerals, vespene, supply)
   - Tracks worker assignments to resource nodes
   - Validates affordability for purchases
   - Signal-based: `resources_changed`, `supply_changed`

7. **PathfindingManager** (TODO - Coming Soon)
   - Flow field pathfinding for large unit groups
   - Centralized pathfinding to avoid duplicate calculations
   - Local collision avoidance (already implemented in MovementSystem)

8. **AIManager** (TODO)
   - AI opponent decision making
   - Build orders, attack timing, micro management
   - Difficulty scaling

### Performance Considerations

**Key optimizations for 1000 total units (500 per side):**

- **Frustum Culling** (CRITICAL):
  - Like StarCraft 2, camera only sees portion of battlefield
  - Only 200-300 units on-screen at once (not all 1000)
  - Off-screen units skip: rendering, LOD checks, visual updates
  - Off-screen units still run: AI, pathfinding (at reduced rate), combat
  - **Result**: Effectively rendering 300 units, not 1000

- **MultiMesh Rendering**:
  - 3 draw calls total (one per unit type) vs 300+ individual draw calls
  - GPU instancing handles all transform updates
  - Massive rendering performance boost

- **Data-Oriented Design**:
  - Packed arrays for cache-friendly sequential access
  - ~240 bytes per unit vs 2KB+ for Node3D
  - All unit data in contiguous memory

- **Spatial Grid**:
  - Grid-based hashing for O(1) insertion, O(k) queries
  - Collision avoidance checks only ~20-30 nearby units, not all 1000
  - Example: 1000 × 20 = 20,000 checks vs 1000 × 1000 = 1,000,000

- **Staggered Updates** (TODO in BehaviorSystem):
  - Update 25% of units per frame (250 units @ 60fps)
  - Each unit updates every 4 frames (66ms latency)
  - Player won't notice; keeps 60fps stable

- **LOD System** (Future - camera zoom based):
  - With isometric camera, distance-based LOD doesn't make sense
  - Instead: LOD based on camera zoom level
  - Zoomed out = simplified models, zoomed in = full detail

### Data Structures

**Unit Data (Structure of Arrays):**
```gdscript
# In UnitDataSystem - all arrays share same index = same unit
var positions: PackedVector3Array
var velocities: PackedVector3Array
var rotations: PackedFloat32Array
var health: PackedFloat32Array
var max_health: PackedFloat32Array
var unit_types: PackedInt32Array  # WORKER, MARINE, TANK
var player_ids: PackedInt32Array
var states: PackedInt32Array  # IDLE, MOVING, ATTACKING, etc.
var target_positions: PackedVector3Array
var target_unit_ids: PackedInt32Array

# Example: Unit at index 42
# positions[42] = Vector3(10, 0, 15)
# health[42] = 75.0
# unit_types[42] = UnitType.MARINE
# states[42] = UnitState.ATTACKING
```

**Spatial Grid:**
```gdscript
# Fast spatial queries - no more checking all 1000 units!
var grid: Dictionary = {}  # Vector2i(cell_x, cell_z) -> Array[unit_index]

# Query only nearby units
var nearby = spatial_grid.query_radius(position, 5.0)  # Returns ~20-30 units
for unit_idx in nearby:
    check_collision(unit_idx)
```

**Building Architecture** (TODO - still using traditional nodes for now):
```
Building (Node3D)
├── Model (MeshInstance3D)
├── BuildingArea (Area3D for placement validation)
├── RallyPoint (Marker3D)
└── building.gd (production queue, upgrades)
```

### Key Patterns

**Command Pattern for Unit Orders:**
```gdscript
# Instead of directly moving units, create command objects
class_name MoveCommand extends Command
var target_position: Vector3
func execute(units: Array[Unit]) -> void:
    for unit in units:
        unit.move_to(target_position)
```

**Signal-Based Communication:**
```gdscript
# Systems emit signals, other systems listen
# Example: When unit dies, multiple systems react
unit.died.connect(_on_unit_died)
```

**Resource Pattern (for costs):**
```gdscript
var marine_cost = {
    ResourceManager.ResourceType.MINERALS: 50,
    ResourceManager.ResourceType.VESPENE: 0
}
if ResourceManager.can_afford(player_id, marine_cost):
    ResourceManager.spend_resources(player_id, marine_cost)
```

## Common Development Tasks

### Running the Project
- Open in Godot 4.6 editor
- Press **F5** to run main scene
- Press **F6** to run current scene

### Testing Specific Systems
- Main scene: `scenes/main/main.tscn`
- Create test scenes in `scenes/` for isolated system testing

### Creating New Units
1. Create scene in `scenes/units/unit_name.tscn`
2. Extend base unit script or create in `scripts/units/unit_name.gd`
3. Set up model, collision, and NavigationAgent3D
4. Register with UnitManager on spawn
5. Define stats: health, speed, damage, cost, build time

### Creating New Buildings
1. Create scene in `scenes/buildings/building_name.tscn`
2. Create script in `scripts/buildings/building_name.gd`
3. Implement production queue if it produces units
4. Define build cost, build time, and requirements

## Technology Choices

**Renderer: Forward+**
- Chosen for best 3D performance with many dynamic lights
- Supports both PBR and stylized rendering (keeping options open)
- MSAA 3D enabled for anti-aliasing

**Camera: Perspective with Isometric-like Settings**
- FOV: 45° (narrower for more isometric feel)
- Angled at ~45° looking down
- Position: High above battlefield

**Pathfinding: Flow Fields (Recommended)**
- Traditional A* doesn't scale well for 100+ units moving together
- Flow fields compute once, benefit many units
- Consider Godot Navigation Server or custom implementation

## File Naming Conventions

- **Scenes**: `snake_case.tscn` (e.g., `marine_unit.tscn`)
- **Scripts**: `snake_case.gd` (e.g., `unit_manager.gd`)
- **Classes**: `PascalCase` (e.g., `class_name UnitManager`)
- **Signals**: `snake_case` (e.g., `signal unit_created`)
- **Constants**: `UPPER_SNAKE_CASE` (e.g., `const MAX_UNITS = 500`)

## GDScript Patterns Used

**Type Hints:**
```gdscript
var units: Array[Node3D] = []
func get_unit_count() -> int:
```

**Docstrings:**
```gdscript
## Brief description
##
## Longer explanation if needed
```

**Signals for Decoupling:**
```gdscript
signal event_happened(data: Dictionary)
# Rather than direct function calls between systems
```

## Map/Scenario Editor

(TODO - Future feature)
- Will allow custom map creation
- Place resource nodes, spawn points
- Set AI behavior and difficulty
- Save/load map files

## Multiplayer/Co-op Considerations

While currently PvE focused, architecture should support:
- Player ID abstraction (already implemented)
- Deterministic simulation for potential lockstep networking
- Clear separation between input, simulation, and rendering
