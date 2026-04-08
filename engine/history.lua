-- engine/history.lua
-- Undo/Redo system for studio actions

local History = {}
History.__index = History

function History.new()
    local self = setmetatable({}, History)
    self.undoStack = {}
    self.redoStack = {}
    self.maxHistory = 100
    return self
end

-- Record an action. action = {undo = function(), redo = function(), desc = "string"}
function History:record(action)
    table.insert(self.undoStack, action)
    -- Clear redo stack when new action is recorded
    self.redoStack = {}
    -- Trim history
    while #self.undoStack > self.maxHistory do
        table.remove(self.undoStack, 1)
    end
end

-- Record a property change
function History:recordPropertyChange(inst, propKey, oldValue, newValue)
    -- Deep copy table values
    local function copyVal(v)
        if type(v) == "table" then
            local c = {}
            for k, val in pairs(v) do c[k] = val end
            return c
        end
        return v
    end

    local oldCopy = copyVal(oldValue)
    local newCopy = copyVal(newValue)

    self:record({
        desc = "Change " .. propKey .. " on " .. inst.Name,
        undo = function()
            -- Navigate to property
            local keys = {}
            for k in propKey:gmatch("[^%.]+") do
                table.insert(keys, k)
            end
            if #keys == 1 then
                inst[keys[1]] = copyVal(oldCopy)
            elseif #keys == 2 then
                if type(inst[keys[1]]) == "table" then
                    inst[keys[1]][keys[2]] = oldCopy
                end
            end
        end,
        redo = function()
            local keys = {}
            for k in propKey:gmatch("[^%.]+") do
                table.insert(keys, k)
            end
            if #keys == 1 then
                inst[keys[1]] = copyVal(newCopy)
            elseif #keys == 2 then
                if type(inst[keys[1]]) == "table" then
                    inst[keys[1]][keys[2]] = newCopy
                end
            end
        end,
    })
end

-- Record creating an instance
function History:recordCreate(inst, parent)
    self:record({
        desc = "Create " .. inst.Name,
        undo = function()
            inst:setParent(nil)
        end,
        redo = function()
            inst:setParent(parent)
        end,
    })
end

-- Record deleting an instance
function History:recordDelete(inst, parent)
    self:record({
        desc = "Delete " .. inst.Name,
        undo = function()
            inst:setParent(parent)
        end,
        redo = function()
            inst:setParent(nil)
        end,
    })
end

function History:undo()
    if #self.undoStack == 0 then
        print("[Luvoxel] Nothing to undo")
        return false
    end
    local action = table.remove(self.undoStack)
    action.undo()
    table.insert(self.redoStack, action)
    print("[Luvoxel] Undo: " .. (action.desc or "action"))
    return true
end

function History:redo()
    if #self.redoStack == 0 then
        print("[Luvoxel] Nothing to redo")
        return false
    end
    local action = table.remove(self.redoStack)
    action.redo()
    table.insert(self.undoStack, action)
    print("[Luvoxel] Redo: " .. (action.desc or "action"))
    return true
end

function History:canUndo()
    return #self.undoStack > 0
end

function History:canRedo()
    return #self.redoStack > 0
end

function History:clear()
    self.undoStack = {}
    self.redoStack = {}
end

return History
