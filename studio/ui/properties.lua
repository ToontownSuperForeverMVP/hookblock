-- studio/ui/properties.lua
-- Properties panel: shows editable fields for selected instance

local Theme = require("studio.theme")
local ColorPicker = require("studio.ui.color_picker")
local utf8 = require("utf8")

local Properties = {}

Properties.scrollY = 0
Properties.editField = nil  -- {inst, key, subkey, prop} currently editing
local editText  = ""

-- Drag-to-change numeric values
Properties.dragField = nil -- {inst, key, startVal, startX}
local dragSensitivity = 0.1

function Properties.isEditing()
    return Properties.editField ~= nil
end

-- Property definitions per class
local function getProps(inst)
    if not inst then return {} end
    local props = {
        {group = "Instance", items = {
            {key = "Name",      label = "Name",      type = "string",
                get = function(i) return i.Name end,
                set = function(i, v) i.Name = v end},
            {key = "ClassName", label = "ClassName",  type = "string_ro",
                get = function(i) return i.ClassName end},
            {key = "Locked", label = "Locked", type = "bool",
                get = function(i) return i.Locked end,
                set = function(i, v) i.Locked = v end},
        }}
    }

    if inst:IsA("Lighting") then
        table.insert(props, {group = "Lighting", items = {
            {key = "Ambient", label = "Ambient", type = "color",
                get = function(i) return string.format("%.0f, %.0f, %.0f", i.Ambient.r*255, i.Ambient.g*255, i.Ambient.b*255) end,
                set = function() end},
            {key = "Brightness", label = "Brightness", type = "number",
                get = function(i) return string.format("%.2f", i.Brightness) end,
                set = function(i, v) i.Brightness = tonumber(v) or i.Brightness end},
            {key = "GlobalShadows", label = "Global Shadows", type = "bool",
                get = function(i) return i.GlobalShadows end,
                set = function(i, v) i.GlobalShadows = v end},
            {key = "OutdoorAmbient", label = "Outdoor Ambient", type = "color",
                get = function(i) return string.format("%.0f, %.0f, %.0f", i.OutdoorAmbient.r*255, i.OutdoorAmbient.g*255, i.OutdoorAmbient.b*255) end,
                set = function() end},
            {key = "ShadowColor", label = "Shadow Color", type = "color",
                get = function(i) return string.format("%.0f, %.0f, %.0f", i.ShadowColor.r*255, i.ShadowColor.g*255, i.ShadowColor.b*255) end,
                set = function() end},
            {key = "ClockTime", label = "ClockTime", type = "number",
                get = function(i) return string.format("%.2f", i.ClockTime) end,
                set = function(i, v) i:SetClockTime(tonumber(v) or i.ClockTime) end},
        }})
    end

    if inst.Position then
        table.insert(props, {group = "Transform", items = {
            {key = "Position.x", label = "Position X", type = "number",
                get = function(i) return string.format("%.3f", i.Position.x) end,
                set = function(i, v) i.Position.x = tonumber(v) or i.Position.x end},
            {key = "Position.y", label = "Position Y", type = "number",
                get = function(i) return string.format("%.3f", i.Position.y) end,
                set = function(i, v) i.Position.y = tonumber(v) or i.Position.y end},
            {key = "Position.z", label = "Position Z", type = "number",
                get = function(i) return string.format("%.3f", i.Position.z) end,
                set = function(i, v) i.Position.z = tonumber(v) or i.Position.z end},
        }})
    end

    if inst.Rotation then
        table.insert(props, {group = "Rotation", items = {
            {key = "Rotation.x", label = "Rotation X", type = "number",
                get = function(i) return string.format("%.1f", i.Rotation.x) end,
                set = function(i, v) i.Rotation.x = tonumber(v) or i.Rotation.x end},
            {key = "Rotation.y", label = "Rotation Y", type = "number",
                get = function(i) return string.format("%.1f", i.Rotation.y) end,
                set = function(i, v) i.Rotation.y = tonumber(v) or i.Rotation.y end},
            {key = "Rotation.z", label = "Rotation Z", type = "number",
                get = function(i) return string.format("%.1f", i.Rotation.z) end,
                set = function(i, v) i.Rotation.z = tonumber(v) or i.Rotation.z end},
        }})
    end

    if inst.Size then
        table.insert(props, {group = "Size", items = {
            {key = "Size.x", label = "Size X", type = "number",
                get = function(i) return string.format("%.3f", i.Size.x) end,
                set = function(i, v) i.Size.x = math.max(0.01, tonumber(v) or i.Size.x) end},
            {key = "Size.y", label = "Size Y", type = "number",
                get = function(i) return string.format("%.3f", i.Size.y) end,
                set = function(i, v) i.Size.y = math.max(0.01, tonumber(v) or i.Size.y) end},
            {key = "Size.z", label = "Size Z", type = "number",
                get = function(i) return string.format("%.3f", i.Size.z) end,
                set = function(i, v) i.Size.z = math.max(0.01, tonumber(v) or i.Size.z) end},
        }})
    end

    if inst.Color then
        local appearance = {group = "Appearance", items = {
            {key = "Color", label = "Color", type = "color",
                get = function(i)
                    return string.format("%.0f, %.0f, %.0f", i.Color.r*255, i.Color.g*255, i.Color.b*255)
                end,
                set = function() end},
        }}

        if inst.Transparency ~= nil then
            table.insert(appearance.items, {key = "Transparency", label = "Transparency", type = "number",
                get = function(i) return string.format("%.2f", i.Transparency) end,
                set = function(i, v) i.Transparency = math.max(0, math.min(1, tonumber(v) or i.Transparency)) end})
        end

        if inst.Material then
            table.insert(appearance.items, {key = "Material", label = "Material", type = "enum",
                options = {"Plastic", "Wood", "Metal", "Glass", "Neon", "Brick", "Concrete", "Sand", "Grass", "Ice"},
                get = function(i) return i.Material end,
                set = function(i, v) i.Material = v end})
        end

        if inst.Shape then
            table.insert(appearance.items, {key = "Shape", label = "Shape", type = "enum",
                options = {"Block", "Sphere", "Cylinder", "Wedge"},
                get = function(i) return i.Shape end,
                set = function(i, v) if i.setShape then i:setShape(v) else i.Shape = v end end})
        end

        table.insert(props, appearance)
    end

    if inst.Value ~= nil then
        -- Value instances...
        local vtype = type(inst.Value)
        local ptype = "string"
        if vtype == "number" then ptype = "number"
        elseif vtype == "boolean" then ptype = "bool"
        elseif vtype == "table" then
            if inst.ClassName == "Color3Value" then ptype = "color"
            elseif inst.ClassName == "Vector3Value" then ptype = "vector3"
            end
        end

        local valGroup = {group = "Value", items = {}}
        if ptype == "vector3" then
            table.insert(valGroup.items, {key = "Value.x", label = "Value X", type = "number",
                get = function(i) return string.format("%.3f", i.Value.x) end,
                set = function(i, v) i.Value.x = tonumber(v) or i.Value.x end})
            table.insert(valGroup.items, {key = "Value.y", label = "Value Y", type = "number",
                get = function(i) return string.format("%.3f", i.Value.y) end,
                set = function(i, v) i.Value.y = tonumber(v) or i.Value.y end})
            table.insert(valGroup.items, {key = "Value.z", label = "Value Z", type = "number",
                get = function(i) return string.format("%.3f", i.Value.z) end,
                set = function(i, v) i.Value.z = tonumber(v) or i.Value.z end})
        else
            table.insert(valGroup.items, {key = "Value", label = "Value", type = ptype,
                get = function(i)
                    if ptype == "color" then
                        return string.format("%.0f, %.0f, %.0f", i.Value.r*255, i.Value.g*255, i.Value.b*255)
                    end
                    return tostring(i.Value)
                end,
                set = function(i, v)
                    if ptype == "number" then i.Value = tonumber(v) or i.Value
                    elseif ptype == "bool" then i.Value = (v == true or v == "true")
                    else i.Value = v end
                end})
        end
        table.insert(props, valGroup)
    end

    if inst.Anchored ~= nil or inst.CanCollide ~= nil then
        local physics = {group = "Physics", items = {}}
        if inst.Anchored ~= nil then
            table.insert(physics.items, {key = "Anchored", label = "Anchored", type = "bool",
                get = function(i) return i.Anchored end,
                set = function(i, v) i.Anchored = v end})
        end
        if inst.CanCollide ~= nil then
            table.insert(physics.items, {key = "CanCollide", label = "CanCollide", type = "bool",
                get = function(i) return i.CanCollide end,
                set = function(i, v) i.CanCollide = v end})
        end
        table.insert(props, physics)
    end

    return props
