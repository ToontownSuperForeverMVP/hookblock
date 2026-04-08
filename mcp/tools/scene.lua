-- mcp/tools/scene.lua
-- Save and load the workspace via the engine serializer

local Scene = {}

function Scene.save(_args)
    if not Engine or not Engine.Workspace then
        return false, nil, "Engine.Workspace not ready"
    end

    local Serializer = require("engine.serializer")
    local tmpFile = "mcp_scene_export.json"

    local ok, err = pcall(Serializer.saveToFile, Engine.Workspace, tmpFile)
    if not ok then
        return false, nil, "Save failed: " .. tostring(err)
    end

    local content = love.filesystem.read(tmpFile)
    if not content then
        return false, nil, "Could not read saved file"
    end

    -- Clean up temp file
    love.filesystem.remove(tmpFile)

    return true, {
        json     = content,
        byteSize = #content,
        savePath = love.filesystem.getSaveDirectory() .. "/" .. tmpFile,
    }
end

function Scene.load(args)
    local jsonStr = args.json
    if not jsonStr or type(jsonStr) ~= "string" then
        return false, nil, "args.json (string) is required"
    end

    local Serializer = require("engine.serializer")
    local tmpFile = "mcp_scene_import.json"

    local writeOk = love.filesystem.write(tmpFile, jsonStr)
    if not writeOk then
        return false, nil, "Could not write import file"
    end

    local ws, err = pcall(Serializer.loadFromFile, tmpFile)
    love.filesystem.remove(tmpFile)

    if not ws then
        return false, nil, "Load failed: " .. tostring(err)
    end

    Engine.Workspace = ws
    return true, {message = "Workspace loaded successfully"}
end

return Scene
