-- engine/modulescript.lua
-- A script that returns a single value (usually a table) to be required by other scripts

local Instance = require("engine.instance")

local ModuleScript = setmetatable({}, {__index = Instance})
ModuleScript.ClassName = "ModuleScript"
ModuleScript.__index = ModuleScript
ModuleScript.__newindex = Instance.__newindex

function ModuleScript.new(name)
    local self = setmetatable({}, ModuleScript)
    self:init("ModuleScript", name or "ModuleScript")

    self.Source = "local module = {}\n\nreturn module"
    return self
end

-- Register class
Instance.register("ModuleScript", ModuleScript)

return ModuleScript
