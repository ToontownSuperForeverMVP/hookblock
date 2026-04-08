-- studio/ui/script_editor.lua
-- Enhanced Lua script editor with multi-tab support, cursor, and linting

local Theme = require("studio.theme")
local utf8  = require("utf8")

local ScriptEditor = {}

ScriptEditor.visible = false
ScriptEditor.x = 80
ScriptEditor.y = 80
ScriptEditor.width = 800
ScriptEditor.height = 600

-- Tabs: {name, content, cursorX, cursorY, scrollY, instance, history, historyIndex}
ScriptEditor.tabs = {}
ScriptEditor.activeTab = 0

local COLORS = {
    keyword  = {0.86, 0.55, 0.76, 1},
    builtin  = {0.40, 0.76, 0.94, 1},
    string   = {0.80, 0.90, 0.40, 1},
    comment  = {0.45, 0.55, 0.45, 1},
    number   = {0.90, 0.70, 0.40, 1},
    normal   = {0.90, 0.90, 0.90, 1},
    lineNum  = {0.40, 0.44, 0.50, 1},
    bg       = {0.12, 0.12, 0.14, 1},
    lineNumBg = {0.10, 0.10, 0.11, 1},
    cursor   = {1, 1, 1, 1},
    selection = {0.2, 0.4, 0.6, 0.5},
    error    = {1, 0.3, 0.3, 1},
}

local KEYWORDS = {
    ["and"]=true, ["break"]=true, ["do"]=true, ["else"]=true, ["elseif"]=true, ["end"]=true,
    ["false"]=true, ["for"]=true, ["function"]=true, ["goto"]=true, ["if"]=true, ["in"]=true,
    ["local"]=true, ["nil"]=true, ["not"]=true, ["or"]=true, ["repeat"]=true, ["return"]=true,
    ["then"]=true, ["true"]=true, ["until"]=true, ["while"]=true,
}
local BUILTINS = {
    ["print"]=true, ["require"]=true, ["script"]=true, ["game"]=true, ["workspace"]=true,
    ["math"]=true, ["table"]=true, ["string"]=true, ["pairs"]=true, ["ipairs"]=true,
}

local function getSelectionRange(tab)
    if not tab.selectionStart then return nil end
    local sy, ey = tab.selectionStart.y, tab.cursorY
    local sx, ex = tab.selectionStart.x, tab.cursorX
    if sy > ey or (sy == ey and sx > ex) then
        sy, ey = ey, sy
        sx, ex = ex, sx
    end
    return sx, sy, ex, ey
end

local function deleteSelection(tab)
    local sx, sy, ex, ey = getSelectionRange(tab)
    if not sx then return end
    
    local firstPart = tab.lines[sy]:sub(1, sx - 1)
    local lastPart = tab.lines[ey]:sub(ex)
    
    tab.lines[sy] = firstPart .. lastPart
    for i = 1, ey - sy do
        table.remove(tab.lines, sy + 1)
    end
    
    tab.cursorX = sx
    tab.cursorY = sy
    tab.selectionStart = nil
end

local function getSelectedText(tab)
    local sx, sy, ex, ey = getSelectionRange(tab)
    if not sx then return "" end
    
    if sy == ey then
        return tab.lines[sy]:sub(sx, ex - 1)
    end
    
    local res = {tab.lines[sy]:sub(sx)}
    for i = sy + 1, ey - 1 do
        table.insert(res, tab.lines[i])
    end
    table.insert(res, tab.lines[ey]:sub(1, ex - 1))
    return table.concat(res, "\n")
end

function ScriptEditor.openScript(name, content, instance)
    if _G._UI then _G._UI.activeTab = "Script" end
    for i, tab in ipairs(ScriptEditor.tabs) do
        if tab.instance == instance then
            ScriptEditor.activeTab = i
            ScriptEditor.visible = true
            return
        end
    end

    local lines = {}
    for line in (content .. "\n"):gmatch("(.-)\r?\n") do
        table.insert(lines, line)
    end
    if #lines == 0 then table.insert(lines, "") end

    table.insert(ScriptEditor.tabs, {
        name = name,
        lines = lines,
        cursorX = 1,
        cursorY = 1,
        selectionStart = nil, -- {x, y}
        scrollY = 0,
        instance = instance,
        errors = {},
    })
    ScriptEditor.activeTab = #ScriptEditor.tabs
    ScriptEditor.visible = true
    ScriptEditor.lint()
end

