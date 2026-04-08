-- studio/ui/explorer.lua
-- Instance tree panel (left-side of right column)

local Theme = require("studio.theme")
local Instance = require("engine.instance")
local utf8 = require("utf8")

local Explorer = {}

Explorer.scrollY       = 0
Explorer.selectedInst  = nil
Explorer.collapsed     = {}
Explorer.contextTarget = nil
Explorer.showContext   = false
Explorer.contextX, Explorer.contextY = 0, 0
Explorer.searchText    = ""
Explorer.searchFocused = false

local rowRects = {}
local flatList = {}
local needsRefresh = true

-- Class icons (Unicode symbols that exist in DejaVuSans)
local CLASS_ICONS = {
    DataModel     = "➲",
    Lighting      = "💡",
    Workspace     = "⌂",
    Part          = "■",
    SpawnLocation = "◉",
    Model         = "◆",
    Folder        = "▣",
    Humanoid      = "☺",
    Script        = "☰",
    ModuleScript  = "⚙",
    BoolValue     = "✔",
    StringValue   = "✍",
    NumberValue   = "#",
    IntValue      = "1",
    Color3Value   = "🎨",
    Vector3Value  = "↗",
    StarterGui    = "📺",
    ReplicatedStorage = "📦",
    ServerStorage = "🔒",
    Players       = "👥",
}

local function getClassIcon(className)
    return CLASS_ICONS[className] or "○"
end

-- Class icon colors
local CLASS_COLORS = {
    DataModel     = {1, 1, 1, 1},
    Lighting      = {1, 1, 0.4, 1},
    Workspace     = {0.55, 0.80, 1.00, 1},
    Part          = {0.65, 0.65, 0.65, 1},
    SpawnLocation = {0.30, 0.85, 0.35, 1},
    Model         = {1.00, 0.75, 0.30, 1},
    Folder        = {1.00, 0.85, 0.40, 1},
    Humanoid      = {0.85, 0.55, 0.55, 1},
    Script        = {0.55, 0.75, 1.00, 1},
    ModuleScript  = {1.00, 1.00, 0.60, 1},
    BoolValue     = {0.40, 0.70, 1.00, 1},
    StringValue   = {1.00, 0.60, 0.40, 1},
    NumberValue   = {0.60, 1.00, 0.60, 1},
    IntValue      = {0.60, 1.00, 0.60, 1},
    ReplicatedStorage = {1, 0.8, 0.2, 1},
    ServerStorage = {0.8, 0.4, 0.4, 1},
    StarterGui    = {0.4, 0.8, 0.4, 1},
}

local function getClassColor(className)
    return CLASS_COLORS[className] or Theme.colors.text_secondary
end

local function insertObject(className, parent)
    local obj = Instance.new(className)
    if not obj then return end
    
    obj.Parent = parent or Engine.Workspace
    if Engine.History then
        Engine.History:recordCreate(obj, obj.Parent)
    end
    if _G._UI then _G._UI.selectedInstance = obj end
    
    needsRefresh = true
    print("[Luvoxel] Inserted " .. className .. " under " .. (obj.Parent.Name))
    return obj
end

local CONTEXT_ITEMS = {
    {label = "Insert Part", action = function(inst) insertObject("Part", inst) end},
    {label = "Insert Model", action = function(inst) insertObject("Model", inst) end},
    {label = "Insert Folder", action = function(inst) insertObject("Folder", inst) end},
    {label = "Insert Script", action = function(inst) insertObject("Script", inst) end},
    {label = "Insert ModuleScript", action = function(inst) insertObject("ModuleScript", inst) end},
    {label = "Values >", sub = {
        {label = "BoolValue", action = function(inst) insertObject("BoolValue", inst) end},
        {label = "NumberValue", action = function(inst) insertObject("NumberValue", inst) end},
        {label = "StringValue", action = function(inst) insertObject("StringValue", inst) end},
        {label = "Vector3Value", action = function(inst) insertObject("Vector3Value", inst) end},
        {label = "Color3Value", action = function(inst) insertObject("Color3Value", inst) end},
    }},
    {label = "---"},
    {label = "Rename", action = function(inst) end},
    {label = "Duplicate",
        action = function(inst)
            if inst and inst.Clone and inst.ClassName ~= "Workspace" and inst.ClassName ~= "DataModel" then
                local clone = inst:Clone()
                if clone.Position then clone.Position.x = clone.Position.x + 2 end
                clone.Parent = inst.Parent or Engine.Workspace
                if _G._UI then _G._UI.selectedInstance = clone end
                needsRefresh = true
            end
        end
    },
    {label = "Delete",
        action = function(inst)
            if inst and inst.Parent and inst.ClassName ~= "Workspace" and inst.ClassName ~= "DataModel" then
                local parent = inst.Parent
                if Engine.History then Engine.History:recordDelete(inst, parent) end
                inst.Parent = nil
                if _G._UI then _G._UI.selectedInstance = nil end
                needsRefresh = true
            end
        end
    },
}

