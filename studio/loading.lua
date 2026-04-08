-- studio/loading.lua
local Theme = require("studio.theme")

local Loading = {}

Loading.active = true
Loading.progress = 0
Loading.status = "Initializing..."
Loading.tasks = {}
Loading.currentTaskIndex = 1
Loading.onFinished = nil

-- For UI animations
local splashAlpha = 0
local barWidth = 0
local spinnerAngle = 0

function Loading.init(tasks, onFinished)
    Loading.tasks = tasks
    Loading.onFinished = onFinished
    Loading.active = true
    Loading.progress = 0
    Loading.currentTaskIndex = 1
    Loading.status = "Starting..."
    
    -- Reset animations
    splashAlpha = 0
    barWidth = 0
    spinnerAngle = 0
end

function Loading.update(dt)
    if not Loading.active then return end

    spinnerAngle = spinnerAngle + dt * 5

    if Loading.currentTaskIndex <= #Loading.tasks then
        local task = Loading.tasks[Loading.currentTaskIndex]
        Loading.status = task.name or "Loading..."
        
        -- Execute task
        local success, err = pcall(task.func)
        if not success then
            print("[Loading Error] " .. tostring(err))
        end
        
        Loading.currentTaskIndex = Loading.currentTaskIndex + 1
        Loading.progress = (Loading.currentTaskIndex - 1) / #Loading.tasks
    else
        Loading.progress = 1
        Loading.status = "Ready"
        Loading.active = false
        if Loading.onFinished then
            Loading.onFinished()
        end
    end
end

function Loading.draw()
    if not Loading.active then return end

    local W, H = love.graphics.getDimensions()
    local lg = love.graphics

    -- Background (Unity/Roblox dark style)
    lg.clear(Theme.colors.bg_dark)
    
    -- Draw a subtle gradient or pattern? 
    -- For now, just solid dark.

    -- Splash Logo
    local logo = Theme.assets.logo_full or Theme.assets.logo_studio
    if logo then
        local sw = W * 0.3
        local sh = sw * (logo:getHeight() / logo:getWidth())
        if sh > H * 0.4 then
            sh = H * 0.4
            sw = sh * (logo:getWidth() / logo:getHeight())
        end
        
        splashAlpha = math.min(1, splashAlpha + love.timer.getDelta() * 2)
        lg.setColor(1, 1, 1, splashAlpha)
        lg.draw(logo, W/2, H/2 - 40, 0, sw/logo:getWidth(), sh/logo:getHeight(), logo:getWidth()/2, logo:getHeight()/2)
    end

    -- Progress Bar (Roblox/Unity style)
    local barW = W * 0.4
    local barH = 4
    local barX = (W - barW) / 2
    local barY = H * 0.7
    
    -- Track
    Theme.drawRect(barX, barY, barW, barH, Theme.colors.bg_light, 2)
    
    -- Fill
    barWidth = barWidth + (barW * Loading.progress - barWidth) * (1 - math.exp(-10 * love.timer.getDelta()))
    Theme.drawRect(barX, barY, barWidth, barH, Theme.colors.text_accent, 2)

    -- Status Text
    lg.setFont(Theme.fonts.normal)
    local statusText = Loading.status .. " (" .. math.floor(Loading.progress * 100) .. "%)"
    local tw = Theme.fonts.normal:getWidth(statusText)
    Theme.drawText(statusText, (W - tw) / 2, barY + 15, Theme.colors.text_secondary)

    -- Spinner (Roblox-style)
    local spinX, spinY = W/2, barY - 40
    local spinR = 12
    lg.setLineWidth(2)
    lg.setColor(Theme.colors.text_accent)
    lg.arc("line", "open", spinX, spinY, spinR, spinnerAngle, spinnerAngle + math.pi * 1.5)
    
    -- Version (Bottom-Right)
    local version = "v0.0.1-dev"
    local vw = Theme.fonts.small:getWidth(version)
    Theme.drawText(version, W - vw - 20, H - 30, Theme.colors.text_disabled, Theme.fonts.small)

    -- Project Name (Top-Center)
    local projectName = "LUVÖXEL STUDIO"
    lg.setFont(Theme.fonts.header)
    local pnw = Theme.fonts.header:getWidth(projectName)
    Theme.drawText(projectName, (W - pnw) / 2, H * 0.2, Theme.colors.text_primary)
end

return Loading
