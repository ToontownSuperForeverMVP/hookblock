-- engine/character.lua
-- Character: Roblox-like avatar composed of a Model containing a Humanoid and Parts.
-- Currently simplified to a single movable block (HumanoidRootPart) as requested.

local Instance = require("engine.instance")
local Humanoid = require("engine.humanoid")
local Part = require("engine.part")
local Vector3 = require("engine.vector3")
local Color3 = require("engine.color3")

local Character = setmetatable({}, {__index = Instance})
Character.ClassName = "Model"
Character.__index = Character
Character.__newindex = Instance.__newindex

function Character.new(name)
    local self = Instance.new("Model", name or "Character")
    setmetatable(self, Character)

    -- Create humanoid
    self.Humanoid = Humanoid.new("Humanoid")
    self.Humanoid:setParent(self)

    -- Create the single block body (HumanoidRootPart)
    self.HumanoidRootPart = Part.new("HumanoidRootPart")
    self.HumanoidRootPart.Size = Vector3.new(2, 2, 2)
    self.HumanoidRootPart.Position = Vector3.new(0, 5, 0)
    self.HumanoidRootPart.Color = Color3.new(0.2, 0.6, 1.0)
    self.HumanoidRootPart.Anchored = false
    self.HumanoidRootPart.CanCollide = true
    self.HumanoidRootPart:setParent(self)

    self.PrimaryPart = self.HumanoidRootPart

    return self
end

function Character:setPosition(x, y, z)
    if self.HumanoidRootPart then
        self.HumanoidRootPart.Position = Vector3.new(x, y, z)
    end
end

function Character:update(dt)
    -- A single block doesn't need limb animation, but we keep this method
    -- in case future logic needs to run on the character model per frame.
end

return Character
