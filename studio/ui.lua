-- studio/ui.lua
-- Main UI compositor — wires all sub-panels together and manages layout

local Theme           = require("studio.theme")
local MenuBar         = require("studio.ui.menubar")
local Toolbar         = require("studio.ui.toolbar")
local Explorer        = require("studio.ui.explorer")
local Properties      = require("studio.ui.properties")
local Output          = require("studio.ui.output")
local AssetBrowser    = require("studio.ui.asset_browser")
local AnimationEditor = require("studio.ui.animation_editor")
local TerrainEditor   = require("studio.ui.terrain_editor")
local ColorPicker     = require("studio.ui.color_picker")
local ViewportGizmo   = require("studio.ui.viewport_gizmo")
local ScriptEditor    = require("studio.ui.script_editor")
local StatusBar       = require("studio.ui.status_bar")
local Notifications   = require("studio.ui.notifications")
local AboutDialog     = require("studio.ui.about_dialog")

local UI = {}

-- Localize for performance
local lg = love.graphics
local math_floor = math.floor

-- Shared selection state (exposed as a global so sub-modules can read/write it)
UI.selectedInstance = nil
UI.activeTab = "Viewport" -- "Viewport" or "Script"
UI.activeBottomTab = "Output" -- "Output", "Assets", "Animation"
UI.activeRightTab = "Properties" -- "Properties", "Terrain"
_G._UI = UI
_G._Notifications = Notifications

-- Panel visibility and floating state
UI.panelState = {
    explorer   = { visible = true, pinned = true, x = 100, y = 100, w = 260, h = 400 },
    properties = { visible = true, pinned = true, x = 400, y = 100, w = 260, h = 400 },
    output     = { visible = true, pinned = true, x = 100, y = 550, w = 600, h = 200 },
}

-- Camera slider interaction
UI.draggingCameraSpeed = false

-- Dragging/Resizing state
UI.draggingPanel = nil
UI.resizingPanel = nil
UI.dragOffsetX = 0
UI.dragOffsetY = 0

-- Layout cache
local cachedLayout = {}
local layoutDirty = true

function UI.togglePanel(name)
    if UI.panelState[name] then
        UI.panelState[name].visible = not UI.panelState[name].visible
        layoutDirty = true
    end
end

-- Layout calculation
function UI.getLayout()
    if not layoutDirty then return cachedLayout end

    local W  = lg.getWidth()
    local H  = lg.getHeight()
    local L  = Theme.layout

    local menuH    = L.menu_h
    local toolH    = L.toolbar_h
    local statH    = L.statusbar_h
    local tabH     = L.viewport_tab_h
    local topH     = menuH + toolH + tabH

    local hasPinnedRight = (UI.panelState.explorer.visible and UI.panelState.explorer.pinned) or
                           (UI.panelState.properties.visible and UI.panelState.properties.pinned)
    local rightW   = hasPinnedRight and L.explorer_w or 0

    local hasPinnedBottom = UI.panelState.output.visible and UI.panelState.output.pinned
    local outH     = hasPinnedBottom and L.output_h or 0
    local bTabH    = hasPinnedBottom and 24 or 0

    local viewW    = W - rightW
    local viewH    = H - topH - outH - bTabH - statH
    local viewX    = 0
    local viewY    = topH

    local rightX   = viewW
    local rightY   = menuH + toolH

    -- Calculate right panel heights based on which ones are pinned and visible
    local expPinned = UI.panelState.explorer.visible and UI.panelState.explorer.pinned
    local propPinned = UI.panelState.properties.visible and UI.panelState.properties.pinned

    local availableRightH = H - rightY - statH
    local expH = 0
    local propH = 0

    if expPinned and propPinned then
        expH = math_floor(availableRightH / 2)
        propH = availableRightH - expH
    elseif expPinned then
        expH = availableRightH
    elseif propPinned then
        propH = availableRightH
    end

    local rTabH    = (propPinned) and 24 or 0
    local propContentH = propH - rTabH

    cachedLayout.W = W
    cachedLayout.H = H
    cachedLayout.menuH = menuH
    cachedLayout.toolH = toolH
    cachedLayout.statH = statH
    cachedLayout.tabH = tabH
    cachedLayout.topH = topH
    cachedLayout.viewX = viewX
    cachedLayout.viewY = viewY
    cachedLayout.viewW = viewW
    cachedLayout.viewH = viewH
    cachedLayout.rightX = rightX
    cachedLayout.rightY = rightY
    cachedLayout.rightW = rightW
    cachedLayout.expX = rightX
    cachedLayout.expY = rightY
    cachedLayout.expW = rightW
    cachedLayout.expH = expH

    cachedLayout.propTabY = rightY + expH
    cachedLayout.propX = rightX
    cachedLayout.propY = cachedLayout.propTabY + rTabH
    cachedLayout.propW = rightW
    cachedLayout.propH = propContentH

    cachedLayout.outTabY = H - outH - bTabH - statH
    cachedLayout.outX = 0
    cachedLayout.outY = cachedLayout.outTabY + bTabH
    cachedLayout.outW = viewW
    cachedLayout.outH = outH

    cachedLayout.statX = 0
    cachedLayout.statY = H - statH
    cachedLayout.statW = W
    cachedLayout.statH = statH

    layoutDirty = false
    return cachedLayout
