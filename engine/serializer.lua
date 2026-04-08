-- engine/serializer.lua
-- Save/Load workspace to/from JSON-like Lua table format
-- Uses a simple JSON encoder/decoder since Love2D doesn't include one

local Vector3 = require("engine.vector3")
local Color3 = require("engine.color3")
local Instance = require("engine.instance")

local Serializer = {}

-- Simple JSON encoder
local function jsonEncode(val, indent, currentIndent)
    indent = indent or "  "
    currentIndent = currentIndent or ""
    local nextIndent = currentIndent .. indent

    if val == nil then
        return "null"
    elseif type(val) == "boolean" then
        return tostring(val)
    elseif type(val) == "number" then
        if val ~= val then return "0" end -- NaN
        if val == math.huge then return "1e308" end
        if val == -math.huge then return "-1e308" end
        return string.format("%.6g", val)
    elseif type(val) == "string" then
        return '"' .. val:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
    elseif type(val) == "table" then
        -- Check if it's a Vector3 or Color3 by looking at its metatable or structure
        -- But for JSON we want to treat them as objects {x,y,z} or {r,g,b}
        
        -- Check if array
        local isArray = #val > 0 or next(val) == nil
        if isArray and #val > 0 then
            -- Verify it's truly an array
            for k in pairs(val) do
                if type(k) ~= "number" then
                    isArray = false
                    break
                end
            end
        end

        if isArray then
            if #val == 0 then return "[]" end
            local items = {}
            for i, v in ipairs(val) do
                items[i] = nextIndent .. jsonEncode(v, indent, nextIndent)
            end
            return "[\n" .. table.concat(items, ",\n") .. "\n" .. currentIndent .. "]"
        else
            local items = {}
            -- Sort keys for deterministic output
            local keys = {}
            for k in pairs(val) do
                if type(k) == "string" then
                    table.insert(keys, k)
                end
            end
            table.sort(keys)
            for _, k in ipairs(keys) do
                table.insert(items, nextIndent .. '"' .. k .. '": ' .. jsonEncode(val[k], indent, nextIndent))
            end
            if #items == 0 then return "{}" end
            return "{\n" .. table.concat(items, ",\n") .. "\n" .. currentIndent .. "}"
        end
    end
    return "null"
end

-- Simple JSON decoder
local function jsonDecode(str)
    local pos = 1

    local function skipWhitespace()
        while pos <= #str and str:sub(pos, pos):match("%s") do
            pos = pos + 1
        end
    end

    local function parseValue()
        skipWhitespace()
        local c = str:sub(pos, pos)

        if c == '"' then
            -- String
            pos = pos + 1
            local result = {}
            while pos <= #str do
                c = str:sub(pos, pos)
                if c == '\\' then
                    pos = pos + 1
                    local esc = str:sub(pos, pos)
                    if esc == 'n' then table.insert(result, '\n')
                    elseif esc == 'r' then table.insert(result, '\r')
                    elseif esc == 't' then table.insert(result, '\t')
                    elseif esc == '"' then table.insert(result, '"')
                    elseif esc == '\\' then table.insert(result, '\\')
                    else table.insert(result, esc) end
                elseif c == '"' then
                    pos = pos + 1
                    return table.concat(result)
                else
                    table.insert(result, c)
                end
                pos = pos + 1
            end
        elseif c == '{' then
            -- Object
            pos = pos + 1
            local obj = {}
            skipWhitespace()
            if str:sub(pos, pos) == '}' then
                pos = pos + 1
                return obj
            end
            while true do
                skipWhitespace()
                local key = parseValue()
                skipWhitespace()
                pos = pos + 1 -- skip ':'
                local val = parseValue()
                obj[key] = val
                skipWhitespace()
                if str:sub(pos, pos) == ',' then
                    pos = pos + 1
                else
                    break
                end
            end
            skipWhitespace()
            if str:sub(pos, pos) == '}' then pos = pos + 1 end
            return obj
        elseif c == '[' then
            -- Array
            pos = pos + 1
            local arr = {}
            skipWhitespace()
            if str:sub(pos, pos) == ']' then
                pos = pos + 1
                return arr
            end
            while true do
                table.insert(arr, parseValue())
                skipWhitespace()
                if str:sub(pos, pos) == ',' then
                    pos = pos + 1
                else
                    break
                end
            end
            skipWhitespace()
            if str:sub(pos, pos) == ']' then pos = pos + 1 end
            return arr
        elseif c == 't' then
            pos = pos + 4
            return true
        elseif c == 'f' then
            pos = pos + 5
            return false
        elseif c == 'n' then
            pos = pos + 4
            return nil
        else
            -- Number
            local numStr = str:match("%-?%d+%.?%d*[eE]?[+-]?%d*", pos)
            if numStr then
                pos = pos + #numStr
                return tonumber(numStr)
            end
        end
    end

    return parseValue()
