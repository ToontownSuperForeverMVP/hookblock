-- engine/sky.lua
-- Dynamic day/night skybox for HookBlock with 3D projection, smooth transitions, and Voxel Clouds
local Sky = {}
local g3d = require("g3d")

-- Localize for performance
local lg = love.graphics
local math_sin = math.sin
local math_cos = math.cos
local math_max = math.max
local math_min = math.min
local math_floor = math.floor

-- Sky states for interpolation
local SKY_STATES = {
    {time = 0,  top = {0.02, 0.02, 0.1, 1},  bottom = {0.05, 0.05, 0.15, 1}}, -- Midnight
    {time = 5,  top = {0.05, 0.05, 0.15, 1}, bottom = {0.1, 0.05, 0.2, 1}},   -- Pre-dawn
    {time = 6,  top = {0.5, 0.4, 0.6, 1},    bottom = {0.8, 0.5, 0.4, 1}},    -- Sunrise
    {time = 8,  top = {0.53, 0.81, 0.98, 1}, bottom = {0.7, 0.85, 1.0, 1}},   -- Morning
    {time = 12, top = {0.53, 0.81, 0.98, 1}, bottom = {0.7, 0.85, 1.0, 1}},   -- Noon
    {time = 17, top = {0.53, 0.6, 0.8, 1},    bottom = {0.9, 0.6, 0.4, 1}},    -- Afternoon
    {time = 18, top = {0.2, 0.15, 0.4, 1},   bottom = {0.9, 0.3, 0.2, 1}},    -- Sunset
    {time = 19, top = {0.1, 0.1, 0.3, 1},    bottom = {0.3, 0.1, 0.4, 1}},    -- Dusk
    {time = 21, top = {0.02, 0.02, 0.1, 1},  bottom = {0.05, 0.05, 0.15, 1}}, -- Night
    {time = 24, top = {0.02, 0.02, 0.1, 1},  bottom = {0.05, 0.05, 0.15, 1}}, -- Midnight loop
}

function Sky.new()
    local self = setmetatable({}, {__index = Sky})
    
    -- Current colors
    self.topColor = {0.53, 0.81, 0.98, 1}
    self.bottomColor = {0.7, 0.85, 1.0, 1}
    
    -- Mesh and caching
    self.mesh = nil
    self.lastW = -1
    self.lastH = -1
    
    -- Pre-generate stars for a stable globe
    self.stars = {}
    love.math.setRandomSeed(42)
    for i = 1, 400 do
        local theta = love.math.random() * 2 * math.pi
        local phi = math.acos(2 * love.math.random() - 1)
        local r = 500
        table.insert(self.stars, {
            x = r * math.sin(phi) * math.cos(theta),
            y = r * math.sin(phi) * math.sin(theta),
            z = r * math.cos(phi),
            size = love.math.random(1, 3),
            offset = love.math.random() * 10
        })
    end

    -- Cloud scrolling state
    self.cloudOffset = 0
    
    return self
end

local function lerpColor(c1, c2, alpha)
    return {
        c1[1] + (c2[1] - c1[1]) * alpha,
        c1[2] + (c2[2] - c1[2]) * alpha,
        c1[3] + (c2[3] - c1[3]) * alpha,
        c1[4] + (c2[4] - c1[4]) * alpha
    }
end

function Sky:updateColors(clockTime)
    local s1, s2
    for i = 1, #SKY_STATES - 1 do
        if clockTime >= SKY_STATES[i].time and clockTime < SKY_STATES[i+1].time then
            s1 = SKY_STATES[i]
            s2 = SKY_STATES[i+1]
            break
        end
    end
    
    if s1 and s2 then
        local alpha = (clockTime - s1.time) / (s2.time - s1.time)
        self.topColor = lerpColor(s1.top, s2.top, alpha)
        self.bottomColor = lerpColor(s1.bottom, s2.bottom, alpha)
    end
end

-- Helper to project a 3D point to screen 2D
local function projectPoint(x, y, z, w, h)
    local cam = g3d.camera
    local m = cam.viewMatrix
    
    local vx = x*m[1] + y*m[2] + z*m[3]
    local vy = x*m[5] + y*m[6] + z*m[7]
    local vz = x*m[9] + y*m[10] + z*m[11]
    
    if vz >= 0 then return nil end
    
    local pm = cam.projectionMatrix
    local xc = vx * pm[1] + vz * pm[3]
    local yc = vy * pm[6] + vz * pm[7]
    local wc = -vz
    
    local ndcX = xc / wc
    local ndcY = yc / wc
    
    return (ndcX + 1) * 0.5 * w, (1 - ndcY) * 0.5 * h
end

