-- engine/spawnlocation.lua
-- SpawnLocation: marks where the player spawns in play mode

local Part = require("engine.part")
local Instance = require("engine.instance")
local Vector3 = require("engine.vector3")
local Color3 = require("engine.color3")

local SpawnLocation = setmetatable({}, {__index = Part})
SpawnLocation.ClassName = "SpawnLocation"
SpawnLocation.__index = SpawnLocation
SpawnLocation.__newindex = Instance.__newindex

function SpawnLocation.new(name)
    local self = Part.new(name or "SpawnLocation")
    setmetatable(self, SpawnLocation)
    self.ClassName = "SpawnLocation"

    -- Default properties
    self.Size = Vector3.new(4, 1, 4)
    self.Color = Color3.new(0.24, 0.71, 0.29)
    
    -- SpawnLocation-specific
    self.Duration = 0
    self.Enabled = true
    self.Neutral = true

    return self
end

-- SpawnLocation uses Part:render by default, but we can override it if we want custom visuals
-- Current SpawnLocation:render was very similar to Part:render

-- Register class
Instance.register("SpawnLocation", SpawnLocation)

return SpawnLocation
