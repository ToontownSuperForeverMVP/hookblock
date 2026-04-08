-- mcp/dispatcher.lua
-- Routes tool names to handler modules and returns results

local Screenshot = require("mcp.tools.screenshot")
local Inspect    = require("mcp.tools.inspect")
local Control    = require("mcp.tools.control")
local PlayMode   = require("mcp.tools.playmode")
local Eval       = require("mcp.tools.eval")
local Scene      = require("mcp.tools.scene")

local TOOL_LIST = {
    {
        name = "screenshot",
        description = "Capture the current studio viewport as a PNG. Returns path and base64 data.",
        inputSchema = { type = "object", properties = {} }
    },
    {
        name = "inspect",
        description = "Return the full workspace scene tree as JSON.",
        inputSchema = { type = "object", properties = {} }
    },
    {
        name = "get_instance",
        description = "Get properties of a named instance.",
        inputSchema = {
            type = "object",
            properties = { path = { type = "string" } },
            required = {"path"}
        }
    },
    {
        name = "set_property",
        description = "Set a property on an instance.",
        inputSchema = {
            type = "object",
            properties = {
                path = { type = "string" },
                property = { type = "string" },
                value = {} -- Allow any type by omitting 'type'
            },
            required = {"path", "property", "value"}
        }
    },

    {
        name = "select_instance",
        description = "Set the studio selection.",
        inputSchema = {
            type = "object",
            properties = { path = { type = "string" } },
            required = {"path"}
        }
    },
    {
        name = "control_key",
        description = "Inject a key event.",
        inputSchema = {
            type = "object",
            properties = {
                key = { type = "string" },
                action = { type = "string", enum = {"press", "release"} }
            },
            required = {"key", "action"}
        }
    },
    {
        name = "control_mouse",
        description = "Inject a mouse click.",
        inputSchema = {
            type = "object",
            properties = {
                x = { type = "number" },
                y = { type = "number" },
                button = { type = "number" }
            },
            required = {"x", "y", "button"}
        }
    },
    {
        name = "control_mousemove",
        description = "Move the virtual mouse.",
        inputSchema = {
            type = "object",
            properties = {
                x = { type = "number" },
                y = { type = "number" }
            },
            required = {"x", "y"}
        }
    },
    {
        name = "control_type",
        description = "Type a string as text input.",
        inputSchema = {
            type = "object",
            properties = { text = { type = "string" } },
            required = {"text"}
        }
    },
    {
        name = "playmode_play",
        description = "Start play mode.",
        inputSchema = { type = "object", properties = {} }
    },
    {
        name = "playmode_pause",
        description = "Pause play mode.",
        inputSchema = { type = "object", properties = {} }
    },
    {
        name = "playmode_stop",
        description = "Stop play mode.",
        inputSchema = { type = "object", properties = {} }
    },
    {
        name = "playmode_state",
        description = "Return current play mode state string.",
        inputSchema = { type = "object", properties = {} }
    },
    {
        name = "eval",
        description = "Run Lua code inside the engine.",
        inputSchema = {
            type = "object",
            properties = { code = { type = "string" } },
            required = {"code"}
        }
    },
    {
        name = "scene_save",
        description = "Serialize current workspace to JSON. Returns JSON string.",
        inputSchema = { type = "object", properties = {} }
    },
    {
        name = "scene_load",
        description = "Load workspace from JSON string.",
        inputSchema = {
            type = "object",
            properties = { json = { type = "string" } },
            required = {"json"}
        }
    },
    {
        name = "get_logs",
        description = "Return recent print() output.",
        inputSchema = {
            type = "object",
            properties = { n = { type = "number", default = 50 } }
        }
    },
    {
        name = "list_tools",
        description = "Return this tool list.",
        inputSchema = { type = "object", properties = {} }
    },
}

TOOL_LIST.__IS_ARRAY = true



local Dispatcher = {}

function Dispatcher.dispatch(name, args)
    -- list_tools
    if name == "list_tools" then
        return true, {tools = TOOL_LIST}

    -- get_logs
    elseif name == "get_logs" then
        local logs = _G._MCP_getLogs and _G._MCP_getLogs(args.n or 50) or {}
        return true, {logs = logs}

    -- Screenshot
    elseif name == "screenshot" then
        return Screenshot.capture(args)

    -- Inspect / instance tools
    elseif name == "inspect" then
        return Inspect.sceneTree(args)
    elseif name == "get_instance" then
        return Inspect.getInstance(args)
    elseif name == "set_property" then
        return Inspect.setProperty(args)
    elseif name == "select_instance" then
        return Inspect.selectInstance(args)

    -- Control
    elseif name == "control_key" then
        return Control.key(args)
    elseif name == "control_mouse" then
        return Control.mouse(args)
    elseif name == "control_mousemove" then
        return Control.mousemove(args)
    elseif name == "control_type" then
        return Control.typeText(args)

    -- PlayMode
    elseif name == "playmode_play" then
        return PlayMode.play(args)
    elseif name == "playmode_pause" then
        return PlayMode.pause(args)
    elseif name == "playmode_stop" then
        return PlayMode.stop(args)
    elseif name == "playmode_state" then
        return PlayMode.getState(args)

    -- Eval
    elseif name == "eval" then
        return Eval.run(args)

    -- Scene
    elseif name == "scene_save" then
        return Scene.save(args)
    elseif name == "scene_load" then
        return Scene.load(args)


    else
        return false, nil, "Unknown tool: " .. tostring(name)
    end
end

function Dispatcher.poll(name)
    if name == "screenshot" then
        return Screenshot.poll()
    end
    return false, nil, "Tool not pollable: " .. tostring(name)
end

return Dispatcher


