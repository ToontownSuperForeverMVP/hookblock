-- studio/ui/animation_editor.lua
-- Boilerplate for an Animation Editor / Timeline panel

local Theme = require("studio.theme")

local AnimationEditor = {}

function AnimationEditor.load()
end

function AnimationEditor.update(dt)
end

function AnimationEditor.draw(x, y, w, h)
    Theme.drawRect(x, y, w, h, Theme.colors.bg_medium)

    -- Timeline Placeholder
    local timelineY = y + 10
    Theme.drawRect(x + 10, timelineY, w - 20, 30, Theme.colors.bg_dark, 4)
    Theme.drawBorder(x + 10, timelineY, w - 20, 30, Theme.colors.border, 1)

    Theme.drawText("Select a model to begin animating.", x + 20, timelineY + 8, Theme.colors.text_secondary, Theme.fonts.normal)
end

function AnimationEditor.mousepressed(x, y, button, rx, ry, rw, rh)
    if Theme.inRect(x, y, rx, ry, rw, rh) then
        return true
    end
    return false
end

function AnimationEditor.wheelmoved(x, y, rx, ry, rw, rh)
    local mx, my = love.mouse.getPosition()
    if Theme.inRect(mx, my, rx, ry, rw, rh) then
        return true
    end
    return false
end

return AnimationEditor
