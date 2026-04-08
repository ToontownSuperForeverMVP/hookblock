-- studio/tools/rotate.lua
-- Rotate tool: drag-on-ring rotation with snapping

local Gizmo = require("studio.tools.gizmo")

local RotateTool = {}

RotateTool.hoveredAxis = nil
RotateTool.dragging = false
RotateTool.dragAxis = nil
RotateTool.snapAngle = 15  -- degrees

function RotateTool.update(dt)
    local mx, my = love.mouse.getPosition()
    local inst = _G._UI and _G._UI.selectedInstance
    if inst and inst.Rotation and not RotateTool.dragging then
        RotateTool.hoveredAxis = Gizmo.hitTestAxis(mx, my, inst, "rotate")
    end
end

function RotateTool.draw()
    local inst = _G._UI and _G._UI.selectedInstance
    if inst and inst.Rotation then
        Gizmo.drawRotateGizmo(inst, RotateTool.hoveredAxis or RotateTool.dragAxis)
    end
end

function RotateTool.mousepressed(x, y, button)
    if button ~= 1 then return end
    local inst = _G._UI and _G._UI.selectedInstance
    if not inst or not inst.Rotation then return end

    local axis = Gizmo.hitTestAxis(x, y, inst, "rotate")
    if axis then
        RotateTool.dragging = true
        RotateTool.dragAxis = axis
        RotateTool._startRot = {
            x = inst.Rotation.x,
            y = inst.Rotation.y,
            z = inst.Rotation.z,
        }
        RotateTool._accumDelta = 0
    else
        local Select = require("studio.tools.select")
        Select.mousepressed(x, y, button)
    end
end

function RotateTool.mousemoved(x, y, dx, dy)
    if not RotateTool.dragging then return end
    local inst = _G._UI and _G._UI.selectedInstance
    if not inst or not inst.Rotation then return end

    -- Use horizontal mouse delta for rotation speed
    local delta = dx * 0.5
    RotateTool._accumDelta = (RotateTool._accumDelta or 0) + delta

    -- Snap to angle increments
    local snap = RotateTool.snapAngle
    local snappedDelta = math.floor(RotateTool._accumDelta / snap) * snap

    if RotateTool.dragAxis == "x" then
        inst.Rotation.x = RotateTool._startRot.x + snappedDelta
    elseif RotateTool.dragAxis == "y" then
        inst.Rotation.y = RotateTool._startRot.y + snappedDelta
    elseif RotateTool.dragAxis == "z" then
        inst.Rotation.z = RotateTool._startRot.z + snappedDelta
    end
end

function RotateTool.mousereleased(x, y, button)
    if button == 1 and RotateTool.dragging then
        local inst = _G._UI and _G._UI.selectedInstance
        if inst and RotateTool._startRot and Engine.History then
            local startRot = RotateTool._startRot
            local endRot = {x = inst.Rotation.x, y = inst.Rotation.y, z = inst.Rotation.z}
            Engine.History:record({
                desc = "Rotate " .. inst.Name,
                undo = function()
                    inst.Rotation.x = startRot.x
                    inst.Rotation.y = startRot.y
                    inst.Rotation.z = startRot.z
                end,
                redo = function()
                    inst.Rotation.x = endRot.x
                    inst.Rotation.y = endRot.y
                    inst.Rotation.z = endRot.z
                end,
            })
        end
        RotateTool.dragging = false
        RotateTool.dragAxis = nil
        RotateTool._startRot = nil
        RotateTool._accumDelta = 0
    end
end

function RotateTool.wheelmoved(x, y) end

return RotateTool
