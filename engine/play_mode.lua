-- engine/play_mode.lua
-- Play mode lifecycle: snapshot workspace, spawn character, run physics

local Physics = require("engine.physics")
local Character = require("engine.character")
local Humanoid = require("engine.humanoid")
local ScriptRuntime = require("engine.script_runtime")
local g3d = require("g3d")

local PlayMode = {}
PlayMode.__index = PlayMode

PlayMode.State = {
    Stopped = "Stopped",
    Playing = "Playing",
    Paused = "Paused",
}

function PlayMode.new()
    local self = setmetatable({}, PlayMode)
    self.state = PlayMode.State.Stopped
    self.physics = Physics.new()
    self.scripts = ScriptRuntime.new()
    self.character = nil
    self._snapshot = nil  -- serialized workspace for restore
    
    -- Camera state
    self.cameraDistance = 12
    self.cameraYaw = 0
    self.cameraPitch = 0.3
    self.cameraSmooth = {x = 0, y = 5, z = -12}

    -- In-game menu state
    self.menuOpen = false
    self._lastClicked = false
    self.debugHitboxes = false
    self._f1Down = false

    return self
end

function PlayMode:play(workspace)
    if self.state == PlayMode.State.Playing then return end

    -- Snapshot the workspace for later restore
    local Serializer = require("engine.serializer")
    self._snapshot = Serializer.serializeInstance(workspace)

    -- Start scripts
    self.scripts:start(workspace)
    
    -- Find spawn location
    self:spawnCharacter(workspace)

    -- Register all non-anchored parts for physics
    self:registerPhysicsBodies(workspace)

    self.state = PlayMode.State.Playing
    self.menuOpen = false
    print("[Luvoxel] ▶ Play mode started")
end

function PlayMode:spawnCharacter(workspace)
    if self.character then
        if self.character.Parent then
            self.character:setParent(nil)
        end
        self.character = nil
    end

    local spawnPos = {x = 0, y = 5, z = 0}
    local function findSpawn(inst)
        if inst.ClassName == "SpawnLocation" and inst.Position then
            spawnPos = {
                x = inst.Position.x,
                y = inst.Position.y + inst.Size.y / 2 + 3,
                z = inst.Position.z,
            }
            return true
        end
        for _, child in ipairs(inst:GetChildren()) do
            if findSpawn(child) then return true end
        end
        return false
    end
    findSpawn(workspace)

    self.character = Character.new("Player")
    self.character._runtimeOnly = true
    self.character:setPosition(spawnPos.x, spawnPos.y, spawnPos.z)
    self.character:setParent(workspace)

    -- Add the character's root part to physics
    local rootPart = self.character.PrimaryPart
    if rootPart then
        self.physics:addBody(rootPart)
        if rootPart._physicsBody then
            rootPart._physicsBody.friction = 0.8
            rootPart._physicsBody.restitution = 0
            rootPart._physicsBody.mass = 5
        end
    end
end

function PlayMode:registerPhysicsBodies(inst)
    if inst.ClassName == "Part" and not inst.Anchored then
        if not inst._physicsBody then
            self.physics:addBody(inst)
        end
    end
    for _, child in ipairs(inst:GetChildren()) do
        self:registerPhysicsBodies(child)
    end
end

function PlayMode:pause()
    if self.state == PlayMode.State.Playing then
        self.state = PlayMode.State.Paused
        print("[Luvoxel] ⏸ Paused")
    elseif self.state == PlayMode.State.Paused then
        self.state = PlayMode.State.Playing
        print("[Luvoxel] ▶ Resumed")
    end
end

function PlayMode:stop(workspace)
    if self.state == PlayMode.State.Stopped then return end

    -- Stop scripts
    self.scripts:stop()

    -- Remove character
    if self.character then
        self.character:setParent(nil)
        self.character = nil
    end

    self.menuOpen = false

    -- Clear all physics bodies
    self.physics.bodies = {}

    -- Restore workspace from snapshot
    if self._snapshot and workspace then
        local children = workspace:GetChildren()
        for i = #children, 1, -1 do
            children[i]:setParent(nil)
        end

        local Serializer = require("engine.serializer")
        if self._snapshot.Children then
            for _, childData in ipairs(self._snapshot.Children) do
                local child = Serializer.deserializeInstance(childData)
                if child then
                    child:setParent(workspace)
                end
            end
        end
        self._snapshot = nil
    end

    -- Restore studio camera
    g3d.camera.position = {0, 5, -10}
    g3d.camera.target = {0, 0, 0}
    g3d.camera.updateViewMatrix()

    self.state = PlayMode.State.Stopped
    print("[Luvoxel] ■ Stopped — workspace restored")
end

