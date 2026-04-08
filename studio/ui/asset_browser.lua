-- studio/ui/asset_browser.lua
-- Asset Browser panel

local Theme = require("studio.theme")
local Instance = require("engine.instance")
local Part = require("engine.part")
local Script = require("engine.script")

local AssetBrowser = {}

AssetBrowser.currentPath = "assets"
AssetBrowser.items = {}
AssetBrowser.scrollY = 0
AssetBrowser.needsRefresh = true
AssetBrowser.selectedItem = nil
AssetBrowser.itemRects = {}
AssetBrowser.rowHeight = 24

-- Icons for file types
local function getFileIcon(isDir, name)
    if isDir then return "📁", Theme.colors.folder_icon or {1, 0.8, 0.4, 1} end
    local ext = name:match("^.+(%..+)$")
    if not ext then return "📄", Theme.colors.text_secondary end
    ext = ext:lower()
    
    if ext == ".lua" then return "📜", {0.4, 0.8, 1, 1} end
    if ext == ".png" or ext == ".jpg" or ext == ".jpeg" then return "🖼️", {0.8, 0.4, 0.8, 1} end
    if ext == ".obj" then return "🧊", {0.4, 1, 0.4, 1} end
    if ext == ".wav" or ext == ".ogg" or ext == ".mp3" then return "🎵", {1, 0.6, 0.2, 1} end
    if ext == ".ttf" or ext == ".otf" then return "A", {1, 1, 1, 1} end
    
    return "📄", Theme.colors.text_secondary
end

function AssetBrowser.refresh()
    AssetBrowser.items = {}
    
    -- Add up directory if not at root
    if AssetBrowser.currentPath ~= "" then
        table.insert(AssetBrowser.items, {
            name = "..",
            path = AssetBrowser.currentPath:match("^(.*)/[^/]+$") or "",
            isDir = true,
            icon = "📁",
            color = {1, 0.8, 0.4, 1}
        })
    end
    
    local files = love.filesystem.getDirectoryItems(AssetBrowser.currentPath)
    
    -- Separate dirs and files to sort dirs first
    local dirs = {}
    local regFiles = {}
    
    for _, file in ipairs(files) do
        local fullPath = AssetBrowser.currentPath == "" and file or (AssetBrowser.currentPath .. "/" .. file)
        local info = love.filesystem.getInfo(fullPath)
        
        if info then
            local isDir = info.type == "directory"
            local icon, color = getFileIcon(isDir, file)
            local item = {
                name = file,
                path = fullPath,
                isDir = isDir,
                icon = icon,
                color = color
            }
            if isDir then
                table.insert(dirs, item)
            else
                table.insert(regFiles, item)
            end
        end
    end
    
    table.sort(dirs, function(a, b) return a.name:lower() < b.name:lower() end)
    table.sort(regFiles, function(a, b) return a.name:lower() < b.name:lower() end)
    
    for _, d in ipairs(dirs) do table.insert(AssetBrowser.items, d) end
    for _, f in ipairs(regFiles) do table.insert(AssetBrowser.items, f) end
    
    AssetBrowser.needsRefresh = false
    AssetBrowser.scrollY = 0
end

function AssetBrowser.load()
    AssetBrowser.refresh()
end

function AssetBrowser.update(dt)
    if AssetBrowser.needsRefresh then
        AssetBrowser.refresh()
    end
end

function AssetBrowser.draw(panelX, panelY, panelW, panelH)
    local mx, my = love.mouse.getPosition()
    
    -- Panel background
    Theme.drawRect(panelX, panelY, panelW, panelH, Theme.colors.bg_dark)
    
    -- Top bar (Path)
    local topBarH = 24
    Theme.drawRect(panelX, panelY, panelW, topBarH, Theme.colors.bg_medium)
    Theme.drawText("Path: " .. (AssetBrowser.currentPath == "" and "/" or AssetBrowser.currentPath), panelX + 8, panelY + 4, Theme.colors.text_primary, Theme.fonts.small)
    Theme.drawDivider(panelX, panelY + topBarH - 1, panelW, 1, false)
    
    -- Content Area
    local contentY = panelY + topBarH
    local contentH = panelH - topBarH
    
    love.graphics.setScissor(panelX, contentY, panelW, contentH)
    
    AssetBrowser.itemRects = {}
    local yOff = contentY + 2 + AssetBrowser.scrollY
    local rh = AssetBrowser.rowHeight
    
    for i, item in ipairs(AssetBrowser.items) do
        if yOff + rh >= contentY and yOff < contentY + contentH then
            local isSelected = (AssetBrowser.selectedItem == item)
            local isHovered = Theme.inRect(mx, my, panelX, yOff, panelW, rh)
            
            if isSelected then
                Theme.drawRect(panelX, yOff, panelW, rh, Theme.colors.bg_selected)
            elseif isHovered then
                Theme.drawRect(panelX, yOff, panelW, rh, Theme.colors.bg_hover)
            end
            
            -- Icon
            love.graphics.setFont(Theme.fonts.normal)
            Theme.setColor(item.color)
            love.graphics.print(item.icon, panelX + 8, yOff + 1)
            
            -- Name
            Theme.setColor(Theme.colors.text_primary)
            love.graphics.print(item.name, panelX + 28, yOff + 1)
            
            table.insert(AssetBrowser.itemRects, {
                x = panelX, y = yOff, w = panelW, h = rh, item = item
            })
        end
        yOff = yOff + rh
    end
    
    love.graphics.setScissor()
    
    -- Scrollbar
    local totalContentH = #AssetBrowser.items * rh
    if totalContentH > contentH then
        local sbH = math.max(20, contentH * (contentH / totalContentH))
        local sbY = contentY + (-AssetBrowser.scrollY / totalContentH) * contentH
        Theme.drawRect(panelX + panelW - 6, sbY, 4, sbH, Theme.colors.bg_hover, 2)
    end
