-- studio/ui/color_picker.lua
-- HSV color picker dialog

local Theme = require("studio.theme")

local ColorPicker = {}

ColorPicker.visible = false
ColorPicker.x = 100
ColorPicker.y = 100
ColorPicker.width = 240
ColorPicker.height = 280

-- HSV state
ColorPicker.hue = 0        -- 0-360
ColorPicker.saturation = 1 -- 0-1
ColorPicker.value = 1      -- 0-1

-- Callback
ColorPicker.onColorChanged = nil
ColorPicker.targetInstance = nil
ColorPicker.targetKey = nil
ColorPicker.draggingSV = false
ColorPicker.draggingH = false

-- Preset colors (Roblox-like palette)
local PRESETS = {
    {1, 1, 1},     {0.84, 0.84, 0.84}, {0.63, 0.63, 0.63}, {0.42, 0.42, 0.42}, {0.2, 0.2, 0.2},  {0, 0, 0},
    {1, 0, 0},     {1, 0.5, 0},        {1, 1, 0},           {0.5, 1, 0},        {0, 1, 0},        {0, 1, 0.5},
    {0, 1, 1},     {0, 0.5, 1},        {0, 0, 1},           {0.5, 0, 1},        {1, 0, 1},        {1, 0, 0.5},
    {1, 0.6, 0.6}, {1, 0.8, 0.6},      {1, 1, 0.6},         {0.6, 1, 0.6},      {0.6, 0.8, 1},    {0.8, 0.6, 1},
}

function ColorPicker.open(inst, x, y, key)
    ColorPicker.visible = true
    ColorPicker.targetInstance = inst
    ColorPicker.targetKey = key or "Color"
    ColorPicker.x = math.max(0, math.min(x, love.graphics.getWidth() - ColorPicker.width))
    ColorPicker.y = math.max(0, math.min(y, love.graphics.getHeight() - ColorPicker.height))

    -- Initialize from instance color property
    local color = inst[ColorPicker.targetKey]
    if color then
        local r, g, b = color[1], color[2], color[3]
        ColorPicker.hue, ColorPicker.saturation, ColorPicker.value = ColorPicker.rgbToHsv(r, g, b)
    end
end

function ColorPicker.close()
    ColorPicker.visible = false
    ColorPicker.targetInstance = nil
    ColorPicker.draggingSV = false
    ColorPicker.draggingH = false
end

-- HSV to RGB conversion
function ColorPicker.hsvToRgb(h, s, v)
    local c = v * s
    local hp = h / 60
    local x = c * (1 - math.abs(hp % 2 - 1))
    local r, g, b

    if hp < 1 then     r, g, b = c, x, 0
    elseif hp < 2 then r, g, b = x, c, 0
    elseif hp < 3 then r, g, b = 0, c, x
    elseif hp < 4 then r, g, b = 0, x, c
    elseif hp < 5 then r, g, b = x, 0, c
    else               r, g, b = c, 0, x
    end

    local m = v - c
    return r + m, g + m, b + m
end

-- RGB to HSV conversion
function ColorPicker.rgbToHsv(r, g, b)
    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local d = max - min
    local h, s, v

    v = max
    s = (max == 0) and 0 or (d / max)

    if d == 0 then
        h = 0
    elseif max == r then
        h = 60 * (((g - b) / d) % 6)
    elseif max == g then
        h = 60 * ((b - r) / d + 2)
    else
        h = 60 * ((r - g) / d + 4)
    end

    return h, s, v
end

