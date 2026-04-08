-- studio/ui/viewport_gizmo.lua
-- Advanced 3D orientation indicator
-- Shows XYZ axes relative to camera with depth sorting and interactivity

local Theme = require("studio.theme")
local g3d = require("g3d")

local ViewportGizmo = {}

ViewportGizmo.size = 80
ViewportGizmo.padding = 15

local AXES = {
    {name = "X", label = "Right", dir = {1, 0, 0}, color = {1, 0.25, 0.25}, is_positive = true},
    {name = "-X", label = "Left", dir = {-1, 0, 0}, color = {1, 0.25, 0.25}, is_positive = false},
    {name = "Y", label = "Top", dir = {0, 1, 0}, color = {0.5, 0.85, 0.2}, is_positive = true},
    {name = "-Y", label = "Bottom", dir = {0, -1, 0}, color = {0.5, 0.85, 0.2}, is_positive = false},
    {name = "Z", label = "Back", dir = {0, 0, 1}, color = {0.15, 0.5, 1.0}, is_positive = true},
    {name = "-Z", label = "Front", dir = {0, 0, -1}, color = {0.15, 0.5, 1.0}, is_positive = false},
}

function ViewportGizmo.draw(viewX, viewY, viewW, viewH)
    local gizSize = ViewportGizmo.size
    local gizX = viewX + viewW - gizSize - ViewportGizmo.padding
    local gizY = viewY + ViewportGizmo.padding
    local centerX = gizX + gizSize / 2
    local centerY = gizY + gizSize / 2
    local mx, my = love.mouse.getPosition()

    -- Calculate camera vectors
    local cam = g3d.camera
    local fwd = {
        cam.target[1] - cam.position[1],
        cam.target[2] - cam.position[2],
        cam.target[3] - cam.position[3],
    }
    local flen = math.sqrt(fwd[1]^2 + fwd[2]^2 + fwd[3]^2)
    if flen < 0.001 then return end
    fwd[1] = fwd[1]/flen; fwd[2] = fwd[2]/flen; fwd[3] = fwd[3]/flen

    local up = {0, 1, 0}
    local right = {
        fwd[2]*up[3] - fwd[3]*up[2],
        fwd[3]*up[1] - fwd[1]*up[3],
        fwd[1]*up[2] - fwd[2]*up[1],
    }
    local rlen = math.sqrt(right[1]^2 + right[2]^2 + right[3]^2)
    if rlen > 0.001 then
        right[1] = right[1]/rlen; right[2] = right[2]/rlen; right[3] = right[3]/rlen
    else
        right = {1, 0, 0}
    end
    
    local camUp = {
        right[2]*fwd[3] - right[3]*fwd[2],
        right[3]*fwd[1] - right[1]*fwd[3],
        right[1]*fwd[2] - right[2]*fwd[1],
    }

    local axisLen = gizSize * 0.38
    local renderData = {}

    for _, axis in ipairs(AXES) do
        local dx = axis.dir[1] * right[1] + axis.dir[2] * right[2] + axis.dir[3] * right[3]
        local dy = -(axis.dir[1] * camUp[1] + axis.dir[2] * camUp[2] + axis.dir[3] * camUp[3])
        local depth = axis.dir[1] * fwd[1] + axis.dir[2] * fwd[2] + axis.dir[3] * fwd[3]
        
        local ex = centerX + dx * axisLen
        local ey = centerY + dy * axisLen
        local radius = axis.is_positive and 8 or 5
        
        table.insert(renderData, {
            axis = axis,
            ex = ex,
            ey = ey,
            depth = depth,
            radius = radius
        })
    end

    -- Add center dot
    table.insert(renderData, {
        is_center = true,
        ex = centerX,
        ey = centerY,
        depth = 0,
        radius = 3,
        color = {1, 1, 1}
    })

    -- Sort by depth descending (furthest first)
    table.sort(renderData, function(a, b) return a.depth > b.depth end)

    -- Detect hover
    local hoveredData = nil
    for _, data in ipairs(renderData) do
        if not data.is_center then
            local dist = math.sqrt((mx - data.ex)^2 + (my - data.ey)^2)
            if dist <= data.radius + 4 then
                if not hoveredData or data.depth < hoveredData.depth then
                    hoveredData = data
                end
            end
        end
    end
    ViewportGizmo.hoveredData = hoveredData

    -- Draw background
    local distToCenter = math.sqrt((mx - centerX)^2 + (my - centerY)^2)
    local bgHovered = distToCenter <= gizSize / 2
    if bgHovered and not hoveredData then
        love.graphics.setColor(0, 0, 0, 0.4)
    else
        love.graphics.setColor(0, 0, 0, 0.25)
    end
    love.graphics.circle("fill", centerX, centerY, gizSize / 2)
    love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", centerX, centerY, gizSize / 2)

    -- Render axes
    love.graphics.setLineWidth(2)
    for _, data in ipairs(renderData) do
        if data.is_center then
            love.graphics.setColor(data.color[1], data.color[2], data.color[3], 0.8)
            love.graphics.circle("fill", data.ex, data.ey, data.radius)
        else
            local axis = data.axis
            local isHovered = (ViewportGizmo.hoveredData == data)
            
            -- Draw line for positive axes
            if axis.is_positive then
                love.graphics.setColor(axis.color[1], axis.color[2], axis.color[3], 1)
                love.graphics.line(centerX, centerY, data.ex, data.ey)
            end
            
            local r = data.radius
            if isHovered then
                r = r * 1.3
            end
            
            -- Draw node
            if axis.is_positive then
                love.graphics.setColor(axis.color[1], axis.color[2], axis.color[3], 1)
                love.graphics.circle("fill", data.ex, data.ey, r)
                
                love.graphics.setColor(1, 1, 1, 1)
                local font = Theme.fonts.tiny or love.graphics.getFont()
                local fw = font:getWidth(axis.name)
                local fh = font:getHeight()
                love.graphics.print(axis.name, math.floor(data.ex - fw/2), math.floor(data.ey - fh/2))
            else
                love.graphics.setColor(axis.color[1] * 0.5, axis.color[2] * 0.5, axis.color[3] * 0.5, 1)
                love.graphics.circle("fill", data.ex, data.ey, r)
            end
            
            -- Hover highlight
            if isHovered then
                love.graphics.setColor(1, 1, 1, 0.9)
                love.graphics.setLineWidth(1.5)
                love.graphics.circle("line", data.ex, data.ey, r + 1)
                love.graphics.setLineWidth(2)
            end
        end
    end
    love.graphics.setLineWidth(1)