local function refreshFlatList()
    flatList = {}
    local function collect(inst, depth)
        if not inst then return end
        local node = {inst = inst, depth = depth}
        table.insert(flatList, node)

        local children = inst:GetChildren()
        if #children > 0 and not Explorer.collapsed[inst] then
            for _, child in ipairs(children) do
                collect(child, depth + 1)
            end
        end
    end

    if Engine.Game then
        collect(Engine.Game, 0)
    else
        collect(Engine.Workspace, 0)
    end
    needsRefresh = false
end

local contextRects = {}
local submenuRects = {}
local activeSubmenu = nil

function Explorer.load() end
function Explorer.update(dt) 
    -- Periodic refresh check
    Explorer._refreshTimer = (Explorer._refreshTimer or 0) + dt
    if Explorer._refreshTimer > 1.0 then
        needsRefresh = true
        Explorer._refreshTimer = 0
    end
end

function Explorer.draw(panelX, panelY, panelW, panelH)
    local mx, my = love.mouse.getPosition()

    -- Panel background
    Theme.drawRect(panelX, panelY, panelW, panelH, Theme.colors.bg_dark)

    -- Search bar toggle/focus icon
    local searchX = panelX + panelW - 22
    local searchHov = Theme.inRect(mx, my, searchX, panelY + 2, 18, 18)
    if searchHov or Explorer.searchFocused then
        Theme.drawRect(searchX, panelY + 2, 18, 18, Theme.colors.bg_hover, 3)
    end
    Theme.drawIcon(searchX + 3, panelY + 4, "🔍",
        Explorer.searchFocused and Theme.colors.text_accent or Theme.colors.text_secondary,
        Theme.fonts.tiny)

    -- Search input field
    local searchBarH = 0
    if Explorer.searchFocused or Explorer.searchText ~= "" then
        searchBarH = 24
        Theme.drawRect(panelX, panelY, panelW, searchBarH, Theme.colors.bg_medium)
        local ix, iy, iw, ih = panelX + 4, panelY + 3, panelW - 8, 18
        Theme.drawRect(ix, iy, iw, ih, Theme.colors.bg_light, 2)
        Theme.drawBorder(ix, iy, iw, ih, Explorer.searchFocused and Theme.colors.border_focus or Theme.colors.border, 1)

        if Explorer.searchText == "" and not Explorer.searchFocused then
            Theme.drawText("Search...", ix + 6, iy + 2, Theme.colors.text_disabled, Theme.fonts.small)
        else
            Theme.drawText(Explorer.searchText, ix + 6, iy + 2, Theme.colors.text_primary, Theme.fonts.small)
            if Explorer.searchFocused and (math.floor(os.clock() * 2) % 2 == 0) then
                local tw = Theme.fonts.small:getWidth(Explorer.searchText)
                Theme.drawRect(ix + 6 + tw, iy + 3, 1, 12, Theme.colors.text_accent)
            end
        end

        if Explorer.searchText ~= "" then
            local clX = ix + iw - 16
            Theme.drawText("×", clX, iy + 1, Explorer._clearSearchHover and Theme.colors.text_primary or Theme.colors.text_secondary, Theme.fonts.normal)
        end
        Theme.drawDivider(panelX, panelY + searchBarH - 1, panelW, 1, false)
    end

    -- Clip content
    local contentY = panelY + searchBarH
    local contentH = panelH - searchBarH
    love.graphics.setScissor(panelX, contentY, panelW, contentH)

    if needsRefresh then refreshFlatList() end

    rowRects = {}
    local rh = Theme.layout.row_h
    local yOff = contentY + 2 + Explorer.scrollY

    for i, node in ipairs(flatList) do
        local inst = node.inst
        local depth = node.depth
        
        -- Filter check
        local matches = true
        if Explorer.searchText ~= "" then
            matches = inst.Name:lower():find(Explorer.searchText:lower(), 1, true) ~= nil
        end

        if matches then
            -- Skip drawing if off screen
            if yOff + rh >= contentY and yOff < contentY + contentH then
                local ry = yOff
                local isSelected = (_G._UI and _G._UI.selectedInstance == inst)
                local isHovered  = Theme.inRect(mx, my, panelX, ry, panelW, rh)

                if isSelected then Theme.drawRect(panelX, ry, panelW, rh, Theme.colors.bg_selected)
                elseif isHovered then Theme.drawRect(panelX, ry, panelW, rh, Theme.colors.bg_hover) end

                local ix = panelX + 6 + depth * Theme.layout.indent_w
                local children = inst:GetChildren()
                local hasChildren = #children > 0
                if hasChildren then
                    local collapsed = Explorer.collapsed[inst]
                    love.graphics.setFont(Theme.fonts.tiny)
                    Theme.setColor(Theme.colors.text_secondary)
                    love.graphics.print(collapsed and "▶" or "▼", ix, ry + 5)
                end

                local icon = getClassIcon(inst.ClassName)
                local iconColor = getClassColor(inst.ClassName)
                love.graphics.setFont(Theme.fonts.normal)
                Theme.setColor(iconColor)
                love.graphics.print(icon, ix + 14, ry + 1)

                Theme.setColor(Theme.colors.text_primary)
                love.graphics.print(inst.Name, ix + 28, ry + 1)

                local classW = Theme.fonts.small:getWidth(inst.ClassName)
                love.graphics.setFont(Theme.fonts.small)
                Theme.setColor(Theme.colors.text_secondary)
                love.graphics.print(inst.ClassName, panelX + panelW - classW - 6, ry + 5)

                table.insert(rowRects, {x = panelX, y = ry, w = panelW, h = rh, inst = inst,
                                         arrowX = ix, arrowW = 14, hasChildren = hasChildren})
            end
            yOff = yOff + rh
        end
    end
    
    love.graphics.setScissor()

    -- Scrollbar
    local totalContentH = yOff - (contentY + 2 + Explorer.scrollY)
    if totalContentH > contentH then
        local sbH = math.max(20, contentH * (contentH / totalContentH))
        local sbY = contentY + (-Explorer.scrollY / totalContentH) * contentH
        Theme.drawRect(panelX + panelW - 6, sbY, 4, sbH, Theme.colors.bg_hover, 2)
    end

    -- Context menu
    if Explorer.showContext then
        local cmW = 180
        local rh2 = 22
        local cmH = #CONTEXT_ITEMS * rh2 + 4
        local cmX, cmY = Explorer.contextX, Explorer.contextY
        local W, H = love.graphics.getDimensions()
        if cmX + cmW > W then cmX = W - cmW end
        if cmY + cmH > H then cmY = H - cmH end

        Theme.drawRect(cmX, cmY, cmW, cmH, Theme.colors.bg_medium, 2)
        Theme.drawBorder(cmX, cmY, cmW, cmH, Theme.colors.border, 1)

        contextRects = {}
        local iy = cmY + 2
        for j, item in ipairs(CONTEXT_ITEMS) do
            if item.label == "---" then Theme.drawDivider(cmX + 4, iy + rh2 / 2, cmW - 8, 1, false)
            else
                if Theme.inRect(mx, my, cmX, iy, cmW, rh2) then
                    Theme.drawRect(cmX + 2, iy + 1, cmW - 4, rh2 - 2, Theme.colors.bg_hover, 2)
                    if item.sub then activeSubmenu = {items = item.sub, x = cmX + cmW, y = iy} end
                end
                Theme.drawText(item.label, cmX + 10, iy + 4, Theme.colors.text_primary, Theme.fonts.normal)
                if item.sub then Theme.drawText(">", cmX + cmW - 15, iy + 4, Theme.colors.text_secondary, Theme.fonts.normal) end
            end
            contextRects[j] = {x = cmX, y = iy, w = cmW, h = rh2, item = item}
            iy = iy + rh2
        end
        
        if activeSubmenu then
            local sub = activeSubmenu
            local smW, smH = 150, #sub.items * rh2 + 4
            Theme.drawRect(sub.x, sub.y, smW, smH, Theme.colors.bg_medium, 2)
            Theme.drawBorder(sub.x, sub.y, smW, smH, Theme.colors.border, 1)
            submenuRects = {}
            local siy = sub.y + 2
            for k, sitem in ipairs(sub.items) do
                if Theme.inRect(mx, my, sub.x, siy, smW, rh2) then Theme.drawRect(sub.x + 2, siy + 1, smW - 4, rh2 - 2, Theme.colors.bg_hover, 2) end
                Theme.drawText(sitem.label, sub.x + 10, siy + 4, Theme.colors.text_primary, Theme.fonts.normal)
                submenuRects[k] = {x = sub.x, y = siy, w = smW, h = rh2, item = sitem}
                siy = siy + rh2
            end
            if not Theme.inRect(mx, my, cmX, cmY, cmW, cmH) and not Theme.inRect(mx, my, sub.x, sub.y, smW, smH) then activeSubmenu = nil end
        end
    end
