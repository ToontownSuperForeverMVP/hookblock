-- engine/workspace.lua
local Instance = require("engine.instance")
local Physics = require("engine.physics")

local Workspace = setmetatable({}, {__index = Instance})
Workspace.ClassName = "Workspace"
Workspace.__index = Workspace
Workspace.__newindex = Instance.__newindex

function Workspace.new()
    local self = setmetatable({}, Workspace)
    self:init("Workspace", "Workspace")
    
    -- Physics Service (Internal to Workspace)
    self.Physics = Physics.new()
    
    -- Terrain
    local Terrain = require("engine.terrain")
    self.Terrain = Terrain.new("Terrain")
    self.Terrain:setParent(self)
    
    return self
end

function Workspace:render()
    local g3d = require("g3d")
    local camera = g3d.camera
    local shader = g3d.shader
    
    love.graphics.setShader(shader)
    shader:send("viewMatrix", camera.viewMatrix)
    shader:send("projectionMatrix", camera.projectionMatrix)
    if shader:hasUniform "isCanvasEnabled" then
        shader:send("isCanvasEnabled", love.graphics.getCanvas() ~= nil)
    end

    -- Call base render which will recurse through children
    Instance.render(self)
    
    love.graphics.setShader()
end

-- Register class
Instance.register("Workspace", Workspace)

return Workspace
