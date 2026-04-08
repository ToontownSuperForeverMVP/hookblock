-- studio/start_menu.lua
local Theme = require("studio.theme")

local StartMenu = {}

StartMenu.projects = {}
StartMenu.selectedIndex = nil
StartMenu.newProjectName = ""
StartMenu.isTypingNew = false
StartMenu.onStart = nil -- Callback for when a project is selected/created

function StartMenu.init(onStartCallback)
    StartMenu.onStart = onStartCallback
    StartMenu.refreshProjects()
end

function StartMenu.refreshProjects()
    StartMenu.projects = {}
    if not love.filesystem.getInfo("projects", "directory") then
        love.filesystem.createDirectory("projects")
    end

    local items = love.filesystem.getDirectoryItems("projects")
    for _, item in ipairs(items) do
        if love.filesystem.getInfo("projects/" .. item, "directory") then
            table.insert(StartMenu.projects, item)
        end
    end
end

function StartMenu.update(dt)
end

function StartMenu.draw()
    local w, h = love.graphics.getDimensions()
    
    -- Background
    Theme.drawRect(0, 0, w, h, Theme.colors.bg_dark)
    
    -- Title
    love.graphics.setFont(Theme.fonts.large)
    Theme.setColor(Theme.colors.text_primary)
    love.graphics.printf("Luvöxel Studio", 0, h * 0.1, w, "center")
    
    local panelW, panelH = 400, 400
    local panelX, panelY = (w - panelW) / 2, (h - panelH) / 2
    
    -- Panel BG
    Theme.drawRect(panelX, panelY, panelW, panelH, Theme.colors.bg_medium, 8)
    Theme.drawBorder(panelX, panelY, panelW, panelH, Theme.colors.border, 2)
    
    -- List Projects
    Theme.drawText("Recent Projects:", panelX + 20, panelY + 20, Theme.colors.text_primary, Theme.fonts.normal)
    
    local listY = panelY + 50
    local listH = 200
    Theme.drawRect(panelX + 20, listY, panelW - 40, listH, Theme.colors.bg_dark, 4)
    
    for i, proj in ipairs(StartMenu.projects) do
        local itemY = listY + (i - 1) * 30
        if itemY + 30 <= listY + listH then
            if StartMenu.selectedIndex == i then
                Theme.drawRect(panelX + 20, itemY, panelW - 40, 30, Theme.colors.bg_selected)
            end
            local mx, my = love.mouse.getPosition()
            if Theme.inRect(mx, my, panelX + 20, itemY, panelW - 40, 30) and StartMenu.selectedIndex ~= i then
                Theme.drawRect(panelX + 20, itemY, panelW - 40, 30, Theme.colors.bg_hover)
            end
            Theme.drawText(proj, panelX + 30, itemY + 6, Theme.colors.text_primary, Theme.fonts.normal)
        end
    end
    
    -- Load Button
    local btnW, btnH = 100, 30
    local loadBtnX = panelX + panelW - 20 - btnW
    local loadBtnY = listY + listH + 10
    local mx, my = love.mouse.getPosition()
    
    local loadHover = Theme.inRect(mx, my, loadBtnX, loadBtnY, btnW, btnH)
    Theme.drawRect(loadBtnX, loadBtnY, btnW, btnH, loadHover and Theme.colors.bg_hover or Theme.colors.bg_light, 4)
    Theme.drawText("Load", loadBtnX + 32, loadBtnY + 6, StartMenu.selectedIndex and Theme.colors.text_primary or Theme.colors.text_disabled, Theme.fonts.normal)
    
    Theme.drawDivider(panelX + 20, loadBtnY + 50, panelW - 40, 1, false)
    
    -- New Project Area
    local newY = loadBtnY + 60
    Theme.drawText("New Project:", panelX + 20, newY, Theme.colors.text_primary, Theme.fonts.normal)
    
    local inputX, inputY, inputW, inputH = panelX + 20, newY + 25, panelW - 140, 30
    Theme.drawRect(inputX, inputY, inputW, inputH, Theme.colors.bg_dark, 4)
    if StartMenu.isTypingNew then
        Theme.drawBorder(inputX, inputY, inputW, inputH, Theme.colors.text_accent, 1)
    end
    
    local dispText = StartMenu.newProjectName
    if dispText == "" and not StartMenu.isTypingNew then
        Theme.drawText("Project Name...", inputX + 10, inputY + 6, Theme.colors.text_disabled, Theme.fonts.normal)
    else
        Theme.drawText(dispText, inputX + 10, inputY + 6, Theme.colors.text_primary, Theme.fonts.normal)
        if StartMenu.isTypingNew and (math.floor(os.clock() * 2) % 2 == 0) then
            local tw = Theme.fonts.normal:getWidth(dispText)
            Theme.drawRect(inputX + 12 + tw, inputY + 6, 2, 16, Theme.colors.text_primary)
        end
    end
    
    local createBtnX = inputX + inputW + 10
    local createBtnY = inputY
    local createHover = Theme.inRect(mx, my, createBtnX, createBtnY, btnW, btnH)
    local canCreate = #StartMenu.newProjectName > 0
    Theme.drawRect(createBtnX, createBtnY, btnW, btnH, createHover and Theme.colors.bg_hover or Theme.colors.bg_light, 4)
    Theme.drawText("Create", createBtnX + 25, createBtnY + 6, canCreate and Theme.colors.text_primary or Theme.colors.text_disabled, Theme.fonts.normal)
