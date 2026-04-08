-- engine/model.lua
-- Model: groups multiple Parts under a single parent (like Roblox Model)

local Instance = require("engine.instance")
local Vector3 = require("engine.vector3")

local Model = setmetatable({}, {__index = Instance})
Model.ClassName = "Model"
Model.__index = Model
Model.__newindex = Instance.__newindex

function Model.new(name)
    local self = setmetatable({}, Model)
    self:init("Model", name or "Model")
    self.PrimaryPart = nil  -- reference to one child Part for pivot
    return self
end

-- Get the bounding box spanning all child parts
function Model:GetBoundingBox()
    local minX, minY, minZ = math.huge, math.huge, math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
    local found = false

    local function scan(inst)
        if inst:IsA("Part") then
            found = true
            local pos = inst.Position
            local size = inst.Size
            local hx = size.x / 2
            local hy = size.y / 2
            local hz = size.z / 2
            minX = math.min(minX, pos.x - hx)
            minY = math.min(minY, pos.y - hy)
            minZ = math.min(minZ, pos.z - hz)
            maxX = math.max(maxX, pos.x + hx)
            maxY = math.max(maxY, pos.y + hy)
            maxZ = math.max(maxZ, pos.z + hz)
        end
        for _, child in ipairs(inst:GetChildren()) do
            scan(child)
        end
    end

    scan(self)

    if not found then
        return {min = Vector3.new(0,0,0), max = Vector3.new(0,0,0)}
    end
    return {min = Vector3.new(minX, minY, minZ), max = Vector3.new(maxX, maxY, maxZ)}
end

-- Get the pivot point (PrimaryPart position, or bounding box center)
function Model:GetPivot()
    if self.PrimaryPart and self.PrimaryPart.Position then
        return self.PrimaryPart.Position
    end
    local bb = self:GetBoundingBox()
    return (bb.min + bb.max) * 0.5
end

-- Move entire model by offset
function Model:TranslateBy(offset)
    local function translate(inst)
        if inst:IsA("Part") then
            inst.Position = inst.Position + offset
        end
        for _, child in ipairs(inst:GetChildren()) do
            translate(child)
        end
    end
    translate(self)
end

-- Register class
Instance.register("Model", Model)

return Model
