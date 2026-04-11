-- Hardware-Aware Performance Configuration
io.stdout:setvbuf("no")
local isWindows = love.system.getOS() == "Windows"
local Config = {
    targetFPS = 60,
    physicsSubsteps = isWindows and 3 or 2, -- Smoother physics on Windows
    farClip = isWindows and 1000 or 500,    -- Further view distance on modern hardware
    gcPause = 105,
    gcStepMul = 250,
    memEmergencyThreshold = 256             -- Increased for modern 64-bit systems
}

-- Globals
Engine = { Config = Config }
Studio = {}

collectgarbage("setpause", Config.gcPause)
collectgarbage("setstepmul", Config.gcStepMul)

-- Load Engine components
local Game = require("engine.game")
local Camera = require("engine.camera")
local Sky = require("engine.sky")
local History = require("engine.history")
local PlayMode = require("engine.play_mode")
local Serializer = require("engine.serializer")

-- Hotloader and Error Catcher
local Hotloader = require("studio.hotloader")
love.errorhandler = require("studio.error_catcher")

-- Studio Main
local StudioMain = require("studio.main")
_G.Studio = StudioMain

-- Localize for performance
local math_min = math.min
local lg = love.graphics
local lt = love.timer

_G.g3d = require("g3d")
local Loading = require("studio.loading")
local StartMenu = require("studio.start_menu")

-- State
local fpsTimer = 0
local lightingTimer = 0
local appState = "start"

function love.load()
    -- Center window on load for a better Windows experience
    local _, _, flags = love.window.getMode()
    local dw, dh = love.window.getDesktopDimensions(flags.display)
    local ww, wh = love.window.getMode()

    -- Safety check: if standard resolution is larger than desktop, scale down
    if ww > dw or wh > dh then
        ww = math.floor(dw * 0.8)
        wh = math.floor(dh * 0.8)
        love.window.setMode(ww, wh, {resizable=true, highdpi=true, msaa=4, vsync=1})
    end

    love.window.setPosition(math.floor((dw - ww) / 2), math.floor((dh - wh) / 2), flags.display)

    -- Initial minimal setup for loading screen
    require("studio.theme").loadAssets()
    
    StartMenu.init(function(projName, isNew)
        Engine.CurrentProject = projName
        appState = "loading"
        
        local tasks = {
            { name = "Initializing Core Engine", func = function()
                -- Initialize root game DataModel
                local gameInst = Game.new()
                gameInst:init_aliases()
                
                -- Expose common services
                Engine.Game = gameInst
                Engine.Workspace = gameInst:GetService("Workspace")
                Engine.Lighting = gameInst:GetService("Lighting")
                gameInst:GetService("ReplicatedStorage")
                gameInst:GetService("ServerStorage")
                gameInst:GetService("StarterGui")
                gameInst:GetService("ReplicatedFirst")
                gameInst:GetService("Players")

                Engine.Camera = Camera.new()
                Engine.Sky = Sky.new()
                Engine.History = History.new()
                Engine.PlayMode = PlayMode.new()
            end },
            { name = "Configuring Physics & Rendering", func = function()
                -- Apply Recommended Baseline settings
                g3d.camera.farClip = Config.farClip
                g3d.camera.updateProjectionMatrix()

                if Engine.Workspace.Physics then
                    Engine.Workspace.Physics.substeps = Config.physicsSubsteps
                end
            end },
            { name = "Loading UI System & Resources", func = function()
                require("studio.ui").load()
            end },
            { name = "Preparing Workspace Tools", func = function()
                require("studio.tools.tool_manager").load()
            end },
            { name = "Loading Environment Assets", func = function()
                local ok, gridTexture = pcall(love.graphics.newImage, "assets/grid.png")
                if ok and gridTexture then gridTexture:setWrap("repeat", "repeat") end
            end },
            { name = "Synchronizing DataModel", func = function()
                local Part = require("engine.part")
                local SpawnLocation = require("engine.spawnlocation")
                local Vector3 = require("engine.vector3")
                local Color3 = require("engine.color3")

                if not isNew then
                    -- Load from file
                    local path = "projects/" .. projName .. "/workspace.json"
                    if love.filesystem.getInfo(path) then
                        local loaded = Serializer.loadFromFile(path)
                        if loaded then
                            -- Clear current workspace children
                            local currentChildren = Engine.Workspace:GetChildren()
                            for i = #currentChildren, 1, -1 do
                                currentChildren[i]:setParent(nil)
                            end
                            -- Add loaded children
                            for _, child in ipairs(loaded:GetChildren()) do
                                child:setParent(Engine.Workspace)
                            end
                            print("[Luvoxel] Loaded workspace from " .. path)
                        else
                            print("[Error] Failed to load workspace!")
                            isNew = true
                        end
                    else
                        print("[Warning] Save file not found: " .. path)
                        isNew = true
                    end
                end
                
                if isNew then
                    -- Generate default scene
                    -- 1. Baseplate (Thickened to 4 studs to prevent physics tunneling at 60Hz)
                    local baseplate = Part.new("Baseplate")
                    baseplate.Size     = Vector3.new(100, 4, 100)
                    baseplate.Position = Vector3.new(0, -2, 0)
                    baseplate.Color    = Color3.new(0.3, 0.3, 0.3)
                    baseplate.Anchored = true
                    baseplate.Locked   = true
                    baseplate:setTexture("assets/grid.png")
                    baseplate:setParent(Engine.Workspace)

                    -- 2. Spawn Point
                    local spawn = SpawnLocation.new("SpawnLocation")
                    spawn.Position = Vector3.new(0, 0.5, 0)
                    spawn:setParent(Engine.Workspace)
                end
            end },
            { name = "Preparing Asset Registry", func = function()
                -- Placeholder for asset registry loading
                love.timer.sleep(0.05)
            end },
            { name = "Initializing Hotloader", func = function()
                Hotloader.init()
                Hotloader.loadState()
            end },
            { name = "Finalizing Project", func = function()
                love.timer.sleep(0.1)
            end }
        }

        Loading.init(tasks, function()
            appState = "studio"
            print("[Luvöxel] All systems initialized")
        end)
    end)
