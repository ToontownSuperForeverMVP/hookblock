-- studio/tools/select.lua
-- Select tool: ray-picks Parts in Workspace, updates UI.selectedInstance

local Select = {}

function Select.mousepressed(x, y, button)
    if button ~= 1 then return end

    -- Don't pick if over UI chrome
    if _G._UI and _G._UI.isOverUI and _G._UI.isOverUI(x, y) then return end

    -- Simple 2D bounding box pick (project each Part center onto screen)
    -- Full 3D raycast requires more math; this is a robust approximation
    local g3d   = require("g3d")
    local cam   = g3d.camera
    local W, H  = love.graphics.getWidth(), love.graphics.getHeight()

    local bestDist = math.huge
    local bestInst = nil

    local function pickInst(inst)
        if inst.Position and inst.model then
            local wx, wy, wz = inst.Position.x, inst.Position.y, inst.Position.z
            -- Transform world pos to clip space via g3d view+proj matrices
            -- g3d stores camera matrices; use a manual projection approximation
            local vx = wx - cam.position[1]
            local vy = wy - cam.position[2]
            local vz = wz - cam.position[3]

            -- Camera forward vector
            local fwd = {
                cam.target[1] - cam.position[1],
                cam.target[2] - cam.position[2],
                cam.target[3] - cam.position[3],
            }
            local flen = math.sqrt(fwd[1]^2 + fwd[2]^2 + fwd[3]^2)
            fwd[1] = fwd[1] / flen
            fwd[2] = fwd[2] / flen
            fwd[3] = fwd[3] / flen

            -- Dot with forward = depth
            local depth = vx * fwd[1] + vy * fwd[2] + vz * fwd[3]
            if depth <= 0.1 then return end -- behind camera

            -- Camera right = fwd × up
            local up = {0, 1, 0}
            local right = {
                fwd[2]*up[3] - fwd[3]*up[2],
                fwd[3]*up[1] - fwd[1]*up[3],
                fwd[1]*up[2] - fwd[2]*up[1],
            }
            local rup = {
                fwd[2]*right[3] - fwd[3]*right[2],
                fwd[3]*right[1] - fwd[1]*right[3],
                fwd[1]*right[2] - fwd[2]*right[1],
            }

            local rx = vx*right[1] + vy*right[2] + vz*right[3]
            local ry2 = vx*rup[1]  + vy*rup[2]  + vz*rup[3]

            -- Project (simple perspective)
            local fov   = math.pi / 3
            local scale = (H / 2) / math.tan(fov / 2)
            local sx    = W / 2 + (rx / depth) * scale
            local sy    = H / 2 - (ry2 / depth) * scale

            -- Approximate screen half-size from world Size
            local sizeW = (inst.Size and inst.Size.x or 1)
            local sizeH = (inst.Size and inst.Size.y or 1)
            local screenR = math.max(sizeW, sizeH) * scale / depth * 0.6

            local dx = x - sx
            local dy = y - sy
            local dist2d = math.sqrt(dx*dx + dy*dy)

            if dist2d < screenR + 10 and depth < bestDist then
                bestDist = depth
                bestInst = inst
            end
        end

        for _, child in ipairs(inst:GetChildren()) do
            pickInst(child)
        end
    end

    pickInst(Engine.Workspace)

    if _G._UI then
        _G._UI.selectedInstance = bestInst
        if bestInst then
            print("[Luvoxel] Selected: " .. bestInst.Name)
        end
    end
end

function Select.draw()
    -- Draw selection outline around selected Part
    if not (_G._UI and _G._UI.selectedInstance) then return end
    local inst = _G._UI.selectedInstance
    if not inst.Position then return end

    -- Re-project to screen (same math as above) to draw highlight box
    local g3d  = require("g3d")
    local cam  = g3d.camera
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()

    local vx = inst.Position.x - cam.position[1]
    local vy = inst.Position.y - cam.position[2]
    local vz = inst.Position.z - cam.position[3]

    local fwd = {
        cam.target[1] - cam.position[1],
        cam.target[2] - cam.position[2],
        cam.target[3] - cam.position[3],
    }
    local flen = math.sqrt(fwd[1]^2 + fwd[2]^2 + fwd[3]^2)
    fwd[1] = fwd[1]/flen; fwd[2] = fwd[2]/flen; fwd[3] = fwd[3]/flen

    local depth = vx*fwd[1] + vy*fwd[2] + vz*fwd[3]
    if depth <= 0.1 then return end

    local up    = {0, 1, 0}
    local right = {
        fwd[2]*up[3]-fwd[3]*up[2],
        fwd[3]*up[1]-fwd[1]*up[3],
        fwd[1]*up[2]-fwd[2]*up[1],
    }
    local rup = {
        fwd[2]*right[3]-fwd[3]*right[2],
        fwd[3]*right[1]-fwd[1]*right[3],
        fwd[1]*right[2]-fwd[2]*right[1],
    }

    local rx  = vx*right[1]+vy*right[2]+vz*right[3]
    local ry2 = vx*rup[1]+vy*rup[2]+vz*rup[3]

    local fov   = math.pi / 3
    local scale = (H / 2) / math.tan(fov / 2)
    local sx    = W / 2 + (rx / depth) * scale
    local sy    = H / 2 - (ry2 / depth) * scale

    local sizeR = math.max(
        inst.Size and inst.Size.x or 1,
        inst.Size and inst.Size.y or 1,
        inst.Size and inst.Size.z or 1
    ) * scale / depth * 0.7

    -- Pulsing outline
    local t     = love.timer.getTime()
    local alpha = 0.6 + 0.4 * math.sin(t * 4)
    love.graphics.setDepthMode()
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.38, 0.71, 1, alpha)
    love.graphics.rectangle("line", sx - sizeR, sy - sizeR, sizeR * 2, sizeR * 2, 4)

    -- Name label
    love.graphics.setFont(love.graphics.newFont(11))
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print(inst.Name, sx - sizeR, sy - sizeR - 16)
end

function Select.update(dt) end
function Select.mousereleased(x, y, button) end
function Select.mousemoved(x, y, dx, dy) end
function Select.wheelmoved(x, y) end

return Select
