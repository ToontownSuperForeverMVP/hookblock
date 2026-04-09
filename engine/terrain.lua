-- engine/terrain.lua
local Instance = require("engine.instance")
local g3d = require("g3d")

local Terrain = setmetatable({}, {__index = Instance})
Terrain.ClassName = "Terrain"
Terrain.__index = Terrain
Terrain.__newindex = Instance.__newindex

Terrain.Materials = {
    Air = 0,
    Grass = 1,
    Dirt = 2,
    Stone = 3,
    Water = 4,
    Sand = 5,
    Snow = 6,
    Wood = 7,
    Leaves = 8
}

local MaterialColors = {
    [1] = {0.2, 0.8, 0.2}, -- Grass
    [2] = {0.5, 0.3, 0.1}, -- Dirt
    [3] = {0.5, 0.5, 0.5}, -- Stone
    [4] = {0.2, 0.4, 0.9, 0.8}, -- Water
    [5] = {0.8, 0.8, 0.4}, -- Sand
    [6] = {0.9, 0.9, 0.9}, -- Snow
    [7] = {0.4, 0.2, 0.0}, -- Wood
    [8] = {0.1, 0.6, 0.1}, -- Leaves
}

function Terrain.new(name)
    local self = setmetatable({}, Terrain)
    self:init("Terrain", name or "Terrain")
    
    self.voxels = {}
    self.dirty = false
    self.model = nil
    
    self.VoxelSize = 4 -- Size of each voxel in studs
    
    return self
end

function Terrain:getVoxel(x, y, z)
    x, y, z = math.floor(x), math.floor(y), math.floor(z)
    local hash = x .. "," .. y .. "," .. z
    return self.voxels[hash] or 0
end

function Terrain:setVoxel(x, y, z, material)
    x, y, z = math.floor(x), math.floor(y), math.floor(z)
    local hash = x .. "," .. y .. "," .. z
    if material == 0 then
        if self.voxels[hash] then
            self.voxels[hash] = nil
            self.dirty = true
        end
    else
        if self.voxels[hash] ~= material then
            self.voxels[hash] = material
            self.dirty = true
        end
    end
end

-- Advanced procedural generation
function Terrain:generate(seed, sizeX, sizeY, sizeZ, scale, amplitude, waterLevel)
    self.voxels = {}
    seed = seed or love.math.random(1, 10000)
    scale = scale or 0.05
    amplitude = amplitude or 20
    waterLevel = waterLevel or 5
    
    for x = -sizeX/2, sizeX/2 do
        for z = -sizeZ/2, sizeZ/2 do
            -- 2D Noise for base height
            local nx = (x + seed) * scale
            local nz = (z + seed) * scale
            
            local e = love.math.noise(nx, nz)
            -- Add some detail
            e = e + 0.5 * love.math.noise(nx * 2.5, nz * 2.5)
            e = e + 0.25 * love.math.noise(nx * 5, nz * 5)
            e = e / (1 + 0.5 + 0.25)
            
            -- Power to flatten valleys and raise mountains
            e = math.pow(e, 1.5)
            
            local height = math.floor(e * amplitude)
            
            for y = -sizeY/2, sizeY/2 do
                if y <= height then
                    local mat = Terrain.Materials.Stone
                    if y == height then
                        if y <= waterLevel + 1 then
                            mat = Terrain.Materials.Sand
                        elseif y > amplitude * 0.7 then
                            mat = Terrain.Materials.Snow
                        else
                            mat = Terrain.Materials.Grass
                        end
                    elseif y > height - 3 then
                        if y <= waterLevel then
                            mat = Terrain.Materials.Sand
                        else
                            mat = Terrain.Materials.Dirt
                        end
                    end
                    self:setVoxel(x, y, z, mat)
                elseif y <= waterLevel then
                    self:setVoxel(x, y, z, Terrain.Materials.Water)
                end
            end
        end
    end
    self.dirty = true
end

function Terrain:clear()
    self.voxels = {}
    self.dirty = true
end

-- Face definitions for meshing
local faces = {
    -- Top (y+)
    { dir = {0, 1, 0}, corners = { {0,1,1}, {1,1,1}, {1,1,0}, {0,1,0} } },
    -- Bottom (y-)
    { dir = {0, -1, 0}, corners = { {0,0,0}, {1,0,0}, {1,0,1}, {0,0,1} } },
    -- Right (x+)
    { dir = {1, 0, 0}, corners = { {1,0,1}, {1,0,0}, {1,1,0}, {1,1,1} } },
    -- Left (x-)
    { dir = {-1, 0, 0}, corners = { {0,0,0}, {0,0,1}, {0,1,1}, {0,1,0} } },
    -- Front (z+)
    { dir = {0, 0, 1}, corners = { {0,0,1}, {1,0,1}, {1,1,1}, {0,1,1} } },
    -- Back (z-)
    { dir = {0, 0, -1}, corners = { {1,0,0}, {0,0,0}, {0,1,0}, {1,1,0} } }
}

