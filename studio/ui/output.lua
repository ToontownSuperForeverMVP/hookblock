-- studio/ui/output.lua
-- Output panel at the bottom: captures print() and shows logs

local Theme  = require("studio.theme")

local Output = {}

Output.messages  = {}
Output.scrollY   = 0
Output.collapsed = false

-- Override global print to capture messages
local _origPrint = print
function print(...)
    local parts = {}
    for i = 1, select("#", ...) do
        table.insert(parts, tostring(select(i, ...)))
    end
    local msg = table.concat(parts, "\t")
    _origPrint(msg)
    table.insert(Output.messages, {text = msg, level = "info", time = os.clock()})
    -- Keep last 500 messages
    if #Output.messages > 500 then table.remove(Output.messages, 1) end
    -- Auto-scroll if at bottom
    if Output.atBottom then
        Output.scrollY = -math.huge
    end
end

-- Compatibility for ScriptRuntime
function Output.log(msg)
    table.insert(Output.messages, {text = msg, level = "info", time = os.clock()})
    if #Output.messages > 500 then table.remove(Output.messages, 1) end
    if Output.atBottom then Output.scrollY = -math.huge end
end

function Output.warn(msg)
    _origPrint("[WARN] " .. msg)
    table.insert(Output.messages, {text = msg, level = "warn", time = os.clock()})
    if #Output.messages > 500 then table.remove(Output.messages, 1) end
    if Output.atBottom then Output.scrollY = -math.huge end
end

function Output.error(msg)
    _origPrint("[ERROR] " .. msg)
    table.insert(Output.messages, {text = msg, level = "error", time = os.clock()})
    if #Output.messages > 500 then table.remove(Output.messages, 1) end
    if Output.atBottom then Output.scrollY = -math.huge end
end

function Output.load()
    Output.atBottom = true
    print("[Luvoxel] Studio loaded — welcome!")
end

function Output.update(dt) end

function Output.draw(panelX, panelY, panelW, panelH)
    local mx, my = love.mouse.getPosition()

    -- Panel background
    Theme.drawRect(panelX, panelY, panelW, panelH, Theme.colors.bg_dark)

    -- Toolbar / Action bar (minimal)
    local ah = 20
    Theme.drawRect(panelX, panelY, panelW, ah, Theme.colors.bg_header)

    -- Clear button
    local clearBtn = {x = panelX + 6, y = panelY + 2, w = 40, h = 16}
    local clrHov = Theme.inRect(mx, my, clearBtn.x, clearBtn.y, clearBtn.w, clearBtn.h)
    Theme.drawRect(clearBtn.x, clearBtn.y, clearBtn.w, clearBtn.h, clrHov and Theme.colors.btn_hover or Theme.colors.btn_normal, 2)
    love.graphics.setFont(Theme.fonts.tiny)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Clear", clearBtn.x, clearBtn.y + 2, clearBtn.w, "center")
    Output._clearBtn = clearBtn

    Theme.drawDivider(panelX, panelY + ah, panelW, 1, false)

    if Output.collapsed then return end

    -- Messages
    local contentH = panelH - ah
    love.graphics.setScissor(panelX, panelY + ah, panelW, contentH)

    local rh = 18
    local totalRows = #Output.messages
    local totalContentH = totalRows * rh
    
    local maxScrollY = -math.max(0, totalContentH - (contentH - 4))
    if Output.scrollY == -math.huge then
        Output.scrollY = maxScrollY
        Output.atBottom = true
    end
    
    Output.scrollY = math.max(maxScrollY, math.min(0, Output.scrollY))
    -- Update atBottom flag for next print
    Output.atBottom = (Output.scrollY <= maxScrollY + 2)

    local yBase = panelY + ah + 2 + Output.scrollY
    for i = 1, totalRows do
        local ly = yBase + (i-1) * rh
        if ly + rh > panelY + ah and ly < panelY + panelH then
            local msg = Output.messages[i]
            local color = msg.level == "error" and Theme.colors.text_error
                       or msg.level == "warn"  and Theme.colors.text_warn
                       or Theme.colors.text_primary

            love.graphics.setFont(Theme.fonts.mono)
            Theme.setColor(color)
            love.graphics.print(msg.text, panelX + 6, ly)
        end
    end

    love.graphics.setScissor()

    -- Top border
    Theme.drawDivider(panelX, panelY, panelW, 1, false)
end

function Output.mousepressed(x, y, button, panelX, panelY, panelW, panelH)
    if not Theme.inRect(x, y, panelX, panelY, panelW, panelH) then return false end

    -- Clear button
    if Output._clearBtn and Theme.inRect(x, y, Output._clearBtn.x, Output._clearBtn.y,
                                          Output._clearBtn.w, Output._clearBtn.h) then
        Output.messages = {}
        return true
    end

    -- Collapse toggle (top-right of header)
    local cbX = panelX + panelW - 22
    if Theme.inRect(x, y, cbX, panelY + 2, 18, 18) then
        Output.collapsed = not Output.collapsed
        return true
    end

    return true
end

function Output.wheelmoved(x, y, panelX, panelY, panelW, panelH)
    local mx, my = love.mouse.getPosition()
    if Theme.inRect(mx, my, panelX, panelY, panelW, panelH) then
        Output.scrollY = Output.scrollY + y * 18
    end
end

return Output
