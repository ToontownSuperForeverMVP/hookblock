-- engine/lighting.lua
-- The Lighting service for HookBlock, implementing voxel-based lighting

local Instance = require("engine.instance")
local Vector3 = require("engine.vector3")
local Color3 = require("engine.color3")

local Lighting = setmetatable({}, {__index = Instance})
Lighting.ClassName = "Lighting"
Lighting.__index = Lighting
Lighting.__newindex = Instance.__newindex

function Lighting.new()
    local self = setmetatable({}, Lighting)
    self:init("Lighting", "Lighting")
    
    -- Properties matching Roblox 2008 style
    self.Ambient = Color3.new(0.5, 0.5, 0.5)
    self.Brightness = 1.0
    self.ColorShift_Bottom = Color3.new(0, 0, 0)
    self.ColorShift_Top = Color3.new(0, 0, 0)
    self.GlobalShadows = true
    self.OutdoorAmbient = Color3.new(0.5, 0.5, 0.5)
    self.ShadowColor = Color3.new(0.3, 0.3, 0.3)
    self.ClockTime = 14 -- 2 PM
    self.TimeOfDay = "14:00:00"
    self.LightingShift = true -- NEW: Toggle for auto-adjusting ambient/brightness
    
    -- Clouds
    self.CloudsEnabled = true
    self.CloudColor = Color3.new(1, 1, 1)
    self.CloudSpeed = 0.5
    self.CloudAltitude = 200
    self.CloudDensity = 0.5
    
    -- Auto-cycle
    self.GeographicLatitude = 23.5
    self._sunDirection = Vector3.new(0, -1, 0)
    
    -- Voxel Grid parameters
    self.VoxelSize = 4 -- studs per voxel
    self.GridSize = Vector3.new(64, 32, 64) -- Voxels (total world size: 256x128x256)
    self.GridOffset = Vector3.new(-128, -64, -128) -- World space offset
    
    -- The voxel data (stored as a flat array for performance)
    -- Indexing: (x + y*sizeX + z*sizeX*sizeY) + 1
    self.voxels = {} -- {lightValue} 0-1
    self.occupancy = {} -- {boolean}
    self.parts = {} -- Cached list of parts
    self:clearVoxels()
    
    return self
end

function Lighting:clearVoxels()
    local size = self.GridSize.x * self.GridSize.y * self.GridSize.z
    for i = 1, size do
        self.voxels[i] = 1.0 -- Default to fully lit
        self.occupancy[i] = false
    end
end

-- Convert world position to grid index
function Lighting:WorldToGrid(worldPos)
    local gx = math.floor((worldPos.x - self.GridOffset.x) / self.VoxelSize)
    local gy = math.floor((worldPos.y - self.GridOffset.y) / self.VoxelSize)
    local gz = math.floor((worldPos.z - self.GridOffset.z) / self.VoxelSize)
    return gx, gy, gz
end

function Lighting:GetVoxel(gx, gy, gz)
    if gx < 0 or gx >= self.GridSize.x or
       gy < 0 or gy >= self.GridSize.y or
       gz < 0 or gz >= self.GridSize.z then
        return 1.0 -- Outside grid is lit
    end
    local index = (gx) + (gy * self.GridSize.x) + (gz * self.GridSize.x * self.GridSize.y) + 1
    return self.voxels[index] or 1.0
end

function Lighting:SetVoxel(gx, gy, gz, value)
    if gx < 0 or gx >= self.GridSize.x or
       gy < 0 or gy >= self.GridSize.y or
       gz < 0 or gz >= self.GridSize.z then
        return
    end
    local index = (gx) + (gy * self.GridSize.x) + (gz * self.GridSize.x * self.GridSize.y) + 1
    self.voxels[index] = value
end

function Lighting:SetClockTime(time)
    self.ClockTime = time % 24
    local hours = math.floor(self.ClockTime)
    local minutes = math.floor((self.ClockTime - hours) * 60)
    local seconds = math.floor(((self.ClockTime - hours) * 60 - minutes) * 60)
    self.TimeOfDay = string.format("%02d:%02d:%02d", hours, minutes, seconds)
    self:updateSunDirection()
end

function Lighting:updateSunDirection()
    -- Map 0-24 to 0-2*PI (0 is midnight, 12 is noon)
    local angle = (self.ClockTime / 24) * 2 * math.pi + math.pi/2 -- Offset so 12 is top
    local x = math.cos(angle)
    local y = math.sin(angle)
    -- We'll use Y as up/down for simplicity in this engine's coordinate system
    -- In HookBlock, Y is usually up
    self._sunDirection = Vector3.new(x, y, 0)
end

-- Localize for performance
local math_max = math.max
local math_min = math.min