end

function love.update(dt)
    -- State transition requested
    if _G._RequestedState then
        appState = _G._RequestedState
        _G._RequestedState = nil
        if appState == "start" then
            StartMenu.init(StartMenu._callback) -- Re-init start menu
        end
        return
    end

    if appState == "start" then
        StartMenu.update(dt)
        return
    elseif appState == "loading" then
        Loading.update(dt)
        return
    end

    -- Cap dt to avoid physics explosions
    dt = math_min(dt, 1/30)

    if Engine.PlayMode and Engine.PlayMode.state == "Playing" then
        -- Play mode: run physics + character
        Engine.PlayMode:update(dt, Engine.Workspace)
    elseif Engine.Camera then
        -- Studio mode: fly camera
        Engine.Camera:update(dt)
    end

    StudioMain.update(dt)
    Hotloader.update(dt)

    -- Update Lighting at a lower frequency
    lightingTimer = lightingTimer + dt
    if lightingTimer >= 0.1 then -- 10Hz lighting updates
        if Engine.Lighting then
            Engine.Lighting:Update(lightingTimer)
        end
        lightingTimer = 0
    end

    -- Performance Monitoring (Standardized)
    fpsTimer = fpsTimer + dt
    if fpsTimer >= 1.0 then
        local mem = collectgarbage("count")/1024
        love.window.setTitle(string.format("Luvöxel Studio [v0.0.1-dev] - FPS: %d - MEM: %.1fMB",
            lt.getFPS(), mem))
        fpsTimer = 0

        -- More granular GC when approaching threshold to avoid large spikes
        if mem > Config.memEmergencyThreshold * 0.8 then
            collectgarbage("step", 100)
        end
        if mem > Config.memEmergencyThreshold then
            collectgarbage("collect") -- Final fallback if step didn't help
        end
    end
end

function love.draw()
    if appState == "start" then
        StartMenu.draw()
        return
    elseif appState == "loading" then
        Loading.draw()
        return
    end

    local UI = require("studio.ui")
    local lay = UI.getLayout and UI.getLayout() or {viewX=0, viewY=0, viewW=lg.getWidth(), viewH=lg.getHeight()}

    -- Update 3D viewport projection if needed
    local targetAspect = lay.viewW / lay.viewH
    if math.abs(g3d.camera.aspectRatio - targetAspect) > 0.001 then
        g3d.camera.updateProjectionMatrix(targetAspect)
    end

    -- Enable depth testing and back-face culling for 3D rendering
    lg.setDepthMode("lequal", true)
    lg.setMeshCullMode("back")

    -- Scissor to viewport
    lg.setScissor(lay.viewX, lay.viewY, lay.viewW, lay.viewH)

    -- Render Sky first
    if Engine.Sky then
        Engine.Sky:draw()
    end

    -- Render 3D World
    if Engine.Workspace then
        Engine.Workspace:render()
    end

    -- Render play mode (character + HUD)
    if Engine.PlayMode and Engine.PlayMode.state ~= "Stopped" then
        Engine.PlayMode:draw()
    end

    lg.setScissor()

    -- Render UI on top
    lg.setDepthMode()
    lg.setMeshCullMode("none")
    StudioMain.draw()
end

function love.mousepressed(x, y, button, istouch, presses)
    if appState == "start" then
        StartMenu.mousepressed(x, y, button)
        return
    elseif appState == "loading" then
        return
    end
    StudioMain.mousepressed(x, y, button, istouch, presses)
end

function love.mousereleased(x, y, button, istouch, presses)
    if appState ~= "studio" then return end
    StudioMain.mousereleased(x, y, button)
end

function love.mousemoved(x, y, dx, dy, istouch)
    if appState ~= "studio" then return end
    StudioMain.mousemoved(x, y, dx, dy)
    if Engine.PlayMode and Engine.PlayMode.state == "Playing" then
        Engine.PlayMode:mousemoved(dx, dy)
    elseif Engine.Camera then
        Engine.Camera:mousemoved(x, y, dx, dy)
    end
end

