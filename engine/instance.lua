-- engine/instance.lua
-- Base class for all engine objects (Roblox Instance equivalent)

local Signal = require("engine.signal")
local Vector3 = require("engine.vector3")
local Color3 = require("engine.color3")

local Instance = {}
Instance.ClassName = "Instance"

-- The metatable for all instances
local InstanceMeta = {}

function InstanceMeta.__index(t, k)
    -- 1. Check hidden properties first
    local props = rawget(t, "_properties")
    if props and props[k] ~= nil then
        return props[k]
    end

    -- 2. Check properties/methods of the instance's class (metatable)
    -- Since the instance's metatable IS the class (e.g. Workspace),
    -- we can just look there.
    local cls = getmetatable(t)
    if cls then
        -- We must use rawget on the class to avoid infinite recursion
        -- if the class also has an __index function.
        -- Actually, classes are set up with __index = class, so we can just index them.
        local v = cls[k]
        if v ~= nil then return v end
    end
    
    -- 3. Fallback to children lookup by name
    local children = rawget(t, "_children")
    if children then
        for _, child in ipairs(children) do
            if child.Name == k then
                return child
            end
        end
    end
    
    return nil
end

function InstanceMeta.__newindex(t, k, v)
    if k == "Parent" then
        t:setParent(v)
        return
    end

    -- Fluid conversion for common properties
    if k == "Position" or k == "Size" or k == "Rotation" or k == "Velocity" then
        if type(v) == "table" and getmetatable(v) ~= Vector3 then
            v = Vector3.new(v.x or v[1] or 0, v.y or v[2] or 0, v.z or v[3] or 0)
        end
        -- Hook up change listener
        if getmetatable(v) == Vector3 then
            v._onChange = function()
                if t.Changed then t.Changed:Fire(k) end
                local signals = rawget(t, "_propertySignals")
                if signals and signals[k] then signals[k]:Fire(v) end
            end
        end
    elseif k == "Color" then
        if type(v) == "table" and getmetatable(v) ~= Color3 then
            v = Color3.new(v.r or v[1] or 1, v.g or v[2] or 1, v.b or v[3] or 1)
            if v.a == nil and (v[4] or v.a) then v.a = v[4] or v.a end
        end
        -- Hook up change listener
        if getmetatable(v) == Color3 then
            v._onChange = function()
                if t.Changed then t.Changed:Fire(k) end
                local signals = rawget(t, "_propertySignals")
                if signals and signals[k] then signals[k]:Fire(v) end
            end
        end
    end

    local props = rawget(t, "_properties")
    if not props then
        -- Fallback for extremely early initialization
        rawset(t, k, v)
        return
    end

    local old = props[k]
    props[k] = v
    
    -- Fire Changed signal if it exists and value changed
    if old ~= v then
        if t.Changed then
            t.Changed:Fire(k)
        end
        
        -- Fire property-specific signal
        local signals = rawget(t, "_propertySignals")
        if signals and signals[k] then
            signals[k]:Fire(v)
        end
    end
end

-- Expose meta methods so subclasses can use them
Instance.metatable = InstanceMeta

-- Class registry for Instance.new and Clone
local registry = {}

function Instance.register(className, classTable)
    registry[className] = classTable
    -- Subclasses MUST use InstanceMeta
    classTable.__index = InstanceMeta.__index
    classTable.__newindex = InstanceMeta.__newindex
end

function Instance.new(className, name)
    if className and registry[className] then
        return registry[className].new(name)
    end
    
    -- Default base instance if not registered
    local self = setmetatable({_properties = {}}, Instance)
    self:init(className or "Instance", name)
    return self
end

function Instance:init(className, name)
    local props = rawget(self, "_properties") or {}
    rawset(self, "_properties", props)
    
    props.ClassName = className or "Instance"
    props.Name = name or props.ClassName
    props.Locked = false
    
    rawset(self, "_children", {})
    rawset(self, "_destroyed", false)
    rawset(self, "_propertySignals", {})
    -- DO NOT rawset Parent here, so it's always handled via __index/__newindex
    
    -- Signals
    self.Changed = Signal.new()
end

function Instance:GetPropertyChangedSignal(property)
    local signals = rawget(self, "_propertySignals")
    if not signals[property] then
        signals[property] = Signal.new()
    end
    return signals[property]
end

function Instance:GetChildren()
    return rawget(self, "_children") or {}
end

function Instance:GetDescendants()
    local desc = {}
    local function collect(inst)
        local children = inst:GetChildren()
        for i=1, #children do
            local child = children[i]
            table.insert(desc, child)
            collect(child)
        end
    end
    collect(self)
    return desc
end