end

-- Serialize children list
function Serializer.serializeChildren(inst)
    local children = inst:GetChildren()
    local list = {}
    for _, child in ipairs(children) do
        if not child._runtimeOnly then
            table.insert(list, Serializer.serializeInstance(child))
        end
    end
    return list
end

-- Deserialize list of children and parent them
function Serializer.deserializeChildren(childrenData, parent)
    if not childrenData then return end
    for _, childData in ipairs(childrenData) do
        local child = Serializer.deserializeInstance(childData)
        if child then
            child:setParent(parent)
        end
    end
end

-- Serialize an instance tree to a Lua table
function Serializer.serializeInstance(inst)
    local data = {
        ClassName = inst.ClassName,
        Name = inst.Name,
    }

    -- Serialize known properties per class
    if inst.Position then
        data.Position = {x = inst.Position.x, y = inst.Position.y, z = inst.Position.z}
    end
    if inst.Size then
        data.Size = {x = inst.Size.x, y = inst.Size.y, z = inst.Size.z}
    end
    if inst.Rotation then
        data.Rotation = {x = inst.Rotation.x, y = inst.Rotation.y, z = inst.Rotation.z}
    end
    if inst.Color then
        -- Handle both Color3 and old table format
        if type(inst.Color) == "table" and inst.Color.r then
            data.Color = {inst.Color.r, inst.Color.g, inst.Color.b, inst.Color.a or 1}
        else
            data.Color = {inst.Color[1], inst.Color[2], inst.Color[3], inst.Color[4] or 1}
        end
    end
    if inst.Transparency ~= nil then
        data.Transparency = inst.Transparency
    end
    if inst.Anchored ~= nil then
        data.Anchored = inst.Anchored
    end
    if inst.CanCollide ~= nil then
        data.CanCollide = inst.CanCollide
    end
    if inst.Material then
        data.Material = inst.Material
    end
    if inst.Shape then
        data.Shape = inst.Shape
    end
    if inst.Locked ~= nil then
        data.Locked = inst.Locked
    end
    if inst.TexturePath then
        data.Texture = inst.TexturePath
    end
    if inst.Velocity then
        data.Velocity = {x = inst.Velocity.x, y = inst.Velocity.y, z = inst.Velocity.z}
    end

    -- Humanoid specific
    if inst:IsA("Humanoid") then
        data.Health = inst.Health
        data.MaxHealth = inst.MaxHealth
        data.WalkSpeed = inst.WalkSpeed
        data.JumpPower = inst.JumpPower
    end

    -- SpawnLocation specific
    if inst:IsA("SpawnLocation") then
        data.Duration = inst.Duration
        data.Enabled = inst.Enabled
        data.Neutral = inst.Neutral
    end
    
    -- Script specific
    if inst:IsA("Script") or inst:IsA("ModuleScript") then
        data.Source = inst.Source
        if inst.Disabled ~= nil then data.Disabled = inst.Disabled end
    end

    -- Value instance specific
    if inst.Value ~= nil then
        if type(inst.Value) == "table" then
            if inst:IsA("Vector3Value") then
                data.Value = {x = inst.Value.x, y = inst.Value.y, z = inst.Value.z}
            elseif inst:IsA("Color3Value") then
                data.Value = {inst.Value.r, inst.Value.g, inst.Value.b, inst.Value.a or 1}
            end
        else
            data.Value = inst.Value
        end
    end

    -- Serialize children
    local children = inst:GetChildren()
    if #children > 0 then
        data.Children = Serializer.serializeChildren(inst)
    end

    return data
end

