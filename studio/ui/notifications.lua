-- studio/ui/notifications.lua
-- Transient toast notifications for user feedback

local Theme = require("studio.theme")

local Notifications = {}

local toasts = {}
local nextId = 1

function Notifications.show(text, level, duration)
    table.insert(toasts, {
        id = nextId,
        text = text,
        level = level or "info",
        startTime = os.clock(),
        duration = duration or 3,
        opacity = 0,
    })
    nextId = nextId + 1
end

function Notifications.update(dt)
    local now = os.clock()
    for i = #toasts, 1, -1 do
        local t = toasts[i]
        local elapsed = now - t.startTime

        -- Fade in/out
        if elapsed < 0.3 then
            t.opacity = elapsed / 0.3
        elseif elapsed > t.duration - 0.5 then
            t.opacity = math.max(0, (t.duration - elapsed) / 0.5)
        else
            t.opacity = 1
        end

        if elapsed >= t.duration then
            table.remove(toasts, i)
        end
    end
end

function Notifications.draw()
    local W, H = love.graphics.getDimensions()
    local y = H - 60 -- Start from bottom above status bar

    -- Adjust if status bar is present
    if Theme.layout.statusbar_h then
        y = y - Theme.layout.statusbar_h
    end

    love.graphics.setFont(Theme.fonts.normal)

    for i = #toasts, 1, -1 do
        local t = toasts[i]
        local tw = Theme.fonts.normal:getWidth(t.text)
        local th = Theme.fonts.normal:getHeight() + 16
        local bw = tw + 32
        local bx = W / 2 - bw / 2
        local by = y - th

        local color = t.level == "error" and Theme.colors.text_error
                   or t.level == "warn"  and Theme.colors.text_warn
                   or Theme.colors.text_accent

        -- Background with opacity
        love.graphics.setColor(0.1, 0.1, 0.1, 0.9 * t.opacity)
        love.graphics.rectangle("fill", bx, by, bw, th, 5)

        -- Border
        love.graphics.setColor(color[1], color[2], color[3], t.opacity)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", bx, by, bw, th, 5)

        -- Text
        Theme.drawText(t.text, bx + 16, by + 8, {color[1], color[2], color[3], t.opacity}, Theme.fonts.normal)

        y = by - 10
    end
end

return Notifications
