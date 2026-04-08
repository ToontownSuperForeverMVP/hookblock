-- studio/tools/scale.lua
-- Scale tool: drag-on-axis scaling with cube handles

local Gizmo = require("studio.tools.gizmo")

local ScaleTool = {}

ScaleTool.hoveredAxis = nil
ScaleTool.dragging = false
ScaleTool.dragAxis = nil
ScaleTool.minSize = 0.1

function ScaleTool.update(dt)
    local mx, my = love.mouse.getPosition()
    local inst = _G._UI and _G._UI.selectedInstance
    if inst and inst.Size and not ScaleTool.dragging then
        ScaleTool.hoveredAxis = Gizmo.hitTestAxis(mx, my, inst, "scale")
    end
end

function ScaleTool.draw()
    local inst = _G._UI and _G._UI.selectedInstance
    if inst and inst.Size then
        Gizmo.drawScaleGizmo(inst, ScaleTool.hoveredAxis or ScaleTool.dragAxis)
    end
end

function ScaleTool.mousepressed(x, y, button)
    if button ~= 1 then return end
    local inst = _G._UI and _G._UI.selectedInstance
    if not inst or not inst.Size then return end

    local axis = Gizmo.hitTestAxis(x, y, inst, "scale")
    if axis then
        ScaleTool.dragging = true
        ScaleTool.dragAxis = axis
        ScaleTool._startSize = {
            x = inst.Size.x,
            y = inst.Size.y,
            z = inst.Size.z,
        }
    else
        local Select = require("studio.tools.select")
        Select.mousepressed(x, y, button)
    end
end

function ScaleTool.mousemoved(x, y, dx, dy)
    if not ScaleTool.dragging then return end
    local inst = _G._UI and _G._UI.selectedInstance
    if not inst or not inst.Size then return end

    local delta = Gizmo.calculateAxisDrag(ScaleTool.dragAxis, dx, dy, inst) * 0.5

    if ScaleTool.dragAxis == "x" then
        inst.Size.x = math.max(ScaleTool.minSize, inst.Size.x + delta)
    elseif ScaleTool.dragAxis == "y" then
        inst.Size.y = math.max(ScaleTool.minSize, inst.Size.y + delta)
    elseif ScaleTool.dragAxis == "z" then
        inst.Size.z = math.max(ScaleTool.minSize, inst.Size.z + delta)
    end
end

function ScaleTool.mousereleased(x, y, button)
    if button == 1 and ScaleTool.dragging then
        local inst = _G._UI and _G._UI.selectedInstance
        if inst and ScaleTool._startSize and Engine.History then
            local startSize = ScaleTool._startSize
            local endSize = {x = inst.Size.x, y = inst.Size.y, z = inst.Size.z}
            Engine.History:record({
                desc = "Scale " .. inst.Name,
                undo = function()
                    inst.Size.x = startSize.x
                    inst.Size.y = startSize.y
                    inst.Size.z = startSize.z
                end,
                redo = function()
                    inst.Size.x = endSize.x
                    inst.Size.y = endSize.y
                    inst.Size.z = endSize.z
                end,
            })
        end
        ScaleTool.dragging = false
        ScaleTool.dragAxis = nil
        ScaleTool._startSize = nil
    end
end

function ScaleTool.wheelmoved(x, y) end

return ScaleTool
