-- studio/hotloader.lua
-- Watches files and reloads the studio while preserving state

local Hotloader = {}
local Serializer = require("engine.serializer")

-- File watching state
local files = {}
local watchDirs = {"studio", "engine"}
local lastCheck = 0
local checkInterval = 1.0 -- Increase interval for low-end specs

local function getFiles(dir, fileList)
    local items = love.filesystem.getDirectoryItems(dir)
    for _, item in ipairs(items) do
        local path = (dir == "." and "" or dir .. "/") .. item
        local info = love.filesystem.getInfo(path)
        if info then
            if info.type == "file" and (item:match("%.lua$") or item:match("%.json$")) then
                fileList[path] = info.modtime
            elseif info.type == "directory" and item ~= ".git" and item ~= "crashes" and item ~= "assets" then
                getFiles(path, fileList)
            end
        end
    end
end

function Hotloader.init()
    files = {}
    -- Only watch specific directories to save IO and CPU
    for _, dir in ipairs(watchDirs) do
        if love.filesystem.getInfo(dir, "directory") then
            getFiles(dir, files)
        end
    end
    print("[Hotloader] Watching " .. (function() local c=0 for _ in pairs(files) do c=c+1 end return c end)() .. " files.")
end

function Hotloader.update(dt)
    lastCheck = lastCheck + dt
    if lastCheck >= checkInterval then
        lastCheck = 0
        local currentFiles = {}
        -- Only watch specific directories
        for _, dir in ipairs(watchDirs) do
            if love.filesystem.getInfo(dir, "directory") then
                getFiles(dir, currentFiles)
            end
        end

        local changed = false
        for path, modtime in pairs(currentFiles) do
            if not files[path] then
                -- New file
                changed = true
                break
            elseif files[path] < modtime then
                -- Modified file
                print("[Hotloader] Change detected in " .. path)
                changed = true
                break
            end
        end

        -- Also check for deleted files
        if not changed then
            for path in pairs(files) do
                if not currentFiles[path] then
                    changed = true
                    break
                end
            end
        end

        if changed then
            files = currentFiles -- Update local cache to avoid infinite reload
            Hotloader.reload()
        end
    end
end

function Hotloader.saveState()
    print("[Hotloader] Saving state before restart...")
    -- 1. Save entire DataModel
    Serializer.saveToFile(Engine.Game, "hotreload_game.json")

    -- 2. Save Camera and UI state
    local g3d = require("g3d")
    local state = {
        camera = {
            pos = {g3d.camera.position[1], g3d.camera.position[2], g3d.camera.position[3]},
            pitch = Engine.Camera and Engine.Camera.pitch or 0,
            yaw = Engine.Camera and Engine.Camera.yaw or 0
        },
        selection = _G._UI and _G._UI.selectedInstance and _G._UI.selectedInstance.Name or nil
    }
    love.filesystem.write("hotreload_state.json", Serializer.jsonEncode(state))
end

function Hotloader.loadState()
    if not love.filesystem.getInfo("hotreload_state.json") then return end

    print("[Hotloader] Hotreload detected! Restoring state...")

    -- 1. Load DataModel
    local gm = Serializer.loadFromFile("hotreload_game.json")
    if gm then
        -- Engine.Game is already initialized in love.load, but we want to merge or replace its contents.
        -- Serializer.deserializeInstance already handles merging if it finds existing services.
        Engine.Game = gm
        Engine.Workspace = gm:GetService("Workspace")
    end

    -- 2. Load Camera and UI state
    local content = love.filesystem.read("hotreload_state.json")
    if content then
        local state = Serializer.jsonDecode(content)
        if state then
            if state.camera and Engine.Camera then
                local g3d = require("g3d")
                g3d.camera.position = {state.camera.pos[1], state.camera.pos[2], state.camera.pos[3]}
                Engine.Camera.pitch = state.camera.pitch
                Engine.Camera.yaw = state.camera.yaw
                Engine.Camera:updateTarget()
            end
            if state.selection and _G._UI then
                local function findByName(parent, name)
                    if parent.Name == name then return parent end
                    for _, child in ipairs(parent:GetChildren()) do
                        local found = findByName(child, name)
                        if found then return found end
                    end
                end
                _G._UI.selectedInstance = findByName(Engine.Game, state.selection)
            end
        end
    end

    -- Cleanup
    love.filesystem.remove("hotreload_game.json")
    love.filesystem.remove("hotreload_state.json")
    print("[Hotloader] State successfully restored.")
end

function Hotloader.reload()
    Hotloader.saveState()
    love.event.quit("restart")
end

return Hotloader
