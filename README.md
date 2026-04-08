# Luvöxel Studio / HookBlock Engine

Luvöxel Studio is a lightweight, 3D game development environment and engine inspired by the Roblox architecture, built entirely on top of the **LÖVE (Love2D)** framework. It features a familiar instance-property hierarchy, 3D workspace, and an integrated editor with Model Context Protocol (MCP) support for external tool integration.

## Key Features

- **Instance-Property System**: A hierarchical object model identical to the one found in Roblox (e.g., `Instance`, `Part`, `Workspace`, `Folder`).
- **3D Engine**: Powered by **g3d**, providing a 3D rendering pipeline within the LÖVE 2D environment.
- **Integrated Studio Environment**: 
  - **Scene Explorer**: Navigate and manage object hierarchies.
  - **Properties Editor**: Real-time manipulation of object properties.
  - **Transformation Tools**: Standard Move, Scale, and Rotate gizmos.
  - **Asset Browser**: Manage and import project assets.
- **Built-in MCP Server**: Native support for the **Model Context Protocol**, allowing AI agents (like Gemini or Claude) to inspect the game tree, manipulate objects, and execute code within the engine.
- **Roblox-like Lua Scripting**: A script runtime that supports Lua-based logic within the game hierarchy.
- **Cross-Platform**: Runs on Windows, macOS, and Linux via Love2D.

## Getting Started

### Prerequisites

You must have **LÖVE 11.x** installed on your system.

- **Windows/macOS/Linux**: Download from [love2d.org](https://love2d.org/).

### Running from Source

1. **Clone the repository**:
   ```bash
   git clone https://github.com/ToontownSuperForeverMVP/hookblock.git
   cd hookblock
   ```

2. **Launch with LÖVE**:
   - **Windows**: Drag the `hookblock` folder onto `love.exe` or run:
     ```bash
     path/to/love.exe .
     ```
   - **macOS**:
     ```bash
     open -a love .
     ```
   - **Linux**:
     ```bash
     love .
     ```

## Quality of Life (QOL) Improvements

The `qol` branch introduces several editor improvements to streamline the development workflow:

### Keyboard Shortcuts (Studio Mode)
- **`Delete` / `Backspace`**: Delete selected instance.
- **`Ctrl+D`**: Duplicate selected instance.
- **`Ctrl+Z` / `Ctrl+Shift+Z`**: Undo / Redo.
- **`Ctrl+Y`**: Redo.
- **`Ctrl+S`**: Save scene to `save.json`.
- **`Ctrl+G`**: Group selection into a Model.
- **`F`**: Focus camera on selected instance.
- **`F5` / `F6` / `F7`**: Play / Pause / Stop playtest.

### Rendering & Precision
- **Depth Buffer**: Enabled 24-bit depth buffer for correct 3D layering.
- **Back-Face Culling**: Optimized rendering by culling non-visible internal faces.
- **Improved Z-Precision**: Adjusted near-clip plane to reduce "Z-fighting" artifacts.
- **Transparency Sorting**: Semi-transparent parts no longer "cut holes" into background geometry.

## Engine Structure

- `/engine`: The core runtime, including `Instance`, `Vector3`, `Color3`, `Physics`, and `Workspace`.
- `/studio`: The development environment UI, gizmos, and editor state.
- `/g3d`: The 3D rendering library.
- `/mcp`: The Model Context Protocol server and tool dispatchers.
- `/assets`: Default models, textures, and fonts.

## MCP Integration

Luvöxel Studio hosts an MCP server on `localhost:7111`. This allows external tools to:
- **Search the Game Tree**: Find instances by name or class.
- **Inspect Instances**: Read properties, attributes, and children.
- **Execute Lua**: Run arbitrary code in the engine's environment.
- **Transform Objects**: Move or rotate parts via external commands.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.