end

function ViewportGizmo.mousepressed(x, y, viewX, viewY, viewW, viewH)
    if ViewportGizmo.hoveredData and ViewportGizmo.hoveredData.axis then
        local axis = ViewportGizmo.hoveredData.axis
        local cam = g3d.camera
        
        -- maintain current target, move position
        local target = cam.target
        local dist = math.sqrt(
            (cam.position[1] - target[1])^2 +
            (cam.position[2] - target[2])^2 +
            (cam.position[3] - target[3])^2
        )
        if dist < 1 then dist = 15 end
        
        local newPos = {
            target[1] + axis.dir[1] * dist,
            target[2] + axis.dir[2] * dist,
            target[3] + axis.dir[3] * dist,
        }
        
        cam.position = newPos
        cam.updateViewMatrix()
        
        -- Update Engine.Camera if it exists
        if Engine and Engine.Camera then
            local fwd = {
                target[1] - newPos[1],
                target[2] - newPos[2],
                target[3] - newPos[3],
            }
            local flen = math.sqrt(fwd[1]^2 + fwd[2]^2 + fwd[3]^2)
            if flen > 0.001 then
                Engine.Camera.pitch = math.asin(fwd[2] / flen)
                Engine.Camera.yaw = math.atan2(fwd[3], fwd[1])
            end
        end
        
        print("[Luvoxel] Snapped to " .. axis.label .. " view")
        return true
    end
    
    -- Consume click if within gizmo bounds
    local gizSize = ViewportGizmo.size
    local gizX = viewX + viewW - gizSize - ViewportGizmo.padding
    local gizY = viewY + ViewportGizmo.padding
    local centerX = gizX + gizSize / 2
    local centerY = gizY + gizSize / 2
    local distToCenter = math.sqrt((x - centerX)^2 + (y - centerY)^2)
    
    if distToCenter <= gizSize / 2 then
        return true
    end
    
    return false
end

return ViewportGizmo