end

function StartMenu.mousepressed(x, y, button)
    if button ~= 1 then return end
    
    local w, h = love.graphics.getDimensions()
    local panelW, panelH = 400, 400
    local panelX, panelY = (w - panelW) / 2, (h - panelH) / 2
    
    -- List Projects
    local listY = panelY + 50
    local listH = 200
    if Theme.inRect(x, y, panelX + 20, listY, panelW - 40, listH) then
        local index = math.floor((y - listY) / 30) + 1
        if index > 0 and index <= #StartMenu.projects then
            StartMenu.selectedIndex = index
        else
            StartMenu.selectedIndex = nil
        end
    end
    
    -- Load Button
    local btnW, btnH = 100, 30
    local loadBtnX = panelX + panelW - 20 - btnW
    local loadBtnY = listY + listH + 10
    if StartMenu.selectedIndex and Theme.inRect(x, y, loadBtnX, loadBtnY, btnW, btnH) then
        local projName = StartMenu.projects[StartMenu.selectedIndex]
        if StartMenu.onStart then StartMenu.onStart(projName, false) end
        return
    end
    
    -- New Project Input
    local newY = loadBtnY + 60
    local inputX, inputY, inputW, inputH = panelX + 20, newY + 25, panelW - 140, 30
    if Theme.inRect(x, y, inputX, inputY, inputW, inputH) then
        StartMenu.isTypingNew = true
        StartMenu.selectedIndex = nil
    else
        StartMenu.isTypingNew = false
    end
    
    -- Create Button
    local createBtnX = inputX + inputW + 10
    local createBtnY = inputY
    if #StartMenu.newProjectName > 0 and Theme.inRect(x, y, createBtnX, createBtnY, btnW, btnH) then
        -- Validate name doesn't exist
        local exists = false
        for _, p in ipairs(StartMenu.projects) do
            if p == StartMenu.newProjectName then exists = true break end
        end
        
        if not exists then
            love.filesystem.createDirectory("projects/" .. StartMenu.newProjectName)
            if StartMenu.onStart then StartMenu.onStart(StartMenu.newProjectName, true) end
        else
            print("[StartMenu] Project already exists!")
        end
    end
end

function StartMenu.keypressed(key)
    if StartMenu.isTypingNew then
        if key == "backspace" then
            local utf8 = require("utf8")
            local byteoffset = utf8.offset(StartMenu.newProjectName, -1)
            if byteoffset then
                StartMenu.newProjectName = string.sub(StartMenu.newProjectName, 1, byteoffset - 1)
            end
        elseif key == "return" then
            StartMenu.isTypingNew = false
        elseif key == "escape" then
            StartMenu.isTypingNew = false
        end
    end
end

function StartMenu.textinput(t)
    if StartMenu.isTypingNew then
        -- Simple validation (alphanumeric, spaces, dashes, underscores)
        if t:match("[%w%s%-_]") then
            StartMenu.newProjectName = StartMenu.newProjectName .. t
        end
    end
end

return StartMenu