function ColorPicker.draw()
    if not ColorPicker.visible then return end

    local px = ColorPicker.x
    local py = ColorPicker.y
    local pw = ColorPicker.width
    local ph = ColorPicker.height

    -- Background panel
    Theme.setColor({0, 0, 0, 0.6})
    love.graphics.rectangle("fill", px + 3, py + 3, pw, ph, 4)
    Theme.drawRect(px, py, pw, ph, Theme.colors.bg_dark, 4)
    Theme.drawBorder(px, py, pw, ph, Theme.colors.border_focus, 2)

    -- Title
    local hh = 22
    Theme.drawRect(px, py, pw, hh, Theme.colors.bg_header, 4)
    Theme.drawText("Color Picker", px + 8, py + 4, Theme.colors.text_primary, Theme.fonts.bold)

    -- Close button
    local closeX = px + pw - 20
    local closeBtnHov = Theme.inRect(love.mouse.getX(), love.mouse.getY(), closeX, py + 2, 18, 18)
    if closeBtnHov then
        Theme.drawRect(closeX, py + 2, 18, 18, Theme.colors.btn_stop, 3)
    end
    love.graphics.setFont(Theme.fonts.small)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("✕", closeX, py + 5, 18, "center")

    -- SV picker area (saturation-value square)
    local svX = px + 10
    local svY = py + hh + 8
    local svW = pw - 40
    local svH = 120

    -- Draw the SV gradient
    for ix = 0, svW - 1, 3 do
        for iy = 0, svH - 1, 3 do
            local s = ix / svW
            local v = 1 - (iy / svH)
            local r, g, b = ColorPicker.hsvToRgb(ColorPicker.hue, s, v)
            love.graphics.setColor(r, g, b, 1)
            love.graphics.rectangle("fill", svX + ix, svY + iy, 3, 3)
        end
    end
    Theme.drawBorder(svX, svY, svW, svH, Theme.colors.border, 1)

    -- SV cursor
    local svCursorX = svX + ColorPicker.saturation * svW
    local svCursorY = svY + (1 - ColorPicker.value) * svH
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("line", svCursorX, svCursorY, 5)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.circle("line", svCursorX, svCursorY, 4)

    -- Hue slider (vertical on right side)
    local hueX = px + pw - 24
    local hueY = svY
    local hueW = 14
    local hueH = svH

    for iy = 0, hueH - 1, 2 do
        local h = (iy / hueH) * 360
        local r, g, b = ColorPicker.hsvToRgb(h, 1, 1)
        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", hueX, hueY + iy, hueW, 2)
    end
    Theme.drawBorder(hueX, hueY, hueW, hueH, Theme.colors.border, 1)

    -- Hue cursor
    local hueCursorY = hueY + (ColorPicker.hue / 360) * hueH
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", hueX - 2, hueCursorY - 2, hueW + 4, 4)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("line", hueX - 2, hueCursorY - 2, hueW + 4, 4)

    -- Preview swatch
    local previewY = svY + svH + 8
    local r, g, b = ColorPicker.hsvToRgb(ColorPicker.hue, ColorPicker.saturation, ColorPicker.value)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.rectangle("fill", svX, previewY, 30, 20, 3)
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.rectangle("line", svX, previewY, 30, 20, 3)

    -- RGB values text
    love.graphics.setFont(Theme.fonts.small)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(
        string.format("R:%.0f G:%.0f B:%.0f", r*255, g*255, b*255),
        svX + 36, previewY + 4
    )

    -- Preset palette
    local presetY = previewY + 28
    local presetSize = 16
    local presetPad = 3
    local cols = 6
    for i, col in ipairs(PRESETS) do
        local row = math.floor((i - 1) / cols)
        local column = (i - 1) % cols
        local cx = svX + column * (presetSize + presetPad)
        local cy = presetY + row * (presetSize + presetPad)

        love.graphics.setColor(col[1], col[2], col[3], 1)
        love.graphics.rectangle("fill", cx, cy, presetSize, presetSize, 2)

        local mx, my = love.mouse.getPosition()
        if Theme.inRect(mx, my, cx, cy, presetSize, presetSize) then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.rectangle("line", cx, cy, presetSize, presetSize, 2)
        else
            love.graphics.setColor(0.3, 0.3, 0.3, 1)
            love.graphics.rectangle("line", cx, cy, presetSize, presetSize, 2)
        end
    end