function love.wheelmoved(x, y)
    if appState ~= "studio" then return end
    StudioMain.wheelmoved(x, y)
    if Engine.PlayMode and Engine.PlayMode.state == "Playing" then
        Engine.PlayMode:wheelmoved(y)
    elseif Engine.PlayMode and Engine.PlayMode.state == "Stopped" then
        local mx, my = love.mouse.getPosition()
        if _G._UI and not _G._UI.isOverUI(mx, my) and Engine.Camera then
            Engine.Camera:wheelmoved(x, y)
        end
    end
end

function love.keypressed(key, scancode, isrepeat)
    if appState == "start" then
        StartMenu.keypressed(key)
        return
    elseif appState == "loading" then
        return
    end

    if key == "escape" then
        if Engine.PlayMode and Engine.PlayMode.state ~= "Stopped" then
            Engine.PlayMode.menuOpen = not Engine.PlayMode.menuOpen
            return
        end
    end

    -- Global shortcuts
    if love.keyboard.isDown("lctrl", "rctrl", "lgui", "rgui") then
        if key == "z" and Engine.History then
            Engine.History:undo()
            return
        elseif key == "y" and Engine.History then
            Engine.History:redo()
            return
        elseif key == "s" and Engine.Workspace and Engine.CurrentProject then
            Serializer.saveToFile(Engine.Workspace, "projects/" .. Engine.CurrentProject .. "/workspace.json")
            _G._Notifications.new("Saved project: " .. Engine.CurrentProject, "info")
            return
        elseif key == "d" then
            local sel = _G._UI and _G._UI.selectedInstance
            if sel and sel.Clone and sel.ClassName ~= "Workspace" and sel.ClassName ~= "DataModel" then
                local clone = sel:Clone()
                if clone.Position then
                    clone.Position.x = clone.Position.x + 2
                end
                clone.Parent = sel.Parent or Engine.Workspace
                if Engine.History then
                    Engine.History:recordCreate(clone, clone.Parent)
                end
                _G._UI.selectedInstance = clone
                print("[Luvoxel] Duplicated " .. sel.Name)
            end
            return
        end
    end

    -- F5/F6/F7 for play controls
    if Engine.PlayMode then
        if key == "f5" then
            if Engine.PlayMode.state == "Stopped" then
                Engine.PlayMode:play(Engine.Workspace)
            end
            return
        elseif key == "f6" then
            Engine.PlayMode:pause()
            return
        elseif key == "f7" or key == "f8" then
            Engine.PlayMode:stop(Engine.Workspace)
            return
        end
    end

    -- Delete
    if key == "delete" or key == "backspace" then
        local Properties = require("studio.ui.properties")
        local Explorer = require("studio.ui.explorer")
        if not (Properties.isEditing() or Explorer.searchFocused) then
            local sel = _G._UI and _G._UI.selectedInstance
            if sel and sel.Parent and sel.ClassName ~= "Workspace" and sel.ClassName ~= "DataModel" then
                local parent = sel.Parent
                if Engine.History then
                    Engine.History:recordDelete(sel, parent)
                end
                sel.Parent = nil
                _G._UI.selectedInstance = nil
                print("[Luvoxel] Deleted " .. sel.Name)
                return
            end
        end
    end

    StudioMain.keypressed(key, scancode, isrepeat)
end

function love.textinput(t)
    if appState == "start" then
        StartMenu.textinput(t)
        return
    elseif appState == "loading" then
        return
    end
    StudioMain.textinput(t)
end

function love.resize(w, h)
    g3d.camera.updateProjectionMatrix()
end

function love.filedropped(file)
    if appState ~= "studio" then return end
    local path = file:getFilename()
    local ext = path:match("%.([^%.]+)$")
    if not ext then return end
    ext = ext:lower()

    local Part = require("engine.part")
    local Script = require("engine.script")

    if ext == "obj" then
        -- Load as a new Part with this mesh
        local p = Part.new(path:match("([^/\\]+)%.obj$") or "Model")
        if Engine.Camera then
            p.Position = Engine.Camera:getFrontPosition(10)
        end
        p:setShape("Mesh")
        p:setParent(Engine.Workspace)
        _G._Notifications.new("Imported model: " .. path:match("([^/\\]+)$"), "info")
    elseif ext == "png" or ext == "jpg" or ext == "jpeg" then
        -- Apply as texture to selected part
        local sel = _G._UI and _G._UI.selectedInstance
        if sel and sel.setTexture then
            sel:setTexture(path)
            _G._Notifications.new("Applied texture: " .. path:match("([^/\\]+)$"), "info")
        else
            _G._Notifications.new("Select a Part to apply texture", "warn")
        end
    elseif ext == "lua" then
        -- Create a new script
        local s = Script.new(path:match("([^/\\]+)%.lua$") or "Script")
        file:open("r")
        local content = file:read()
        file:close()
        if content then
            s.Source = content
            s:setParent(Engine.Workspace)
            _G._Notifications.new("Imported script: " .. path:match("([^/\\]+)$"), "info")
        end
    end
end

function love.quit()
    require("studio.ui.script_editor").cleanup()
end