end

function UI.load()
    Theme.loadAssets()
    MenuBar.load()
    Toolbar.load()
    Explorer.load()
    Properties.load()
    Output.load()
    AssetBrowser.load()
    AnimationEditor.load()
    TerrainEditor.load()
    StatusBar.load()
    layoutDirty = true
end

function UI.update(dt)
    -- Check if window size changed
    local W, H = lg.getDimensions()
    if W ~= (cachedLayout.W or 0) or H ~= (cachedLayout.H or 0) then
        layoutDirty = true
    end

    local mx, my = love.mouse.getPosition()

    -- Handle Dragging
    if UI.draggingPanel and love.mouse.isDown(1) then
        local p = UI.panelState[UI.draggingPanel]
        p.x = mx - UI.dragOffsetX
        p.y = my - UI.dragOffsetY
        -- Clamp to screen
        p.x = math.max(0, math.min(W - p.w, p.x))
        p.y = math.max(0, math.min(H - p.h, p.y))
    elseif not love.mouse.isDown(1) then
        UI.draggingPanel = nil
    end

    -- Handle Resizing
    if UI.resizingPanel and love.mouse.isDown(1) then
        local p = UI.panelState[UI.resizingPanel]
        p.w = math.max(100, mx - p.x)
        p.h = math.max(80, my - p.y)
    elseif not love.mouse.isDown(1) then
        UI.resizingPanel = nil
    end

    -- Handle Camera Speed Slider Dragging
    if UI.draggingCameraSpeed and love.mouse.isDown(1) then
        local lay = cachedLayout
        local cam = Engine.Camera
        if cam then
            local sliderW = 120
            local padding = 10
            local sx = lay.viewX + padding + 100
            local localX = mx - sx
            local progress = math.max(0, math.min(1, localX / sliderW))
            cam.speed = cam.minSpeed + (cam.maxSpeed - cam.minSpeed) * progress
        end
    elseif not love.mouse.isDown(1) then
        UI.draggingCameraSpeed = false
    end

    MenuBar.update(dt)
    Toolbar.update(dt)
    Explorer.update(dt)
    ScriptEditor.update(dt)
    Properties.update(dt)
    Output.update(dt)
    AssetBrowser.update(dt)
    AnimationEditor.update(dt)
    TerrainEditor.update(dt)
    StatusBar.update(dt)
    Notifications.update(dt)
end

