-- studio/tools/gizmo.lua
-- Shared 3D gizmo rendering and axis interaction for manipulation tools
-- Projects 3D axis handles to screen space for hit testing and dragging

local g3d = require("g3d")

local Gizmo = {}

-- Axis colors
Gizmo.colors = {
    x = {1.0, 0.2, 0.2, 1},  -- Red
    y = {0.2, 0.8, 0.2, 1},  -- Green
    z = {0.2, 0.4, 1.0, 1},  -- Blue
    xHover = {1.0, 0.5, 0.5, 1},
    yHover = {0.5, 1.0, 0.5, 1},
    zHover = {0.5, 0.7, 1.0, 1},
}

-- Project a world position to screen coordinates
function Gizmo.worldToScreen(wx, wy, wz)
    local cam = g3d.camera
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()

    local vx = wx - cam.position[1]
    local vy = wy - cam.position[2]
    local vz = wz - cam.position[3]

    -- Camera forward
    local fwd = {
        cam.target[1] - cam.position[1],
        cam.target[2] - cam.position[2],
        cam.target[3] - cam.position[3],
    }
    local flen = math.sqrt(fwd[1]^2 + fwd[2]^2 + fwd[3]^2)
    if flen < 0.001 then return nil end
    fwd[1] = fwd[1]/flen; fwd[2] = fwd[2]/flen; fwd[3] = fwd[3]/flen

    local depth = vx*fwd[1] + vy*fwd[2] + vz*fwd[3]
    if depth <= 0.1 then return nil end

    -- Camera right = fwd × up
    local up = {0, 1, 0}
    local right = {
        fwd[2]*up[3] - fwd[3]*up[2],
        fwd[3]*up[1] - fwd[1]*up[3],
        fwd[1]*up[2] - fwd[2]*up[1],
    }
    local rlen = math.sqrt(right[1]^2 + right[2]^2 + right[3]^2)
    if rlen > 0.001 then
        right[1] = right[1]/rlen; right[2] = right[2]/rlen; right[3] = right[3]/rlen
    end

    -- Camera up = right × fwd
    local camUp = {
        right[2]*fwd[3] - right[3]*fwd[2],
        right[3]*fwd[1] - right[1]*fwd[3],
        right[1]*fwd[2] - right[2]*fwd[1],
    }

    local rx = vx*right[1] + vy*right[2] + vz*right[3]
    local ry = vx*camUp[1] + vy*camUp[2] + vz*camUp[3]

    local fov = math.pi / 3
    local scale = (H / 2) / math.tan(fov / 2)
    local sx = W / 2 + (rx / depth) * scale
    local sy = H / 2 - (ry / depth) * scale

    return sx, sy, depth
end

-- Draw axis arrows for move gizmo
function Gizmo.drawMoveGizmo(part, hoveredAxis)
    if not part or not part.Position then return end

    love.graphics.setDepthMode()
    love.graphics.setLineWidth(3)

    local px, py, pz = part.Position.x, part.Position.y, part.Position.z
    local cx, cy = Gizmo.worldToScreen(px, py, pz)
    if not cx then return end

    -- Axis length in world space (scale with distance for consistent screen size)
    local cam = g3d.camera
    local dist = math.sqrt(
        (px - cam.position[1])^2 +
        (py - cam.position[2])^2 +
        (pz - cam.position[3])^2
    )
    local axisLen = math.max(1.5, dist * 0.15)

    -- Draw each axis
    local axes = {
        {name = "x", dx = axisLen, dy = 0, dz = 0},
        {name = "y", dx = 0, dy = axisLen, dz = 0},
        {name = "z", dx = 0, dy = 0, dz = axisLen},
    }

    for _, axis in ipairs(axes) do
        local ex, ey = Gizmo.worldToScreen(px + axis.dx, py + axis.dy, pz + axis.dz)
        if ex then
            local isHovered = (hoveredAxis == axis.name)
            local col = isHovered and Gizmo.colors[axis.name .. "Hover"] or Gizmo.colors[axis.name]
            love.graphics.setColor(col[1], col[2], col[3], col[4])

            -- Line
            love.graphics.line(cx, cy, ex, ey)

            -- Arrow head
            local dx = ex - cx
            local dy = ey - cy
            local len = math.sqrt(dx*dx + dy*dy)
            if len > 5 then
                local nx = dx / len
                local ny = dy / len
                local arrowSize = 8
                love.graphics.polygon("fill",
                    ex, ey,
                    ex - nx * arrowSize + ny * arrowSize * 0.4,
                    ey - ny * arrowSize - nx * arrowSize * 0.4,
                    ex - nx * arrowSize - ny * arrowSize * 0.4,
                    ey - ny * arrowSize + nx * arrowSize * 0.4
                )
            end

            -- Axis label
            love.graphics.setFont(love.graphics.newFont(10))
            love.graphics.print(axis.name:upper(), ex + 4, ey - 6)
        end
    end

    -- Center dot
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", cx, cy, 4)
    love.graphics.setLineWidth(1)
