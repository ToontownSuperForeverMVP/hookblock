-- engine/physics.lua
-- Lightweight 3D physics engine: AABB collision, gravity, rigid body dynamics
-- Optimized for Roblox-like block worlds

local Physics = {}
Physics.__index = Physics

-- Localize for performance
local math_abs = math.abs
local math_max = math.max
local math_min = math.min
local table_insert = table.insert
local table_remove = table.remove

-- Constants (Roblox-like defaults)
Physics.GRAVITY = 196.2  -- studs/s² (Roblox uses ~196.2)
Physics.AIR_FRICTION = 0.01
Physics.GROUND_FRICTION = 0.5
Physics.RESTITUTION = 0.0  -- bounciness (default to 0 to prevent unwanted bouncing)
Physics.MIN_VELOCITY = 0.001  -- velocities below this are zeroed
Physics.SLEEP_THRESHOLD = 0.01 -- velocity below which body goes to sleep

function Physics.new()
    local self = setmetatable({}, Physics)
    self.bodies = {}  -- list of physics-enabled parts
    self.collidables = {} -- cached list of all static collidable parts
    self.gravity = {x = 0, y = -Physics.GRAVITY, z = 0}
    self.enabled = true
    -- Increased substeps from 1 to 2 for better stability on the target Celeron N4500
    self.substeps = 2
    self.lastWorkspaceVersion = -1
    self.frameCount = 0

    -- Spatial Hash Grid
    self.cellSize = 10
    self.grid = {} -- grid[hash] = {part1, part2, ...}
    
    return self
end

-- Spatial Hash Grid methods
function Physics:hash(x, y, z)
    local gx = math.floor(x / self.cellSize)
    local gy = math.floor(y / self.cellSize)
    local gz = math.floor(z / self.cellSize)
    -- Simple hashing function for 3D coordinates
    return gx .. "," .. gy .. "," .. gz
end

