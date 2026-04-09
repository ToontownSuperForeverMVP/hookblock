# Luvöxel Studio

**Luvöxel Studio** (powered by the **HookBlock Engine**) is a high-performance, 3D game development environment and engine built on the **LÖVE (Love2D)** framework. The HookBlock Engine is a modified and extended version of the **g3d** engine, optimized for Roblox-style hierarchical object models and real-time physics. The studio provides a professional-grade suite of development tools, uniquely optimized for integration with AI-driven workflows via the Model Context Protocol (MCP).

## 🚀 Key Offerings

### 1. The Engine (HookBlock)
A robust, object-oriented 3D engine with a strict Instance-Property hierarchy.
- **Hierarchical Object Model**: Familiar `Instance`, `Part`, `Model`, `Workspace`, and `Folder` classes.
- **Lua Scripting Runtime**: Support for `Script` and `ModuleScript` with a sandboxed environment, including a custom `Task` scheduler and `TweenService`.
- **Integrated Physics**: A custom AABB-based 3D physics engine with gravity, rigid body dynamics, and collision detection.
- **Character Support**: Built-in `Humanoid` and `Character` models with movement and health management.
- **Optimized Rendering**: High-precision 3D pipeline featuring back-face culling, 24-bit depth buffering, and transparency sorting.

### 2. The Studio (IDE)
A full-featured development environment to build and manage 3D scenes.
- **Scene Explorer**: Real-time tree view of the game hierarchy with drag-and-drop support.
- **Properties Editor**: Dynamic UI for inspecting and modifying instance properties in real-time.
- **Professional Transformation Tools**: Standard `Move`, `Scale`, and `Rotate` gizmos for precise spatial manipulation.
- **Multi-Tab Script Editor**: A native Lua editor with syntax highlighting, auto-indentation, and multi-tab support for direct code editing within the engine.
- **Asset Browser**: Centralized management for importing 3D models (`.obj`), textures, and fonts.
- **Quality of Life**: Built-in Undo/Redo (`Ctrl+Z`/`Ctrl+Y`), Duplication (`Ctrl+D`), and Selection Focusing (`F`).

### 3. MCP Integration (AI-Driven Development)
The first engine of its kind to natively host a **Model Context Protocol (MCP)** server on `localhost:7111`.
- **AI-Powered Manipulation**: Connect AI agents (like Gemini or Claude) to explore the game tree, inspect properties, and modify the scene remotely.
- **Remote Code Execution**: Execute Lua code directly within the engine via the `eval` tool.
- **Automated Scene Auditing**: Use tools to scan, refactor, or generate complex game hierarchies autonomously.

## 🛠️ Getting Started

### Prerequisites
You must have **LÖVE 11.x** installed.
- **Windows/macOS/Linux**: Download from [love2d.org](https://love2d.org/).

### Running from Source
1. **Clone the repository**:
   ```bash
   git clone -b unstable https://github.com/ToontownSuperForeverMVP/hookblock.git
   cd hookblock
   ```
2. **Launch with LÖVE**:
   - **Windows**: `path/to/love.exe .`
   - **macOS**: `open -a love .`
   - **Linux**: `love .`

## ⌨️ Studio Controls
| Action | Shortcut |
| :--- | :--- |
| **Undo / Redo** | `Ctrl+Z` / `Ctrl+Y` (or `Ctrl+Shift+Z`) |
| **Duplicate** | `Ctrl+D` |
| **Delete** | `Delete` / `Backspace` |
| **Group selection** | `Ctrl+G` |
| **Focus Camera** | `F` |
| **Save Scene** | `Ctrl+S` (saves to `save.json`) |
| **Play / Stop** | `F5` / `F7` |

## 📁 Architecture
- `/engine`: Core runtime logic (`Instance`, `Vector3`, `Physics`, `PlayMode`).
- `/studio`: The development UI, tools, and script editor.
- `/g3d`: Lightweight 3D rendering library.
- `/mcp`: Model Context Protocol server and tool implementation.
- `/assets`: Default assets including models, icons, and textures.

## 📜 License
Licensed under the **GNU General Public License v3.0**. See the [LICENSE](LICENSE) file for details.
