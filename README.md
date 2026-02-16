# ClipboardPoncho

A sci-fi/fantasy real-time strategy game built with Godot 4.6, inspired by StarCraft 2.

## Overview

ClipboardPoncho is an ambitious RTS featuring:
- **Stylized 3D graphics** with perspective camera (near-isometric view)
- **Large-scale battles** supporting 500+ units per side
- **StarCraft 2-inspired gameplay** with fast-paced unit movement and exciting battles
- **Core RTS mechanics**: base building, resource gathering, worker management, tech trees, and unit upgrades
- **PvE focused** with potential co-op mode against AI opponents
- **Built-in map/scenario editor**

## Technical Stack

- **Engine**: Godot 4.6
- **Renderer**: Forward+ (for best 3D performance and lighting)
- **Language**: GDScript
- **Target Platforms**: PC (Windows, Linux, macOS)

## Getting Started

### Prerequisites
- Godot 4.6 or later
- Git

### Opening the Project
1. Clone this repository
2. Open Godot 4.6
3. Import the project by selecting the `project.godot` file
4. Press F5 to run the main scene

## Project Structure

```
ClipboardPoncho/
├── scenes/          # All .tscn scene files
│   ├── main/       # Main game scenes
│   ├── units/      # Unit scenes and prefabs
│   ├── buildings/  # Building scenes
│   ├── ui/         # UI scenes
│   └── maps/       # Map/level scenes
├── scripts/         # All GDScript files
│   ├── systems/    # Core game systems (managers)
│   ├── units/      # Unit behavior scripts
│   ├── buildings/  # Building scripts
│   ├── ui/         # UI controller scripts
│   ├── ai/         # AI behavior and pathfinding
│   └── utils/      # Utility scripts
├── assets/          # All game assets
│   ├── models/     # 3D models (.gltf, .glb)
│   ├── textures/   # Textures and materials
│   ├── audio/      # Sound effects and music
│   └── vfx/        # Visual effects
└── addons/          # Godot plugins and extensions
```

## Development Status

🚧 **Early Development** - Core systems are being implemented.

Current focus:
- [ ] Core game systems (UnitManager, ResourceManager, PathfindingManager)
- [ ] Basic unit movement and selection
- [ ] Resource gathering mechanics
- [ ] Camera controls (RTS-style)
- [ ] Basic AI opponent