function PlayMode:update(dt, workspace)
    if self.state ~= PlayMode.State.Playing then return end

    -- Toggle debug hitboxes with F1
    if love.keyboard.isDown("f1") then
        if not self._f1Down then
            self.debugHitboxes = not self.debugHitboxes
            print("[Luvoxel] Physics Debug: " .. (self.debugHitboxes and "ON" or "OFF"))
            self._f1Down = true
        end
    else
        self._f1Down = false
    end

    if self.menuOpen then
        return
    end

    -- Step scripts
    self.scripts:step(dt)

    if not self.character then return end

    local hum = self.character.Humanoid
    local rootPart = self.character.PrimaryPart
    if not rootPart or not rootPart._physicsBody then return end
    
    local body = rootPart._physicsBody

    -- Player input
    local moveX, moveZ = 0, 0
    local UI = _G._UI
    local Properties = require("studio.ui.properties")
    local Explorer = require("studio.ui.explorer")
    local isEditing = (Properties and Properties.isEditing()) or (Explorer and Explorer.searchFocused)
    local isViewportActive = UI and UI.activeTab == "Viewport"
    
    local mx, my = love.mouse.getPosition()
    local isOverUI = UI and UI.isOverUI(mx, my)

    if hum.Health > 0 and not isEditing and isViewportActive and not isOverUI then
        if love.keyboard.isDown("w") then moveZ = -1 end
        if love.keyboard.isDown("s") then moveZ = 1 end
        if love.keyboard.isDown("a") then moveX = -1 end
        if love.keyboard.isDown("d") then moveX = 1 end
    end

    -- Normalize
    local moveLen = math.sqrt(moveX * moveX + moveZ * moveZ)
    if moveLen > 0 then
        moveX = moveX / moveLen
        moveZ = moveZ / moveLen
    end

    local cosY = math.cos(self.cameraYaw)
    local sinY = math.sin(self.cameraYaw)
    local worldMoveX = moveX * cosY + moveZ * sinY
    local worldMoveZ = -moveX * sinY + moveZ * cosY

    -- Apply movement
    local Vector3 = require("engine.vector3")
    if type(hum.MoveDirection) == "table" and hum.MoveDirection.ClassName == nil then
        hum.MoveDirection = Vector3.new(worldMoveX, 0, worldMoveZ)
    else
        hum.MoveDirection = Vector3.new(worldMoveX, 0, worldMoveZ)
    end

    if moveLen > 0 and hum.Health > 0 then
        body.velocity.x = worldMoveX * hum.WalkSpeed
        body.velocity.z = worldMoveZ * hum.WalkSpeed

        -- Smoothly face movement direction
        local targetRot = math.atan2(worldMoveX, worldMoveZ)
        
        local currentRotRad = math.rad(rootPart.Rotation.y)
        local diff = targetRot - currentRotRad
        while diff > math.pi do diff = diff - math.pi*2 end
        while diff < -math.pi do diff = diff + math.pi*2 end

        local turnSpeed = 12
        rootPart.Rotation.y = rootPart.Rotation.y + math.deg(diff * math.min(1, dt * turnSpeed))
    else
        -- Friction stops movement
        body.velocity.x = body.velocity.x * 0.85
        body.velocity.z = body.velocity.z * 0.85
    end

    -- Jump
    if hum.Health > 0 and not isEditing and isViewportActive and not isOverUI then
        hum.Jump = love.keyboard.isDown("space")
    end
    
    if hum:canJump(body.grounded) then
        body.velocity.y = hum.JumpPower
        hum:onJumped()
    end

    -- Update humanoid state
    hum._jumpCooldown = math.max(0, (hum._jumpCooldown or 0) - dt)
    hum:update(dt, body.grounded, body.velocity.y)


    -- Physics step
    self.physics:step(dt, workspace)

    -- Dead logic
    if hum.State == Humanoid.States.Dead then
        if not self._respawnTimer then self._respawnTimer = 3 end
        self._respawnTimer = self._respawnTimer - dt
        if self._respawnTimer <= 0 then
            self._respawnTimer = nil
            self:spawnCharacter(workspace)
            return
        end
    end

    self.character:update(dt)

    -- Update third-person camera
    self:updateCamera(dt)
end

