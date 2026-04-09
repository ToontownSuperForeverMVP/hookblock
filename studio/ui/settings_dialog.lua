-- studio/ui/settings_dialog.lua
-- Settings dialog for Luvöxel Studio

local Theme = require("studio.theme")

local SettingsDialog = {}

SettingsDialog.visible = false
SettingsDialog.width = 400
SettingsDialog.height = 300

SettingsDialog.settings = {
    showGrid = true,
    showFPS = true,
    cameraSpeed = 50,
}

_G._StudioSettings = SettingsDialog.settings

function SettingsDialog.open()
    SettingsDialog.visible = true
end

function SettingsDialog.close()
    SettingsDialog.visible = false
end

function SettingsDialog.update(dt)
    if not SettingsDialog.visible then return end
    
    if SettingsDialog.draggingSlider and love.mouse.isDown(1) then
        local lg = love.graphics
        local sw, sh = lg.getDimensions()
        local dx = math.floor((sw - SettingsDialog.width) / 2)
        local cx = dx + 20
        local sliderW = 150
        local sliderX = cx + 120
        
        local mx = love.mouse.getX()
        local progress = math.max(0, math.min(1, (mx - sliderX) / sliderW))
        
        if Engine and Engine.Camera then
            local cam = Engine.Camera
            cam.speed = cam.minSpeed + (cam.maxSpeed - cam.minSpeed) * progress
            SettingsDialog.settings.cameraSpeed = cam.speed
        else
            -- fallback
            SettingsDialog.settings.cameraSpeed = progress * 100
        end
    elseif not love.mouse.isDown(1) then
        SettingsDialog.draggingSlider = false
    end
end

function SettingsDialog.draw()
    if not SettingsDialog.visible then return end

    local lg = love.graphics
    local sw, sh = lg.getDimensions()
    local dx = math.floor((sw - SettingsDialog.width) / 2)
    local dy = math.floor((sh - SettingsDialog.height) / 2)
    local dw = SettingsDialog.width
    local dh = SettingsDialog.height

    -- Dim background
    Theme.setColor({0, 0, 0, 0.5})
    lg.rectangle("fill", 0, 0, sw, sh)

    -- Shadow
    Theme.setColor({0, 0, 0, 0.4})
    lg.rectangle("fill", dx + 4, dy + 4, dw, dh, 6)

    -- Panel
    Theme.drawRect(dx, dy, dw, dh, Theme.colors.bg_dark, 6)
    Theme.drawBorder(dx, dy, dw, dh, Theme.colors.border_focus, 2)

    -- Title Bar
    local th = 28
    Theme.drawRect(dx, dy, dw, th, Theme.colors.bg_header, 6)
    lg.rectangle("fill", dx, dy + th/2, dw, th/2)
    Theme.drawText("Studio Settings", dx + 12, dy + 6, Theme.colors.text_primary, Theme.fonts.bold)

    -- Close button
    local closeX = dx + dw - 24
    local closeY = dy + 4
    local mx, my = love.mouse.getPosition()
    local closeHov = Theme.inRect(mx, my, closeX, closeY, 20, 20)
    if closeHov then
        Theme.drawRect(closeX, closeY, 20, 20, Theme.colors.btn_stop, 4)
    end
    lg.setFont(Theme.fonts.small)
    lg.setColor(1, 1, 1, 1)
    lg.printf("✕", closeX, closeY + 3, 20, "center")

    -- Settings Content
    local cy = dy + th + 20
    local cx = dx + 20
    
    -- Show Grid Toggle
    Theme.drawText("Show Grid", cx, cy, Theme.colors.text_primary)
    Theme.drawRect(cx + 120, cy, 40, 20, SettingsDialog.settings.showGrid and Theme.colors.btn_active or Theme.colors.bg_medium, 4)
    Theme.drawText(SettingsDialog.settings.showGrid and "ON" or "OFF", cx + 128, cy + 2, Theme.colors.text_primary, Theme.fonts.small)
    cy = cy + 30

    -- Show FPS Toggle
    Theme.drawText("Show FPS", cx, cy, Theme.colors.text_primary)
    Theme.drawRect(cx + 120, cy, 40, 20, SettingsDialog.settings.showFPS and Theme.colors.btn_active or Theme.colors.bg_medium, 4)
    Theme.drawText(SettingsDialog.settings.showFPS and "ON" or "OFF", cx + 128, cy + 2, Theme.colors.text_primary, Theme.fonts.small)
    cy = cy + 30

    -- Camera Speed Slider
    Theme.drawText("Camera Speed", cx, cy, Theme.colors.text_primary)
    local sliderW = 150
    local sliderX = cx + 120
    Theme.drawRect(sliderX, cy + 8, sliderW, 4, Theme.colors.bg_medium, 2)
    
    local cam = Engine and Engine.Camera
    local speed = cam and cam.speed or SettingsDialog.settings.cameraSpeed
    local minS = cam and cam.minSpeed or 0
    local maxS = cam and cam.maxSpeed or 100
    local progress = math.max(0, math.min(1, (speed - minS) / (maxS - minS)))
    if progress ~= progress then progress = 0.5 end -- handle NaN just in case
    
    Theme.drawRect(sliderX, cy + 8, sliderW * progress, 4, Theme.colors.text_accent, 2)
    Theme.drawRect(sliderX + sliderW * progress - 4, cy + 2, 8, 16, Theme.colors.text_primary, 4)
    Theme.drawText(string.format("%.1f", speed), sliderX + sliderW + 10, cy, Theme.colors.text_secondary, Theme.fonts.small)
    
    -- About text at the bottom
    cy = dy + dh - 30
    lg.setFont(Theme.fonts.tiny)
    Theme.setColor(Theme.colors.text_disabled)
    lg.printf("Luvöxel Studio Settings Configuration", dx, cy, dw, "center")
end

function SettingsDialog.mousepressed(x, y, button)
    if not SettingsDialog.visible then return false end

    local lg = love.graphics
    local sw, sh = lg.getDimensions()
    local dx = math.floor((sw - SettingsDialog.width) / 2)
    local dy = math.floor((sh - SettingsDialog.height) / 2)
    local dw = SettingsDialog.width
    local dh = SettingsDialog.height

    -- Close button
    if Theme.inRect(x, y, dx + dw - 24, dy + 4, 20, 20) then
        SettingsDialog.close()
        return true
    end

    local cy = dy + 28 + 20
    local cx = dx + 20

    -- Grid Toggle
    if Theme.inRect(x, y, cx + 120, cy, 40, 20) then
        SettingsDialog.settings.showGrid = not SettingsDialog.settings.showGrid
        return true
    end
    cy = cy + 30

    -- FPS Toggle
    if Theme.inRect(x, y, cx + 120, cy, 40, 20) then
        SettingsDialog.settings.showFPS = not SettingsDialog.settings.showFPS
        return true
    end
    cy = cy + 30

    -- Slider interaction
    local sliderW = 150
    local sliderX = cx + 120
    if Theme.inRect(x, y, sliderX - 10, cy, sliderW + 20, 20) then
        SettingsDialog.draggingSlider = true
        return true
    end

    -- Clicks outside dialog close it
    if not Theme.inRect(x, y, dx, dy, dw, dh) then
        SettingsDialog.close()
        return true
    end

    return true
end

return SettingsDialog