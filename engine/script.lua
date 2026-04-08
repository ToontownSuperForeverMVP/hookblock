-- engine/script.lua
-- Script instance that runs Lua code in the engine

local Instance = require("engine.instance")

local Script = setmetatable({}, {__index = Instance})
Script.ClassName = "Script"
Script.__index = Script
Script.__newindex = Instance.__newindex

function Script.new(name)
    local self = setmetatable({}, Script)
    self:init("Script", name or "Script")

    self.Source = "-- New Script\nprint(\"Hello from \" .. script.Name)"
    self.Disabled = false
    self.RunContext = "Legacy"

    return self
end

-- Register class
Instance.register("Script", Script)

return Script