end

-- Draw scale gizmo (cube handles on axes)
function Gizmo.drawScaleGizmo(part, hoveredAxis)
    if not part or not part.Position then return end

    love.graphics.setDepthMode()
    love.graphics.setLineWidth(2)

    local px, py, pz = part.Position.x, part.Position.y, part.Position.z
    local cx, cy = Gizmo.worldToScreen(px, py, pz)
    if not cx then return end

    local cam = g3d.camera
    local dist = math.sqrt(
        (px - cam.position[1])^2 +
        (py - cam.position[2])^2 +
        (pz - cam.position[3])^2
    )
    local axisLen = math.max(1.5, dist * 0.15)

    local axes = {
        {name = "x", dx = axisLen, dy = 0, dz = 0},
        {name = "y", dx = 0, dy = axisLen, dz = 0},
        {name = "z", dx = 0, dy = 0, dz = axisLen},
    }

    for _, axis in ipairs(axes) do
        local ex, ey = Gizmo.worldToScreen(px + axis.dx, py + axis.dy, pz + axis.dz)
        if ex then
            local isHovered = (hoveredAxis == axis.name)
            local col = isHovered and Gizmo.colors[axis.name .. "Hover"] or Gizmo.colors[axis.name]
            love.graphics.setColor(col[1], col[2], col[3], col[4])

            -- Line
            love.graphics.line(cx, cy, ex, ey)

            -- Cube handle
            local s = isHovered and 7 or 5
            love.graphics.rectangle("fill", ex - s, ey - s, s*2, s*2)
        end
    end

    -- Center cube
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", cx - 4, cy - 4, 8, 8)
    love.graphics.setLineWidth(1)
end

-- Draw rotation gizmo (circles around each axis)
function Gizmo.drawRotateGizmo(part, hoveredAxis)
    if not part or not part.Position then return end

    love.graphics.setDepthMode()
    love.graphics.setLineWidth(2)

    local px, py, pz = part.Position.x, part.Position.y, part.Position.z
    local cx, _ = Gizmo.worldToScreen(px, py, pz)
    if not cx then return end

    local cam = g3d.camera
    local dist = math.sqrt(
        (px - cam.position[1])^2 +
        (py - cam.position[2])^2 +
        (pz - cam.position[3])^2
    )
    local radius = math.max(1.5, dist * 0.15)

    -- Draw projected circles for each axis
    local segments = 32
    local axisCircles = {
        {name = "x", axis = function(t) return 0, math.cos(t), math.sin(t) end},
        {name = "y", axis = function(t) return math.cos(t), 0, math.sin(t) end},
        {name = "z", axis = function(t) return math.cos(t), math.sin(t), 0 end},
    }

    for _, ac in ipairs(axisCircles) do
        local isHovered = (hoveredAxis == ac.name)
        local col = isHovered and Gizmo.colors[ac.name .. "Hover"] or Gizmo.colors[ac.name]
        love.graphics.setColor(col[1], col[2], col[3], col[4])

        local points = {}
        for i = 0, segments do
            local t = (i / segments) * math.pi * 2
            local dx, dy, dz = ac.axis(t)
            local sx, sy = Gizmo.worldToScreen(
                px + dx * radius,
                py + dy * radius,
                pz + dz * radius
            )
            if sx then
                table.insert(points, sx)
                table.insert(points, sy)
            end
        end

        if #points >= 4 then
            love.graphics.line(points)
        end
    end

    love.graphics.setLineWidth(1)