end

function ColorPicker.mousepressed(x, y, button)
    if not ColorPicker.visible then return false end
    if button ~= 1 then return false end

    local px = ColorPicker.x
    local py = ColorPicker.y
    local pw = ColorPicker.width
    local ph = ColorPicker.height

    -- Outside picker → close
    if not Theme.inRect(x, y, px, py, pw, ph) then
        ColorPicker.close()
        return true
    end

    -- Close button
    local closeX = px + pw - 20
    if Theme.inRect(x, y, closeX, py + 2, 18, 18) then
        ColorPicker.close()
        return true
    end

    local hh = 22
    local svX = px + 10
    local svY = py + hh + 8
    local svW = pw - 40
    local svH = 120

    -- SV area
    if Theme.inRect(x, y, svX, svY, svW, svH) then
        ColorPicker.draggingSV = true
        ColorPicker.saturation = math.max(0, math.min(1, (x - svX) / svW))
        ColorPicker.value = math.max(0, math.min(1, 1 - (y - svY) / svH))
        ColorPicker._applyColor()
        return true
    end

    -- Hue slider
    local hueX = px + pw - 24
    local hueW = 14
    if Theme.inRect(x, y, hueX, svY, hueW, svH) then
        ColorPicker.draggingH = true
        ColorPicker.hue = math.max(0, math.min(360, (y - svY) / svH * 360))
        ColorPicker._applyColor()
        return true
    end

    -- Preset palette
    local previewY = svY + svH + 8
    local presetY = previewY + 28
    local presetSize = 16
    local presetPad = 3
    local cols = 6
    for i, col in ipairs(PRESETS) do
        local row = math.floor((i - 1) / cols)
        local column = (i - 1) % cols
        local cx = svX + column * (presetSize + presetPad)
        local cy = presetY + row * (presetSize + presetPad)
        if Theme.inRect(x, y, cx, cy, presetSize, presetSize) then
            local h, s, v = ColorPicker.rgbToHsv(col[1], col[2], col[3])
            ColorPicker.hue = h
            ColorPicker.saturation = s
            ColorPicker.value = v
            ColorPicker._applyColor()
            return true
        end
    end

    return true  -- consume click
end

function ColorPicker.mousemoved(x, y, dx, dy)
    if not ColorPicker.visible then return end

    local px = ColorPicker.x
    local py = ColorPicker.y
    local pw = ColorPicker.width
    local hh = 22
    local svX = px + 10
    local svY = py + hh + 8
    local svW = pw - 40
    local svH = 120

    if ColorPicker.draggingSV then
        ColorPicker.saturation = math.max(0, math.min(1, (x - svX) / svW))
        ColorPicker.value = math.max(0, math.min(1, 1 - (y - svY) / svH))
        ColorPicker._applyColor()
    end

    if ColorPicker.draggingH then
        ColorPicker.hue = math.max(0, math.min(360, (y - svY) / svH * 360))
        ColorPicker._applyColor()
    end
end

function ColorPicker.mousereleased(x, y, button)
    ColorPicker.draggingSV = false
    ColorPicker.draggingH = false
end

function ColorPicker._applyColor()
    local r, g, b = ColorPicker.hsvToRgb(ColorPicker.hue, ColorPicker.saturation, ColorPicker.value)
    local inst = ColorPicker.targetInstance
    local key = ColorPicker.targetKey
    if inst and key and inst[key] then
        inst[key][1] = r
        inst[key][2] = g
        inst[key][3] = b
        -- Trigger change listener if it exists (Vector3/Color3 often have _onChange)
        if inst[key]._onChange then inst[key]._onChange() end
    end
    if ColorPicker.onColorChanged then
        ColorPicker.onColorChanged(r, g, b)
    end
end

return ColorPicker