function Physics:updateGrid(workspace)
    self.grid = {}
    local cellSize = self.cellSize
    
    local descendants = workspace:GetDescendants()
    -- Include the workspace itself if it has position/size (though it usually doesn't)
    table_insert(descendants, 1, workspace)

    for i=1, #descendants do
        local part = descendants[i]
        if part.Position and part.Size and part.CanCollide ~= false then
            local pos = part.Position
            local size = part.Size
            local hx, hy, hz = size.x * 0.5, size.y * 0.5, size.z * 0.5
            
            local minX, maxX = math.floor((pos.x - hx) / cellSize), math.floor((pos.x + hx - 0.0001) / cellSize)
            local minY, maxY = math.floor((pos.y - hy) / cellSize), math.floor((pos.y + hy - 0.0001) / cellSize)
            local minZ, maxZ = math.floor((pos.z - hz) / cellSize), math.floor((pos.z + hz - 0.0001) / cellSize)
            
            for x = minX, maxX do
                for y = minY, maxY do
                    for z = minZ, maxZ do
                        local h = x .. "," .. y .. "," .. z
                        if not self.grid[h] then self.grid[h] = {} end
                        table_insert(self.grid[h], part)
                    end
                end
            end
        end
    end
end

-- Register a part for physics simulation
function Physics:addBody(part)
    if not part._physicsBody then
        part._physicsBody = {
            velocity = {x = 0, y = 0, z = 0},
            acceleration = {x = 0, y = 0, z = 0},
            grounded = false,
            mass = 1.0,
            friction = Physics.GROUND_FRICTION,
            restitution = Physics.RESTITUTION,
            sleeping = false,
        }
        table_insert(self.bodies, part)
    end
end

-- Remove a part from physics
function Physics:removeBody(part)
    if not part._physicsBody then return end
    part._physicsBody = nil
    for i, b in ipairs(self.bodies) do
        if b == part then
            table_remove(self.bodies, i)
            break
        end
    end
end

-- AABB collision detection between two parts
-- Optimized to return multiple values to avoid table allocation
function Physics.checkAABB(a, b)
    local ax, ay, az = a.Position.x, a.Position.y, a.Position.z
    local asx, asy, asz = a.Size.x * 0.5, a.Size.y * 0.5, a.Size.z * 0.5

    local bx, by, bz = b.Position.x, b.Position.y, b.Position.z
    local bsx, bsy, bsz = b.Size.x * 0.5, b.Size.y * 0.5, b.Size.z * 0.5

    local overlapX = (asx + bsx) - math_abs(ax - bx)
    if overlapX <= 0.001 then return false end

    local overlapY = (asy + bsy) - math_abs(ay - by)
    if overlapY <= 0.001 then return false end

    local overlapZ = (asz + bsz) - math_abs(az - bz)
    if overlapZ <= 0.001 then return false end

    -- Priority Resolution Logic
    local nx, ny, nz = 0, 0, 0
    local minOverlap

    local topB = by + bsy
    local bottomA = ay - asy

    local vy = a._physicsBody and a._physicsBody.velocity.y or 0
    local threshold = 0.5 -- Reduced from 1.5 to prevent "popping"
    if vy < 0 then
        threshold = threshold + math_abs(vy) * 0.05
    end

    local isAbove = (bottomA > topB - threshold)

    -- Force UP resolution if we are within the top threshold and falling.
    -- This ensures we land on the platform even at the very edge where horizontal overlap is minimal.
    if isAbove and (ay > by or (vy < 0 and bottomA > topB - 1.0)) then
        minOverlap = overlapY
        ny = 1
    elseif overlapX < overlapY and overlapX < overlapZ then
        minOverlap = overlapX
        nx = (ax > bx) and 1 or -1
    elseif overlapZ < overlapY then
        minOverlap = overlapZ
        nz = (az > bz) and 1 or -1
    else
        minOverlap = overlapY
        ny = (ay > by) and 1 or -1
    end

    return true, minOverlap, nx, ny, nz
end

-- Point inside AABB test
function Physics.pointInAABB(px, py, pz, part)
    local hx = part.Size.x * 0.5
    local hy = part.Size.y * 0.5
    local hz = part.Size.z * 0.5
    return px >= part.Position.x - hx and px <= part.Position.x + hx
       and py >= part.Position.y - hy and py <= part.Position.y + hy
       and pz >= part.Position.z - hz and pz <= part.Position.z + hz
end

-- Ray-AABB intersection for raycasting
function Physics.raycastAABB(ox, oy, oz, dx, dy, dz, part, maxDist)
    local hx = part.Size.x * 0.5
    local hy = part.Size.y * 0.5
    local hz = part.Size.z * 0.5

    local minX = part.Position.x - hx
    local maxX = part.Position.x + hx
    local minY = part.Position.y - hy
    local maxY = part.Position.y + hy
    local minZ = part.Position.z - hz
    local maxZ = part.Position.z + hz

    local tmin = -math.huge
    local tmax = math.huge

    -- X slab
    if math_abs(dx) < 1e-8 then
        if ox < minX or ox > maxX then return nil end
    else
        local t1 = (minX - ox) / dx
        local t2 = (maxX - ox) / dx
        if t1 > t2 then t1, t2 = t2, t1 end
        tmin = math_max(tmin, t1)
        tmax = math_min(tmax, t2)
        if tmin > tmax then return nil end
    end

    -- Y slab
    if math_abs(dy) < 1e-8 then
        if oy < minY or oy > maxY then return nil end
    else
        local t1 = (minY - oy) / dy
        local t2 = (maxY - oy) / dy
        if t1 > t2 then t1, t2 = t2, t1 end
        tmin = math_max(tmin, t1)
        tmax = math_min(tmax, t2)
        if tmin > tmax then return nil end
    end

    -- Z slab
    if math_abs(dz) < 1e-8 then
        if oz < minZ or oz > maxZ then return nil end
    else
        local t1 = (minZ - oz) / dz
        local t2 = (maxZ - oz) / dz
        if t1 > t2 then t1, t2 = t2, t1 end
        tmin = math_max(tmin, t1)
        tmax = math_min(tmax, t2)
        if tmin > tmax then return nil end
    end

    if tmin < 0 then tmin = tmax end
    if tmin < 0 then return nil end
    if maxDist and tmin > maxDist then return nil end

    -- Hit normal
    local hitX = ox + dx * tmin
    local hitY = oy + dy * tmin
    local hitZ = oz + dz * tmin

    -- Calculate surface normal from hit point
    local nx, ny, nz = 0, 0, 0
    local eps = 0.001
    if math_abs(hitX - minX) < eps then nx = -1
    elseif math_abs(hitX - maxX) < eps then nx = 1
    elseif math_abs(hitY - minY) < eps then ny = -1
    elseif math_abs(hitY - maxY) < eps then ny = 1
    elseif math_abs(hitZ - minZ) < eps then nz = -1
    elseif math_abs(hitZ - maxZ) < eps then nz = 1
    end

    return {
        distance = tmin,
        position = {x = hitX, y = hitY, z = hitZ},
        normal = {x = nx, y = ny, z = nz},
        part = part,
    }
end

-- Raycast through all collidable parts in workspace
function Physics.raycast(workspace, ox, oy, oz, dx, dy, dz, maxDist, ignore)
    maxDist = maxDist or 1000
    local closest = nil

    local function castPart(inst)
        if inst.Position and inst.Size and inst.CanCollide ~= false then
            -- Check ignore list
            if ignore then
                for _, ig in ipairs(ignore) do
                    if ig == inst then return end
                end
            end
            local hit = Physics.raycastAABB(ox, oy, oz, dx, dy, dz, inst, maxDist)
            if hit and (not closest or hit.distance < closest.distance) then
                closest = hit
            end
        end
        local children = inst:GetChildren()
        for i=1, #children do
            castPart(children[i])
        end
    end

    castPart(workspace)
    return closest
end

-- Main physics step
function Physics:step(dt, workspace)
    if not self.enabled then return end
    self.frameCount = self.frameCount + 1

    -- Update spatial grid every 10 frames (0.16s at 60fps) to keep moving parts accurate
    if self.frameCount % 10 == 0 or not next(self.grid) then
        self:updateGrid(workspace)
    end

    local subDt = dt / self.substeps
    for _ = 1, self.substeps do
        self:_substep(subDt)
    end
end

local function getScreenPos(x, y, z, view, proj)
    -- 1. Multiply by View Matrix
    local vx = view[1]*x + view[2]*y + view[3]*z + view[4]
    local vy = view[5]*x + view[6]*y + view[7]*z + view[8]
    local vz = view[9]*x + view[10]*y + view[11]*z + view[12]
    local vw = view[13]*x + view[14]*y + view[15]*z + view[16]

    -- 2. Multiply by Projection Matrix
    local px = proj[1]*vx + proj[2]*vy + proj[3]*vz + proj[4]*vw
    local py = proj[5]*vx + proj[6]*vy + proj[7]*vz + proj[8]*vw
    local pz = proj[9]*vx + proj[10]*vy + proj[11]*vz + proj[12]*vw
    local pw = proj[13]*vx + proj[14]*vy + proj[15]*vz + proj[16]*vw

    -- Near plane clipping
    if pz < -pw then return nil end
    if pw <= 0 then return nil end

    -- 3. Perspective Divide (NDC)
    local ndcX = px / pw
    local ndcY = py / pw

    -- 4. Map to Screen Coordinates
    local sw, sh = love.graphics.getDimensions()
    local sx = (ndcX + 1) * 0.5 * sw
    local sy = (1 - ndcY) * 0.5 * sh

    return sx, sy
end

local function drawWireframeBox(pos, size, view, proj)
    local lg = love.graphics
    local hx, hy, hz = size.x * 0.5, size.y * 0.5, size.z * 0.5
    
    local corners = {
        {pos.x - hx, pos.y - hy, pos.z - hz}, {pos.x + hx, pos.y - hy, pos.z - hz},
        {pos.x + hx, pos.y + hy, pos.z - hz}, {pos.x - hx, pos.y + hy, pos.z - hz},
        {pos.x - hx, pos.y - hy, pos.z + hz}, {pos.x + hx, pos.y - hy, pos.z + hz},
        {pos.x + hx, pos.y + hy, pos.z + hz}, {pos.x - hx, pos.y + hy, pos.z + hz},
    }
    
    local screenPoints = {}
    for i=1, 8 do
        local x, y, z = corners[i][1], corners[i][2], corners[i][3]
        local sx, sy = getScreenPos(x, y, z, view, proj)
        if sx and sy then screenPoints[i] = {sx, sy} end
    end
    
    local function line(i, j)
        local p1, p2 = screenPoints[i], screenPoints[j]
        if p1 and p2 then lg.line(p1[1], p1[2], p2[1], p2[2]) end
    end
    
    line(1,2) line(2,3) line(3,4) line(4,1) -- bottom
    line(5,6) line(6,7) line(7,8) line(8,5) -- top
    line(1,5) line(2,6) line(3,7) line(4,8) -- sides
end

function Physics:renderDebug(workspace)
    local lg = love.graphics
    local g3d = require("g3d")
    local cam = g3d.camera
    local view = cam.viewMatrix
    local proj = cam.projectionMatrix
    
    lg.setLineWidth(1)
    
    -- 1. Draw all physics bodies
    for i=1, #self.bodies do
        local part = self.bodies[i]
        lg.setColor(0, 1, 0, 0.8) -- Green for bodies
        if part._physicsBody and part._physicsBody.sleeping then
            lg.setColor(0.5, 0.5, 0.5, 0.5)
        end
        drawWireframeBox(part.Position, part.Size, view, proj)
    end
    
    -- 2. Draw static collidables in view
    local descendants = workspace:GetDescendants()
    local camPos = cam.position
    for i=1, #descendants do
        local part = descendants[i]
        if part.Position and part.Size and part.CanCollide ~= false and not part._physicsBody then
            local dx, dy, dz = part.Position.x - camPos[1], part.Position.y - camPos[2], part.Position.z - camPos[3]
            local distSq = dx*dx + dy*dy + dz*dz
            if distSq < 100 * 100 then
                lg.setColor(1, 0, 0, 0.4) -- Red for static collidables
                drawWireframeBox(part.Position, part.Size, view, proj)
            end
        end
    end
end

function Physics:_substep(dt)
    local gravityX = self.gravity.x * dt
    local gravityY = self.gravity.y * dt
    local gravityZ = self.gravity.z * dt

    local grid = self.grid
    local cellSize = self.cellSize

    -- Update each physics body
    for i=1, #self.bodies do
        local part = self.bodies[i]
        local body = part._physicsBody
        if body and not part.Anchored then
            -- Sleeping logic: skip if stationary
            local shouldUpdate = true
            if body.sleeping then
                if body.acceleration.x ~= 0 or body.acceleration.y ~= 0 or body.acceleration.z ~= 0
                or body.velocity.x ~= 0 or body.velocity.y ~= 0 or body.velocity.z ~= 0 then
                    body.sleeping = false
                else
                    shouldUpdate = false
                end
            end

            if shouldUpdate then
                -- Apply gravity and integration
                local vx = body.velocity.x + gravityX + body.acceleration.x * dt
                local vy = body.velocity.y + gravityY + body.acceleration.y * dt
                local vz = body.velocity.z + gravityZ + body.acceleration.z * dt

                vx = vx * (1 - Physics.AIR_FRICTION)
                vz = vz * (1 - Physics.AIR_FRICTION)

                part.Position.x = part.Position.x + vx * dt
                part.Position.y = part.Position.y + vy * dt
                part.Position.z = part.Position.z + vz * dt

                body.velocity.x, body.velocity.y, body.velocity.z = vx, vy, vz

                -- Collision resolution using Spatial Hash
                body.grounded = false
                
                -- Determine cells to check
                local hx, hy, hz = part.Size.x * 0.5, part.Size.y * 0.5, part.Size.z * 0.5
                local minX, maxX = math.floor((part.Position.x - hx) / cellSize), math.floor((part.Position.x + hx - 0.0001) / cellSize)
                local minY, maxY = math.floor((part.Position.y - hy) / cellSize), math.floor((part.Position.y + hy - 0.0001) / cellSize)
                local minZ, maxZ = math.floor((part.Position.z - hz) / cellSize), math.floor((part.Position.z + hz - 0.0001) / cellSize)
                
                local checked = {} -- Avoid checking same part multiple times
                for gx = minX, maxX do
                    for gy = minY, maxY do
                        for gz = minZ, maxZ do
                            local h = gx .. "," .. gy .. "," .. gz
                            local cell = grid[h]
                            if cell then
                                for j=1, #cell do
                                    local other = cell[j]
                                    if other ~= part and not checked[other] then
                                        checked[other] = true
                                        local hit, overlap, nx, ny, nz = Physics.checkAABB(part, other)
                                        if hit then
                                            part.Position.x = part.Position.x + nx * overlap
                                            part.Position.y = part.Position.y + ny * overlap
                                            part.Position.z = part.Position.z + nz * overlap

                                            local vDotN = body.velocity.x * nx + body.velocity.y * ny + body.velocity.z * nz
                                            if vDotN < 0 then
                                                local res = body.restitution
                                                body.velocity.x = body.velocity.x - (1 + res) * vDotN * nx
                                                body.velocity.y = body.velocity.y - (1 + res) * vDotN * ny
                                                body.velocity.z = body.velocity.z - (1 + res) * vDotN * nz
                                                
                                                -- Zero out tiny vertical velocities to prevent micro-bouncing
                                                if ny > 0.5 and math_abs(body.velocity.y) < 2.0 then
                                                    body.velocity.y = 0
                                                end
                                            end

                                            if ny > 0.5 then
                                                body.grounded = true
                                                body.velocity.x = body.velocity.x * (1 - body.friction * 0.1)
                                                body.velocity.z = body.velocity.z * (1 - body.friction * 0.1)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                -- Velocity thresholds and sleeping
                local speedSq = body.velocity.x^2 + body.velocity.y^2 + body.velocity.z^2
                if speedSq < Physics.MIN_VELOCITY^2 then
                    body.velocity.x, body.velocity.y, body.velocity.z = 0, 0, 0
                    if body.grounded then body.sleeping = true end
                end

                if part.Position.y < -500 then
                    part.Position.y = 50
                    body.velocity.x, body.velocity.y, body.velocity.z = 0, 0, 0
                end
            end
        end
    end
end

return Physics
