-- studio/main.lua
local UI         = require("studio.ui")
local ToolManager = require("studio.tools.tool_manager")

local Studio = {}

function Studio.load()
    UI.load()
    ToolManager.load()

    -- Load grid texture
    local ok, gridTexture = pcall(love.graphics.newImage, "assets/grid.png")
    if not ok then gridTexture = nil end
    if gridTexture then gridTexture:setWrap("repeat", "repeat") end

    -- Default scene objects
    local Part = require("engine.part")
    local SpawnLocation = require("engine.spawnlocation")
    local Vector3 = require("engine.vector3")
    local Color3 = require("engine.color3")

    -- The Baseplate (Thickened to 4 studs to prevent physics tunneling at 60Hz)
    local baseplate = Part.new("Baseplate")
    baseplate.Size     = Vector3.new(50, 4, 50)
    baseplate.Position = Vector3.new(0, -2, 0)
    baseplate.Color    = Color3.new(0.3, 0.3, 0.3)
    baseplate.Anchored = true
    baseplate:setTexture("assets/grid.png")
    baseplate:setParent(Engine.Workspace)

    -- A decorative Part
    local p2 = Part.new("Part")
    p2.Size     = Vector3.new(2, 2, 2)
    p2.Position = Vector3.new(0, 1, 0)
    p2.Color    = Color3.new(0.1, 0.6, 1)
    p2.Anchored = true
    p2:setParent(Engine.Workspace)

    -- SpawnLocation
    local spawn = SpawnLocation.new("SpawnLocation")
    spawn.Position = Vector3.new(5, 0.5, 5)
    spawn:setParent(Engine.Workspace)

    print("[Luvoxel] Scene loaded — 3 objects in Workspace")
end

function Studio.update(dt)
    UI.update(dt)
    if Engine.PlayMode and Engine.PlayMode.state == "Stopped" then
        ToolManager.update(dt)
    end
end

function Studio.draw()
    -- G3D resets depth test — clear it before 2D UI
    love.graphics.setDepthMode()
    UI.draw()
    if Engine.PlayMode and Engine.PlayMode.state == "Stopped" then
        ToolManager.draw()
    end
end

function Studio.mousepressed(x, y, button, istouch, presses)
    -- UI panels get first pick
    if UI.mousepressed(x, y, button, istouch, presses) then return end
    -- Otherwise let viewport tool handle it (only in studio mode)
    if Engine.PlayMode and Engine.PlayMode.state == "Stopped" then
        ToolManager.mousepressed(x, y, button)
    end
end

function Studio.mousereleased(x, y, button, istouch, presses)
    UI.mousereleased(x, y, button)
    if Engine.PlayMode and Engine.PlayMode.state == "Stopped" then
        ToolManager.mousereleased(x, y, button)
    end
end

function Studio.mousemoved(x, y, dx, dy, istouch)
    UI.mousemoved(x, y, dx, dy)
    if Engine.PlayMode and Engine.PlayMode.state == "Stopped" then
        ToolManager.mousemoved(x, y, dx, dy)
    end
end

function Studio.wheelmoved(x, y)
    UI.wheelmoved(x, y)
    if Engine.PlayMode and Engine.PlayMode.state == "Stopped" then
        ToolManager.wheelmoved(x, y)
    end
end

function Studio.keypressed(key, scancode, isrepeat)
    UI.keypressed(key)
    if Engine.PlayMode and Engine.PlayMode.state == "Stopped" then
        ToolManager.keypressed(key)
    end
end

function Studio.textinput(t)
    UI.textinput(t)
end

return Studio