end

function Explorer.mousepressed(x, y, button, panelX, panelY, panelW, panelH)
    if Explorer.showContext then
        for _, rect in ipairs(submenuRects) do
            if Theme.inRect(x, y, rect.x, rect.y, rect.w, rect.h) then
                if rect.item.action then rect.item.action(Explorer.contextTarget) end
                Explorer.showContext = false return true
            end
        end
        for _, rect in ipairs(contextRects) do
            if Theme.inRect(x, y, rect.x, rect.y, rect.w, rect.h) then
                if rect.item.action then rect.item.action(Explorer.contextTarget) end
                if not rect.item.sub then Explorer.showContext = false return true end
                return true
            end
        end
        Explorer.showContext = false return true
    end

    if not Theme.inRect(x, y, panelX, panelY, panelW, panelH) then Explorer.searchFocused = false return false end

    local searchX = panelX + panelW - 22
    if Theme.inRect(x, y, searchX, panelY + 2, 18, 18) then Explorer.searchFocused = not Explorer.searchFocused return true end

    local searchBarH = (Explorer.searchFocused or Explorer.searchText ~= "") and 24 or 0
    if searchBarH > 0 and Theme.inRect(x, y, panelX, panelY, panelW, searchBarH) then
        local clX = panelX + panelW - 20
        if Explorer.searchText ~= "" and Theme.inRect(x, y, clX, panelY + 3, 16, 18) then
            Explorer.searchText = "" needsRefresh = true return true
        end
        Explorer.searchFocused = true return true
    end

    Explorer.searchFocused = false

    if button == 2 then
        for _, rect in ipairs(rowRects) do
            if Theme.inRect(x, y, rect.x, rect.y, rect.w, rect.h) then
                Explorer.contextTarget, Explorer.contextX, Explorer.contextY, Explorer.showContext = rect.inst, x, y, true
                return true
            end
        end
        Explorer.contextTarget, Explorer.contextX, Explorer.contextY, Explorer.showContext = Engine.Workspace, x, y, true
        return true
    end

    if button == 1 then
        for _, rect in ipairs(rowRects) do
            if Theme.inRect(x, y, rect.x, rect.y, rect.w, rect.h) then
                if rect.hasChildren and Theme.inRect(x, y, rect.arrowX, rect.y, rect.arrowW, rect.h) then
                    Explorer.collapsed[rect.inst] = not Explorer.collapsed[rect.inst]
                    needsRefresh = true
                else
                    if _G._UI then _G._UI.selectedInstance = rect.inst end
                    local now = os.clock()
                    if Explorer._lastClick and Explorer._lastClick.inst == rect.inst and (now - Explorer._lastClick.time < 0.3) then
                        if rect.inst.ClassName == "Script" or rect.inst.ClassName == "ModuleScript" then
                            require("studio.ui.script_editor").openScript(rect.inst.Name, rect.inst.Source, rect.inst)
                        end
                    end
                    Explorer._lastClick = {inst = rect.inst, time = now}
                end
                return true
            end
        end
    end
    return false
end

function Explorer.keypressed(key)
    if not Explorer.searchFocused then return false end
    if key == "backspace" then
        local byteoffset = utf8.offset(Explorer.searchText, -1)
        if byteoffset then Explorer.searchText = Explorer.searchText:sub(1, byteoffset - 1) end
    elseif key == "escape" or key == "return" then Explorer.searchFocused = false end
    needsRefresh = true
    return true
end

function Explorer.textinput(t)
    if not Explorer.searchFocused then return false end
    Explorer.searchText = Explorer.searchText .. t
    needsRefresh = true
    return true
end

function Explorer.wheelmoved(x, y, panelX, panelY, panelW, panelH)
    local mx, my = love.mouse.getPosition()
    if Theme.inRect(mx, my, panelX, panelY, panelW, panelH) then
        Explorer.scrollY = math.min(0, Explorer.scrollY + y * 18)
    end
end

return Explorer
