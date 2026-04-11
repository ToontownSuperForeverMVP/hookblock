# Luvöxel Studio (MCP Edition)

**Luvöxel Studio** (powered by the **HookBlock Engine**) is a high-performance, 3D game development environment and engine built on the **LÖVE (Love2D)** framework. This branch (`unstable-mcp`) is dedicated to AI-driven development via the **Model Context Protocol (MCP)**.

## 🚀 Key Offerings

### 1. The Engine (HookBlock)
A robust, object-oriented 3D engine with a strict Instance-Property hierarchy.
- **Hierarchical Object Model**: Familiar `Instance`, `Part`, `Model`, `Workspace`, and `Folder` classes.
- **Lua Scripting Runtime**: Support for `Script` and `ModuleScript` with a sandboxed environment.
- **Integrated Physics**: A custom AABB-based 3D physics engine.

### 2. The Studio (IDE)
A full-featured development environment to build and manage 3D scenes.
- **Scene Explorer & Properties Editor**: Real-time management of the game hierarchy.
- **Professional Transformation Tools**: Standard `Move`, `Scale`, and `Rotate` gizmos.
- **Native Script Editor**: Multi-tab Lua editor with syntax highlighting.

### 3. MCP Integration (AI-Driven Development)
The first engine of its kind to natively host a **Model Context Protocol (MCP)** server on `localhost:7111`. This allows AI agents (like Claude, Gemini, or Cursor) to:
- **Explore**: Inspect the live DataModel hierarchy.
- **Manipulate**: Move, scale, and rotate objects in real-time.
- **Code**: Read, write, and execute Lua scripts remotely.
- **Debug**: Visual debugging via screenshots and real-time logs.

## 🛠️ Getting Started

### Prerequisites
You must have **LÖVE 11.x** installed.
- **Windows/macOS/Linux**: Download from [love2d.org](https://love2d.org/).

### Running from Source
1. **Clone the repository and switch to MCP branch**:
   ```bash
   git clone -b unstable-mcp https://github.com/ToontownSuperForeverMVP/hookblock.git
   cd hookblock
   ```
2. **Launch with LÖVE**:
   - `love .`

## ⌨️ Studio Controls
| Action | Shortcut |
| :--- | :--- |
| **Undo / Redo** | `Ctrl+Z` / `Ctrl+Y` |
| **Save Scene** | `Ctrl+S` |
| **Play / Stop** | `F5` / `F7` |

## 📁 Architecture
- `/engine`: Core runtime logic.
- `/studio`: The development UI and tools.
- `/mcp`: Model Context Protocol server and tool implementation.
- `/g3d`: 3D rendering library.

## 📜 License
Licensed under the **GNU General Public License v3.0**.

This branch is experimental and optimized for AI-human collaborative workflows.
