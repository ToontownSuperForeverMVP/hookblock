-- engine/tween_service.lua
-- Service for interpolating properties over time

local Task = require("engine.task")

local TweenService = {}

local function lerp(a, b, t)
    if type(a) == "table" and a.Lerp then
        return a:Lerp(b, t)
    elseif type(a) == "number" then
        return a + (b - a) * t
    elseif type(a) == "table" then
        -- Handle simple tables like {1, 1, 1} (Color)
        local res = {}
        for k, v in pairs(a) do
            res[k] = v + (b[k] - v) * t
        end
        return res
    end
    return b
end

-- Easing functions
local Easing = {
    Linear = function(t) return t end,
    QuadIn = function(t) return t * t end,
    QuadOut = function(t) return t * (2 - t) end,
    SineIn = function(t) return 1 - math.cos(t * math.pi / 2) end,
    SineOut = function(t) return math.sin(t * math.pi / 2) end,
}

function TweenService.create(instance, info, goals)
    local tween = {
        Instance = instance,
        Info = info,
        Goals = goals,
        PlaybackState = "Begin",
        Completed = require("engine.signal").new()
    }
    
    function tween:Play()
        if self.PlaybackState == "Playing" then return end
        self.PlaybackState = "Playing"
        
        local startTime = love.timer.getTime()
        local duration = self.Info.Time or 1
        local easing = Easing[self.Info.EasingStyle or "Linear"] or Easing.Linear
        
        local initialValues = {}
        for k, _ in pairs(self.Goals) do
            initialValues[k] = self.Instance[k]
        end
        
        Task.spawn(function()
            while self.PlaybackState == "Playing" do
                local elapsed = love.timer.getTime() - startTime
                local alpha = math.min(1, elapsed / duration)
                local easedAlpha = easing(alpha)
                
                for k, goal in pairs(self.Goals) do
                    self.Instance[k] = lerp(initialValues[k], goal, easedAlpha)
                end
                
                if alpha >= 1 then
                    self.PlaybackState = "Completed"
                    self.Completed:Fire()
                    break
                end
                Task.wait()
            end
        end)
    end
    
    function tween:Cancel()
        self.PlaybackState = "Cancelled"
    end
    
    return tween
end

return TweenService
