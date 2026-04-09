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
    local cls = getmetatable(t)
    local v = cls[k]
    if v ~= nil then return v end
    
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

Instance.__index = InstanceMeta.__index
Instance.__newindex = InstanceMeta.__newindex

-- Class registry for Instance.new and Clone
local registry = {}

function Instance.register(className, classTable)
    registry[className] = classTable
    -- Ensure class table uses our meta methods if it doesn't already
    if not classTable.__index then classTable.__index = classTable end
    -- We don't set __newindex on the class table itself, but on the instances
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
    rawset(self, "Parent", nil) -- Note: setParent uses rawget/set
    
    -- Signals
    self.Changed = Signal.new()
end

-- ... rest of methods ...
-- I will keep the rest of the file content but ensures it uses the new structure.

function Instance:GetPropertyChangedSignal(property)
    local signals = rawget(self, "_propertySignals")
    if not signals[property] then
        signals[property] = Signal.new()
    end
    return signals[property]
end

function Instance:GetChildren()
    return rawget(self, "_children")
end

function Instance:GetDescendants()
    local desc = {}
    local function collect(inst)
        local children = rawget(inst, "_children")
        if children then
            for i=1, #children do
                local child = children[i]
                table.insert(desc, child)
                collect(child)
            end
        end
    end
    collect(self)
    return desc
end

function Instance:FindFirstChild(name)
    local children = rawget(self, "_children")
    for _, child in ipairs(children) do
        if child.Name == name then
            return child
        end
    end
    return nil
end

function Instance:FindFirstChildOfClass(className)
    local children = rawget(self, "_children")
    for _, child in ipairs(children) do
        if child.ClassName == className then
            return child
        end
    end
    return nil
end

function Instance:FindFirstChildWhichIsA(className)
    local children = rawget(self, "_children")
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
    
    local mt = getmetatable(self)
    while mt do
        if mt.ClassName == className then return true end
        local superMt = getmetatable(mt)
        if superMt and superMt.__index then
            mt = superMt.__index
        else
            break
        end
    end
    return false
end

function Instance:setParent(newParent)
    if rawget(self, "_destroyed") then return end
    local currentParent = rawget(self, "Parent")
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
        for i, child in ipairs(children) do
            if child == self then
                table.remove(children, i)
                break
            end
        end
    end
    
    rawset(self, "Parent", newParent)
    
    if newParent then
        local children = rawget(newParent, "_children")
        table.insert(children, self)
    end
    
    if self.Changed then
        self.Changed:Fire("Parent")
    end
end

function Instance:Destroy()
    if rawget(self, "_destroyed") then return end
    rawset(self, "_destroyed", true)
    
    local children = rawget(self, "_children")
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
    
    local children = rawget(self, "_children")
    for _, child in ipairs(children) do
        local childClone = child:Clone()
        childClone.Parent = clone
    end
    
    return clone
end

function Instance:render()
    local children = rawget(self, "_children")
    if children then
        for _, child in ipairs(children) do
            if child.render then
                child:render()
            end
        end
    end
end

return Instance