function ScriptEditor.lint()
    local tab = ScriptEditor.tabs[ScriptEditor.activeTab]
    if not tab then return end
    tab.errors = {}
    local source = table.concat(tab.lines, "\n")
    local f, err = load(source)
    if not f then
        local line, msg = err:match(":(%d+): (.+)")
        if line then
            table.insert(tab.errors, {line = tonumber(line), message = msg})
        end
    end
end

function ScriptEditor.save()
    local tab = ScriptEditor.tabs[ScriptEditor.activeTab]
    if tab and tab.instance then
        tab.instance.Source = table.concat(tab.lines, "\n")
        if _G._Notifications then _G._Notifications.show("Script saved", "info") end
        ScriptEditor.lint()
    end
end

function ScriptEditor.closeTab(index)
    table.remove(ScriptEditor.tabs, index)
    if ScriptEditor.activeTab > #ScriptEditor.tabs then
        ScriptEditor.activeTab = #ScriptEditor.tabs
    end
    if #ScriptEditor.tabs == 0 then ScriptEditor.visible = false end
end

local function drawLineHighlighted(text, x, y)
    local pos = 1
    local dx = x
    local font = Theme.fonts.mono
    while pos <= #text do
        local c = text:sub(pos, pos)
        if c:match("%s") then
            dx = dx + font:getWidth(c)
            pos = pos + 1
        elseif text:sub(pos, pos+1) == "--" then
            Theme.setColor(COLORS.comment)
            love.graphics.print(text:sub(pos), dx, y)
            break
        elseif c == '"' or c == "'" then
            local q = c
            local stop = text:find(q, pos+1, true) or #text
            local s = text:sub(pos, stop)
            Theme.setColor(COLORS.string)
            love.graphics.print(s, dx, y)
            dx = dx + font:getWidth(s)
            pos = stop + 1
        elseif c:match("%d") then
            local stop = pos
            while stop <= #text and text:sub(stop, stop):match("[%d%.]") do stop = stop + 1 end
            local s = text:sub(pos, stop-1)
            Theme.setColor(COLORS.number)
            love.graphics.print(s, dx, y)
            dx = dx + font:getWidth(s)
            pos = stop
        elseif c:match("[%a_]") then
            local stop = pos
            while stop <= #text and text:sub(stop, stop):match("[%w_]") do stop = stop + 1 end
            local s = text:sub(pos, stop-1)
            if KEYWORDS[s] then Theme.setColor(COLORS.keyword)
            elseif BUILTINS[s] then Theme.setColor(COLORS.builtin)
            else Theme.setColor(COLORS.normal) end
            love.graphics.print(s, dx, y)
            dx = dx + font:getWidth(s)
            pos = stop
        else
            Theme.setColor(COLORS.normal)
            love.graphics.print(c, dx, y)
            dx = dx + font:getWidth(c)
            pos = pos + 1
        end
    end
end

function ScriptEditor.update(dt)
    if #ScriptEditor.tabs == 0 then return end
    
    -- Check for deleted scripts
    for i = #ScriptEditor.tabs, 1, -1 do
        local tab = ScriptEditor.tabs[i]
        if not tab.instance or not tab.instance.Parent then
            ScriptEditor.closeTab(i)
        end
    end
end