end

-- Hit-test: which axis is the mouse near?
function Gizmo.hitTestAxis(mx, my, part, gizmoType)
    if not part or not part.Position then return nil end

    local px, py, pz = part.Position.x, part.Position.y, part.Position.z
    local cx, cy = Gizmo.worldToScreen(px, py, pz)
    if not cx then return nil end

    local cam = g3d.camera
    local dist = math.sqrt(
        (px - cam.position[1])^2 +
        (py - cam.position[2])^2 +
        (pz - cam.position[3])^2
    )
    local axisLen = math.max(1.5, dist * 0.15)
    local threshold = 15  -- pixels

    local axes = {
        {name = "x", dx = axisLen, dy = 0, dz = 0},
        {name = "y", dx = 0, dy = axisLen, dz = 0},
        {name = "z", dx = 0, dy = 0, dz = axisLen},
    }

    local bestAxis = nil
    local bestDist = threshold

    for _, axis in ipairs(axes) do
        local ex, ey = Gizmo.worldToScreen(px + axis.dx, py + axis.dy, pz + axis.dz)
        if ex then
            -- Distance from mouse to line segment (cx,cy)-(ex,ey)
            local segDist = Gizmo._distToSegment(mx, my, cx, cy, ex, ey)
            if segDist < bestDist then
                bestDist = segDist
                bestAxis = axis.name
            end
        end
    end

    return bestAxis
end

-- Distance from point to line segment
function Gizmo._distToSegment(px, py, x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local lenSq = dx*dx + dy*dy
    if lenSq < 0.001 then
        return math.sqrt((px-x1)^2 + (py-y1)^2)
    end
    local t = math.max(0, math.min(1, ((px-x1)*dx + (py-y1)*dy) / lenSq))
    local projX = x1 + t*dx
    local projY = y1 + t*dy
    return math.sqrt((px-projX)^2 + (py-projY)^2)
end

-- Calculate world-space drag delta along an axis
function Gizmo.calculateAxisDrag(axis, dx, dy, part)
    if not part or not part.Position then return 0 end

    local px, py, pz = part.Position.x, part.Position.y, part.Position.z

    -- Get screen-space axis direction
    local len = 2
    local endX, endY, endZ
    if axis == "x" then endX, endY, endZ = px + len, py, pz
    elseif axis == "y" then endX, endY, endZ = px, py + len, pz
    else endX, endY, endZ = px, py, pz + len end

    local sx1, sy1 = Gizmo.worldToScreen(px, py, pz)
    local sx2, sy2 = Gizmo.worldToScreen(endX, endY, endZ)

    if not sx1 or not sx2 then return 0 end

    -- Project mouse delta onto screen-space axis direction
    local adx = sx2 - sx1
    local ady = sy2 - sy1
    local aLen = math.sqrt(adx*adx + ady*ady)
    if aLen < 0.001 then return 0 end
    adx = adx / aLen
    ady = ady / aLen

    -- World units per pixel
    local pixelsPerUnit = aLen / len
    if pixelsPerUnit < 0.001 then return 0 end

    local projected = dx * adx + dy * ady
    return projected / pixelsPerUnit
end

return Gizmo