-- Deserialize a Lua table back into an instance tree
function Serializer.deserializeInstance(data)
    -- Make sure all engine classes are loaded
    require("engine.part")
    require("engine.spawnlocation")
    require("engine.model")
    require("engine.workspace")
    require("engine.humanoid")
    require("engine.script")
    require("engine.modulescript")
    require("engine.game")
    require("engine.folder")
    require("engine.value_instances")

    local inst
    if data.ClassName == "DataModel" then
        inst = Engine.Game
    else
        -- Check if it's a service already present in Engine.Game
        if Engine.Game and Engine.Game:FindFirstChild(data.Name) then
            inst = Engine.Game:FindFirstChild(data.Name)
        else
            inst = Instance.new(data.ClassName, data.Name)
        end
    end
    
    if not inst then return nil end

    -- Restore properties
    if data.Position then
        inst.Position = Vector3.new(data.Position.x, data.Position.y, data.Position.z)
    end
    if data.Size then
        inst.Size = Vector3.new(data.Size.x, data.Size.y, data.Size.z)
    end
    if data.Rotation then
        inst.Rotation = Vector3.new(data.Rotation.x, data.Rotation.y, data.Rotation.z)
    end
    if data.Color then
        inst.Color = Color3.new(data.Color[1], data.Color[2], data.Color[3])
        if data.Color[4] then inst.Color.a = data.Color[4] end
    end
    if data.Transparency ~= nil then inst.Transparency = data.Transparency end
    if data.Anchored ~= nil then inst.Anchored = data.Anchored end
    if data.CanCollide ~= nil then inst.CanCollide = data.CanCollide end
    if data.Material then inst.Material = data.Material end
    if data.Shape and inst.setShape then inst:setShape(data.Shape) end
    if data.Locked ~= nil then inst.Locked = data.Locked end
    if data.Texture and inst.setTexture then inst:setTexture(data.Texture) end
    if data.Velocity then
        inst.Velocity = Vector3.new(data.Velocity.x, data.Velocity.y, data.Velocity.z)
    end

    -- Humanoid specific
    if inst:IsA("Humanoid") then
        if data.Health then inst.Health = data.Health end
        if data.MaxHealth then inst.MaxHealth = data.MaxHealth end
        if data.WalkSpeed then inst.WalkSpeed = data.WalkSpeed end
        if data.JumpPower then inst.JumpPower = data.JumpPower end
    end

    -- SpawnLocation specific
    if inst:IsA("SpawnLocation") then
        if data.Duration then inst.Duration = data.Duration end
        if data.Enabled ~= nil then inst.Enabled = data.Enabled end
        if data.Neutral ~= nil then inst.Neutral = data.Neutral end
    end
    
    -- Script specific
    if inst:IsA("Script") or inst:IsA("ModuleScript") then
        if data.Source then inst.Source = data.Source end
        if data.Disabled ~= nil then inst.Disabled = data.Disabled end
    end

    -- Value instance specific
    if data.Value ~= nil then
        if inst:IsA("Vector3Value") then
            inst.Value = Vector3.new(data.Value.x, data.Value.y, data.Value.z)
        elseif inst:IsA("Color3Value") then
            inst.Value = Color3.new(data.Value[1], data.Value[2], data.Value[3])
            if data.Value[4] then inst.Value.a = data.Value[4] end
        else
            inst.Value = data.Value
        end
    end

    -- Deserialize children
    if data.Children then
        Serializer.deserializeChildren(data.Children, inst)
    end

    return inst
end

-- Save workspace to file
function Serializer.saveToFile(workspace, filepath)
    local data = Serializer.serializeInstance(workspace)
    local json = jsonEncode(data)

    local success, err = love.filesystem.write(filepath, json)
    if success then
        print("[Luvoxel] Saved to " .. filepath)
        return true
    else
        print("[Luvoxel] Save failed: " .. tostring(err))
        return false, err
    end
end

-- Load workspace from file
function Serializer.loadFromFile(filepath)
    local info = love.filesystem.getInfo(filepath)
    if not info then
        print("[Luvoxel] File not found: " .. filepath)
        return nil, "File not found"
    end

    local content, err = love.filesystem.read(filepath)
    if not content then
        print("[Luvoxel] Read failed: " .. tostring(err))
        return nil, err
    end

    local data = jsonDecode(content)
    if not data then
        print("[Luvoxel] Failed to parse file")
        return nil, "Parse error"
    end

    local workspace = Serializer.deserializeInstance(data)
    print("[Luvoxel] Loaded from " .. filepath)
    return workspace
end

-- Expose JSON utilities
Serializer.jsonEncode = jsonEncode
Serializer.jsonDecode = jsonDecode

return Serializer
