-- studio/theme.lua
-- Centralized theme constants matching Roblox Studio dark theme

local Theme = {}

-- ──────────────────────────────────────────
-- Colors
-- ──────────────────────────────────────────
Theme.colors = {
    -- Backgrounds
    bg_dark      = {0.117, 0.117, 0.117, 1},   -- #1e1e1e panels
    bg_medium    = {0.149, 0.157, 0.165, 1},   -- #262a2a mid panels
    bg_light     = {0.196, 0.204, 0.212, 1},   -- #323435 rows
    bg_header    = {0.102, 0.102, 0.102, 1},   -- #1a1a1a headers
    bg_menubar   = {0.133, 0.133, 0.133, 1},   -- #222222
    bg_toolbar   = {0.176, 0.176, 0.176, 1},   -- #2d2d2d
    bg_active    = {0.169, 0.420, 0.753, 1},   -- #2b6bc0 selected/active blue
    bg_hover     = {0.231, 0.251, 0.271, 1},   -- #3b4045 row hover
    bg_selected  = {0.196, 0.322, 0.494, 1},   -- #32527e tree selection
    bg_separator = {0.075, 0.075, 0.075, 1},   -- #131313 dividers

    -- Text
    text_primary   = {0.937, 0.937, 0.937, 1}, -- #efefef
    text_secondary = {0.624, 0.651, 0.678, 1}, -- #9fa6ad
    text_disabled  = {0.42, 0.44, 0.46, 1},
    text_accent    = {0.38, 0.71, 1.00, 1},    -- #61b5ff links/highlights
    text_error     = {1.00, 0.38, 0.38, 1},
    text_warn      = {1.00, 0.80, 0.30, 1},
    text_info      = {0.60, 0.85, 1.00, 1},

    -- Borders
    border       = {0.235, 0.235, 0.235, 1},
    border_focus = {0.38, 0.71, 1.00, 1},

    -- Buttons
    btn_normal   = {0.25, 0.26, 0.28, 1},
    btn_hover    = {0.30, 0.32, 0.34, 1},
    btn_active   = {0.169, 0.420, 0.753, 1},
    btn_play     = {0.14, 0.60, 0.14, 1},
    btn_stop     = {0.75, 0.15, 0.15, 1},
    btn_pause    = {0.70, 0.55, 0.10, 1},

    -- Toolbar item active
    tool_active  = {0.169, 0.420, 0.753, 1},
    tool_hover   = {0.25, 0.30, 0.38, 1},

    white        = {1, 1, 1, 1},
    clear        = {0, 0, 0, 0},
}

-- ──────────────────────────────────────────
-- Layout dimensions
-- ──────────────────────────────────────────
Theme.layout = {
    menu_h      = 24,
    toolbar_h   = 44,
    statusbar_h = 22,
    viewport_tab_h = 24,
    explorer_w  = 260,
    output_h    = 130,
    row_h       = 20,
    indent_w    = 14,
    padding     = 6,
    icon_size   = 16,
    ui_icon_size = 24, -- Size of icons in the generated sprite sheet
}

-- ──────────────────────────────────────────
-- Assets (loaded in Theme.load)
-- ──────────────────────────────────────────
Theme.assets = {}

function Theme.loadAssets()
    Theme.loadFonts()
    -- Load logos
    local ok, img = pcall(love.graphics.newImage, "assets/Icon.png")
    if ok then Theme.assets.logo_studio = img end

    local ok2, img2 = pcall(love.graphics.newImage, "assets/Logo.png")
    if ok2 then Theme.assets.logo_full = img2 end
end

-- ──────────────────────────────────────────
-- Fonts (loaded lazily once love is ready)
-- ──────────────────────────────────────────
Theme.fonts = {}