function Instance:FindFirstChild(name)
    local children = rawget(self, "_children")
    if not children then return nil end
    for _, child in ipairs(children) do
        if child.Name == name then
            return child
        end
    end
    return nil
end

function Instance:FindFirstChildOfClass(className)
    local children = rawget(self, "_children")
    if not children then return nil end
    for _, child in ipairs(children) do
        if child.ClassName == className then
            return child
        end
    end
    return nil
end

function Instance:FindFirstChildWhichIsA(className)
    local children = rawget(self, "_children")
    if not children then return nil end
    for _, child in ipairs(children) do
        if child:IsA(className) then
            return child
        end
    end
    return nil
end

function Instance:IsA(className)
    if className == "Instance" then return true end
    if self.ClassName == className then return true end
    
    -- Walk up the metatable chain
    local mt = getmetatable(self)
    while mt do
        -- Classes are set up with Instance as their metatable's __index
        -- So we check ClassName on the mt itself (which is the class table)
        if rawget(mt, "ClassName") == className then return true end
        
        -- Get the metatable of the current class table to find its parent class
        local nextMt = getmetatable(mt)
        if nextMt and nextMt.__index then
            mt = nextMt.__index
        else
            break
        end
    end
    return false
end

function Instance:setParent(newParent)
    if rawget(self, "_destroyed") then return end
    local currentParent = rawget(self, "_parent")
    if newParent == currentParent then return end
    if newParent == self then return end

    local curr = newParent
    while curr do
        if curr == self then
            error("Attempt to set parent to a descendant (circular reference)", 2)
            return
        end
        curr = curr.Parent
    end

    if currentParent then
        local children = rawget(currentParent, "_children")
        if children then
            for i, child in ipairs(children) do
                if child == self then
                    table.remove(children, i)
                    break
                end
            end
        end
    end
    
    rawset(self, "_parent", newParent)
    
    if newParent then
        local children = rawget(newParent, "_children")
        if children then
            table.insert(children, self)
        end
    end
    
    if self.Changed then
        self.Changed:Fire("Parent")
    end
end

-- Add Parent getter to __index logic
function InstanceMeta.__index(t, k)
    if k == "Parent" then
        return rawget(t, "_parent")
    end

    -- 1. Check hidden properties first
    local props = rawget(t, "_properties")
    if props and props[k] ~= nil then
        return props[k]
    end

    -- 2. Check methods/class fields
    local cls = getmetatable(t)
    if cls then
        -- Find method in the metatable hierarchy
        -- Since subclasses use InstanceMeta.__index, we must avoid recursion
        -- We look in the actual table of the class
        local v = rawget(cls, k)
        if v ~= nil then return v end
        
        -- If not in class, check parent class (Instance)
        -- This is a bit tricky with this structure.
        -- Let's just look in Instance table too as fallback.
        v = Instance[k]
        if v ~= nil then return v end
    end
    
    -- 3. Fallback to children lookup by name
    local children = rawget(t, "_children")
    if children then
        for _, child in ipairs(children) do
            if child.Name == k then
                return child
            end
        end
    end
    
    return nil
end

-- Re-assign fixed __index
Instance.__index = InstanceMeta.__index
Instance.__newindex = InstanceMeta.__newindex

function Instance:Destroy()
    if rawget(self, "_destroyed") then return end
    rawset(self, "_destroyed", true)
    
    local children = self:GetChildren()
    for i = #children, 1, -1 do
        children[i]:Destroy()
    end
    
    self:setParent(nil)
    
    if self.Changed then
        self.Changed:Destroy()
    end
    
    local signals = rawget(self, "_propertySignals")
    if signals then
        for _, sig in pairs(signals) do
            sig:Destroy()
        end
    end
end

function Instance:Clone()
    local constructor = registry[self.ClassName]
    local clone
    if constructor then
        clone = constructor.new(self.Name)
    else
        clone = Instance.new(self.ClassName, self.Name)
    end
    
    local props = rawget(self, "_properties")
    for k, v in pairs(props) do
        if k ~= "ClassName" and k ~= "Name" then
            if type(v) == "table" then
                local copy = {}
                for tk, tv in pairs(v) do
                    if tk ~= "_onChange" then copy[tk] = tv end
                end
                if getmetatable(v) == Vector3 then setmetatable(copy, Vector3)
                elseif getmetatable(v) == Color3 then setmetatable(copy, Color3) end
                clone[k] = copy
            else
                clone[k] = v
            end
        end
    end
    
    local children = self:GetChildren()
    for _, child in ipairs(children) do
        local childClone = child:Clone()
        childClone.Parent = clone
    end
    
    return clone
end

function Instance:render()
    local children = self:GetChildren()
    for _, child in ipairs(children) do
        if child.render then
            child:render()
        end
    end
end

return Instance
