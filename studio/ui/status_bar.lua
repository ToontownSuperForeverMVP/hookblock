-- studio/ui/status_bar.lua
-- Bottom-most bar showing editor state and performance metrics

local Theme = require("studio.theme")
local g3d   = require("g3d")

local StatusBar = {}

function StatusBar.load() end
function StatusBar.update(dt) end

function StatusBar.draw(x, y, w, h)
    local lg = love.graphics

    -- Background
    Theme.drawRect(x, y, w, h, Theme.colors.bg_menubar)
    Theme.drawDivider(x, y, w, 1, false)

    local font = Theme.fonts.small
    lg.setFont(font)

    -- 1. Selection Info (Left)
    local sel = _G._UI and _G._UI.selectedInstance
    local selText = sel and (sel.Name .. " (" .. sel.ClassName .. ")") or "No selection"
    Theme.drawText(selText, x + 8, y + 4, Theme.colors.text_secondary, font)

    -- 2. Performance Mode (Left-Center)
    local cfg = Engine.Config or {}
    local modeText = cfg.farClip and (cfg.farClip > 500 and "Mode: High Perf" or "Mode: Standard") or ""
    Theme.drawText(modeText, x + 300, y + 4, Theme.colors.text_accent, font)

    -- 3. Camera Info (Center)
    local camPos = g3d.camera.position
    local camText = string.format("Pos: %.1f, %.1f, %.1f", camPos[1], camPos[2], camPos[3])
    local camW = font:getWidth(camText)
    Theme.drawText(camText, x + math.floor(w / 2 - camW / 2), y + 4, Theme.colors.text_secondary, font)

    -- 4. Perf Metrics (Right)
    local fps = love.timer.getFPS()
    local dt = love.timer.getDelta() * 1000
    local mem = collectgarbage("count") / 1024 -- in MB
    local perfText = string.format("%.1f ms | %d FPS | %.1f MB", dt, fps, mem)
    local perfW = font:getWidth(perfText)
    Theme.drawText(perfText, x + w - perfW - 8, y + 4, Theme.colors.text_secondary, font)
end

function StatusBar.mousepressed(x, y, button, panelX, panelY, panelW, panelH)
    return Theme.inRect(x, y, panelX, panelY, panelW, panelH)
end

return StatusBar
