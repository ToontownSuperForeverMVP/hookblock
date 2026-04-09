-- studio/ui/menubar.lua
-- Top menu bar: File | Edit | View | Insert | Model | Test | Help

local Theme = require("studio.theme")
local AboutDialog = require("studio.ui.about_dialog")

local MenuBar = {}

-- Menu structure
local menus = {
    {
        label = "File",
        items = {
            {label = "New",    key = "Ctrl+N", action = function()
                -- Clear workspace and re-create default scene
                local children = Engine.Workspace:GetChildren()
                for i = #children, 1, -1 do
                    children[i]:setParent(nil)
                end
                
                -- Create default scene
                local Part = require("engine.part")
                local SpawnLocation = require("engine.spawnlocation")
                local Vector3 = require("engine.vector3")
                local Color3 = require("engine.color3")

                local baseplate = Part.new("Baseplate")
                baseplate.Size     = Vector3.new(100, 4, 100)
                baseplate.Position = Vector3.new(0, -2, 0)
                baseplate.Color    = Color3.new(0.3, 0.3, 0.3)
                baseplate.Anchored = true
                baseplate:setTexture("assets/grid.png")
                baseplate:setParent(Engine.Workspace)

                local spawn = SpawnLocation.new("SpawnLocation")
                spawn.Position = Vector3.new(0, 0.5, 0)
                spawn:setParent(Engine.Workspace)

                if _G._UI then _G._UI.selectedInstance = nil end
                if Engine.History then Engine.History:clear() end
                if _G._Notifications then _G._Notifications.show("New scene created", "info") end
                print("[Luvoxel] New scene created")
            end},
            {label = "Open...", key = "Ctrl+O", action = function()
                local Serializer = require("engine.serializer")
                local path = "projects/" .. (Engine.CurrentProject or "default") .. "/workspace.json"
                local loadedWorkspace, err = Serializer.loadFromFile(path)
                if loadedWorkspace then
                    -- Replace workspace children
                    local children = Engine.Workspace:GetChildren()
                    for i = #children, 1, -1 do
                        children[i]:setParent(nil)
                    end
                    for _, child in ipairs(loadedWorkspace:GetChildren()) do
                        child:setParent(Engine.Workspace)
                    end
                    if _G._UI then _G._UI.selectedInstance = nil end
                    if Engine.History then Engine.History:clear() end
                    if _G._Notifications then _G._Notifications.show("Scene loaded", "info") end
                else
                    if _G._Notifications then _G._Notifications.show("Open failed: " .. tostring(err), "error") end
                    print("[Luvoxel] Open failed: " .. tostring(err))
                end
            end},
            {label = "Save",   key = "Ctrl+S", action = function()
                local Serializer = require("engine.serializer")
                local path = "projects/" .. (Engine.CurrentProject or "default") .. "/workspace.json"
                Serializer.saveToFile(Engine.Workspace, path)
                if _G._Notifications then _G._Notifications.show("Scene saved", "info") end
            end},
            {label = "Settings", key = "Ctrl+,", action = function()
                local SettingsDialog = require("studio.ui.settings_dialog")
                SettingsDialog.open()
            end},
            {label = "---"},
            {label = "Quit",   key = "Alt+F4", action = function() 
                -- Go back to start menu
                if _G.Studio and _G.Studio.cleanup then _G.Studio.cleanup() end
                Engine.Game = nil
                Engine.Workspace = nil
                Engine.Lighting = nil
                -- Accessing appState via _G since it's local in main.lua is not possible directly, 
                -- but we can assume main.lua handles the state transition if we provide a hook or trigger.
                -- For now, we will use a global flag that main.lua checks.
                _G._RequestedState = "start"
            end},
        }
    },
    {
        label = "Edit",
        items = {
            {label = "Undo",  key = "Ctrl+Z", action = function()
                if Engine.History then Engine.History:undo() end
            end},
            {label = "Redo",  key = "Ctrl+Y", action = function()
                if Engine.History then Engine.History:redo() end
            end},
            {label = "---"},
            {label = "Duplicate", key = "Ctrl+D", action = function()
                local sel = _G._UI and _G._UI.selectedInstance
                if sel and sel.Clone then
                    local clone = sel:Clone()
                    if clone.Position then
                        clone.Position.x = clone.Position.x + 2
                    end
                    clone:setParent(sel.Parent or Engine.Workspace)
                    _G._UI.selectedInstance = clone
                    print("[Luvoxel] Duplicated " .. sel.Name)
                end
            end},
            {label = "Delete", key = "Del",
                action = function()
                    local sel = _G._UI and _G._UI.selectedInstance
                    if sel and sel.setParent and sel.ClassName ~= "Workspace" then
                        local parent = sel.Parent
                        if Engine.History then
                            Engine.History:recordDelete(sel, parent)
                        end
                        sel:setParent(nil)
                        _G._UI.selectedInstance = nil
                        print("[Luvoxel] Deleted " .. sel.Name)
                    end
                end
            },
        }
    },
    {
        label = "View",
        items = {
            {label = "Explorer",   action = function() MenuBar.togglePanel("explorer") end},
            {label = "Properties", action = function() MenuBar.togglePanel("properties") end},
            {label = "Output",     action = function() MenuBar.togglePanel("output") end},
        }
    },
    {
        label = "Insert",
        items = {
            {label = "Part",
                action = function()
                    local Part = require("engine.part")
                    local p = Part.new("Part")
                    p.Position = {x=0, y=2, z=0}
                    p.Anchored = true
                    p:setParent(Engine.Workspace)
                    if Engine.History then
                        Engine.History:recordCreate(p, Engine.Workspace)
                    end
                    if _G._UI then _G._UI.selectedInstance = p end
                    if _G._Notifications then _G._Notifications.show("Inserted Part", "info") end
                    print("[Luvoxel] Inserted Part")
                end
            },
            {label = "SpawnLocation",
                action = function()
                    local SpawnLocation = require("engine.spawnlocation")
                    local s = SpawnLocation.new("SpawnLocation")
                    s.Position = {x=0, y=0.5, z=0}
                    s:setParent(Engine.Workspace)
                    if Engine.History then
                        Engine.History:recordCreate(s, Engine.Workspace)
                    end
                    if _G._UI then _G._UI.selectedInstance = s end
                    print("[Luvoxel] Inserted SpawnLocation")
                end
            },
            {label = "Model",
                action = function()
                    local Model = require("engine.model")
                    local m = Model.new("Model")
                    m:setParent(Engine.Workspace)
                    if Engine.History then
                        Engine.History:recordCreate(m, Engine.Workspace)
                    end
                    print("[Luvoxel] Inserted Model")
                end
            },
            {label = "Folder",
                action = function()
                    local Instance = require("engine.instance")
                    local f = Instance.new("Folder", "Folder")
                    f:setParent(Engine.Workspace)
                    if Engine.History then
                        Engine.History:recordCreate(f, Engine.Workspace)
                    end
                    print("[Luvoxel] Inserted Folder")
                end
            },
        }
    },
    {
        label = "Model",
        items = {
            {label = "Group Selected", key = "Ctrl+G", action = function()
                local sel = _G._UI and _G._UI.selectedInstance
                if sel and sel.ClassName ~= "Workspace" then
                    local Model = require("engine.model")
                    local m = Model.new("Model")
                    local parent = sel.Parent or Engine.Workspace
                    m:setParent(parent)
                    sel:setParent(m)
                    m.PrimaryPart = (sel.Position) and sel or nil
                    _G._UI.selectedInstance = m
                    print("[Luvoxel] Grouped " .. sel.Name .. " into Model")
                end
            end},
            {label = "Ungroup Selected", action = function()
                local sel = _G._UI and _G._UI.selectedInstance
                if sel and sel.ClassName == "Model" then
                    local parent = sel.Parent or Engine.Workspace
                    local children = sel:GetChildren()
                    for _, child in ipairs(children) do
                        child:setParent(parent)
                    end
                    sel:setParent(nil)
                    _G._UI.selectedInstance = nil
                    print("[Luvoxel] Ungrouped Model")
                end
            end},
        }
    },
    {
        label = "Test",
        items = {
            {label = "Play",  key = "F5",  action = function()
                if Engine.PlayMode.state == "Stopped" then
                    Engine.PlayMode:play(Engine.Workspace)
                end
            end},
            {label = "Pause", key = "F6",  action = function()
                Engine.PlayMode:pause()
            end},
            {label = "Stop",  key = "F7",  action = function()
                Engine.PlayMode:stop(Engine.Workspace)
            end},
        }
    },
    {
        label = "Help",
        items = {
            {label = "About Luvöxel", action = function()
                AboutDialog.open()
                print("[Luvöxel] Luvöxel Studio v0.0.1-dev")
                print("[Luvöxel] (Internal: HookBlock)")
                print("[Luvöxel] FOSS Roblox Studio Alternative")
                print("[Luvöxel] Built with Love2D + G3D")
                print("[Luvöxel] License: GPL v3.0")
                print("")
                print("[Luvöxel] === Controls ===")
                print("  RMB+WASD: Fly camera (Studio)")
                print("  WASD: Walk, Space: Jump (Play)")
                print("  1-4: Select/Move/Scale/Rotate tools")
                print("  F5: Play, F6: Pause, F7: Stop")
                print("  Ctrl+Z/Y: Undo/Redo")
                print("  Ctrl+S: Save, Ctrl+D: Duplicate")
                print("  Del: Delete selected")
            end},
        }
    },
}