function Terrain:updateMesh()
    if not self.dirty then return end
    self.dirty = false
    
    local verts = {}
    local s = self.VoxelSize
    
    -- Very basic meshing: iterate over all voxels, add visible faces
    for hash, mat in pairs(self.voxels) do
        if mat ~= 0 then
            local parts = {}
            for part in string.gmatch(hash, "[^,]+") do
                table.insert(parts, tonumber(part))
            end
            local x, y, z = parts[1], parts[2], parts[3]
            
            local color = MaterialColors[mat] or {1, 1, 1}
            local r, g, b, a = color[1], color[2], color[3], color[4] or 1
            
            -- For each face, check neighbor
            for _, face in ipairs(faces) do
                local nx, ny, nz = x + face.dir[1], y + face.dir[2], z + face.dir[3]
                local neighborMat = self:getVoxel(nx, ny, nz)
                
                -- Draw face if neighbor is air, or if we are opaque and neighbor is transparent (water)
                local drawFace = false
                if neighborMat == 0 then
                    drawFace = true
                elseif mat ~= Terrain.Materials.Water and neighborMat == Terrain.Materials.Water then
                    drawFace = true
                end
                
                if drawFace then
                    -- Add 2 triangles for this face
                    local c = face.corners
                    local v1 = { (x + c[1][1])*s, (y + c[1][2])*s, (z + c[1][3])*s, 0,0, face.dir[1], face.dir[2], face.dir[3], r,g,b,a }
                    local v2 = { (x + c[2][1])*s, (y + c[2][2])*s, (z + c[2][3])*s, 1,0, face.dir[1], face.dir[2], face.dir[3], r,g,b,a }
                    local v3 = { (x + c[3][1])*s, (y + c[3][2])*s, (z + c[3][3])*s, 1,1, face.dir[1], face.dir[2], face.dir[3], r,g,b,a }
                    local v4 = { (x + c[4][1])*s, (y + c[4][2])*s, (z + c[4][3])*s, 0,1, face.dir[1], face.dir[2], face.dir[3], r,g,b,a }
                    
                    table.insert(verts, v1)
                    table.insert(verts, v2)
                    table.insert(verts, v3)
                    
                    table.insert(verts, v1)
                    table.insert(verts, v3)
                    table.insert(verts, v4)
                end
            end
        end
    end
    
    if #verts > 0 then
        self.model = g3d.newModel(verts, nil, {0,0,0}, nil, nil)
    else
        self.model = nil
    end
    
    -- Also update physics collisions if needed
    -- (A simple implementation would create an invisible mesh for Physics,
    -- but for now let's just do rendering and hook raycasting)
end

function Terrain:render()
    if self.dirty then
        self:updateMesh()
    end
    if self.model then
        self.model:draw()
    end
    -- Base render for children (though Terrain usually has none)
    Instance.render(self)
end

-- Raycast against voxels
function Terrain:raycast(ox, oy, oz, dx, dy, dz, maxDist)
    -- Simple DDA raycast or step-based
    maxDist = maxDist or 1000
    local s = self.VoxelSize
    
    local step = s / 2
    local dist = 0
    
    -- Normalize direction
    local len = math.sqrt(dx*dx + dy*dy + dz*dz)
    if len == 0 then return nil end
    local ndx, ndy, ndz = dx/len, dy/len, dz/len
    
    local px, py, pz = ox, oy, oz
    while dist <= maxDist do
        local vx = math.floor(px / s)
        local vy = math.floor(py / s)
        local vz = math.floor(pz / s)
        
        local mat = self:getVoxel(vx, vy, vz)
        if mat ~= 0 and mat ~= Terrain.Materials.Water then -- Ignore water for simple physics raycasts
            -- Calculate normal (approximate based on direction)
            return {
                distance = dist,
                position = {x = px, y = py, z = pz},
                normal = {x = 0, y = 1, z = 0}, -- Simplified normal
                part = self,
                material = mat,
                voxel = {x = vx, y = vy, z = vz}
            }
        end
        
        px = px + ndx * step
        py = py + ndy * step
        pz = pz + ndz * step
        dist = dist + step
    end
    return nil
end

Instance.register("Terrain", Terrain)

return Terrain