end

local rowRects = {}
local cachedProps = nil
local lastInst = nil

function Properties.load() end
function Properties.update(dt) end

function Properties.draw(panelX, panelY, panelW, panelH)
    local mx, my = love.mouse.getPosition()
    local inst = _G._UI and _G._UI.selectedInstance

    -- Background
    Theme.drawRect(panelX, panelY, panelW, panelH, Theme.colors.bg_dark)

    -- No selection
    if not inst then
        cachedProps = nil
        lastInst = nil
        love.graphics.setFont(Theme.fonts.normal)
        Theme.setColor(Theme.colors.text_secondary)
        love.graphics.print("No selection", panelX + 10, panelY + 10)
        return
    end

    -- Update cache if selection changed
    if inst ~= lastInst then
        cachedProps = getProps(inst)
        lastInst = inst
    end

    love.graphics.setScissor(panelX, panelY, panelW, panelH)

    rowRects = {}
    local yOff  = panelY + 2 + Properties.scrollY
    local rh     = Theme.layout.row_h
    local halfW  = math.floor(panelW / 2)

    local props  = cachedProps

    for _, group in ipairs(props) do
        -- Group header
        Theme.drawRect(panelX, yOff, panelW, rh, Theme.colors.bg_medium)
        love.graphics.setFont(Theme.fonts.small)
        Theme.setColor(Theme.colors.text_accent)
        love.graphics.print("▸ " .. group.group, panelX + 6, yOff + 5)
        yOff = yOff + rh

        for _, prop in ipairs(group.items) do
            if yOff > panelY + panelH then break end

            local isEditing = (Properties.editField and Properties.editField.inst == inst and Properties.editField.key == prop.key)
            local isHov     = Theme.inRect(mx, my, panelX, yOff, panelW, rh)
            local isDragging = (Properties.dragField and Properties.dragField.inst == inst and Properties.dragField.key == prop.key)

            -- Row bg
            if isEditing or isDragging then
                Theme.drawRect(panelX, yOff, panelW, rh, Theme.colors.bg_active)
            elseif isHov then
                Theme.drawRect(panelX, yOff, panelW, rh, Theme.colors.bg_hover)
            end

            -- Label (left half)
            love.graphics.setFont(Theme.fonts.normal)
            Theme.setColor(Theme.colors.text_secondary)
            love.graphics.print(prop.label, panelX + 8, yOff + 3)

            -- Value divider
            Theme.drawDivider(panelX + halfW, yOff, 1, rh, true)

            -- Value rendering based on type
            if prop.type == "bool" then
                -- Checkbox
                local boolVal = prop.get(inst)
                local cbX = panelX + halfW + 6
                local cbY = yOff + 3
                local cbS = 14

                if boolVal then love.graphics.setColor(0.17, 0.42, 0.75, 1)
                else love.graphics.setColor(0.25, 0.26, 0.28, 1) end
                love.graphics.rectangle("fill", cbX, cbY, cbS, cbS, 3)
                love.graphics.setColor(0.4, 0.4, 0.4, 1)
                love.graphics.rectangle("line", cbX, cbY, cbS, cbS, 3)

                if boolVal then
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.setFont(Theme.fonts.small)
                    love.graphics.print("✓", cbX + 2, cbY)
                end

                love.graphics.setFont(Theme.fonts.normal)
                Theme.setColor(Theme.colors.text_primary)
                love.graphics.print(tostring(boolVal), cbX + cbS + 4, yOff + 3)

            elseif prop.type == "enum" then
                local valText = prop.get(inst)
                love.graphics.setFont(Theme.fonts.normal)
                Theme.setColor(Theme.colors.text_primary)
                love.graphics.print(valText .. " ▾", panelX + halfW + 6, yOff + 3)

            elseif prop.type == "color" then
                -- Color swatch
                local colorValue = inst[prop.key:match("^[^.]+")]
                if colorValue then
                    love.graphics.setColor(colorValue.r, colorValue.g, colorValue.b, 1)
                    love.graphics.rectangle("fill", panelX + halfW + 6, yOff + 3, rh - 6, rh - 6, 3)
                    love.graphics.setColor(0.5, 0.5, 0.5, 1)
                    love.graphics.rectangle("line", panelX + halfW + 6, yOff + 3, rh - 6, rh - 6, 3)
                end

                love.graphics.setFont(Theme.fonts.small)
                Theme.setColor(Theme.colors.text_primary)
                love.graphics.print(prop.get(inst), panelX + halfW + 6 + rh, yOff + 5)

            elseif isEditing then
                Theme.setColor(Theme.colors.bg_dark)
                love.graphics.rectangle("fill", panelX + halfW + 2, yOff + 2, halfW - 4, rh - 4)
                Theme.setColor(Theme.colors.border_focus)
                love.graphics.rectangle("line", panelX + halfW + 2, yOff + 2, halfW - 4, rh - 4)
                love.graphics.setFont(Theme.fonts.normal)
                Theme.setColor(Theme.colors.text_primary)
                love.graphics.print(editText .. "|", panelX + halfW + 6, yOff + 3)
            else
                local valText = prop.get(inst)
                local valColor = (prop.type == "string_ro") and Theme.colors.text_disabled or Theme.colors.text_primary
                
                -- Highlight numeric value on hover for drag hint
                if isHov and prop.type == "number" then
                    Theme.drawRect(panelX + halfW + 4, yOff + 2, panelW - halfW - 8, rh - 4, {1, 1, 1, 0.1}, 2)
                end

                Theme.setColor(valColor)
                love.graphics.setFont(Theme.fonts.normal)
                love.graphics.print(valText, panelX + halfW + 6, yOff + 3)
            end

            table.insert(rowRects, {
                x = panelX + halfW, y = yOff, w = halfW, h = rh,
                inst = inst, key = prop.key, prop = prop
            })

            yOff = yOff + rh
            Theme.drawDivider(panelX, yOff, panelW, 1, false)
        end
    end

    love.graphics.setScissor()
    Theme.drawDivider(panelX + panelW - 1, panelY, 1, panelH, true)