function UI.drawTabs(x, y, w, h, tabs, activeTab, panelKey)
    Theme.drawRect(x, y, w, h, Theme.colors.bg_header)
    Theme.drawDivider(x, y + h - 1, w, 1)

    local mx, my = love.mouse.getPosition()
    local tx = x + 4
    for _, tab in ipairs(tabs) do
        local tw = Theme.fonts.small:getWidth(tab) + 20
        local isHovered = Theme.inRect(mx, my, tx, y, tw, h)
        local isActive = (activeTab == tab)

        local colorId = "tab_color_" .. tab .. x .. y
        local targetColor = isActive and Theme.colors.bg_dark or (isHovered and Theme.colors.bg_hover or Theme.colors.bg_header)
        local animColor = Theme.animateColor(colorId, targetColor, love.timer.getDelta(), 20)

        Theme.drawRect(tx, y + 2, tw, h - 2, animColor, 4)
        if isActive then
            Theme.drawRect(tx, y + h - 1, tw, 1, Theme.colors.bg_dark)
        end

        Theme.drawText(tab, tx + 10, y + 5, isActive and Theme.colors.text_primary or Theme.colors.text_secondary, Theme.fonts.small)
        tx = tx + tw + 2
    end

    if panelKey and UI.panelState[panelKey] then
        local unpinX = x + w - 22
        local isHover = Theme.inRect(mx, my, unpinX, y + 4, 18, 18)
        Theme.drawText("❐", unpinX, y + 4, isHover and Theme.colors.text_accent or Theme.colors.text_secondary, Theme.fonts.small)
    end
end

function UI.drawWindow(panelKey, title, contentFunc)
    local p = UI.panelState[panelKey]
    if not p or not p.visible or p.pinned then return end

    local x, y, w, h = p.x, p.y, p.w, p.h
    local headerH = 24
    local mx, my = love.mouse.getPosition()

    -- Shadow
    Theme.drawRect(x + 4, y + 4, w, h, {0, 0, 0, 0.2}, 4)
    -- Window Background
    Theme.drawRect(x, y, w, h, Theme.colors.bg_dark, 4)
    Theme.drawBorder(x, y, w, h, Theme.colors.border, 1)

    -- Header
    local isHeaderHover = Theme.inRect(mx, my, x, y, w, headerH)
    Theme.drawRect(x, y, w, headerH, isHeaderHover and Theme.colors.bg_menubar or Theme.colors.bg_header, 4)
    Theme.drawDivider(x, y + headerH - 1, w, 1)
    Theme.drawText(title, x + 8, y + 5, Theme.colors.text_primary, Theme.fonts.small)

    -- Pin button
    local pinX = x + w - 22
    local isHoverPin = Theme.inRect(mx, my, pinX, y + 4, 18, 18)
    Theme.drawText("📌", pinX, y + 4, isHoverPin and Theme.colors.text_accent or Theme.colors.text_secondary, Theme.fonts.small)

    -- Content
    lg.setScissor(x, y + headerH, w, h - headerH)
    contentFunc(x, y + headerH, w, h - headerH)
    lg.setScissor()

    -- Resize handle
    local rsSize = 12
    local isHoverRS = Theme.inRect(mx, my, x + w - rsSize, y + h - rsSize, rsSize, rsSize)
    Theme.drawText("◢", x + w - rsSize, y + h - rsSize, isHoverRS and Theme.colors.text_accent or Theme.colors.text_disabled, Theme.fonts.tiny)
end

