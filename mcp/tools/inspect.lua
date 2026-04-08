-- mcp/tools/inspect.lua
-- Workspace/instance inspection tools

local Inspect = {}

-- ─── Scene Tree ────────────────────────────────────────────────────────────

local function vec3ToTable(v)
    if not v then return nil end
    return {x = v.x or 0, y = v.y or 0, z = v.z or 0}
end

local function instanceToTable(inst, depth)
    depth = depth or 0
    if depth > 30 then return {name="[max depth]"} end

    local t = {
        name      = inst.Name or "?",
        class     = inst.ClassName or "Instance",
        children  = {},
    }

    -- Capture common properties
    if inst.Position     then t.position     = vec3ToTable(inst.Position) end
    if inst.Size         then t.size         = vec3ToTable(inst.Size)     end
    if inst.Rotation     then t.rotation     = vec3ToTable(inst.Rotation) end
    if inst.Color        then
        t.color = {r=inst.Color[1], g=inst.Color[2], b=inst.Color[3]}
    end
    if inst.Anchored     ~= nil then t.anchored     = inst.Anchored     end
    if inst.Visible      ~= nil then t.visible      = inst.Visible      end
    if inst.Material     then t.material     = inst.Material     end
    if inst.CanCollide   ~= nil then t.canCollide   = inst.CanCollide   end
    if inst.Locked       ~= nil then t.locked       = inst.Locked       end
    if inst.Transparency ~= nil then t.transparency = inst.Transparency end
    if inst.Shape        ~= nil then t.shape        = inst.Shape        end

    -- Recurse children
    if inst.GetChildren then
        for _, child in ipairs(inst:GetChildren()) do
            table.insert(t.children, instanceToTable(child, depth+1))
        end
    end
    return t
end

function Inspect.sceneTree(_args)
    if not Engine or not Engine.Workspace then
        return false, nil, "Engine.Workspace not ready"
    end
    local tree = instanceToTable(Engine.Workspace)
    return true, {tree = tree}
end

-- ─── Path resolution ────────────────────────────────────────────────────────

local function resolvePath(path)
    if not Engine then return nil, "Engine not ready" end
    local root = Engine.Game or Engine.Workspace
    if not root then return nil, "Game/Workspace not ready" end

    local parts = {}
    for segment in path:gmatch("[^%./]+") do
        table.insert(parts, segment)
    end
    
    if #parts == 0 then return root, nil end

    local node = root
    local start = 1
    
    if node.ClassName == "DataModel" then
        if parts[1] == "game" or parts[1] == "Game" then
            start = 2
        end
    else
        if parts[1] == "Workspace" then
            start = 2
        end
    end

    for i = start, #parts do
        local seg = parts[i]
        local found = false
        if node.GetChildren then
            for _, child in ipairs(node:GetChildren()) do
                if child.Name == seg then
                    node = child
                    found = true
                    break
                end
            end
        end
        -- Handle GetService dynamically for Game root
        if not found and node.ClassName == "DataModel" and node.GetService then
            pcall(function() 
                local svc = node:GetService(seg)
                if svc then
                    node = svc
                    found = true
                end
            end)
        end
        if not found then
            return nil, "Instance not found at segment: " .. seg
        end
    end
    return node, nil
end

function Inspect.getInstance(args)
    local path = args.path or "Workspace"
    local inst, err = resolvePath(path)
    if not inst then return false, nil, err end
    return true, {instance = instanceToTable(inst, 0)}
end

-- Map lowercase to uppercase for common engine properties
local PROP_MAP = {
    position = "Position",
    size = "Size",
    rotation = "Rotation",
    color = "Color",
    anchored = "Anchored",
    visible = "Visible",
    material = "Material",
    cancollide = "CanCollide",
    locked = "Locked",
    transparency = "Transparency",
    shape = "Shape",
    name = "Name"
}

function Inspect.setProperty(args)
    local path  = args.path
    local prop  = args.property
    local value = args.value
    if not path or not prop then
        return false, nil, "args.path and args.property are required"
    end

    local inst, err = resolvePath(path)
    if not inst then return false, nil, err end

    -- Try to map lowercase property name
    local mappedProp = PROP_MAP[prop:lower()] or prop

    -- Check if it exists as-is or as mapped
    if inst[mappedProp] == nil and inst[prop] ~= nil then
        mappedProp = prop
    end

    local existing = inst[mappedProp]

    if existing == nil then
        inst[mappedProp] = value
    elseif type(existing) == "number" then
        inst[mappedProp] = tonumber(value) or value
    elseif type(existing) == "boolean" then
        if type(value) == "string" then
            inst[mappedProp] = (value == "true")
        else
            inst[mappedProp] = (value == true)
        end
    elseif type(existing) == "table" then
        if existing.x ~= nil then
            -- Vector3
            if type(value) == "table" then
                inst[mappedProp] = {x = value.x or 0, y = value.y or 0, z = value.z or 0}
            elseif type(value) == "number" then
                inst[mappedProp] = {x = value, y = value, z = value}
            end
        elseif type(existing[1]) == "number" then
            -- Array of numbers (like Color {r, g, b})
            if type(value) == "table" then
                local newArr = {}
                -- Map r,g,b or x,y,z or 1,2,3
                newArr[1] = tonumber(value.r or value.x or value[1]) or 1
                newArr[2] = tonumber(value.g or value.y or value[2]) or 1
                newArr[3] = tonumber(value.b or value.z or value[3]) or 1
                newArr[4] = tonumber(value.a or value[4]) or 1
                inst[mappedProp] = newArr
            end
        else
            inst[mappedProp] = value
        end
    else
        inst[mappedProp] = value
    end

    return true, {path=path, property=mappedProp, newValue=tostring(inst[mappedProp])}

end

function Inspect.selectInstance(args)
    local path = args.path
    if not path then return false, nil, "args.path required" end

    local inst, err = resolvePath(path)
    if not inst then return false, nil, err end

    if _G._UI then
        _G._UI.selectedInstance = inst
        return true, {selected = inst.Name}
    else
        return false, nil, "_UI not available"
    end
end

return Inspect
