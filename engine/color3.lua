-- engine/color3.lua
-- A Roblox-style Color3 class

local Color3 = {}
Color3.__index = Color3

function Color3.new(r, g, b)
    local self = setmetatable({
        _r = r or 1,
        _g = g or 1,
        _b = b or 1,
        _a = 1,
        _onChange = nil
    }, Color3)
    return self
end

function Color3:__index(k)
    if k == "r" or k == 1 then return rawget(self, "_r") end
    if k == "g" or k == 2 then return rawget(self, "_g") end
    if k == "b" or k == 3 then return rawget(self, "_b") end
    if k == "a" or k == 4 then return rawget(self, "_a") end
    return Color3[k]
end

function Color3:__newindex(k, v)
    local changed = false
    if k == "r" or k == 1 then
        if self._r ~= v then self._r = v; changed = true end
    elseif k == "g" or k == 2 then
        if self._g ~= v then self._g = v; changed = true end
    elseif k == "b" or k == 3 then
        if self._b ~= v then self._b = v; changed = true end
    elseif k == "a" or k == 4 then
        if self._a ~= v then self._a = v; changed = true end
    else
        rawset(self, k, v)
    end

    if changed and self._onChange then
        self._onChange()
    end
end

function Color3.fromRGB(r, g, b)
    return Color3.new((r or 255)/255, (g or 255)/255, (b or 255)/255)
end

function Color3:Lerp(goal, alpha)
    return Color3.new(
        self.r + (goal.r - self.r) * alpha,
        self.g + (goal.g - self.g) * alpha,
        self.b + (goal.b - self.b) * alpha
    )
end

function Color3:ToTable()
    return {self.r, self.g, self.b, self.a}
end

function Color3.__tostring(a)
    return string.format("%.3f, %.3f, %.3f", a.r, a.g, a.b)
end

return Color3