function UI.draw()
    local lay = UI.getLayout()

    -- Render UI on clean 2D state
    lg.setDepthMode()
    lg.origin()
    lg.setBlendMode("alpha")

    -- 1. Draw Main Tab Bar (Viewport | Script)
    local tabY = lay.menuH + lay.toolH
    local topTabs = {"Viewport"}
    if ScriptEditor.visible and ScriptEditor.activeTab > 0 then
        table.insert(topTabs, ScriptEditor.tabs[ScriptEditor.activeTab].name)
    end
    UI.drawTabs(0, tabY, lay.W, lay.tabH, topTabs, UI.activeTab == "Viewport" and "Viewport" or topTabs[2])

    -- 2. Viewport-only elements
    if UI.activeTab == "Viewport" then
        if Engine.PlayMode and Engine.PlayMode.state ~= "Stopped" then
            lg.setFont(Theme.fonts.small)
            Theme.setColor({0, 0, 0, 0.45})
            lg.rectangle("fill", lay.viewX + 4, lay.viewY + 4, 180, 16, 3)
            Theme.setColor(Theme.colors.text_warn)
            local stateIcon = Engine.PlayMode.state == "Playing" and "▶" or "⏸"
            lg.print(stateIcon .. " " .. Engine.PlayMode.state .. "  [WASD+Space] [F7=Stop]",
                lay.viewX + 8, lay.viewY + 5)
        end

        if Engine.PlayMode and Engine.PlayMode.state == "Stopped" then
            ViewportGizmo.draw(lay.viewX, lay.viewY, lay.viewW, lay.viewH)

            -- Camera Speed Slider Overlay (Top-Left)
            local cam = Engine.Camera
            if cam then
                local sliderW = 120
                local padding = 10
                local sx = lay.viewX + padding + 100 -- offset for label
                local sy = lay.viewY + padding

                -- Label
                Theme.drawText(string.format("Cam Speed: %.1f", cam.speed),
                    sx - 100, sy + 1, Theme.colors.text_primary, Theme.fonts.small)

                -- Slider Track
                Theme.drawRect(sx, sy + 6, sliderW, 4, Theme.colors.bg_medium, 2)

                -- Slider Fill
                local progress = (cam.speed - cam.minSpeed) / (cam.maxSpeed - cam.minSpeed)
                Theme.drawRect(sx, sy + 6, sliderW * progress, 4, Theme.colors.text_accent, 2)

                -- Slider Handle
                Theme.drawRect(sx + sliderW * progress - 3, sy + 2, 6, 12, Theme.colors.text_primary, 3)
            end
        end

        lg.setLineWidth(1)
        Theme.setColor(Theme.colors.border)
        lg.rectangle("line", lay.viewX, lay.viewY, lay.viewW, lay.viewH)
    else
        ScriptEditor.x = lay.viewX
        ScriptEditor.y = lay.viewY
        ScriptEditor.width = lay.viewW
        ScriptEditor.height = lay.viewH
        ScriptEditor.draw()
    end

    -- Pinned Right panels
    if lay.rightW > 0 then
        if UI.panelState.explorer.visible and UI.panelState.explorer.pinned then
            UI.drawTabs(lay.expX, lay.expY, lay.expW, 24, {"Explorer"}, "Explorer", "explorer")
            Explorer.draw(lay.expX, lay.expY + 24, lay.expW, lay.expH - 24)
        end
        if UI.panelState.properties.visible and UI.panelState.properties.pinned then
            -- Draw right tabs
            UI.drawTabs(lay.propX, lay.propTabY, lay.propW, 24, {"Properties", "Terrain"}, UI.activeRightTab, "properties")

            if UI.activeRightTab == "Properties" then
                Properties.draw(lay.propX, lay.propY, lay.propW, lay.propH)
            else
                TerrainEditor.draw(lay.propX, lay.propY, lay.propW, lay.propH)
            end
        end
        Theme.drawDivider(lay.rightX, lay.menuH + lay.toolH, 1, lay.H - (lay.menuH + lay.toolH) - lay.statH, true)
    end

    -- Pinned Bottom panels
    if UI.panelState.output.visible and UI.panelState.output.pinned then
        UI.drawTabs(lay.outX, lay.outTabY, lay.outW, 24, {"Output", "Assets", "Animation"}, UI.activeBottomTab, "output")

        if UI.activeBottomTab == "Output" then
            Output.draw(lay.outX, lay.outY, lay.outW, lay.outH)
        elseif UI.activeBottomTab == "Assets" then
            AssetBrowser.draw(lay.outX, lay.outY, lay.outW, lay.outH)
        elseif UI.activeBottomTab == "Animation" then
            AnimationEditor.draw(lay.outX, lay.outY, lay.outW, lay.outH)
        end
    end

    -- Floating panels
    for name, state in pairs(UI.panelState) do
        if state.visible and not state.pinned then
            local title = name:gsub("^%l", string.upper)
            if name == "output" then title = UI.activeBottomTab
            elseif name == "properties" then title = UI.activeRightTab end

            UI.drawWindow(name, title, function(wx, wy, ww, wh)
                if name == "explorer" then
                    Explorer.draw(wx, wy, ww, wh)
                elseif name == "properties" then
                    UI.drawTabs(wx, wy, ww, 24, {"Properties", "Terrain"}, UI.activeRightTab)
                    if UI.activeRightTab == "Properties" then
                        Properties.draw(wx, wy + 24, ww, wh - 24)
                    else
                        TerrainEditor.draw(wx, wy + 24, ww, wh - 24)
                    end
                elseif name == "output" then
                    UI.drawTabs(wx, wy, ww, 24, {"Output", "Assets", "Animation"}, UI.activeBottomTab)
                    if UI.activeBottomTab == "Output" then
                        Output.draw(wx, wy + 24, ww, wh - 24)
                    elseif UI.activeBottomTab == "Assets" then
                        AssetBrowser.draw(wx, wy + 24, ww, wh - 24)
                    elseif UI.activeBottomTab == "Animation" then
                        AnimationEditor.draw(wx, wy + 24, ww, wh - 24)
                    end
                end
            end)
        end
    end

    StatusBar.draw(lay.statX, lay.statY, lay.statW, lay.statH)
    Toolbar.draw()
    MenuBar.draw()
    ColorPicker.draw()
    AboutDialog.draw()
    Notifications.draw()
