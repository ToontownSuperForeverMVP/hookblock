-- mcp/tools/control.lua
-- Injects synthetic keyboard and mouse events into the engine

local Control = {}

-- ─── Key events ─────────────────────────────────────────────────────────────

function Control.key(args)
    local key    = args.key    or ""
    local action = args.action or "press"

    if action == "press" or action == "both" then
        -- Call the global keypressed handler (defined in main.lua)
        if love.keypressed then
            love.keypressed(key, key, false)
        end
    end
    if action == "release" or action == "both" then
        if love.keyreleased then
            love.keyreleased(key, key)
        end
    end

    return true, {key=key, action=action}
end

-- ─── Mouse events ───────────────────────────────────────────────────────────

function Control.mouse(args)
    local x      = tonumber(args.x)      or 0
    local y      = tonumber(args.y)      or 0
    local button = tonumber(args.button) or 1

    if love.mousepressed  then love.mousepressed(x, y, button, false, 1)  end
    if love.mousereleased then love.mousereleased(x, y, button, false, 1) end

    return true, {x=x, y=y, button=button}
end

function Control.mousemove(args)
    local x  = tonumber(args.x)  or 0
    local y  = tonumber(args.y)  or 0
    local dx = tonumber(args.dx) or 0
    local dy = tonumber(args.dy) or 0

    if love.mousemoved then love.mousemoved(x, y, dx, dy, false) end

    return true, {x=x, y=y}
end

-- ─── Text input ─────────────────────────────────────────────────────────────

function Control.typeText(args)
    local text = args.text or ""
    for i = 1, #text do
        local ch = text:sub(i,i)
        if love.textinput then love.textinput(ch) end
        -- Also fire keypressed for things that listen to it
        if love.keypressed then love.keypressed(ch, ch, false) end
    end
    return true, {typed=#text}
end

return Control
