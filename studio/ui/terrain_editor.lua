-- studio/ui/terrain_editor.lua
local Theme = require("studio.theme")

local TerrainEditor = {}

TerrainEditor.params = {
    seed = 12345,
    sizeX = 64,
    sizeY = 32,
    sizeZ = 64,
    scale = 0.05,
    amplitude = 15,
    waterLevel = 5,
}

local activeSlider = nil
local activeInput = nil
local inputText = ""
local scrollY = 0

function TerrainEditor.load()
end

function TerrainEditor.update(dt)
    local mx, my = love.mouse.getPosition()
    if activeSlider then
        if not love.mouse.isDown(1) then
            activeSlider = nil
        else
            local param = activeSlider.param
            local min = activeSlider.min
            local max = activeSlider.max
            
            -- x is activeSlider.x, w is activeSlider.w
            local relX = mx - activeSlider.x
            local pct = math.max(0, math.min(1, relX / activeSlider.w))
            
            local val = min + pct * (max - min)
            if activeSlider.isInt then
                val = math.floor(val + 0.5)
            end
            TerrainEditor.params[param] = val
        end
    end
end

local function drawSlider(label, param, x, y, w, min, max, isInt)
    local h = 20
    Theme.drawText(label, x, y, Theme.colors.text_primary, Theme.fonts.small)
    
    local sliderX = x + 80
    local sliderW = w - 80 - 40
    
    -- Track
    Theme.drawRect(sliderX, y + 8, sliderW, 4, Theme.colors.bg_medium, 2)
    
    local val = TerrainEditor.params[param]
    local pct = (val - min) / (max - min)
    pct = math.max(0, math.min(1, pct))
    
    -- Fill
    Theme.drawRect(sliderX, y + 8, sliderW * pct, 4, Theme.colors.text_accent, 2)
    
    -- Handle
    Theme.drawRect(sliderX + sliderW * pct - 4, y + 2, 8, 16, Theme.colors.text_primary, 2)
    
    -- Value text
    local valStr = isInt and tostring(math.floor(val)) or string.format("%.3f", val)
    Theme.drawText(valStr, sliderX + sliderW + 5, y, Theme.colors.text_secondary, Theme.fonts.small)
    
    return x, y, w, h, sliderX, sliderW
end

function TerrainEditor.draw(x, y, w, h)
    Theme.drawRect(x, y, w, h, Theme.colors.bg_medium)
    
    love.graphics.setScissor(x, y, w, h)
    
    local cy = y + 10 - scrollY
    
    Theme.drawText("Terrain Generation", x + 10, cy, Theme.colors.text_primary, Theme.fonts.bold)
    cy = cy + 25
    
    TerrainEditor.sliderHitboxes = {}
    
    local function addSlider(label, param, min, max, isInt)
        local sx, sy, sw, sh, sTrackX, sTrackW = drawSlider(label, param, x + 10, cy, w - 20, min, max, isInt)
        table.insert(TerrainEditor.sliderHitboxes, {
            param = param, x = sTrackX, y = sy, w = sTrackW, h = sh, min = min, max = max, isInt = isInt
        })
        cy = cy + 30
    end
    
    addSlider("Seed", "seed", 0, 100000, true)
    addSlider("Size X", "sizeX", 16, 256, true)
    addSlider("Size Y", "sizeY", 16, 128, true)
    addSlider("Size Z", "sizeZ", 16, 256, true)
    addSlider("Scale", "scale", 0.01, 0.2, false)
    addSlider("Amplitude", "amplitude", 5, 50, false)
    addSlider("Water Lvl", "waterLevel", 0, 30, true)
    
    cy = cy + 10
    
    TerrainEditor.btnGenerateHitbox = {x = x + 10, y = cy, w = w/2 - 15, h = 24}
    TerrainEditor.btnClearHitbox = {x = x + w/2 + 5, y = cy, w = w/2 - 15, h = 24}
    
    local mx, my = love.mouse.getPosition()
    
    local btnStateGen = Theme.inRect(mx, my, TerrainEditor.btnGenerateHitbox.x, TerrainEditor.btnGenerateHitbox.y, TerrainEditor.btnGenerateHitbox.w, TerrainEditor.btnGenerateHitbox.h) and (love.mouse.isDown(1) and "active" or "hover") or "normal"
    Theme.drawButton("Generate", TerrainEditor.btnGenerateHitbox.x, TerrainEditor.btnGenerateHitbox.y, TerrainEditor.btnGenerateHitbox.w, TerrainEditor.btnGenerateHitbox.h, btnStateGen)
    
    local btnStateClr = Theme.inRect(mx, my, TerrainEditor.btnClearHitbox.x, TerrainEditor.btnClearHitbox.y, TerrainEditor.btnClearHitbox.w, TerrainEditor.btnClearHitbox.h) and (love.mouse.isDown(1) and "active" or "hover") or "normal"
    Theme.drawButton("Clear", TerrainEditor.btnClearHitbox.x, TerrainEditor.btnClearHitbox.y, TerrainEditor.btnClearHitbox.w, TerrainEditor.btnClearHitbox.h, btnStateClr)
    
    cy = cy + 40
    
    -- Status
    local status = "Ready"
    if Engine and Engine.Workspace and Engine.Workspace.Terrain then
        local t = Engine.Workspace.Terrain
        local count = 0
        for _ in pairs(t.voxels) do count = count + 1 end
        status = string.format("Active Voxels: %d", count)
    else
        status = "Terrain system missing."
    end
    
    Theme.drawText(status, x + 10, cy, Theme.colors.text_secondary, Theme.fonts.small)
    
    love.graphics.setScissor()
end

function TerrainEditor.mousepressed(x, y, button, rx, ry, rw, rh)
    if not Theme.inRect(x, y, rx, ry, rw, rh) then return false end
    
    if TerrainEditor.sliderHitboxes then
        for _, box in ipairs(TerrainEditor.sliderHitboxes) do
            if Theme.inRect(x, y, box.x - 10, box.y, box.w + 20, box.h) then
                activeSlider = box
                return true
            end
        end
    end
    
    if TerrainEditor.btnGenerateHitbox and Theme.inRect(x, y, TerrainEditor.btnGenerateHitbox.x, TerrainEditor.btnGenerateHitbox.y, TerrainEditor.btnGenerateHitbox.w, TerrainEditor.btnGenerateHitbox.h) then
        if Engine and Engine.Workspace and Engine.Workspace.Terrain then
            local t = Engine.Workspace.Terrain
            local p = TerrainEditor.params
            t:generate(p.seed, p.sizeX, p.sizeY, p.sizeZ, p.scale, p.amplitude, p.waterLevel)
            if _G._Notifications then
                _G._Notifications.new("Terrain generated!", "info")
            end
        end
        return true
    end
    
    if TerrainEditor.btnClearHitbox and Theme.inRect(x, y, TerrainEditor.btnClearHitbox.x, TerrainEditor.btnClearHitbox.y, TerrainEditor.btnClearHitbox.w, TerrainEditor.btnClearHitbox.h) then
        if Engine and Engine.Workspace and Engine.Workspace.Terrain then
            Engine.Workspace.Terrain:clear()
            if _G._Notifications then
                _G._Notifications.new("Terrain cleared.", "info")
            end
        end
        return true
    end
    
    return true
end

function TerrainEditor.wheelmoved(x, y, rx, ry, rw, rh)
    local mx, my = love.mouse.getPosition()
    if Theme.inRect(mx, my, rx, ry, rw, rh) then
        scrollY = scrollY - y * 20
        scrollY = math.max(0, scrollY)
        return true
    end
    return false
end

return TerrainEditor
