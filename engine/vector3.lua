-- engine/vector3.lua
-- A Roblox-style Vector3 class

local Vector3 = {}
Vector3.__index = Vector3

function Vector3.new(x, y, z)
    local self = setmetatable({
        _x = x or 0,
        _y = y or 0,
        _z = z or 0,
        _onChange = nil
    }, Vector3)
    return self
end

-- Allow t.x access but route through __index/__newindex for change detection
function Vector3:__index(k)
    if k == "x" then return rawget(self, "_x") end
    if k == "y" then return rawget(self, "_y") end
    if k == "z" then return rawget(self, "_z") end
    return Vector3[k]
end

function Vector3:__newindex(k, v)
    local changed = false
    if k == "x" then
        if self._x ~= v then self._x = v; changed = true end
    elseif k == "y" then
        if self._y ~= v then self._y = v; changed = true end
    elseif k == "z" then
        if self._z ~= v then self._z = v; changed = true end
    else
        rawset(self, k, v)
    end

    if changed and self._onChange then
        self._onChange()
    end
end

function Vector3.__add(a, b)
    return Vector3.new(a.x + b.x, a.y + b.y, a.z + b.z)
end

function Vector3.__sub(a, b)
    return Vector3.new(a.x - b.x, a.y - b.y, a.z - b.z)
end

function Vector3.__mul(a, b)
    if type(b) == "number" then
        return Vector3.new(a.x * b, a.y * b, a.z * b)
    elseif type(a) == "number" then
        return Vector3.new(b.x * a, b.y * a, b.z * a)
    else
        return Vector3.new(a.x * b.x, a.y * b.y, a.z * b.z)
    end
end

function Vector3.__div(a, b)
    if type(b) == "number" then
        return Vector3.new(a.x / b, a.y / b, a.z / b)
    else
        return Vector3.new(a.x / b.x, a.y / b.y, a.z / b.z)
    end
end

function Vector3.__unm(a)
    return Vector3.new(-a.x, -a.y, -a.z)
end

function Vector3.__tostring(a)
    return string.format("%.3f, %.3f, %.3f", a.x, a.y, a.z)
end

function Vector3.__eq(a, b)
    return a.x == b.x and a.y == b.y and a.z == b.z
end

function Vector3:Dot(other)
    return self.x * other.x + self.y * other.y + self.z * other.z
end

function Vector3:Cross(other)
    return Vector3.new(
        self.y * other.z - self.z * other.y,
        self.z * other.x - self.x * other.z,
        self.x * other.y - self.y * other.x
    )
end

function Vector3:Lerp(goal, alpha)
    return self + (goal - self) * alpha
end

function Vector3:Magnitude()
    return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
end

function Vector3:Unit()
    local mag = self:Magnitude()
    if mag == 0 then return Vector3.new(0, 0, 0) end
    return self / mag
end

return Vector3
