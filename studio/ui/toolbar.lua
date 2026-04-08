-- studio/ui/toolbar.lua
-- Main toolbar: tool buttons + play controls

local Theme  = require("studio.theme")
local ToolMgr = nil -- loaded lazily

local Toolbar = {}

-- Tool definitions
local toolButtons = {
    {id = "Select", label = "Select", key = "1", icon = "▲"},
    {id = "Move",   label = "Move",   key = "2", icon = "✚"},
    {id = "Scale",  label = "Scale",  key = "3", icon = "↔"},
    {id = "Rotate", label = "Rotate", key = "4", icon = "↺"},
}

local playButtons = {
    {id = "play",  label = "Play",  icon = "▶", color = Theme.colors.btn_play},
    {id = "pause", label = "Pause", icon = "||", color = Theme.colors.btn_pause},
    {id = "stop",  label = "Stop",  icon = "■", color = Theme.colors.btn_stop},
}

local toolRects = {}
local playRects = {}

function Toolbar.load()
    ToolMgr = require("studio.tools.tool_manager")
end

function Toolbar.update(dt)
end

function Toolbar.draw()
    local w   = love.graphics.getWidth()
    local my_ = Theme.layout.menu_h
    local th  = Theme.layout.toolbar_h
    local mx, my = love.mouse.getPosition()

    -- Background
    Theme.drawRect(0, my_, w, th, Theme.colors.bg_toolbar)
    Theme.drawDivider(0, my_ + th - 1, w, 1, false)

    -- Determine if in play mode
    local isPlaying = Engine.PlayMode and Engine.PlayMode.state ~= "Stopped"

    -- Left group: tool buttons
    local bw, bh = 70, 32
    local bpad   = 4
    local gx     = 8
    local by     = my_ + math.floor((th - bh) / 2)

    toolRects = {}
    for i, btn in ipairs(toolButtons) do
        local bx = gx + (i - 1) * (bw + bpad)
        local isActive  = (ToolMgr and ToolMgr.currentTool == btn.id)
        local isHovered = Theme.inRect(mx, my, bx, by, bw, bh)

        -- Dim tools during play mode
        local state = isActive and "active" or (isHovered and not isPlaying and "hover" or "normal")

        local bgColor = (state == "active") and Theme.colors.btn_active
                     or (state == "hover")  and Theme.colors.btn_hover
                     or Theme.colors.btn_normal
        Theme.drawRect(bx, by, bw, bh, bgColor, 4)
        if state == "active" then
            Theme.drawBorder(bx, by, bw, bh, Theme.colors.border_focus, 1)
        else
            Theme.drawBorder(bx, by, bw, bh, Theme.colors.border, 1)
        end

        -- Icon + label (dimmed during play)
        local alpha = isPlaying and 0.4 or 1.0
        local ix = bx + (bw - Theme.fonts.normal:getWidth(btn.icon)) / 2
        local iy = by + 3
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.setFont(Theme.fonts.normal)
        love.graphics.print(btn.icon, ix, iy)

        local lblY  = by + bh - 12
        love.graphics.setFont(Theme.fonts.tiny)
        love.graphics.setColor(0.85, 0.85, 0.85, alpha)
        love.graphics.printf(btn.label .. " [" .. btn.key .. "]", bx, lblY, bw, "center")

        toolRects[i] = {x = bx, y = by, w = bw, h = bh, id = btn.id}
    end

    -- Divider between tool group and play group
    local divX = gx + #toolButtons * (bw + bpad) + 6
    Theme.drawDivider(divX, Theme.layout.menu_h + 6, 1, Theme.layout.toolbar_h - 12, true)

    -- Right group: play buttons
    local pbw, pbh = 80, 30
    local ppad     = 4
    local totalPW  = #playButtons * (pbw + ppad)
    local px       = w - totalPW - 10
    local py       = Theme.layout.menu_h + math.floor((Theme.layout.toolbar_h - pbh) / 2)

    playRects = {}
    local playState = Engine.PlayMode and Engine.PlayMode.state or "Stopped"
    for i, btn in ipairs(playButtons) do
        local bx = px + (i - 1) * (pbw + ppad)
        local isHov = Theme.inRect(mx, my, bx, py, pbw, pbh)
        local isActive = (btn.id == "play" and playState == "Playing")
                      or (btn.id == "pause" and playState == "Paused")

        local bg = isActive and btn.color
               or (isHov and {btn.color[1] + 0.08, btn.color[2] + 0.08, btn.color[3] + 0.08, 1})
               or {btn.color[1] * 0.75, btn.color[2] * 0.75, btn.color[3] * 0.75, 1}

        Theme.drawRect(bx, py, pbw, pbh, bg, 4)
        Theme.drawBorder(bx, py, pbw, pbh, Theme.colors.border, 1)

        local ix = bx + 10
        local iy = py + (pbh - Theme.fonts.normal:getHeight()) / 2
        love.graphics.setFont(Theme.fonts.normal)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(btn.icon, ix, iy)

        love.graphics.setFont(Theme.fonts.normal)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(btn.label, bx + 16, py + (pbh - 13) / 2, pbw - 16, "center")

        playRects[i] = {x = bx, y = py, w = pbw, h = pbh, id = btn.id}
    end
end

function Toolbar.mousepressed(x, y, button)
    if button ~= 1 then return false end

    local isPlaying = Engine.PlayMode and Engine.PlayMode.state ~= "Stopped"

    -- Tool buttons (only in studio mode)
    if not isPlaying then
        for _, rect in ipairs(toolRects) do
            if Theme.inRect(x, y, rect.x, rect.y, rect.w, rect.h) then
                if ToolMgr then ToolMgr.setTool(rect.id) end
                return true
            end
        end
    end

    -- Play buttons (always available)
    for _, rect in ipairs(playRects) do
        if Theme.inRect(x, y, rect.x, rect.y, rect.w, rect.h) then
            if rect.id == "play" then
                if Engine.PlayMode.state == "Stopped" then
                    Engine.PlayMode:play(Engine.Workspace)
                elseif Engine.PlayMode.state == "Paused" then
                    Engine.PlayMode:pause()
                end
            elseif rect.id == "pause" then
                Engine.PlayMode:pause()
            elseif rect.id == "stop" then
                Engine.PlayMode:stop(Engine.Workspace)
            end
            return true
        end
    end

    return false
end

function Toolbar.mousereleased(x, y, button) end
function Toolbar.mousemoved(x, y, dx, dy) end

return Toolbar