end

function UI.checkTabsClick(x, y, tx, ty, w, h, tabs)
    if y >= ty and y < ty + h and x >= tx and x < tx + w then
        local cx = tx + 4
        for _, tab in ipairs(tabs) do
            local tw = Theme.fonts.small:getWidth(tab) + 20
            if x >= cx and x < cx + tw then
                return tab
            end
            cx = cx + tw + 2
        end
    end
    return nil
end

function UI.mousepressed(x, y, button, istouch, presses)
    if ColorPicker.visible and ColorPicker.mousepressed(x, y, button) then return true end
    if AboutDialog.visible and AboutDialog.mousepressed(x, y, button) then return true end

    local lay = UI.getLayout()

    -- Check floating windows first (top-to-bottom, but here just simple)
    for name, state in pairs(UI.panelState) do
        if state.visible and not state.pinned then
            if Theme.inRect(x, y, state.x, state.y, state.w, state.h) then
                -- Resize handle
                if Theme.inRect(x, y, state.x + state.w - 15, state.y + state.h - 15, 15, 15) then
                    UI.resizingPanel = name
                    return true
                end

                -- Header / Drag
                if y < state.y + 24 then
                    -- Pin button
                    if x > state.x + state.w - 24 then
                        state.pinned = true
                        layoutDirty = true
                        return true
                    end

                    UI.draggingPanel = name
                    UI.dragOffsetX = x - state.x
                    UI.dragOffsetY = y - state.y
                    return true
                end

                -- Content clicks
                local contentX, contentY = state.x, state.y + 24
                local contentW, contentH = state.w, state.h - 24

                if name == "explorer" then
                    if Explorer.mousepressed(x, y, button, contentX, contentY, contentW, contentH) then return true end
                elseif name == "properties" then
                    local tab = UI.checkTabsClick(x, y, contentX, contentY, contentW, 24, {"Properties", "Terrain"})
                    if tab then UI.activeRightTab = tab return true end

                    if UI.activeRightTab == "Properties" then
                        if Properties.mousepressed(x, y, button, contentX, contentY + 24, contentW, contentH - 24) then return true end
                    else
                        if TerrainEditor.mousepressed(x, y, button, contentX, contentY + 24, contentW, contentH - 24) then return true end
                    end
                elseif name == "output" then
                    local tab = UI.checkTabsClick(x, y, contentX, contentY, contentW, 24, {"Output", "Assets", "Animation"})
                    if tab then UI.activeBottomTab = tab return true end

                    if UI.activeBottomTab == "Output" then
                        if Output.mousepressed(x, y, button, contentX, contentY + 24, contentW, contentH - 24) then return true end
                    elseif UI.activeBottomTab == "Assets" then
                        if AssetBrowser.mousepressed(x, y, button, contentX, contentY + 24, contentW, contentH - 24) then return true end
                    elseif UI.activeBottomTab == "Animation" then
                        if AnimationEditor.mousepressed(x, y, button, contentX, contentY + 24, contentW, contentH - 24) then return true end
                    end
                end
                return true
            end
        end
    end

    -- Tab clicks for pinned panels
    local topTabClick = UI.checkTabsClick(x, y, 0, lay.menuH + lay.toolH, lay.W, lay.tabH, {"Viewport", ScriptEditor.visible and ScriptEditor.activeTab > 0 and ScriptEditor.tabs[ScriptEditor.activeTab].name or "Script"})
    if topTabClick then
        UI.activeTab = (topTabClick == "Viewport") and "Viewport" or "Script"
        return true
    end

    if lay.rightW > 0 then
        if UI.panelState.explorer.visible and UI.panelState.explorer.pinned then
            -- Unpin explorer
            if Theme.inRect(x, y, lay.expX + lay.expW - 22, lay.expY + 4, 18, 18) then
                UI.panelState.explorer.pinned = false
                layoutDirty = true
                return true
            end
            if Explorer.mousepressed(x, y, button, lay.expX, lay.expY + 24, lay.expW, lay.expH - 24) then return true end
        end

        if UI.panelState.properties.visible and UI.panelState.properties.pinned then
            -- Unpin properties
            if Theme.inRect(x, y, lay.propX + lay.propW - 22, lay.propTabY + 4, 18, 18) then
                UI.panelState.properties.pinned = false
                layoutDirty = true
                return true
            end

            local rightTabClick = UI.checkTabsClick(x, y, lay.propX, lay.propTabY, lay.propW, 24, {"Properties", "Terrain"})
            if rightTabClick then UI.activeRightTab = rightTabClick return true end

            if UI.activeRightTab == "Properties" then
                if Properties.mousepressed(x, y, button, lay.propX, lay.propY, lay.propW, lay.propH) then return true end
            else
                if TerrainEditor.mousepressed(x, y, button, lay.propX, lay.propY, lay.propW, lay.propH) then return true end
            end
        end
    end

    if UI.panelState.output.visible and UI.panelState.output.pinned then
        -- Unpin output
        if Theme.inRect(x, y, lay.outX + lay.outW - 22, lay.outTabY + 4, 18, 18) then
            UI.panelState.output.pinned = false
            layoutDirty = true
            return true
        end

        local botTabClick = UI.checkTabsClick(x, y, lay.outX, lay.outTabY, lay.outW, 24, {"Output", "Assets", "Animation"})
        if botTabClick then UI.activeBottomTab = botTabClick return true end

        if UI.activeBottomTab == "Output" and Output.mousepressed(x, y, button, lay.outX, lay.outY, lay.outW, lay.outH) then return true end
        if UI.activeBottomTab == "Assets" and AssetBrowser.mousepressed(x, y, button, lay.outX, lay.outY, lay.outW, lay.outH) then return true end
        if UI.activeBottomTab == "Animation" and AnimationEditor.mousepressed(x, y, button, lay.outX, lay.outY, lay.outW, lay.outH) then return true end
    end

    if UI.activeTab == "Script" and ScriptEditor.mousepressed(x, y, button) then return true end
    if MenuBar.mousepressed(x, y, button) then return true end

    local toolY = lay.menuH
    if y >= toolY and y <= toolY + lay.toolH then
        if Toolbar.mousepressed(x, y, button) then return true end
    end

    if UI.activeTab == "Viewport" then
        if Engine.PlayMode and Engine.PlayMode.state == "Stopped" then
            -- Check camera speed slider (Top-Left)
            local sliderW = 120
            local padding = 10
            local sx = lay.viewX + padding + 100
            local sy = lay.viewY + padding
            if Theme.inRect(x, y, sx - 100, sy, sliderW + 100, 16) then
                UI.draggingCameraSpeed = true
                return true
            end

            if ViewportGizmo.mousepressed(x, y, lay.viewX, lay.viewY, lay.viewW, lay.viewH) then return true end
        end
    end

    if UI.activeTab == "Viewport" then
        if x < lay.viewW and y >= lay.topH and y < (UI.panelState.output.pinned and lay.outTabY or lay.statY) then
            return false
        end
    end

    if y >= lay.statY and StatusBar.mousepressed(x, y, button, lay.statX, lay.statY, lay.statW, lay.statH) then return true end

    return false
