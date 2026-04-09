-- studio/tools/select.lua
-- Select tool: ray-picks Parts in Workspace, updates UI.selectedInstance
-- Features: 3D Bounding Box highlight, Locked property respect

local Select = {}

local function project(worldPos)
    local g3d = require("g3d")
    local cam = g3d.camera
    local W, H = love.graphics.getDimensions()

    local vx = worldPos.x - cam.position[1]
    local vy = worldPos.y - cam.position[2]
    local vz = worldPos.z - cam.position[3]

    local fwd = {
        cam.target[1] - cam.position[1],
        cam.target[2] - cam.position[2],
        cam.target[3] - cam.position[3],
    }
    local flen = math.sqrt(fwd[1]^2 + fwd[2]^2 + fwd[3]^2)
    if flen == 0 then return nil end
    fwd[1], fwd[2], fwd[3] = fwd[1]/flen, fwd[2]/flen, fwd[3]/flen

    local depth = vx*fwd[1] + vy*fwd[2] + vz*fwd[3]
    if depth <= 0.1 then return nil end

    local up = {0, 1, 0}
    local right = {
        fwd[2]*up[3] - fwd[3]*up[2],
        fwd[3]*up[1] - fwd[1]*up[3],
        fwd[1]*up[2] - fwd[2]*up[1],
    }
    local rlen = math.sqrt(right[1]^2 + right[2]^2 + right[3]^2)
    if rlen > 0 then right[1], right[2], right[3] = right[1]/rlen, right[2]/rlen, right[3]/rlen end

    local rup = {
        fwd[2]*right[3] - fwd[3]*right[2],
        fwd[3]*right[1] - fwd[1]*right[3],
        fwd[1]*right[2] - fwd[2]*right[1],
    }

    local rx = vx*right[1] + vy*right[2] + vz*right[3]
    local ry = vx*rup[1]   + vy*rup[2]   + vz*rup[3]

    local fov = math.pi / 3
    local scale = (H / 2) / math.tan(fov / 2)
    local sx = W / 2 + (rx / depth) * scale
    local sy = H / 2 - (ry / depth) * scale

    return sx, sy
end

function Select.mousepressed(x, y, button)
    if button ~= 1 then return end
    if _G._UI and _G._UI.isOverUI and _G._UI.isOverUI(x, y) then return end

    local bestDist = math.huge
    local bestInst = nil

    local function pickInst(inst)
        if inst.Position and inst.model and not inst.Locked then
            local sx, sy = project(inst.Position)
            if sx then
                local dx, dy = x - sx, y - sy
                local dist2d = math.sqrt(dx*dx + dy*dy)
                
                -- Dynamic radius based on size and depth
                local size = math.max(inst.Size.x, inst.Size.y, inst.Size.z)
                local screenR = size * 50 / (inst.Position:dist(require("g3d").camera.position)) -- approximation
                
                if dist2d < screenR + 20 then
                    local depth = inst.Position:dist(require("g3d").camera.position)
                    if depth < bestDist then
                        bestDist = depth
                        bestInst = inst
                    end
                end
            end
        end

        for _, child in ipairs(inst:GetChildren()) do
            pickInst(child)
        end
    end

    pickInst(Engine.Workspace)
    if _G._UI then _G._UI.selectedInstance = bestInst end
end

function Select.draw()
    local inst = _G._UI and _G._UI.selectedInstance
    if not inst or not inst.Position or not inst.Size then return end

    local pos = inst.Position
    local size = inst.Size
    local hx, hy, hz = size.x/2, size.y/2, size.z/2

    -- 8 corners of the bounding box
    local corners = {
        {x=pos.x-hx, y=pos.y-hy, z=pos.z-hz},
        {x=pos.x+hx, y=pos.y-hy, z=pos.z-hz},
        {x=pos.x+hx, y=pos.y+hy, z=pos.z-hz},
        {x=pos.x-hx, y=pos.y+hy, z=pos.z-hz},
        {x=pos.x-hx, y=pos.y-hy, z=pos.z+hz},
        {x=pos.x+hx, y=pos.y-hy, z=pos.z+hz},
        {x=pos.x+hx, y=pos.y+hy, z=pos.z+hz},
        {x=pos.x-hx, y=pos.y+hy, z=pos.z+hz},
    }

    local screenCorners = {}
    for i, c in ipairs(corners) do
        local sx, sy = project(c)
        if sx then screenCorners[i] = {x=sx, y=sy} end
    end

    local function line(i, j)
        if screenCorners[i] and screenCorners[j] then
            love.graphics.line(screenCorners[i].x, screenCorners[i].y, screenCorners[j].x, screenCorners[j].y)
        end
    end

    love.graphics.setDepthMode()
    love.graphics.setLineWidth(2)
    local t = love.timer.getTime()
    local alpha = 0.6 + 0.4 * math.sin(t * 4)
    love.graphics.setColor(0.3, 0.7, 1, alpha)

    -- Draw 12 edges
    line(1,2); line(2,3); line(3,4); line(4,1) -- bottom
    line(5,6); line(6,7); line(7,8); line(8,5) -- top
    line(1,5); line(2,6); line(3,7); line(4,8) -- vertical

    -- Center label
    local sx, sy = project(pos)
    if sx then
        love.graphics.setFont(love.graphics.newFont(11))
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.print(inst.Name, sx - 20, sy - 10)
    end
end

function Select.update(dt) end
function Select.mousereleased(x, y, button) end
function Select.mousemoved(x, y, dx, dy) end
function Select.wheelmoved(x, y) end

return Select