-- Simple shadow propagation (top-down for now like early Roblox)
function Lighting:Update(dt)
    -- 0. Update ClockTime
    if self.TimeScale ~= 0 then
        self.ClockTime = self.ClockTime + (dt * self.TimeScale) / 3600
    end
    self:SetClockTime(self.ClockTime)

    -- Dynamic Sky Colors (Roblox 2008-ish)
    if self.LightingShift then
        local t = self.ClockTime
        if t >= 6 and t < 18 then -- Day
            local dayFactor = math.sin((t - 6) / 12 * math.pi)
            self.OutdoorAmbient = Color3.new(0.5 + 0.2*dayFactor, 0.5 + 0.2*dayFactor, 0.5 + 0.2*dayFactor)
            self.Brightness = 1.0 + 0.2 * dayFactor
        else -- Night
            self.OutdoorAmbient = Color3.new(0.2, 0.2, 0.3)
            self.Brightness = 0.5
        end
    end

    if not self.GlobalShadows then
        self:clearVoxels()
        return
    end

    -- 1. Refresh parts list every 1s
    self._partRefreshTimer = (self._partRefreshTimer or 0) - dt
    local sceneChanged = false
    if not self._cachedParts or self._partRefreshTimer <= 0 then
        local oldPartCount = self._cachedParts and #self._cachedParts or 0
        self._cachedParts = {}
        local workspace = game:GetService("Workspace")
        for _, descendant in ipairs(workspace:GetDescendants()) do
            if descendant:IsA("Part") and descendant.Transparency < 0.5 then
                table.insert(self._cachedParts, descendant)
            end
        end
        self._partRefreshTimer = 1.0
        if #self._cachedParts ~= oldPartCount then sceneChanged = true end
    end
    
    -- Optimization: Only update shadows if scene changed or every few seconds
    -- Shadows don't need to be frame-perfect
    self._shadowUpdateTimer = (self._shadowUpdateTimer or 0) - dt
    if not sceneChanged and self._shadowUpdateTimer > 0 then
        return
    end
    self._shadowUpdateTimer = 0.5 -- Update shadows twice per second max

    -- 2. Clear occupancy and voxels efficiently
    local sizeX, sizeY, sizeZ = self.GridSize.x, self.GridSize.y, self.GridSize.z
    local totalSize = sizeX * sizeY * sizeZ
    local occupancy = self.occupancy
    local voxels = self.voxels
    
    -- Using a localized loop for speed
    for i = 1, totalSize do
        occupancy[i] = false
    end
    
    -- 3. Mark voxels as occupied
    local offX, offY, offZ = self.GridOffset.x, self.GridOffset.y, self.GridOffset.z
    local vSize = self.VoxelSize
    
    for i = 1, #self._cachedParts do
        local part = self._cachedParts[i]
        local pos = part.Position
        local size = part.Size
        local hx, hy, hz = size.x * 0.5, size.y * 0.5, size.z * 0.5
        
        local minX = math_max(0, math.floor((pos.x - hx - offX) / vSize))
        local minY = math_max(0, math.floor((pos.y - hy - offY) / vSize))
        local minZ = math_max(0, math.floor((pos.z - hz - offZ) / vSize))
        local maxX = math_min(sizeX - 1, math.floor((pos.x + hx - offX) / vSize))
        local maxY = math_min(sizeY - 1, math.floor((pos.y + hy - offY) / vSize))
        local maxZ = math_min(sizeZ - 1, math.floor((pos.z + hz - offZ) / vSize))
        
        for x = minX, maxX do
            local xStep = x
            for z = minZ, maxZ do
                local zStep = z * sizeX * sizeY
                for y = minY, maxY do
                    occupancy[xStep + (y * sizeX) + zStep + 1] = true
                end
            end
        end
    end
    
    -- 4. Top-down light propagation
    for x = 0, sizeX - 1 do
        local xStep = x
        for z = 0, sizeZ - 1 do
            local zStep = z * sizeX * sizeY
            local light = 1.0
            for y = sizeY - 1, 0, -1 do
                local index = xStep + (y * sizeX) + zStep + 1
                if occupancy[index] then
                    light = 0.2 -- Shadow
                end
                voxels[index] = light
                
                -- Decay/Fade
                if not occupancy[index] and light < 1.0 then
                   light = math_min(1.0, light + 0.1)
                end
            end
        end
    end
end

-- Get light value at a world position
function Lighting:GetLightAt(worldPos)
    local gx, gy, gz = self:WorldToGrid(worldPos)
    return self:GetVoxel(gx, gy, gz)
end

-- Register class
Instance.register("Lighting", Lighting)

return Lighting
