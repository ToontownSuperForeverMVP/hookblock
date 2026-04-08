-- engine/humanoid.lua
-- Humanoid: manages character health, movement, and state

local Instance = require("engine.instance")
local Vector3 = require("engine.vector3")

local Humanoid = setmetatable({}, {__index = Instance})
Humanoid.ClassName = "Humanoid"
Humanoid.__index = Humanoid
Humanoid.__newindex = Instance.__newindex

-- States
Humanoid.States = {
    Idle = "Idle",
    Walking = "Walking",
    Jumping = "Jumping",
    Falling = "Falling",
    Dead = "Dead",
}

function Humanoid.new(name)
    local self = setmetatable({}, Humanoid)
    self:init("Humanoid", name or "Humanoid")

    -- Stats
    self.Health = 100
    self.MaxHealth = 100
    self.WalkSpeed = 16
    self.JumpPower = 50
    self.JumpHeight = 7.2

    -- State
    self.State = Humanoid.States.Idle
    self.MoveDirection = Vector3.new(0, 0, 0)
    self.Jump = false

    -- Internal
    self._jumpCooldown = 0

    return self
end

function Humanoid:TakeDamage(amount)
    self.Health = math.max(0, self.Health - amount)
    if self.Health <= 0 then
        self.State = Humanoid.States.Dead
    end
end

function Humanoid:Heal(amount)
    self.Health = math.min(self.MaxHealth, self.Health + amount)
end

function Humanoid:update(dt, grounded, velocityY)
    -- Update state based on physics
    if self.Health <= 0 then
        self.State = Humanoid.States.Dead
    elseif grounded then
        -- Don't snap to grounded states if we're still in the upward phase of a jump
        if self.State == Humanoid.States.Jumping and velocityY and velocityY > 0 then
            return
        end

        if self.MoveDirection:Magnitude() > 0.01 then
            self.State = Humanoid.States.Walking
        else
            self.State = Humanoid.States.Idle
        end
    else
        if velocityY and velocityY > 1 then
            self.State = Humanoid.States.Jumping
        else
            self.State = Humanoid.States.Falling
        end
    end
end

-- Returns true if a jump should be executed
function Humanoid:canJump(grounded)
    return self.Jump and grounded and self._jumpCooldown <= 0
           and self.State ~= Humanoid.States.Dead
end

function Humanoid:onJumped()
    self._jumpCooldown = 0.2
    self.Jump = false
    self.State = Humanoid.States.Jumping
end

-- Register class
Instance.register("Humanoid", Humanoid)

return Humanoid
