local g3d = require("g3d")

local Camera = {}
Camera.__index = Camera

function Camera.new()
    local self = setmetatable({}, Camera)

    -- Using g3d's built-in camera configuration
    g3d.camera.position = {0, 5, -10}
    g3d.camera.target = {0, 0, 0}
    g3d.camera.up = {0, 1, 0}

    -- Variables for freecam studio movement
    self.speed = 10
    self.minSpeed = 1
    self.maxSpeed = 100
    self.sensitivity = 0.005
    self.pitch = 0
    self.yaw = math.pi / 2

    self:updateTarget()

    return self
end

function Camera:updateTarget()
    local forwardX = math.cos(self.yaw) * math.cos(self.pitch)
    local forwardY = math.sin(self.pitch)
    local forwardZ = math.sin(self.yaw) * math.cos(self.pitch)

    g3d.camera.target[1] = g3d.camera.position[1] + forwardX
    g3d.camera.target[2] = g3d.camera.position[2] + forwardY
    g3d.camera.target[3] = g3d.camera.position[3] + forwardZ
    
    g3d.camera.updateViewMatrix()
end

function Camera:update(dt)
    -- Simple flycam controls for studio
    if love.mouse.isDown(2) then
        local dx, dy, dz = 0, 0, 0
        if love.keyboard.isDown("w") then dz = 1 end
        if love.keyboard.isDown("s") then dz = -1 end
        if love.keyboard.isDown("a") then dx = -1 end
        if love.keyboard.isDown("d") then dx = 1 end
        if love.keyboard.isDown("q") then dy = -1 end
        if love.keyboard.isDown("e") then dy = 1 end

        if dx ~= 0 or dy ~= 0 or dz ~= 0 then
            local speed = self.speed * dt
            if love.keyboard.isDown("lshift") then speed = speed * 4 end

            local forwardX = math.cos(self.yaw) * math.cos(self.pitch)
            local forwardY = math.sin(self.pitch)
            local forwardZ = math.sin(self.yaw) * math.cos(self.pitch)

            local rightX = math.cos(self.yaw + math.pi/2)
            local rightZ = math.sin(self.yaw + math.pi/2)

            g3d.camera.position[1] = g3d.camera.position[1] + forwardX * dz * speed + rightX * dx * speed
            g3d.camera.position[2] = g3d.camera.position[2] + forwardY * dz * speed + dy * speed
            g3d.camera.position[3] = g3d.camera.position[3] + forwardZ * dz * speed + rightZ * dx * speed

            self:updateTarget()
        end
    end
end

function Camera:wheelmoved(_, y)
    if love.mouse.isDown(2) then
        -- Zoom speed adjustment
        local delta = y * 0.1
        self.speed = math.max(self.minSpeed, math.min(self.maxSpeed, self.speed * (1 + delta)))
    else
        -- Zoom forward/backward
        local dist = y * (self.speed * 0.1)
        local forwardX = math.cos(self.yaw) * math.cos(self.pitch)
        local forwardY = math.sin(self.pitch)
        local forwardZ = math.sin(self.yaw) * math.cos(self.pitch)

        g3d.camera.position[1] = g3d.camera.position[1] + forwardX * dist
        g3d.camera.position[2] = g3d.camera.position[2] + forwardY * dist
        g3d.camera.position[3] = g3d.camera.position[3] + forwardZ * dist

        self:updateTarget()
    end
end

function Camera:mousemoved(_, _, dx, dy)
    if love.mouse.isDown(2) then
        self.pitch = self.pitch - dy * self.sensitivity
        self.yaw = self.yaw + dx * self.sensitivity

        -- clamp pitch to prevent flipping
        self.pitch = math.max(-math.pi/2 + 0.01, math.min(math.pi/2 - 0.01, self.pitch))

        self:updateTarget()
    end
end

function Camera:getFrontPosition(dist)
    dist = dist or 10
    local fx = math.cos(self.pitch) * math.cos(self.yaw)
    local fy = math.sin(self.pitch)
    local fz = math.cos(self.pitch) * math.sin(self.yaw)
    
    local pos = g3d.camera.position
    local Vector3 = require("engine.vector3")
    return Vector3.new(pos[1] + fx * dist, pos[2] + fy * dist, pos[3] + fz * dist)
end

return Camera
