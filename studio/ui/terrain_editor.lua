-- studio/ui/terrain_editor.lua
-- Boilerplate for Terrain Editor tools

local Theme = require("studio.theme")

local TerrainEditor = {}

function TerrainEditor.load()
end

function TerrainEditor.update(dt)
end

function TerrainEditor.draw(x, y, w, h)
    Theme.drawRect(x, y, w, h, Theme.colors.bg_medium)

    -- Tools Placeholder
    Theme.drawButton("Generate", x + 8, y + 12, 100, 24, "normal")
    Theme.drawButton("Sculpt", x + 8, y + 42, 100, 24, "normal")
    Theme.drawButton("Paint", x + 8, y + 72, 100, 24, "normal")

    Theme.drawText("Terrain system not yet initialized.", x + 8, y + 106, Theme.colors.text_disabled, Theme.fonts.small)
end

function TerrainEditor.mousepressed(x, y, button, rx, ry, rw, rh)
    if Theme.inRect(x, y, rx, ry, rw, rh) then
        return true
    end
    return false
end

function TerrainEditor.wheelmoved(x, y, rx, ry, rw, rh)
    local mx, my = love.mouse.getPosition()
    if Theme.inRect(mx, my, rx, ry, rw, rh) then
        return true
    end
    return false
end

return TerrainEditor