end

local function handleDoubleClick(item)
    if item.isDir then
        AssetBrowser.currentPath = item.path
        AssetBrowser.refresh()
        return
    end
    
    -- File actions
    local ext = item.name:match("^.+(%..+)$")
    if not ext then return end
    ext = ext:lower()
    
    if ext == ".png" or ext == ".jpg" or ext == ".jpeg" then
        local part = Part.new(item.name:gsub("%..+$", ""))
        part.Position = Engine.Workspace and Engine.Workspace:GetChildren()[1] and Engine.Workspace:GetChildren()[1].Position or Vector3.new(0, 5, 0)
        part:setTexture(item.path)
        part.Parent = Engine.Workspace
        if Engine.History then Engine.History:recordCreate(part, part.Parent) end
        print("[AssetBrowser] Inserted Part with texture: " .. item.name)
    elseif ext == ".obj" then
        local part = Part.new(item.name:gsub("%..+$", ""))
        part.Position = Engine.Workspace and Engine.Workspace:GetChildren()[1] and Engine.Workspace:GetChildren()[1].Position or Vector3.new(0, 5, 0)
        -- The engine has specific shapes registered for .obj files.
        -- If it's not registered, we would need to add it to Part.SHAPES or handle custom meshes.
        -- We can just set shape if it's already there, or we could add it dynamically.
        Part.SHAPES[item.name] = item.path
        part:setShape(item.name)
        part.Parent = Engine.Workspace
        if Engine.History then Engine.History:recordCreate(part, part.Parent) end
        print("[AssetBrowser] Inserted Part with mesh: " .. item.name)
    elseif ext == ".lua" then
        local script = Script.new(item.name:gsub("%..+$", ""))
        local content = love.filesystem.read(item.path)
        if content then
            script.Source = content
        end
        script.Parent = Engine.Workspace
        if Engine.History then Engine.History:recordCreate(script, script.Parent) end
        print("[AssetBrowser] Inserted Script from: " .. item.name)
    end
end

function AssetBrowser.mousepressed(x, y, button, panelX, panelY, panelW, panelH)
    local topBarH = 24
    if Theme.inRect(x, y, panelX, panelY, panelW, topBarH) then
        return true -- clicked top bar
    end
    
    local contentY = panelY + topBarH
    local contentH = panelH - topBarH
    
    if Theme.inRect(x, y, panelX, contentY, panelW, contentH) then
        if button == 1 then
            for _, rect in ipairs(AssetBrowser.itemRects) do
                if Theme.inRect(x, y, rect.x, rect.y, rect.w, rect.h) then
                    AssetBrowser.selectedItem = rect.item
                    
                    -- Double click detection
                    local now = os.clock()
                    if AssetBrowser._lastClick and AssetBrowser._lastClick.item == rect.item and (now - AssetBrowser._lastClick.time < 0.3) then
                        handleDoubleClick(rect.item)
                    end
                    AssetBrowser._lastClick = {item = rect.item, time = now}
                    
                    return true
                end
            end
            AssetBrowser.selectedItem = nil
            return true
        end
    end
    
    return false
end

function AssetBrowser.wheelmoved(x, y, panelX, panelY, panelW, panelH)
    local mx, my = love.mouse.getPosition()
    if Theme.inRect(mx, my, panelX, panelY, panelW, panelH) then
        AssetBrowser.scrollY = math.min(0, AssetBrowser.scrollY + y * 24)
        return true
    end
    return false
end

return AssetBrowser
