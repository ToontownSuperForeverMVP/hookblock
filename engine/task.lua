-- engine/task.lua
-- Task scheduler for asynchronous execution (Roblox-style)

local Task = {}
local tasks = {} -- { {thread, wakeTime} }
local deferredTasks = {} -- { thread }

function Task.wait(seconds)
    local thread = coroutine.running()
    seconds = seconds or (1/60)
    table.insert(tasks, {thread = thread, wakeTime = love.timer.getTime() + seconds})
    return coroutine.yield()
end

function Task.spawn(f, ...)
    local thread = coroutine.create(f)
    local ok, err = coroutine.resume(thread, ...)
    if not ok then
        print("[Task Spawn Error] " .. tostring(err))
    end
    return thread
end

function Task.defer(f, ...)
    local thread = coroutine.create(f)
    table.insert(deferredTasks, {thread = thread, args = {...}})
    return thread
end

function Task.delay(seconds, f, ...)
    local thread = coroutine.create(f)
    seconds = seconds or 0
    table.insert(tasks, {thread = thread, wakeTime = love.timer.getTime() + seconds, args = {...}})
    return thread
end

function Task.step(dt)
    local now = love.timer.getTime()
    
    -- Handle waiting tasks
    for i = #tasks, 1, -1 do
        local t = tasks[i]
        if now >= t.wakeTime then
            table.remove(tasks, i)
            local ok, err = coroutine.resume(t.thread, unpack(t.args or {}))
            if not ok then
                print("[Task Wait Error] " .. tostring(err))
            end
        end
    end
    
    -- Handle deferred tasks
    local currentDeferred = deferredTasks
    deferredTasks = {}
    for _, t in ipairs(currentDeferred) do
        local ok, err = coroutine.resume(t.thread, unpack(t.args or {}))
        if not ok then
            print("[Task Defer Error] " .. tostring(err))
        end
    end
end

return Task