function Sky:draw()
    local w, h = lg.getDimensions()
    local lighting = Engine.Lighting
    local clockTime = 12
    if lighting then
        clockTime = lighting.ClockTime
        self:updateColors(clockTime)
    end

    -- 1. Draw Background Gradient
    if not self.mesh or w ~= self.lastW or h ~= self.lastH then
        if self.mesh then self.mesh:release() end
        self.mesh = lg.newMesh({
            {0, 0, 0, 0, 1, 1, 1, 1},
            {w, 0, 1, 0, 1, 1, 1, 1},
            {w, h, 1, 1, 1, 1, 1, 1},
            {0, h, 0, 1, 1, 1, 1, 1}
        }, "fan", "static")
        self.lastW, self.lastH = w, h
    end

    self.mesh:setVertices({
        {0, 0, 0, 0, self.topColor[1], self.topColor[2], self.topColor[3], self.topColor[4]},
        {w, 0, 1, 0, self.topColor[1], self.topColor[2], self.topColor[3], self.topColor[4]},
        {w, h, 1, 1, self.bottomColor[1], self.bottomColor[2], self.bottomColor[3], self.bottomColor[4]},
        {0, h, 0, 1, self.bottomColor[1], self.bottomColor[2], self.bottomColor[3], self.bottomColor[4]}
    })

    lg.push("all")
    lg.setDepthMode("always", false)
    lg.setMeshCullMode("none")
    lg.setColor(1, 1, 1, 1)
    lg.draw(self.mesh)
    
    local t = clockTime
    local angle = (t / 24) * 2 * math.pi + math.pi/2
    local sunDist = 800
    
    local sun3D = {
        x = math_cos(angle) * sunDist,
        y = 0,
        z = math_sin(angle) * sunDist
    }
    
    local moon3D = {
        x = -sun3D.x,
        y = 0,
        z = -sun3D.z
    }
    
    -- 2. Draw Stars
    if t < 7 or t > 17 then
        local starBaseAlpha
        if t < 7 then starBaseAlpha = math_max(0, 1 - (t-5)/2)
        else starBaseAlpha = math_max(0, (t - 17) / 2) end
        
        local timer = love.timer.getTime()
        for _, star in ipairs(self.stars) do
            local sx, sy = projectPoint(star.x, star.y, star.z, w, h)
            if sx then
                local twinkle = 0.7 + 0.3 * math_sin(timer * 3 + star.offset)
                lg.setColor(1, 1, 1, starBaseAlpha * twinkle)
                if star.size > 1.5 then
                    lg.rectangle("fill", sx - star.size/2, sy - star.size/2, star.size, star.size)
                else
                    lg.points(sx, sy)
                end
            end
        end
    end

    -- 3. Draw Voxel Clouds (Optimized 2D Grid with 3D projection)
    if lighting and lighting.CloudsEnabled then
        self.cloudOffset = self.cloudOffset + love.timer.getDelta() * lighting.CloudSpeed * 2
        
        local gridRadius = 15 -- 31x31 grid
        local voxelSize = 40
        local altitude = lighting.CloudAltitude or 200
        local threshold = 1.0 - (lighting.CloudDensity or 0.5)
        
        -- Sample lighting for clouds
        local cloudBaseColor = lighting.CloudColor
        local outdoor = lighting.OutdoorAmbient
        local brightness = lighting.Brightness
        
        -- Tint clouds by outdoor ambient and time of day
        local cr = cloudBaseColor[1] * outdoor[1] * brightness
        local cg = cloudBaseColor[2] * outdoor[2] * brightness
        local cb = cloudBaseColor[3] * outdoor[3] * brightness
        
        -- Get camera integer position to keep grid stable
        -- In HookBlock, Y is UP, so X and Z are the horizontal plane
        local camPos = g3d.camera.position
        local cx = math_floor(camPos[1] / voxelSize)
        local cz = math_floor(camPos[3] / voxelSize)
        
        for ix = -gridRadius, gridRadius do
            for iz = -gridRadius, gridRadius do
                local gx = (cx + ix)
                local gz = (cz + iz)
                
                -- Simple blocky noise for cloud density
                local density = love.math.noise(gx * 0.1, gz * 0.1, self.cloudOffset * 0.05)
                
                if density > threshold then
                    -- Project the 4 corners of the cloud voxel
                    local worldX = gx * voxelSize
                    local worldZ = gz * voxelSize
                    
                    -- Center relative to camera
                    local rx = worldX - camPos[1]
                    local ry = altitude - camPos[2] -- Y is UP
                    local rz = worldZ - camPos[3]
                    
                    -- Only project center first to cull
                    local sx = projectPoint(rx, ry, rz, w, h)
                    
                    if sx then
                        -- Simple alpha based on density
                        local alpha = math_max(0, math_min(1, (density - threshold) * 10))
                        lg.setColor(cr, cg, cb, alpha * 0.8)
                        
                        -- For performance, we'll draw quads in 2D using projected corners
                        -- Voxel is in X-Z plane at height ry
                        local hvs = voxelSize / 2
                        local s1x, s1y = projectPoint(rx - hvs, ry, rz - hvs, w, h)
                        local s2x, s2y = projectPoint(rx + hvs, ry, rz - hvs, w, h)
                        local s3x, s3y = projectPoint(rx + hvs, ry, rz + hvs, w, h)
                        local s4x, s4y = projectPoint(rx - hvs, ry, rz + hvs, w, h)
                        
                        if s1x and s2x and s3x and s4x then
                            lg.polygon("fill", s1x, s1y, s2x, s2y, s3x, s3y, s4x, s4y)
                        end
                    end
                end
            end
        end
    end
    
    -- 4. Draw Sun
    local sx, sy = projectPoint(sun3D.x, sun3D.y, sun3D.z, w, h)
    if sx then
        lg.setColor(1, 1, 0.9, 1)
        lg.circle("fill", sx, sy, 45)
        lg.setColor(1, 1, 0.5, 0.25)
        lg.circle("fill", sx, sy, 90)
    end
    
    -- 5. Draw Moon
    local mx, my = projectPoint(moon3D.x, moon3D.y, moon3D.z, w, h)
    if mx then
        lg.setColor(0.9, 0.9, 1, 1)
        lg.circle("fill", mx, my, 35)
        lg.setColor(1, 1, 1, 0.15)
        lg.circle("fill", mx, my, 55)
    end

    lg.pop()
end

return Sky