function Theme.loadFonts()
    local path = "assets/fonts/DejaVuSans.ttf"
    local f = love.filesystem.getInfo(path)

    Theme.fonts.small   = f and love.graphics.newFont(path, 11) or love.graphics.newFont(11)
    Theme.fonts.normal  = f and love.graphics.newFont(path, 13) or love.graphics.newFont(13)
    Theme.fonts.bold    = f and love.graphics.newFont(path, 13) or love.graphics.newFont(13)
    Theme.fonts.header  = f and love.graphics.newFont(path, 14) or love.graphics.newFont(14)
    Theme.fonts.mono    = f and love.graphics.newFont(path, 12) or love.graphics.newFont(12)
    Theme.fonts.tiny    = f and love.graphics.newFont(path, 10) or love.graphics.newFont(10)
    Theme.fonts.large   = f and love.graphics.newFont(path, 24) or love.graphics.newFont(24)
end

-- ──────────────────────────────────────────
-- Draw helpers
-- ──────────────────────────────────────────

-- Animation / Tweening state
Theme.anims = {}

function Theme.animate(id, target, dt, speed)
    speed = speed or 15
    if not Theme.anims[id] then
        Theme.anims[id] = target
        return target
    end
    Theme.anims[id] = Theme.anims[id] + (target - Theme.anims[id]) * (1 - math.exp(-speed * dt))
    if math.abs(Theme.anims[id] - target) < 0.001 then Theme.anims[id] = target end
    return Theme.anims[id]
end

function Theme.animateColor(id, targetColor, dt, speed)
    speed = speed or 15
    if not Theme.anims[id] then
        Theme.anims[id] = {targetColor[1], targetColor[2], targetColor[3], targetColor[4] or 1}
        return Theme.anims[id]
    end
    local c = Theme.anims[id]
    local t = 1 - math.exp(-speed * dt)
    c[1] = c[1] + (targetColor[1] - c[1]) * t
    c[2] = c[2] + (targetColor[2] - c[2]) * t
    c[3] = c[3] + (targetColor[3] - c[3]) * t
    c[4] = c[4] + ((targetColor[4] or 1) - c[4]) * t
    -- clamp
    for i=1,4 do if c[i] < 0 then c[i]=0 elseif c[i]>1 then c[i]=1 end end
    return c
end

function Theme.setColor(c)
    love.graphics.setColor(c[1], c[2], c[3], c[4] or 1)
end

function Theme.drawRect(x, y, w, h, color, radius)
    Theme.setColor(color)
    if radius and radius > 0 then
        love.graphics.rectangle("fill", x, y, w, h, radius, radius)
    else
        love.graphics.rectangle("fill", x, y, w, h)
    end
end

function Theme.drawBorder(x, y, w, h, color, lw)
    Theme.setColor(color)
    love.graphics.setLineWidth(lw or 1)
    love.graphics.rectangle("line", x, y, w, h)
end

function Theme.drawText(text, x, y, color, font)
    love.graphics.setFont(font or Theme.fonts.normal)
    Theme.setColor(color or Theme.colors.text_primary)
    love.graphics.print(text, x, y)
end

function Theme.drawButton(label, x, y, w, h, state, icon)
    -- state: "normal" | "hover" | "active"
    local bgColor = (state == "active") and Theme.colors.btn_active
                 or (state == "hover")  and Theme.colors.btn_hover
                 or Theme.colors.btn_normal

    Theme.drawRect(x, y, w, h, bgColor, 3)
    Theme.drawBorder(x, y, w, h, Theme.colors.border, 1)

    local ty = y + math.floor((h - Theme.fonts.normal:getHeight()) / 2)
    love.graphics.setFont(Theme.fonts.normal)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(label, x, ty, w, "center")
end

function Theme.drawDivider(x, y, w, h, vertical)
    Theme.setColor(Theme.colors.bg_separator)
    if vertical then
        love.graphics.rectangle("fill", x, y, 1, h)
    else
        love.graphics.rectangle("fill", x, y, w, 1)
    end
end

function Theme.inRect(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

function Theme.drawIcon(x, y, unicode, color, fontSize)
    love.graphics.setFont(fontSize or Theme.fonts.normal)
    Theme.setColor(color or Theme.colors.text_primary)
    love.graphics.print(unicode, x, y)
end

return Theme
