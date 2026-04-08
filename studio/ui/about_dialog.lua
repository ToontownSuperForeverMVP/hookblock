-- studio/ui/about_dialog.lua
-- Visual "About" dialog for Luvöxel Studio

local Theme = require("studio.theme")

local AboutDialog = {}

AboutDialog.visible = false
AboutDialog.width = 440
AboutDialog.height = 360

function AboutDialog.open()
    AboutDialog.visible = true
end

function AboutDialog.close()
    AboutDialog.visible = false
end

function AboutDialog.draw()
    if not AboutDialog.visible then return end

    local lg = love.graphics
    local sw, sh = lg.getDimensions()

    -- Dim background
    Theme.setColor({0, 0, 0, 0.5})
    lg.rectangle("fill", 0, 0, sw, sh)

    -- Dialog box
    local dx = math.floor((sw - AboutDialog.width) / 2)
    local dy = math.floor((sh - AboutDialog.height) / 2)
    local dw = AboutDialog.width
    local dh = AboutDialog.height

    -- Shadow
    Theme.setColor({0, 0, 0, 0.4})
    lg.rectangle("fill", dx + 4, dy + 4, dw, dh, 6)

    -- Panel
    Theme.drawRect(dx, dy, dw, dh, Theme.colors.bg_dark, 6)
    Theme.drawBorder(dx, dy, dw, dh, Theme.colors.border_focus, 2)

    -- Title Bar
    local th = 28
    Theme.drawRect(dx, dy, dw, th, Theme.colors.bg_header, 6)
    -- Mask bottom rounded corners of title bar
    lg.rectangle("fill", dx, dy + th/2, dw, th/2)
    Theme.drawText("About Luvöxel", dx + 12, dy + 6, Theme.colors.text_primary, Theme.fonts.bold)

    -- Close button (top right)
    local closeX = dx + dw - 24
    local closeY = dy + 4
    local closeHov = Theme.inRect(love.mouse.getX(), love.mouse.getY(), closeX, closeY, 20, 20)
    if closeHov then
        Theme.drawRect(closeX, closeY, 20, 20, Theme.colors.btn_stop, 4)
    end
    lg.setFont(Theme.fonts.small)
    lg.setColor(1, 1, 1, 1)
    lg.printf("✕", closeX, closeY + 3, 20, "center")

    -- Text Info
    lg.setFont(Theme.fonts.normal)
    local function centeredText(text, y, color)
        Theme.setColor(color or Theme.colors.text_primary)
        lg.printf(text, dx, y, dw, "center")
    end

    -- Content
    local cy = dy + th + 20

    -- Logo
    if Theme.assets.logo_full then
        local img = Theme.assets.logo_full
        local maxW = dw - 80 -- Leave padding on sides
        local maxH = 100 -- Max height to leave room for text
        local scale = math.min(maxW / img:getWidth(), maxH / img:getHeight(), 1.0)
        local iw = img:getWidth() * scale
        local ih = img:getHeight() * scale
        lg.setColor(1, 1, 1, 1)
        lg.draw(img, dx + (dw - iw)/2, cy, 0, scale, scale)
        cy = cy + ih + 15
    else
        lg.setFont(Theme.fonts.header)
        centeredText("Luvöxel Studio", cy)
        cy = cy + 30
    end

    lg.setFont(Theme.fonts.normal)
    centeredText("v0.0.1-dev", cy)
    cy = cy + 25

    centeredText("Created by ToontownSuper", cy, Theme.colors.text_accent)
    cy = cy + 35

    lg.setFont(Theme.fonts.small)
    centeredText("Powered by Open Source Technology", cy, Theme.colors.text_secondary)
    cy = cy + 20

    centeredText("LÖVE 11.5 (Love2D) — The Framework", cy)
    cy = cy + 18
    centeredText("G3D Engine by groverbuger — 3D Graphics", cy)
    cy = cy + 18
    centeredText("License: GPL v3.0", cy)

    cy = cy + 35
    lg.setFont(Theme.fonts.tiny)
    centeredText("Special thanks to the LÖVE community.", cy, Theme.colors.text_disabled)
end

function AboutDialog.mousepressed(x, y, button)
    if not AboutDialog.visible then return false end

    local lg = love.graphics
    local sw, sh = lg.getDimensions()
    local dx = math.floor((sw - AboutDialog.width) / 2)
    local dy = math.floor((sh - AboutDialog.height) / 2)
    local dw = AboutDialog.width
    local dh = AboutDialog.height

    -- Close button
    local closeX = dx + dw - 24
    local closeY = dy + 4
    if Theme.inRect(x, y, closeX, closeY, 20, 20) then
        AboutDialog.close()
        return true
    end

    -- Clicks outside dialog close it
    if not Theme.inRect(x, y, dx, dy, dw, dh) then
        AboutDialog.close()
        return true
    end

    return true -- Consume clicks
end

return AboutDialog