-- State
MenuBar.openMenu = nil
local menuRects = {}
local itemRects  = {}

function MenuBar.togglePanel(name)
    if _G._UI and _G._UI.togglePanel then
        _G._UI.togglePanel(name)
    end
end

function MenuBar.load() end
function MenuBar.update(dt) end

function MenuBar.draw()
    local w = love.graphics.getWidth()
    local mh = Theme.layout.menu_h

    -- Background
    Theme.drawRect(0, 0, w, mh, Theme.colors.bg_menubar)
    Theme.drawDivider(0, mh - 1, w, 1, false)

    -- Studio Logo
    if Theme.assets.logo_studio then
        Theme.setColor(Theme.colors.white)
        local logoS = mh - 4
        love.graphics.draw(Theme.assets.logo_studio, 4, 2, 0,
            logoS / Theme.assets.logo_studio:getWidth(),
            logoS / Theme.assets.logo_studio:getHeight())
    end

    local mx, my = love.mouse.getPosition()
    local x = 4 + (Theme.assets.logo_studio and (mh + 4) or 0)
    menuRects = {}

    for i, menu in ipairs(menus) do
        love.graphics.setFont(Theme.fonts.normal)
        local tw = Theme.fonts.normal:getWidth(menu.label) + 16
        local isOpen   = (MenuBar.openMenu == i)
        local isHovered = Theme.inRect(mx, my, x, 0, tw, mh)

        if isOpen then
            Theme.drawRect(x, 0, tw, mh, Theme.colors.bg_hover)
        elseif isHovered and not MenuBar.openMenu then
            Theme.drawRect(x, 0, tw, mh, Theme.colors.bg_hover)
        elseif isHovered and MenuBar.openMenu then
            -- Hover-switch: when a menu is open, hovering another opens it
            MenuBar.openMenu = i
            Theme.drawRect(x, 0, tw, mh, Theme.colors.bg_hover)
        end

        Theme.drawText(menu.label, x + 8, math.floor((mh - 13) / 2),
            Theme.colors.text_primary, Theme.fonts.normal)
        menuRects[i] = {x = x, y = 0, w = tw, h = mh}
        x = x + tw + 2
    end

    -- Draw open dropdown
    if MenuBar.openMenu then
        local menu = menus[MenuBar.openMenu]
        local rect = menuRects[MenuBar.openMenu]
        local dropW = 220
        local dropX = rect.x
        local dropY = mh
        local rh = Theme.layout.row_h + 2
        local dropH = #menu.items * rh + 4

        -- Clamp to screen
        if dropX + dropW > w then dropX = w - dropW end

        -- Shadow
        Theme.setColor({0, 0, 0, 0.5})
        love.graphics.rectangle("fill", dropX + 3, dropY + 3, dropW, dropH, 2, 2)

        Theme.drawRect(dropX, dropY, dropW, dropH, Theme.colors.bg_medium, 2)
        Theme.drawBorder(dropX, dropY, dropW, dropH, Theme.colors.border, 1)

        itemRects = {}
        local iy = dropY + 2
        for j, item in ipairs(menu.items) do
            if item.label == "---" then
                Theme.drawDivider(dropX + 4, iy + rh / 2, dropW - 8, 1, false)
            else
                local hovering = Theme.inRect(mx, my, dropX, iy, dropW, rh)
                if hovering then
                    Theme.drawRect(dropX + 2, iy + 1, dropW - 4, rh - 2, Theme.colors.bg_hover, 2)
                end
                Theme.drawText(item.label, dropX + 12, iy + 3,
                    Theme.colors.text_primary, Theme.fonts.normal)
                if item.key then
                    local kw = Theme.fonts.small:getWidth(item.key)
                    Theme.drawText(item.key, dropX + dropW - kw - 10, iy + 4,
                        Theme.colors.text_secondary, Theme.fonts.small)
                end
                itemRects[j] = {x = dropX, y = iy, w = dropW, h = rh, action = item.action}
            end
            iy = iy + rh
        end
    end
end

function MenuBar.mousepressed(x, y, button)
    local mh = Theme.layout.menu_h

    if y >= 0 and y <= mh then
        for i, rect in ipairs(menuRects) do
            if Theme.inRect(x, y, rect.x, rect.y, rect.w, rect.h) then
                if MenuBar.openMenu == i then
                    MenuBar.openMenu = nil
                else
                    MenuBar.openMenu = i
                end
                return true
            end
        end
        MenuBar.openMenu = nil
        return true
    end

    if MenuBar.openMenu then
        for _, rect in ipairs(itemRects) do
            if Theme.inRect(x, y, rect.x, rect.y, rect.w, rect.h) then
                if rect.action then rect.action() end
                MenuBar.openMenu = nil
                return true
            end
        end
        MenuBar.openMenu = nil
    end

    return false
end

function MenuBar.mousereleased(x, y, button) end
function MenuBar.mousemoved(x, y, dx, dy) end

return MenuBar