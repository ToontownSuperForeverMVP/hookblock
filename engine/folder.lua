-- engine/folder.lua
-- A basic container for organization

local Instance = require("engine.instance")

local Folder = setmetatable({}, {__index = Instance})
Folder.ClassName = "Folder"
Folder.__index = Folder
Folder.__newindex = Instance.__newindex

function Folder.new(name)
    local self = setmetatable({}, Folder)
    self:init("Folder", name or "Folder")
    return self
end

-- Register class
Instance.register("Folder", Folder)

return Folder
