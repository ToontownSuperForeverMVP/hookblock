-- engine/script_runtime.lua
-- Manages execution of Script and ModuleScript instances during Play mode

local Task = require("engine.task")
local Vector3 = require("engine.vector3")
local Color3 = require("engine.color3")

local ScriptRuntime = {}
ScriptRuntime.__index = ScriptRuntime

function ScriptRuntime.new()
    local self = setmetatable({}, ScriptRuntime)
    self.runningScripts = {} -- { [scriptInstance] = {thread, env} }
    self.moduleCache = {} -- { [moduleScriptInstance] = {value} }
    self.requiringStack = {} -- To detect circular dependencies
    return self
end

function ScriptRuntime:start(workspace)
    self.runningScripts = {}
    self.moduleCache = {}

    local function findScripts(inst)
        if inst.ClassName == "Script" and not inst.Disabled then
            self:runScript(inst)
        end
        for _, child in ipairs(inst:GetChildren()) do
            findScripts(child)
        end
    end
    findScripts(workspace)
end

function ScriptRuntime:runScript(scriptInst)
    local env = self:createEnvironment(scriptInst)
    local f, err = load(scriptInst.Source, "=" .. scriptInst.Name, "t", env)

    if f then
        local thread = Task.spawn(f)
        self.runningScripts[scriptInst] = {
            thread = thread,
            env = env
        }
    else
        self:reportError(scriptInst, err)
    end
end

function ScriptRuntime:reportError(scriptInst, err)
    local msg = string.format("[Script Error] %s: %s", scriptInst.Name, tostring(err))
    if _G._UI and _G._UI.Output then
        _G._UI.Output.error(msg)
    else
        print(msg)
    end
end

function ScriptRuntime:requireModule(moduleInst)
    if not moduleInst or moduleInst.ClassName ~= "ModuleScript" then
        error("Attempt to require a non-ModuleScript", 2)
    end

    -- Check cache
    if self.moduleCache[moduleInst] then
        return self.moduleCache[moduleInst].value
    end

    -- Check for circular dependency
    for _, inst in ipairs(self.requiringStack) do
        if inst == moduleInst then
            error("Circular dependency detected while requiring " .. moduleInst.Name, 2)
        end
    end

    table.insert(self.requiringStack, moduleInst)

    -- Run module script
    local env = self:createEnvironment(moduleInst)
    local f, err = load(moduleInst.Source, "=" .. moduleInst.Name, "t", env)
    
    if not f then
        table.remove(self.requiringStack)
        error(string.format("Error loading ModuleScript %s: %s", moduleInst.Name, tostring(err)), 2)
    end

    local ok, result = pcall(f)
    table.remove(self.requiringStack)

    if not ok then
        error(string.format("Error running ModuleScript %s: %s", moduleInst.Name, tostring(result)), 2)
    end

    if result == nil then
        error(string.format("ModuleScript %s did not return a value", moduleInst.Name), 2)
    end

    self.moduleCache[moduleInst] = {value = result}
    return result
end

function ScriptRuntime:createEnvironment(scriptInst)
    local env = {}
    
    -- Basic globals
    env.print = function(...)
        local args = {...}
        for i, v in ipairs(args) do args[i] = tostring(v) end
        local msg = "[" .. scriptInst.Name .. "] " .. table.concat(args, " ")
        if _G._UI and _G._UI.Output then
            _G._UI.Output.log(msg)
        else
            print(msg)
        end
    end
    
    env.warn = function(...)
        local args = {...}
        for i, v in ipairs(args) do args[i] = tostring(v) end
        local msg = "[" .. scriptInst.Name .. "] " .. table.concat(args, " ")
        if _G._UI and _G._UI.Output then
            _G._UI.Output.warn(msg)
        else
            print("[WARN] " .. msg)
        end
    end

    env.error = function(msg, level)
        error(msg, level or 2)
    end

    -- Roblox-style globals
    env.script = scriptInst
    env.game = {
        Workspace = Engine.Workspace,
        GetService = function(_, name)
            if name == "Workspace" then return Engine.Workspace end
            if name == "PhysicsService" then return Engine.PlayMode.physics end
            if name == "TweenService" then return require("engine.tween_service") end
            if name == "RunService" then
                return {
                    Stepped = {
                        Connect = function(_, cb)
                            -- This is a bit hacky for now
                            return {Disconnect = function() end}
                        end
                    }
                }
            end
            return nil
        end,
    }
    env.workspace = Engine.Workspace
    
    -- Libraries
    env.Vector3 = Vector3
    env.Color3 = Color3
    env.task = Task
    env.wait = Task.wait
    env.spawn = Task.spawn
    env.delay = Task.delay
    
    env.require = function(module)
        return self:requireModule(module)
    end

    env.Instance = {
        new = function(className, parent)
            local classMap = {
                Part = require("engine.part"),
                Model = require("engine.model"),
                Folder = require("engine.instance"),
                Script = require("engine.script"),
                ModuleScript = require("engine.modulescript"),
            }
            local class = classMap[className]
            if class then
                local inst = class.new(className)
                if parent then inst:setParent(parent) end
                return inst
            end
            error("Unknown ClassName: " .. tostring(className), 2)
        end
    }

    env.tick = function() return love.timer.getTime() end
    env.os = {
        clock = os.clock,
        time = os.time,
        date = os.date,
        difftime = os.difftime,
    }
    env.math = math
    env.table = table
    env.string = string
    env.pairs = pairs
    env.ipairs = ipairs
    env.next = next
    env.tonumber = tonumber
    env.tostring = tostring
    env.type = type
    env.select = select
    env.unpack = unpack
    env.pcall = pcall
    env.xpcall = xpcall
    env._G = {}
    env._VERSION = _VERSION

    setmetatable(env, {__index = _G})
    return env
end

function ScriptRuntime:step(dt)
    Task.step(dt)
    
    -- Check for dead scripts
    for inst, state in pairs(self.runningScripts) do
        if coroutine.status(state.thread) == "dead" then
            self.runningScripts[inst] = nil
        end
    end
end

function ScriptRuntime:stop()
    self.runningScripts = {}
    self.moduleCache = {}
    -- We should probably kill threads here if they are still running
end

return ScriptRuntime