end

function UI.mousereleased(x, y, button)
    ColorPicker.mousereleased(x, y, button)
    if UI.activeTab == "Script" then ScriptEditor.mousereleased(x, y, button) end
end

function UI.mousemoved(x, y, dx, dy)
    ColorPicker.mousemoved(x, y, dx, dy)
    if UI.activeTab == "Script" then ScriptEditor.mousemoved(x, y, dx, dy) end
end

function UI.wheelmoved(x, y)
    local mx, my = love.mouse.getPosition()
    local lay    = UI.getLayout()

    if ScriptEditor.visible then ScriptEditor.wheelmoved(x, y) end

    -- Check floating windows for wheel scroll
    for name, state in pairs(UI.panelState) do
        if state.visible and not state.pinned and Theme.inRect(mx, my, state.x, state.y, state.w, state.h) then
            local contentY = state.y + 24
            local contentH = state.h - 24
            if name == "explorer" then Explorer.wheelmoved(x, y, state.x, contentY, state.w, contentH)
            elseif name == "properties" then
                if UI.activeRightTab == "Properties" then Properties.wheelmoved(x, y, state.x, contentY + 24, state.w, contentH - 24)
                else TerrainEditor.wheelmoved(x, y, state.x, contentY + 24, state.w, contentH - 24) end
            elseif name == "output" then
                if UI.activeBottomTab == "Output" then Output.wheelmoved(x, y, state.x, contentY + 24, state.w, contentH - 24)
                elseif UI.activeBottomTab == "Assets" then AssetBrowser.wheelmoved(x, y, state.x, contentY + 24, state.w, contentH - 24)
                elseif UI.activeBottomTab == "Animation" then AnimationEditor.wheelmoved(x, y, state.x, contentY + 24, state.w, contentH - 24) end
            end
            return
        end
    end

    if my >= lay.outY and UI.panelState.output.visible and UI.panelState.output.pinned then
        if UI.activeBottomTab == "Output" then Output.wheelmoved(x, y, lay.outX, lay.outY, lay.outW, lay.outH)
        elseif UI.activeBottomTab == "Assets" then AssetBrowser.wheelmoved(x, y, lay.outX, lay.outY, lay.outW, lay.outH)
        elseif UI.activeBottomTab == "Animation" then AnimationEditor.wheelmoved(x, y, lay.outX, lay.outY, lay.outW, lay.outH) end
    elseif mx >= lay.rightX and lay.rightW > 0 then
        if my < lay.expY + lay.expH then
            Explorer.wheelmoved(x, y, lay.expX, lay.expY, lay.expW, lay.expH)
        else
            if UI.activeRightTab == "Properties" then Properties.wheelmoved(x, y, lay.propX, lay.propY, lay.propW, lay.propH)
            elseif UI.activeRightTab == "Terrain" then TerrainEditor.wheelmoved(x, y, lay.propX, lay.propY, lay.propW, lay.propH) end
        end
    end
