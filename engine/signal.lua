-- engine/signal.lua
-- A Roblox-style signal class for events

local Signal = {}
Signal.__index = Signal

function Signal.new()
    local self = setmetatable({}, Signal)
    self._connections = {}
    return self
end

function Signal:Connect(callback)
    local connection = {
        _callback = callback,
        _signal = self,
        Connected = true,
    }
    
    function connection:Disconnect()
        if not self.Connected then return end
        self.Connected = false
        for i, _conn in ipairs(self._signal._connections) do
            if _conn == self then
                table.remove(self._signal._connections, i)
                break
            end
        end
    end
    
    table.insert(self._connections, connection)
    return connection
end

function Signal:Fire(...)
    -- Use a copy to avoid issues if a connection disconnects during fire
    local connections = {}
    for i, conn in ipairs(self._connections) do
        connections[i] = conn
    end
    
    for _, conn in ipairs(connections) do
        if conn.Connected then
            -- Wrap in pcall to prevent one script erroring from stopping others
            local ok, err = pcall(conn._callback, ...)
            if not ok then
                print("[Signal Error] " .. tostring(err))
            end
        end
    end
end

function Signal:Wait()
    local thread = coroutine.running()
    local connection
    connection = self:Connect(function(...)
        connection:Disconnect()
        coroutine.resume(thread, ...)
    end)
    return coroutine.yield()
end

function Signal:Destroy()
    for _, conn in ipairs(self._connections) do
        conn.Connected = false
    end
    self._connections = {}
end

return Signal
