-- studio/tools/move.lua
-- Move tool: drag-on-axis movement with snapping

local Gizmo = require("studio.tools.gizmo")

local MoveTool = {}

MoveTool.hoveredAxis = nil
MoveTool.dragging = false
MoveTool.dragAxis = nil
MoveTool.snapGrid = 0.5  -- stud snap

function MoveTool.update(dt)
    local mx, my = love.mouse.getPosition()
    local inst = _G._UI and _G._UI.selectedInstance
    if inst and inst.Position and not MoveTool.dragging then
        MoveTool.hoveredAxis = Gizmo.hitTestAxis(mx, my, inst, "move")
    end
end

function MoveTool.draw()
    local inst = _G._UI and _G._UI.selectedInstance
    if inst and inst.Position then
        Gizmo.drawMoveGizmo(inst, MoveTool.hoveredAxis or MoveTool.dragAxis)
    end
end

function MoveTool.mousepressed(x, y, button)
    if button ~= 1 then return end
    local inst = _G._UI and _G._UI.selectedInstance
    if not inst or not inst.Position then return end

    -- Check if clicking on gizmo axis
    local axis = Gizmo.hitTestAxis(x, y, inst, "move")
    if axis then
        MoveTool.dragging = true
        MoveTool.dragAxis = axis
        -- Record initial position for undo
        MoveTool._startPos = {
            x = inst.Position.x,
            y = inst.Position.y,
            z = inst.Position.z,
        }
    else
        -- Fallback: try to select (delegate to select tool)
        local Select = require("studio.tools.select")
        Select.mousepressed(x, y, button)
    end
end

function MoveTool.mousemoved(x, y, dx, dy)
    if not MoveTool.dragging then return end
    local inst = _G._UI and _G._UI.selectedInstance
    if not inst or not inst.Position then return end

    local delta = Gizmo.calculateAxisDrag(MoveTool.dragAxis, dx, dy, inst)

    -- Apply snap
    if MoveTool.snapGrid > 0 then
        if MoveTool.dragAxis == "x" then
            inst.Position.x = inst.Position.x + delta
        elseif MoveTool.dragAxis == "y" then
            inst.Position.y = inst.Position.y + delta
        elseif MoveTool.dragAxis == "z" then
            inst.Position.z = inst.Position.z + delta
        end
    else
        if MoveTool.dragAxis == "x" then inst.Position.x = inst.Position.x + delta end
        if MoveTool.dragAxis == "y" then inst.Position.y = inst.Position.y + delta end
        if MoveTool.dragAxis == "z" then inst.Position.z = inst.Position.z + delta end
    end
end

function MoveTool.mousereleased(x, y, button)
    if button == 1 and MoveTool.dragging then
        local inst = _G._UI and _G._UI.selectedInstance
        if inst and MoveTool._startPos then
            -- Snap final position to grid
            if MoveTool.snapGrid > 0 then
                local s = MoveTool.snapGrid
                inst.Position.x = math.floor(inst.Position.x / s + 0.5) * s
                inst.Position.y = math.floor(inst.Position.y / s + 0.5) * s
                inst.Position.z = math.floor(inst.Position.z / s + 0.5) * s
            end
            -- Record undo
            if Engine.History then
                Engine.History:record({
                    desc = "Move " .. inst.Name,
                    undo = function()
                        inst.Position.x = MoveTool._startPos.x
                        inst.Position.y = MoveTool._startPos.y
                        inst.Position.z = MoveTool._startPos.z
                    end,
                    redo = function()
                        inst.Position.x = inst.Position.x
                        inst.Position.y = inst.Position.y
                        inst.Position.z = inst.Position.z
                    end,
                })
            end
        end
        MoveTool.dragging = false
        MoveTool.dragAxis = nil
        MoveTool._startPos = nil
    end
end

function MoveTool.wheelmoved(x, y) end

return MoveTool