function ScriptEditor.draw()
    if not ScriptEditor.visible or #ScriptEditor.tabs == 0 then return end
    local tab = ScriptEditor.tabs[ScriptEditor.activeTab]
    local px, py, pw, ph = ScriptEditor.x, ScriptEditor.y, ScriptEditor.width, ScriptEditor.height

    -- Background (Integrated)
    Theme.drawRect(px, py, pw, ph, COLORS.bg)

    -- Integrated header (tabs)
    local hh = 28
    Theme.drawRect(px, py, pw, hh, Theme.colors.bg_header)
    local tx = px + 4
    for i, t in ipairs(ScriptEditor.tabs) do
        local tw = Theme.fonts.small:getWidth(t.name) + 34
        local active = (i == ScriptEditor.activeTab)
        if active then Theme.drawRect(tx, py+2, tw, hh-2, COLORS.bg, 4) end
        Theme.drawText(t.name, tx+8, py+6, active and Theme.colors.text_primary or Theme.colors.text_secondary, Theme.fonts.small)
        Theme.drawText("×", tx+tw-18, py+5, Theme.colors.text_secondary, Theme.fonts.normal)
        tx = tx + tw + 2
    end

    -- Toolbar (New Save etc)
    local th = 24
    Theme.drawRect(px, py+hh, pw, th, Theme.colors.bg_dark)
    Theme.drawDivider(px, py+hh+th-1, pw, 1)

    local btnX = px + 8
    local function drawBtn(label, icon)
        local bw = Theme.fonts.small:getWidth(label) + 24
        local hov = Theme.inRect(love.mouse.getX(), love.mouse.getY(), btnX, py+hh+2, bw, th-4)
        if hov then Theme.drawRect(btnX, py+hh+2, bw, th-4, Theme.colors.bg_hover, 3) end
        Theme.drawText(icon .. " " .. label, btnX+8, py+hh+5, Theme.colors.text_primary, Theme.fonts.small)
        local rect = {x=btnX, y=py+hh+2, w=bw, h=th-4}
        btnX = btnX + bw + 8
        return rect
    end
    ScriptEditor._saveBtn = drawBtn("Save", "💾")

    -- Main Editor
    local editorY = py + hh + th
    local editorH = ph - hh - th
    local lineH = 18
    local lineNumW = 45
    love.graphics.setScissor(px, editorY, pw, editorH)

    local startLine = math.max(1, math.floor(-tab.scrollY / lineH) + 1)
    local endLine = math.min(#tab.lines, startLine + math.floor(editorH / lineH) + 1)

    Theme.drawRect(px, editorY, lineNumW, editorH, COLORS.lineNumBg)
    Theme.drawDivider(px + lineNumW, editorY, 1, editorH, true)

    for i = startLine, endLine do
        local ly = editorY + (i-1) * lineH + tab.scrollY

        -- Selection Rendering
        if tab.selectionStart then
            local sy, ey = tab.selectionStart.y, tab.cursorY
            local sx, ex = tab.selectionStart.x, tab.cursorX
            if sy > ey or (sy == ey and sx > ex) then
                sy, ey = ey, sy
                sx, ex = ex, sx
            end
            
            if i >= sy and i <= ey then
                local line = tab.lines[i]
                local startX = (i == sy) and sx or 1
                local endX = (i == ey) and ex or #line + 1
                
                local x1 = px + lineNumW + 8 + Theme.fonts.mono:getWidth(line:sub(1, startX - 1))
                local x2 = px + lineNumW + 8 + Theme.fonts.mono:getWidth(line:sub(1, endX - 1))
                if i < ey and i >= sy then
                    -- Add space for newline
                    x2 = x2 + Theme.fonts.mono:getWidth(" ")
                end
                
                Theme.drawRect(x1, ly + 2, x2 - x1, lineH - 2, COLORS.selection)
            end
        end

        -- Error marker
        for _, err in ipairs(tab.errors) do
            if err.line == i then
                Theme.drawRect(px, ly, lineNumW, lineH, {1, 0, 0, 0.2})
                Theme.drawText("!", px+4, ly+2, Theme.colors.text_error, Theme.fonts.bold)
            end
        end

        Theme.drawText(tostring(i), px, ly+2, COLORS.lineNum, Theme.fonts.mono)
        drawLineHighlighted(tab.lines[i], px + lineNumW + 8, ly+2)

        -- Cursor
        if i == tab.cursorY and (math.floor(os.clock()*2)%2 == 0) then
            local txtBefore = tab.lines[i]:sub(1, tab.cursorX-1)
            local cx = px + lineNumW + 8 + Theme.fonts.mono:getWidth(txtBefore)
            Theme.drawRect(cx, ly+2, 2, lineH-4, COLORS.cursor)
        end
    end
    love.graphics.setScissor()

    -- Scrollbar (integrated)
    local totalH = #tab.lines * lineH
    if totalH > editorH then
        local ratio = editorH / totalH
        local sbH = math.max(20, editorH * ratio)
        local sbY = editorY + (-tab.scrollY / totalH) * editorH
        Theme.drawRect(px + pw - 6, sbY, 4, sbH, Theme.colors.bg_hover, 2)
    end
end

function ScriptEditor.mousepressed(x, y, button)
    if not ScriptEditor.visible then return false end
    if not Theme.inRect(x, y, ScriptEditor.x, ScriptEditor.y, ScriptEditor.width, ScriptEditor.height) then
        return false
    end

    if ScriptEditor._saveBtn and Theme.inRect(x, y, ScriptEditor._saveBtn.x, ScriptEditor._saveBtn.y, ScriptEditor._saveBtn.w, ScriptEditor._saveBtn.h) then
        ScriptEditor.save()
        return true
    end

    local py = ScriptEditor.y
    local hh = 28
    local tx = ScriptEditor.x + 4
    for i, t in ipairs(ScriptEditor.tabs) do
        local tw = Theme.fonts.small:getWidth(t.name) + 34
        if Theme.inRect(x, y, tx+tw-20, py+2, 20, hh-4) then
            ScriptEditor.closeTab(i)
            return true
        end
        if Theme.inRect(x, y, tx, py+2, tw, hh-4) then
            ScriptEditor.activeTab = i
            return true
        end
        tx = tx + tw + 2
    end

    -- Click in editor to move cursor
    local tab = ScriptEditor.tabs[ScriptEditor.activeTab]
    local editorY = ScriptEditor.y + 28 + 24
    local lineNumW = 45
    local lineH = 18
    if y >= editorY and x >= ScriptEditor.x + lineNumW and button == 1 then
        local lineIdx = math.floor((y - editorY - tab.scrollY) / lineH) + 1
        tab.cursorY = math.max(1, math.min(#tab.lines, lineIdx))
        local line = tab.lines[tab.cursorY]
        local relX = x - (ScriptEditor.x + lineNumW + 8)
        local bestX, minDist = 1, math.huge
        for i = 0, #line do
            local w = Theme.fonts.mono:getWidth(line:sub(1, i))
            local d = math.abs(relX - w)
            if d < minDist then minDist = d; bestX = i + 1 end
        end
        tab.cursorX = bestX
        
        -- Selection
        if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
            if not tab.selectionStart then
                tab.selectionStart = {x = tab.cursorX, y = tab.cursorY}
            end
        else
            tab.selectionStart = {x = tab.cursorX, y = tab.cursorY}
        end
        tab.isSelecting = true
    end

    return true
end

function ScriptEditor.mousereleased(x, y, button)
    if not ScriptEditor.visible then return false end
    local tab = ScriptEditor.tabs[ScriptEditor.activeTab]
    if tab and button == 1 then
        tab.isSelecting = false
        if tab.selectionStart and tab.selectionStart.x == tab.cursorX and tab.selectionStart.y == tab.cursorY then
            tab.selectionStart = nil
        end
    end
    return true
end

function ScriptEditor.mousemoved(x, y, dx, dy)
    if not ScriptEditor.visible then return false end
    local tab = ScriptEditor.tabs[ScriptEditor.activeTab]
    if tab and tab.isSelecting then
        local editorY = ScriptEditor.y + 28 + 24
        local lineNumW = 45
        local lineH = 18
        
        local lineIdx = math.floor((y - editorY - tab.scrollY) / lineH) + 1
        tab.cursorY = math.max(1, math.min(#tab.lines, lineIdx))
        local line = tab.lines[tab.cursorY]
        local relX = x - (ScriptEditor.x + lineNumW + 8)
        local bestX, minDist = 1, math.huge
        for i = 0, #line do
            local w = Theme.fonts.mono:getWidth(line:sub(1, i))
            local d = math.abs(relX - w)
            if d < minDist then minDist = d; bestX = i + 1 end
        end
        tab.cursorX = bestX
        return true
    end
    return false
end

function ScriptEditor.keypressed(key)
    if not ScriptEditor.visible then return false end
    local tab = ScriptEditor.tabs[ScriptEditor.activeTab]
    if not tab then return false end

    if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
        if key == "s" then ScriptEditor.save(); return true end
        if key == "c" then
            local text = getSelectedText(tab)
            if text ~= "" then love.system.setClipboardText(text) end
            return true
        elseif key == "v" then
            if tab.selectionStart then deleteSelection(tab) end
            local text = love.system.getClipboardText()
            for line in (text .. "\n"):gmatch("(.-)\r?\n") do
                local current = tab.lines[tab.cursorY]
                tab.lines[tab.cursorY] = current:sub(1, tab.cursorX - 1) .. line
                local nextPart = current:sub(tab.cursorX)
                table.insert(tab.lines, tab.cursorY + 1, nextPart)
                tab.cursorY = tab.cursorY + 1
                tab.cursorX = 1
            end
            -- Remove the last extra split
            local lastLine = tab.lines[tab.cursorY]
            local prevLine = tab.lines[tab.cursorY - 1]
            tab.lines[tab.cursorY - 1] = prevLine .. lastLine
            table.remove(tab.lines, tab.cursorY)
            tab.cursorY = tab.cursorY - 1
            tab.cursorX = #prevLine + 1
            return true
        elseif key == "x" then
            local text = getSelectedText(tab)
            if text ~= "" then
                love.system.setClipboardText(text)
                deleteSelection(tab)
            end
            return true
        elseif key == "a" then
            tab.selectionStart = {x = 1, y = 1}
            tab.cursorY = #tab.lines
            tab.cursorX = #tab.lines[tab.cursorY] + 1
            return true
        end
    end

    local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
    if shift and not tab.selectionStart then
        tab.selectionStart = {x = tab.cursorX, y = tab.cursorY}
    end

    if key == "up" then
        tab.cursorY = math.max(1, tab.cursorY - 1)
        tab.cursorX = math.min(tab.cursorX, #tab.lines[tab.cursorY] + 1)
        if not shift then tab.selectionStart = nil end
    elseif key == "down" then
        tab.cursorY = math.min(#tab.lines, tab.cursorY + 1)
        tab.cursorX = math.min(tab.cursorX, #tab.lines[tab.cursorY] + 1)
        if not shift then tab.selectionStart = nil end
    elseif key == "left" then
        if tab.cursorX > 1 then tab.cursorX = tab.cursorX - 1
        elseif tab.cursorY > 1 then
            tab.cursorY = tab.cursorY - 1
            tab.cursorX = #tab.lines[tab.cursorY] + 1
        end
        if not shift then tab.selectionStart = nil end
    elseif key == "right" then
        if tab.cursorX <= #tab.lines[tab.cursorY] then tab.cursorX = tab.cursorX + 1
        elseif tab.cursorY < #tab.lines then
            tab.cursorY = tab.cursorY + 1
            tab.cursorX = 1
        end
        if not shift then tab.selectionStart = nil end
    elseif key == "backspace" then
        if tab.selectionStart then
            deleteSelection(tab)
            return true
        end
        local line = tab.lines[tab.cursorY]
        if tab.cursorX > 1 then
            local byteoffset = utf8.offset(line, -1)
            if byteoffset then
                tab.lines[tab.cursorY] = line:sub(1, byteoffset-1) .. line:sub(tab.cursorX)
                tab.cursorX = byteoffset
            end
        elseif tab.cursorY > 1 then
            local prevLen = #tab.lines[tab.cursorY-1]
            tab.lines[tab.cursorY-1] = tab.lines[tab.cursorY-1] .. line
            table.remove(tab.lines, tab.cursorY)
            tab.cursorY = tab.cursorY - 1
            tab.cursorX = prevLen + 1
        end
    elseif key == "return" then
        if tab.selectionStart then deleteSelection(tab) end
        local line = tab.lines[tab.cursorY]
        -- Basic auto-indent
        local indent = line:match("^%s*") or ""
        local after = line:sub(tab.cursorX)
        tab.lines[tab.cursorY] = line:sub(1, tab.cursorX-1)
        table.insert(tab.lines, tab.cursorY + 1, indent .. after)
        tab.cursorY = tab.cursorY + 1
        tab.cursorX = #indent + 1
    elseif key == "tab" then
        if tab.selectionStart then
            -- Block indent/outdent
            local _, sy, _, ey = getSelectionRange(tab)
            if sy ~= ey then
                for i = sy, ey do
                    if shift then
                        tab.lines[i] = tab.lines[i]:gsub("^    ", ""):gsub("^\t", "")
                    else
                        tab.lines[i] = "    " .. tab.lines[i]
                    end
                end
                -- Update selection/cursor to follow
                if shift then
                    tab.cursorX = math.max(1, tab.cursorX - 4)
                    if tab.selectionStart then tab.selectionStart.x = math.max(1, tab.selectionStart.x - 4) end
                else
                    tab.cursorX = tab.cursorX + 4
                    if tab.selectionStart then tab.selectionStart.x = tab.selectionStart.x + 4 end
                end
                return true
            end
        end
        -- Normal tab insertion
        local line = tab.lines[tab.cursorY]
        tab.lines[tab.cursorY] = line:sub(1, tab.cursorX-1) .. "    " .. line:sub(tab.cursorX)
        tab.cursorX = tab.cursorX + 4
        return true
    end
    return true
end

function ScriptEditor.textinput(t)
    if not ScriptEditor.visible then return false end
    local tab = ScriptEditor.tabs[ScriptEditor.activeTab]
    if not tab then return false end
    if tab.selectionStart then deleteSelection(tab) end
    local line = tab.lines[tab.cursorY]
    
    local pairs = { ["("] = ")", ["["] = "]", ["{"] = "}", ['"'] = '"', ["'"] = "'" }
    if pairs[t] then
        tab.lines[tab.cursorY] = line:sub(1, tab.cursorX-1) .. t .. pairs[t] .. line:sub(tab.cursorX)
        tab.cursorX = tab.cursorX + 1
    else
        tab.lines[tab.cursorY] = line:sub(1, tab.cursorX-1) .. t .. line:sub(tab.cursorX)
        tab.cursorX = tab.cursorX + #t
    end
    return true
end

function ScriptEditor.wheelmoved(x, y)
    if not ScriptEditor.visible then return end
    local tab = ScriptEditor.tabs[ScriptEditor.activeTab]
    if tab then tab.scrollY = math.min(0, tab.scrollY + y * 20) end
end

return ScriptEditor
