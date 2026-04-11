# Luvöxel Studio — MCP Development Branch (Notes)
**BRANCH: unstable-mcp**

## Branch Purpose
This branch is specifically maintained for **AI-driven development** and **Model Context Protocol (MCP)** experiments. It contains the full MCP server implementation, allowing external AI agents to interact with the engine.

## Changes & Features
- **Integrated MCP Server**: Listens on `localhost:7111`.
- **AI Tools**: Scene exploration, object manipulation, and remote Luau execution.
- **Auto-Config**: Built-in logic to inject MCP server settings into Claude, Gemini CLI, and Cursor.

## Internal Mandates
- **Keep MCP code intact**: Do not strip MCP features in this branch.
- **Version Tracking**: This branch tracks `v0.0.2-patch` and above.