end

function UI.textinput(t)
    if Explorer.searchFocused then Explorer.textinput(t)
    elseif Properties.isEditing() then Properties.textinput(t)
    elseif UI.activeTab == "Script" then ScriptEditor.textinput(t) end
end

function UI.keypressed(key)
    if Explorer.searchFocused then Explorer.keypressed(key)
    elseif Properties.isEditing() then Properties.keypressed(key)
    elseif UI.activeTab == "Script" then ScriptEditor.keypressed(key) end
end

function UI.isOverUI(x, y)
    local lay = UI.getLayout()
    -- Check floating windows first
    for _, state in pairs(UI.panelState) do
        if state.visible and not state.pinned and Theme.inRect(x, y, state.x, state.y, state.w, state.h) then
            return true
        end
    end

    if y < lay.topH then return true end
    if UI.panelState.output.visible and UI.panelState.output.pinned and y >= lay.outTabY then return true end
    if y >= lay.statY then return true end
    if x >= lay.rightX and lay.rightW > 0 then return true end
    if ColorPicker.visible then return true end
    if UI.activeTab == "Script" and x < lay.viewW then return true end

    -- Camera Speed Slider (Top-Left)
    if UI.activeTab == "Viewport" and Engine.PlayMode and Engine.PlayMode.state == "Stopped" then
        local sliderW = 120
        local padding = 10
        local sx = lay.viewX + padding + 100
        local sy = lay.viewY + padding
        if Theme.inRect(x, y, sx - 100, sy, sliderW + 100, 16) then return true end
    end

    if ScriptEditor.visible and UI.activeTab == "Script" then
        if Theme.inRect(x, y, ScriptEditor.x, ScriptEditor.y, ScriptEditor.width, ScriptEditor.height) then return true end
    end
    return false
end

return UI
