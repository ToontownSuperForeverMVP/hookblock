-- engine/value_instances.lua
-- Roblox-style Value instances

local Instance = require("engine.instance")

-- Generic factory for Value classes
local function createValueClass(className, defaultValue)
    local cls = setmetatable({}, {__index = Instance})
    cls.ClassName = className
    cls.__index = cls
    cls.__newindex = Instance.__newindex

    function cls.new(name)
        local self = setmetatable({}, cls)
        self:init(className, name or className)
        self.Value = defaultValue
        return self
    end

    Instance.register(className, cls)
    return cls
end

local ValueInstances = {
    BoolValue = createValueClass("BoolValue", false),
    StringValue = createValueClass("StringValue", ""),
    NumberValue = createValueClass("NumberValue", 0),
    IntValue = createValueClass("IntValue", 0),
    Color3Value = createValueClass("Color3Value", require("engine.color3").new(1,1,1)),
    Vector3Value = createValueClass("Vector3Value", require("engine.vector3").new(0,0,0)),
}

return ValueInstances
