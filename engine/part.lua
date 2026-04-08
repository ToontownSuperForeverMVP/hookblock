-- engine/part.lua
-- The fundamental building block — a 3D box (like Roblox's Part)
local Instance = require("engine.instance")
local Vector3 = require("engine.vector3")
local Color3 = require("engine.color3")
local g3d = require("g3d")
local ModelCache = require("engine.model_cache")

local Part = setmetatable({}, {__index = Instance})
Part.ClassName = "Part"
Part.__index = Part
Part.__newindex = Instance.__newindex

-- Localize for performance
local math_rad = math.rad
local math_min = math.min
local lg = love.graphics

-- Shape types
Part.SHAPES = {
    Block = "cube.obj",
    Sphere = "assets/models/sphere.obj",
    Cylinder = "assets/models/cylinder.obj",
    Wedge = "assets/models/wedge.obj",
}

-- Material types (visual only for now)
Part.MATERIALS = {
    "Plastic", "Wood", "Metal", "Glass", "Neon",
    "Brick", "Concrete", "Sand", "Grass", "Ice",
}

function Part.new(name)
    local self = setmetatable({}, Part)
    self:init("Part", name or "Part")
    
    -- Transform
    self.Position = Vector3.new(0, 0, 0)
    self.Size = Vector3.new(1, 1, 1)
    self.Rotation = Vector3.new(0, 0, 0)

    -- Appearance
    self.Color = Color3.new(1, 1, 1)
    self.Transparency = 0
    self.Material = "Plastic"
    self.Texture = nil
    self.TexturePath = nil
    self.Shape = "Block"

    -- Physics
    self.Anchored = true
    self.CanCollide = true
    self.Velocity = Vector3.new(0, 0, 0)

    -- G3D Model Setup (Shared)
    self:updateModel()

    return self
end

function Part:updateModel()
    local modelFile = Part.SHAPES[self.Shape] or "cube.obj"
    self.model = ModelCache.get(modelFile)
end

function Part:setShape(shapeName)
    if Part.SHAPES[shapeName] then
        self.Shape = shapeName
        self:updateModel()
    end
end

function Part:setTexture(path)
    if not path then
        self.Texture = nil
        self.TexturePath = nil
        return
    end

    local ok, img = pcall(love.graphics.newImage, path)
    if ok then
        self.Texture = img
        self.TexturePath = path
    else
        print("[Part] Error loading texture: " .. tostring(img))
    end
end

function Part:render()
    if self.model and self.Transparency < 1 then
        local cam = g3d.camera
        local pos = self.Position
        local cpos = cam.position
        local dx = pos.x - cpos[1]
        local dy = pos.y - cpos[2]
        local dz = pos.z - cpos[3]
        local distSq = dx*dx + dy*dy + dz*dz

        -- 1. Distance Culling
        if distSq < (cam.farClip * cam.farClip) then
            -- 2. Basic Front-of-Camera Culling (Dot Product)
            local tx, ty, tz = cam.target[1], cam.target[2], cam.target[3]
            local fx, fy, fz = tx - cpos[1], ty - cpos[2], tz - cpos[3]
            
            -- Normalize forward vector for consistent dot product (projection distance along look vector)
            local flen = math.sqrt(fx*fx + fy*fy + fz*fz)
            if flen > 0 then
                fx, fy, fz = fx/flen, fy/flen, fz/flen
            end
            
            local dot = dx*fx + dy*fy + dz*fz
            
            -- Cull margin based on size to prevent large parts (baseplate) disappearing
            local size = self.Size
            local maxDim = math.max(size.x, size.y, size.z)
            -- Use a buffer based on the part's maximum dimension to ensure it's not culled while still partially visible
            -- 0.866 is approx half the diagonal of a cube (sqrt(3)/2)
            local cullMargin = -(maxDim * 0.9 + 5)
            
            -- Only render if in front of camera (with a buffer for large parts)
            if dot > cullMargin then 
                -- Set transformation on the SHARED model
                local rot = self.Rotation
                self.model:setTranslation(pos.x, pos.y, pos.z)
                self.model:setRotation(
                    math_rad(rot.x),
                    math_rad(rot.y),
                    math_rad(rot.z)
                )
                -- Scale by 0.5 because our .obj models (cube/sphere/etc) are 2 units wide (-1 to 1)
                self.model:setScale(size.x * 0.5, size.y * 0.5, size.z * 0.5)

                -- Set Texture if present
                if self.Texture then
                    self.model.texture = self.Texture
                    self.model.mesh:setTexture(self.Texture)
                else
                    self.model.texture = nil
                    self.model.mesh:setTexture()
                end

                local color = self.Color
                local alpha = (color.a or 1) * (1 - self.Transparency)

                -- 3. Optimized Voxel Lighting (with caching)
                local lighting = Engine.Lighting
                local lightValue = self._cachedLightValue or 1.0
                
                -- Only update light if moved or every few frames
                if lighting then
                    self._lightTimer = (self._lightTimer or 0) + 1
                    if not self._lastLightPos or (pos.x ~= self._lastLightPos.x or pos.y ~= self._lastLightPos.y or pos.z ~= self._lastLightPos.z) or self._lightTimer % 10 == 0 then
                        lightValue = lighting:GetLightAt(pos)
                        self._cachedLightValue = lightValue
                        self._lastLightPos = {x = pos.x, y = pos.y, z = pos.z}
                    end
                    
                    local shadow = lighting.ShadowColor
                    local outdoor = lighting.OutdoorAmbient
                    local brightness = lighting.Brightness
                    
                    local r = math_min(1, color.r * (shadow.r + (outdoor.r - shadow.r) * lightValue) * brightness)
                    local g = math_min(1, color.g * (shadow.g + (outdoor.g - shadow.g) * lightValue) * brightness)
                    local b = math_min(1, color.b * (shadow.b + (outdoor.b - shadow.b) * lightValue) * brightness)
                    
                    if self.Material == "Neon" then
                        lg.setColor(math_min(1, color.r * 1.3), math_min(1, color.g * 1.3), math_min(1, color.b * 1.3), alpha)
                    else
                        lg.setColor(r, g, b, alpha)
                    end
                else
                    if self.Material == "Neon" then
                        lg.setColor(math_min(1, color.r * 1.3), math_min(1, color.g * 1.3), math_min(1, color.b * 1.3), alpha)
                    else
                        lg.setColor(color.r, color.g, color.b, alpha)
                    end
                end

                -- Only write to depth buffer if fully opaque (alpha >= 1)
                -- This fixes "transparency sorting" issues where front transparent parts cull back opaque parts
                if alpha < 1 then
                    lg.setDepthMode("lequal", false)
                end
                
                self.model:draw()
                
                if alpha < 1 then
                    lg.setDepthMode("lequal", true)
                end
            end
        end
    end

    Instance.render(self)
end

-- Get world-space bounding box corners
function Part:GetBoundingBox()
    local pos = self.Position
    local size = self.Size
    local hx = size.x / 2
    local hy = size.y / 2
    local hz = size.z / 2
    return {
        min = {
            x = pos.x - hx,
            y = pos.y - hy,
            z = pos.z - hz,
        },
        max = {
            x = pos.x + hx,
            y = pos.y + hy,
            z = pos.z + hz,
        }
    }
end

-- Register class
Instance.register("Part", Part)

return Part
