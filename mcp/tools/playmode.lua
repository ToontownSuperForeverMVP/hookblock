-- mcp/tools/playmode.lua
-- Play / Pause / Stop controls for the HookBlock engine

local PlayMode = {}

local function pm()
    return Engine and Engine.PlayMode
end

function PlayMode.play(_args)
    local p = pm()
    if not p then return false, nil, "Engine.PlayMode not available" end
    if p.state ~= "Stopped" then
        return false, nil, "Already in state: " .. tostring(p.state)
    end
    p:play(Engine.Workspace)
    return true, {state = p.state}
end

function PlayMode.pause(_args)
    local p = pm()
    if not p then return false, nil, "Engine.PlayMode not available" end
    p:pause()
    return true, {state = p.state}
end

function PlayMode.stop(_args)
    local p = pm()
    if not p then return false, nil, "Engine.PlayMode not available" end
    p:stop(Engine.Workspace)
    return true, {state = p.state}
end

function PlayMode.getState(_args)
    local p = pm()
    if not p then return false, nil, "Engine.PlayMode not available" end
    return true, {state = p.state}
end

return PlayMode
