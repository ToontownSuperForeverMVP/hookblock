-- engine/game.lua
-- The root "game" object for HookBlock

local Instance = require("engine.instance")

local Game = setmetatable({}, {__index = Instance})
Game.ClassName = "DataModel"
Game.__index = Game
Game.__newindex = Instance.__newindex

local services = {}

function Game.new()
    local self = setmetatable({}, Game)
    self:init("DataModel", "game")
    
    -- Root globals for easy access
    _G.game = self
    
    return self
end

function Game:GetService(serviceName)
    if services[serviceName] then
        return services[serviceName]
    end
    
    -- Check if child already exists
    local existing = self:FindFirstChild(serviceName)
    if existing then
        services[serviceName] = existing
        return existing
    end
    
    -- Create new service
    local service
    if serviceName == "Workspace" then
        service = require("engine.workspace").new()
    elseif serviceName == "Lighting" then
        service = require("engine.lighting").new()
    elseif serviceName == "ReplicatedStorage" or serviceName == "ServerStorage" or 
           serviceName == "StarterGui" or serviceName == "ReplicatedFirst" or
           serviceName == "HttpService" or serviceName == "TweenService" or
           serviceName == "RunService" or serviceName == "Debris" or
           serviceName == "Players" then
        
        -- Default to a "Service" instance (Folder-like but fixed name)
        service = Instance.new("Folder", serviceName)
    else
        error("Service '" .. serviceName .. "' is not a valid service name", 2)
    end
    
    service.Parent = self
    services[serviceName] = service
    return service
end

-- Map common aliases
function Game:init_aliases()
    _G.workspace = self:GetService("Workspace")
    _G.game = self
end

-- Register class
Instance.register("DataModel", Game)

return Game
