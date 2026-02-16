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

### Core Systems (Manager Pattern)

The game uses a centralized manager pattern for major systems, coordinated by `GameManager`:

1. **UnitManager** (`scripts/systems/unit_manager.gd`)
   - Tracks all units across all players
   - Implements spatial partitioning for performance (TODO: octree/grid)
   - Handles unit selection and LOD (Level of Detail)
   - Signal-based communication: `unit_created`, `unit_destroyed`

2. **ResourceManager** (`scripts/systems/resource_manager.gd`)
   - Manages player resources (minerals, vespene, supply)
   - Tracks worker assignments to resource nodes
   - Validates affordability for purchases
   - Signal-based: `resources_changed`, `supply_changed`

3. **PathfindingManager** (TODO)
   - Centralized pathfinding to avoid duplicate calculations
   - Flow field pathfinding for large unit groups (recommended for RTS)
   - Unit collision avoidance (steering behaviors)

4. **AIManager** (TODO)
   - AI opponent decision making
   - Build orders, attack timing, micro management
   - Difficulty scaling

### Performance Considerations

**Critical for 500+ units per side:**

- **LOD System**: Units farther from camera use simplified models/animations
  - Close: Full detail
  - Medium (30m+): Reduced polygon count, simplified animations
  - Far (60m+): Billboards or very low poly

- **Spatial Partitioning**: Use octree or grid-based partitioning for:
  - Unit queries (find units in area)
  - Vision/fog of war
  - Collision detection

- **Object Pooling**: Reuse nodes for:
  - Projectiles (bullets, missiles)
  - VFX (explosions, effects)
  - Frequently spawned/destroyed units

- **Batching**: Group similar units for rendering efficiency
  - Use MultiMeshInstance3D for units with same model

- **Update Optimization**: Not all units need _process() every frame
  - Stagger updates across multiple frames
  - Distant units update less frequently

### Scene Structure

**Unit Architecture:**
```
Unit (Node3D)
├── Model (MeshInstance3D or Scene)
├── SelectionDecal (Decal)
├── HealthBar (Node3D → UI)
├── CollisionShape3D
├── NavigationAgent3D
└── Scripts:
    ├── unit.gd (base unit behavior)
    └── unit_type.gd (specific unit: marine, zealot, etc.)
```

**Building Architecture:**
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