function PlayMode:updateCamera(dt)
    if not self.character or not self.character.PrimaryPart then return end

    local target = self.character.PrimaryPart.Position
    local dist = self.cameraDistance

    local camX = target.x + math.sin(self.cameraYaw) * math.cos(self.cameraPitch) * dist
    local camY = target.y + 2 + math.sin(self.cameraPitch) * dist
    local camZ = target.z + math.cos(self.cameraYaw) * math.cos(self.cameraPitch) * dist

    local lerp = math.min(1, dt * 8)
    self.cameraSmooth.x = self.cameraSmooth.x + (camX - self.cameraSmooth.x) * lerp
    self.cameraSmooth.y = self.cameraSmooth.y + (camY - self.cameraSmooth.y) * lerp
    self.cameraSmooth.z = self.cameraSmooth.z + (camZ - self.cameraSmooth.z) * lerp

    g3d.camera.position = {self.cameraSmooth.x, self.cameraSmooth.y, self.cameraSmooth.z}
    g3d.camera.target = {target.x, target.y + 2, target.z}
    g3d.camera.updateViewMatrix()
end

function PlayMode:mousemoved(dx, dy)
    if self.state ~= PlayMode.State.Playing or self.menuOpen then return end
    if love.mouse.isDown(2) then
        self.cameraYaw = self.cameraYaw - dx * 0.005
        self.cameraPitch = self.cameraPitch + dy * 0.005
        self.cameraPitch = math.max(-1.2, math.min(1.2, self.cameraPitch))
    end
end

function PlayMode:wheelmoved(y)
    if self.state ~= PlayMode.State.Playing or self.menuOpen then return end
    self.cameraDistance = math.max(4, math.min(30, self.cameraDistance - y * 2))
end

function PlayMode:draw()
    if self.state == PlayMode.State.Stopped then return end

    -- Render physics debug
    if self.debugHitboxes then
        self.physics:renderDebug(Engine.Workspace)
    end

    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    love.graphics.setDepthMode()
    love.graphics.origin()

    if self.character and self.character.Humanoid then
        local hum = self.character.Humanoid

        local barW = 200
        local barH = 12
        local barX = (W - barW) / 2
        local barY = H - 50

        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", barX - 1, barY - 1, barW + 2, barH + 2, 4)

        local healthPct = math.max(0, math.min(1, hum.Health / hum.MaxHealth))
        local r = 1 - healthPct
        local g = healthPct
        love.graphics.setColor(r, g, 0.1, 0.9)
        love.graphics.rectangle("fill", barX, barY, barW * healthPct, barH, 3)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(love.graphics.newFont(11))
        love.graphics.printf(
            string.format("%.0f / %.0f", hum.Health, hum.MaxHealth),
            barX, barY, barW, "center"
        )

        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.printf(hum.State, barX, barY - 16, barW, "center")
    end

    if not self.menuOpen then
        love.graphics.setColor(0.2, 0.8, 0.2, 0.9)
        love.graphics.rectangle("fill", W/2 - 60, 8, 120, 22, 4)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("▶ PLAYING", W/2 - 60, 12, 120, "center")
    end

    if self.menuOpen then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, W, H)

        local menuW, menuH = 300, 300
        local menuX, menuY = (W - menuW) / 2, (H - menuH) / 2

        love.graphics.setColor(0.15, 0.15, 0.15, 1)
        love.graphics.rectangle("fill", menuX, menuY, menuW, menuH, 8)
        
        love.graphics.setColor(0.25, 0.25, 0.25, 1)
        love.graphics.rectangle("fill", menuX, menuY, menuW, 40, 8)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(love.graphics.newFont(16))
        love.graphics.printf("Luvoxel Menu", menuX, menuY + 12, menuW, "center")

        local buttons = {
            {text = "Resume", y = menuY + 70},
            {text = "Reset Character", y = menuY + 120},
            {text = "Leave Game", y = menuY + 170}
        }

        local mx, my = love.mouse.getPosition()
        local clicked = love.mouse.isDown(1) and not self._lastClicked
        self._lastClicked = love.mouse.isDown(1)

        for _, btn in ipairs(buttons) do
            local bx, by = menuX + 20, btn.y
            local bw, bh = menuW - 40, 40
            local hovered = mx >= bx and mx <= bx + bw and my >= by and my <= by + bh
            
            if hovered then
                love.graphics.setColor(0.3, 0.3, 0.3, 1)
                if clicked then
                    self:onMenuClick(btn.text)
                end
            else
                love.graphics.setColor(0.2, 0.2, 0.2, 1)
            end
            
            love.graphics.rectangle("fill", bx, by, bw, bh, 4)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf(btn.text, bx, by + 12, bw, "center")
        end
    end
end

function PlayMode:onMenuClick(action)
    if action == "Resume" then
        self.menuOpen = false
    elseif action == "Reset Character" then
        if self.character and self.character.Humanoid then
            self.character.Humanoid:TakeDamage(self.character.Humanoid.MaxHealth)
        end
        self.menuOpen = false
    elseif action == "Leave Game" then
        self:stop(Engine.Workspace)
    end
end

return PlayMode
