-- engine/serializer.lua
-- Save/Load workspace to/from JSON-like Lua table format
-- Generic property-based serialization

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
        -- Check if array
        local isArray = #val > 0 or next(val) == nil
        if isArray and #val > 0 then
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
        while pos <= #str and str:sub(pos, pos):match("%s") do pos = pos + 1 end
    end

    local function parseValue()
        skipWhitespace()
        local c = str:sub(pos, pos)
        if c == '"' then
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
            pos = pos + 1
            local obj = {}
            skipWhitespace()
            if str:sub(pos, pos) == '}' then pos = pos + 1; return obj end
            while true do
                skipWhitespace()
                local key = parseValue()
                skipWhitespace()
                pos = pos + 1 -- skip ':'
                local val = parseValue()
                obj[key] = val
                skipWhitespace()
                if str:sub(pos, pos) == ',' then pos = pos + 1 else break end
            end
            skipWhitespace()
            if str:sub(pos, pos) == '}' then pos = pos + 1 end
            return obj
        elseif c == '[' then
            pos = pos + 1
            local arr = {}
            skipWhitespace()
            if str:sub(pos, pos) == ']' then pos = pos + 1; return arr end
            while true do
                table.insert(arr, parseValue())
                skipWhitespace()
                if str:sub(pos, pos) == ',' then pos = pos + 1 else break end
            end
            skipWhitespace()
            if str:sub(pos, pos) == ']' then pos = pos + 1 end
            return arr
        elseif str:sub(pos, pos+3) == 'true' then pos = pos + 4; return true
        elseif str:sub(pos, pos+4) == 'false' then pos = pos + 5; return false
        elseif str:sub(pos, pos+3) == 'null' then pos = pos + 4; return nil
        else
            local numStr = str:match("%-?%d+%.?%d*[eE]?[+-]?%d*", pos)
            if numStr then pos = pos + #numStr; return tonumber(numStr) end
        end
    end
    return parseValue()
end

-- Generic property serialization
function Serializer.serializeInstance(inst)
    local props = rawget(inst, "_properties") or inst
    local data = {
        ClassName = inst.ClassName,
    }

    -- Fields to skip
    local skip = {
        Parent = true, Changed = true, _children = true, _destroyed = true,
        _propertySignals = true, model = true, ClassName = true,
        _runtimeOnly = true, _cachedLightValue = true, _lightTimer = true,
        _lastLightPos = true, Texture = true, _lastClick = true,
        _properties = true,
    }

    for k, v in pairs(props) do
        if not skip[k] and type(v) ~= "function" and type(k) == "string" then
            if type(v) == "table" then
                local mt = getmetatable(v)
                if mt == Vector3 then
                    data[k] = {x = v.x, y = v.y, z = v.z, _type = "Vector3"}
                elseif mt == Color3 then
                    data[k] = {r = v.r, g = v.g, b = v.b, a = v.a or 1, _type = "Color3"}
                end
            else
                data[k] = v
            end
        end
    end

    -- Also check base table for any other properties not in _properties
    for k, v in pairs(inst) do
        if not skip[k] and not props[k] and type(v) ~= "function" and type(k) == "string" then
            if type(v) == "table" then
                local mt = getmetatable(v)
                if mt == Vector3 then
                    data[k] = {x = v.x, y = v.y, z = v.z, _type = "Vector3"}
                elseif mt == Color3 then
                    data[k] = {r = v.r, g = v.g, b = v.b, a = v.a or 1, _type = "Color3"}
                end
            else
                data[k] = v
            end
        end
    end

    -- Serialize children
    local children = inst:GetChildren()
    if #children > 0 then
        local childrenData = {}
        for _, child in ipairs(children) do
            if not child._runtimeOnly then
                table.insert(childrenData, Serializer.serializeInstance(child))
            end
        end
        if #childrenData > 0 then
            data.Children = childrenData
        end
    end

    return data
end

-- Generic property deserialization
function Serializer.deserializeInstance(data, existingInst)
    -- Ensure classes are loaded
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
    require("engine.lighting")

    local inst = existingInst
    if not inst then
        if data.ClassName == "DataModel" then
            inst = Engine.Game
        elseif Engine.Game and Engine.Game:FindFirstChild(data.Name) and (data.ClassName == "Workspace" or data.ClassName == "Lighting" or data.ClassName == "StarterGui") then
            inst = Engine.Game:FindFirstChild(data.Name)
        else
            inst = Instance.new(data.ClassName, data.Name)
        end
    end
    
    if not inst then return nil end

    -- Restore properties
    for k, v in pairs(data) do
        if k ~= "ClassName" and k ~= "Children" then
            if type(v) == "table" and v._type then
                if v._type == "Vector3" then
                    inst[k] = Vector3.new(v.x, v.y, v.z)
                elseif v._type == "Color3" then
                    inst[k] = Color3.new(v.r, v.g, v.b)
                    if v.a then inst[k].a = v.a end
                end
            else
                -- Special case for Shape and TexturePath to use setter if available
                if k == "Shape" and inst.setShape then
                    inst:setShape(v)
                elseif k == "TexturePath" and inst.setTexture then
                    inst:setTexture(v)
                else
                    inst[k] = v
                end
            end
        end
    end

    -- Deserialize children
    if data.Children then
        for _, childData in ipairs(data.Children) do
            local child = Serializer.deserializeInstance(childData)
            if child then
                child:setParent(inst)
            end
        end
    end

    return inst
end

-- Save instance tree to file
function Serializer.saveToFile(inst, filepath)
    local data = Serializer.serializeInstance(inst)
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

-- Load instance tree from file
function Serializer.loadFromFile(filepath)
    local info = love.filesystem.getInfo(filepath)
    if not info then
        return nil, "File not found"
    end

    local content, err = love.filesystem.read(filepath)
    if not content then return nil, err end

    local data = jsonDecode(content)
    if not data then return nil, "Parse error" end

    return Serializer.deserializeInstance(data)
end

-- Expose JSON utilities
Serializer.jsonEncode = jsonEncode
Serializer.jsonDecode = jsonDecode

return Serializer