end

function Properties.mousepressed(x, y, button, panelX, panelY, panelW, panelH)
    if not Theme.inRect(x, y, panelX, panelY, panelW, panelH) then
        if Properties.editField then
            if Properties.editField.prop.set then Properties.editField.prop.set(Properties.editField.inst, editText) end
            Properties.editField = nil
        end
        return false
    end

    if button == 1 then
        for _, rect in ipairs(rowRects) do
            if Theme.inRect(x, y, rect.x, rect.y, rect.w, rect.h) then
                if rect.prop.type == "bool" then
                    local current = rect.prop.get(rect.inst)
                    rect.prop.set(rect.inst, not current)
                    return true
                elseif rect.prop.type == "color" then
                    ColorPicker.open(rect.inst, x, y, rect.key)
                    return true
                elseif rect.prop.type == "enum" and rect.prop.options then
                    local current = rect.prop.get(rect.inst)
                    local opts = rect.prop.options
                    local idx = 1
                    for i, opt in ipairs(opts) do if opt == current then idx = i break end end
                    idx = (idx % #opts) + 1
                    rect.prop.set(rect.inst, opts[idx])
                    return true
                elseif rect.prop.type == "number" then
                    -- Start dragging
                    Properties.dragField = {
                        inst = rect.inst,
                        key = rect.key,
                        prop = rect.prop,
                        startVal = tonumber(rect.prop.get(rect.inst)) or 0,
                        startX = x
                    }
                    return true
                elseif rect.prop.type ~= "string_ro" then
                    Properties.editField = rect
                    editText  = rect.prop.get(rect.inst)
                    return true
                end
            end
        end
    end
    return true
end

function Properties.mousemoved(x, y, dx, dy)
    if Properties.dragField then
        local delta = (x - Properties.dragField.startX) * dragSensitivity
        local newVal = Properties.dragField.startVal + delta
        -- Round based on precision needed
        if Properties.dragField.key:find("Position") or Properties.dragField.key:find("Size") then
            newVal = math.floor(newVal * 1000 + 0.5) / 1000
        else
            newVal = math.floor(newVal * 100 + 0.5) / 100
        end
        Properties.dragField.prop.set(Properties.dragField.inst, tostring(newVal))
        return true
    end
    return false
end

function Properties.mousereleased(x, y, button)
    if button == 1 then
        if Properties.dragField then
            Properties.dragField = nil
            return true
        end
    end
    return false
end

function Properties.textinput(t)
    if Properties.editField then editText = editText .. t end
end

function Properties.keypressed(key)
    if Properties.editField then
        if key == "return" or key == "kpenter" then
            if Properties.editField.prop.set then Properties.editField.prop.set(Properties.editField.inst, editText) end
            Properties.editField = nil
        elseif key == "escape" then Properties.editField = nil
        elseif key == "backspace" then
            local byteoffset = utf8.offset(editText, -1)
            if byteoffset then editText = editText:sub(1, byteoffset - 1) end
        end
    end
end

function Properties.wheelmoved(x, y, panelX, panelY, panelW, panelH)
    local mx, my = love.mouse.getPosition()
    if Theme.inRect(mx, my, panelX, panelY, panelW, panelH) then
        Properties.scrollY = math.min(0, Properties.scrollY + y * 18)
    end
end

return Properties
