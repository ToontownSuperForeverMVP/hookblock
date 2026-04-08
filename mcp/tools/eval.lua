-- mcp/tools/eval.lua
-- Sandboxed Lua evaluator for AI-driven testing and inspection

local Eval = {}

-- Safe whitelist of globals the sandbox can access
local SANDBOX_WHITELIST = {
    "pairs", "ipairs", "next", "select", "type", "tostring", "tonumber",
    "unpack", "table", "string", "math", "os", "io", "pcall", "xpcall",
    "error", "assert", "rawget", "rawset", "rawequal", "setmetatable",
    "getmetatable", "require"
}

local function buildSandbox()
    local env = {}

    -- Whitelist from _G
    for _, k in ipairs(SANDBOX_WHITELIST) do
        env[k] = _G[k]
    end

    -- Engine access
    env.Engine    = Engine
    env.Studio    = Studio
    env._UI       = _G._UI
    env.g3d       = require("g3d")

    -- Capture print to return output
    local printLines = {}
    env.print = function(...)
        local parts = {}
        for i = 1, select('#', ...) do
            parts[i] = tostring(select(i, ...))
        end
        table.insert(printLines, table.concat(parts, "\t"))
        -- Also forward to real print (captured by log ring-buffer)
        print(...)
    end

    return env, printLines
end

function Eval.run(args)
    local code = args.code
    if not code or type(code) ~= "string" then
        return false, nil, "args.code (string) is required"
    end

    -- Wrap in a function to capture return values
    local wrapped = "return (function()\n" .. code .. "\nend)()"
    local chunk, _ = load(wrapped, "mcp_eval", "t")
    if not chunk then
        -- Try without return wrapper (for statements)
        local compileErr
        chunk, compileErr = load(code, "mcp_eval", "t")
        if not chunk then
            return false, nil, "Compile error: " .. tostring(compileErr)
        end
    end

    local env, printLines = buildSandbox()
    -- Set sandbox env
    if setfenv then
        setfenv(chunk, env)  -- Lua 5.1
    else
        -- Lua 5.2+ / LuaJIT with no setfenv: use upvalue trick
        -- Love2D uses LuaJIT which supports setfenv
        debug.setupvalue(chunk, 1, env)
    end

    local results = { pcall(chunk) }
    local ok = results[1]
    local n = 0
    -- determine number of return values (ignoring ok)
    for k, _ in pairs(results) do if type(k) == "number" and k > n then n = k end end

    if not ok then
        local err = tostring(results[2])
        return true, {
            success = false,
            error   = err,
            output  = printLines,
        }
    end

    -- Collect return values
    local returnVals = {}
    for i = 2, n do
        local v = results[i]
        if type(v) == "table" then
            -- Attempt to serialize, but avoid cycles
            local s, err2 = pcall(function()
                -- Use the JSON encoder from server (re-use encodeValue logic)
                -- Simple fallback: tostring
                return tostring(v)
            end)
            table.insert(returnVals, s and err2 or tostring(v))
        else
            table.insert(returnVals, v)
        end
    end

    return true, {
        success = true,
        result  = (n >= 2) and returnVals[1] or nil,
        results = returnVals,
        output  = printLines,
    }
end

return Eval
