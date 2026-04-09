-- mcp/server.lua
-- Built-in MCP server for HookBlock Studio
-- Listens on localhost:7111, speaks newline-delimited JSON-RPC 2.0
-- Non-blocking: poll from love.update() so it never stalls the engine

local Dispatcher = require("mcp.dispatcher")

local MCP = {}

local HOST = "0.0.0.0"

local PORT = 7111

local server  = nil
local clients = {}  -- list of {sock, buf}

-- ─── JSON (minimal encoder/decoder) ────────────────────────────────────────
-- HookBlock already has Serializer which wraps basic JSON; we embed a small
-- self-contained one here so the MCP module is standalone.

local json = {}

local function escape(s)
    return s:gsub('[\\"]', function(c) return "\\" .. c end)
           :gsub("\n","\\n"):gsub("\r","\\r"):gsub("\t","\\t")
end

local function encodeValue(v, depth)
    depth = depth or 0
    if depth > 50 then return '"[cyclic]"' end
    local t = type(v)
    if t == "nil"     then return "null"
    elseif t == "boolean" then return tostring(v)
    elseif t == "number"  then
        if v ~= v then return "null" end  -- NaN
        return tostring(v)
    elseif t == "string"  then return '"' .. escape(v) .. '"'
    elseif t == "table"   then
        -- Check if it's explicitly an array
        local forceArray = v.__IS_ARRAY

        -- array check
        local isArray = true
        local maxN = 0
        for k in pairs(v) do
            if not (type(k) == "string" and k:sub(1,2) == "__") then
                if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
                    isArray = false; break
                else
                    if k > maxN then maxN = k end
                end
            end
        end

        -- If it looks like an array AND is not empty OR explicit flag
        if isArray and maxN == #v and (maxN > 0 or forceArray) then
            local parts = {}
            for i=1, #v do
                parts[i] = encodeValue(v[i], depth+1)
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            for k, val in pairs(v) do
                if not (type(k) == "string" and k:sub(1,2) == "__") then
                    if type(k) == "string" or type(k) == "number" then
                        table.insert(parts, '"' .. tostring(k) .. '":' .. encodeValue(val, depth+1))
                    end
                end
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end


    return '"[' .. t .. ']"'
end

json.encode = encodeValue

-- Minimal JSON decoder (handles the subset we need for RPC requests)
local function skipWS(s, i)
    while i <= #s and s:sub(i,i):match("%s") do i = i + 1 end
    return i
end

local function decodeValue(s, i)
    i = skipWS(s, i)
    local c = s:sub(i,i)
    if c == "n" then return nil,  i+4
    elseif c == "t" then return true, i+4
    elseif c == "f" then return false, i+5
    elseif c == '"' then
        local j = i+1
        local out = {}
        while j <= #s do
            local ch = s:sub(j,j)
            if ch == '"' then
                return table.concat(out), j+1
            elseif ch == "\\" then
                local esc = s:sub(j+1,j+1)
                local map = {n="\n",r="\r",t="\t",["\\"]="\\", ['"']='"', ["/"]="/"}
                table.insert(out, map[esc] or esc)
                j = j + 2
            else
                table.insert(out, ch); j = j + 1
            end
        end
        return table.concat(out), j
    elseif c == "[" then
        local arr = {}; i = i + 1
        i = skipWS(s, i)
        if s:sub(i,i) == "]" then return arr, i+1 end
        while true do
            local v; v, i = decodeValue(s, i)
            table.insert(arr, v)
            i = skipWS(s, i)
            if s:sub(i,i) == "]" then return arr, i+1 end
            i = i + 1  -- skip comma
        end
    elseif c == "{" then
        local obj = {}; i = i + 1
        i = skipWS(s, i)
        if s:sub(i,i) == "}" then return obj, i+1 end
        while true do
            local k; k, i = decodeValue(s, i)
            i = skipWS(s, i) + 1  -- skip colon
            local v; v, i = decodeValue(s, i)
            obj[k] = v
            i = skipWS(s, i)
            if s:sub(i,i) == "}" then return obj, i+1 end
            i = i + 1  -- skip comma
        end
    else
        -- number
        local numStr = s:match("^-?%d+%.?%d*[eE]?[+-]?%d*", i)
        return tonumber(numStr), i + #numStr
    end
end

function json.decode(s)
    local ok, v = pcall(function()
        local val, _ = decodeValue(s, 1)
        return val
    end)
    if ok then return v else return nil end
end

-- ─── Log ring-buffer (captures print output) ───────────────────────────────
local LOG_SIZE = 200
local logBuffer = {}
local logIndex  = 0
local _origPrint = print
local _inMcpPrint = false

local function mcpPrint(...)
    if _inMcpPrint then return _origPrint(...) end
    _inMcpPrint = true
    
    local parts = {}
    for i = 1, select('#', ...) do
        parts[i] = tostring(select(i, ...))
    end
    local line = table.concat(parts, "\t")
    
    -- Call the current global print (which might be overridden by the Output UI)
    print(...)
    
    logIndex = logIndex + 1
    logBuffer[((logIndex-1) % LOG_SIZE) + 1] = {ts = os.time(), msg = line}
    
    _inMcpPrint = false
end

function MCP.getLogs(n)
    n = n or 50
    local out = {}
    local total = math.min(logIndex, LOG_SIZE)
    local start = math.max(1, total - n + 1)
    for i = start, total do
        table.insert(out, logBuffer[((i-1) % LOG_SIZE) + 1])
    end
    out.__IS_ARRAY = true
    return out
end

-- ─── Socket helpers ─────────────────────────────────────────────────────────
local function sendResponse(client, id, result, err)
    local resp
    if err then
        resp = {jsonrpc="2.0", id=id, error={code=-32000, message=err}}
    else
        resp = {jsonrpc="2.0", id=id, result=result}
    end
    local line = json.encode(resp) .. "\n"

    -- Temporarily use blocking send to ensure delivery of tiny JSON buffers
    client.sock:settimeout(nil)
    client.sock:send(line)
    client.sock:settimeout(0)
end


local pendingTasks = {} -- {client, id, isToolCall, toolName}

local function sendToolResponse(client, id, ok, result, errMsg)
    if ok then
        -- Wrap tool results into standard MCP content block
        local textRes = json.encode(result)
        sendResponse(client, id, {
            content = { {type = "text", text = textRes} },
            isError = false
        })
    else
        sendResponse(client, id, {
            content = { {type = "text", text = errMsg or "Unknown tool error"} },
            isError = true
        })
    end
end

local function handleRequest(client, line)
    local req = json.decode(line)
    if not req then
        sendResponse(client, nil, nil, "Parse error")
        return
    end
    local id     = req.id
    local method = req.method or ""
    local params = req.params or {}

    -- Handle standard MCP lifecycle methods
    if method == "initialize" then
        sendResponse(client, id, {
            protocolVersion = "2024-11-05",
            capabilities = {
                tools = { listChanged = false }
            },
            serverInfo = {
                name = "luvoxel-studio",
                version = "1.0.0"
            }
        })
        return
    elseif method == "tools/list" then
        local _, res = Dispatcher.dispatch("list_tools", {})
        sendResponse(client, id, res)
        return
    elseif method == "notifications/initialized" then
        return
    end

    -- Normalize tool calls: tools/call envelope -> flatten
    local isToolCall = (method == "tools/call")
    local toolName   = isToolCall and (params.name or "") or method
    local args       = isToolCall and (params.arguments or {}) or params

    local ok, result, errMsg = Dispatcher.dispatch(toolName, args)

    if ok == "pending" then
        -- Tool started but needs more time (e.g. screenshot)
        table.insert(pendingTasks, {
            client     = client,
            id         = id,
            isToolCall = isToolCall,
            toolName   = toolName
        })
    elseif id then
        if isToolCall then
            sendToolResponse(client, id, ok, result, errMsg)
        else
            -- Non-tool methods (initialize, list, etc) return raw object
            if ok then
                sendResponse(client, id, result)
            else
                sendResponse(client, id, nil, errMsg or "Internal error")
            end
        end
    end
end





-- ─── Public API ─────────────────────────────────────────────────────────────
-- ─── Public API ─────────────────────────────────────────────────────────────
function MCP.start()
    -- Override print to capture logs
    print = mcpPrint

    local socket = require("socket")
    local s, err = socket.bind(HOST, PORT)
    if not s then
        _origPrint("[MCP] Failed to bind on " .. HOST .. ":" .. PORT .. " — " .. tostring(err))
        return
    end
    s:settimeout(0)  -- non-blocking
    server = s
    _origPrint("[MCP] Server listening on " .. HOST .. ":" .. PORT)

    -- Expose log accessor to Dispatcher
    _G._MCP_getLogs = MCP.getLogs
end

function MCP.draw()
    if #pendingTasks == 0 then return end

    local remaining = {}
    for _, task in ipairs(pendingTasks) do
        local ok, result, err = Dispatcher.poll(task.toolName)
        if ok ~= "pending" then
            if task.isToolCall then
                sendToolResponse(task.client, task.id, ok, result, err)
            else
                if ok then
                    sendResponse(task.client, task.id, result)
                else
                    sendResponse(task.client, task.id, nil, err or "Task failed")
                end
            end
        else
            table.insert(remaining, task)
        end
    end
    pendingTasks = remaining
end

function MCP.update(_dt)
    if not server then return end


    -- Accept new connections
    local client = server:accept()
    if client then
        client:settimeout(0)
        table.insert(clients, {sock=client, buf=""})
        _origPrint("[MCP] Client connected.")
    end

    -- Service existing clients
    local dead = {}
    for i, c in ipairs(clients) do
        local chunk, status, partial = c.sock:receive(4096)
        if chunk or (partial and #partial > 0) then
            local data = chunk or partial
            c.buf = c.buf .. data
            -- Process all complete lines
            while true do
                local nl = c.buf:find("\n", 1, true)
                if not nl then break end
                local line = c.buf:sub(1, nl-1)
                c.buf = c.buf:sub(nl+1)
                if #line > 0 then
                    local ok, err = pcall(handleRequest, c, line)
                    if not ok then
                        _origPrint("[MCP] Error handling request: " .. tostring(err))
                        sendResponse(c, nil, nil, "Internal error: " .. tostring(err))
                    end
                end
            end
        end
        if status == "closed" then
            table.insert(dead, i)
        end
    end

    -- Remove disconnected clients (reverse order)
    for i = #dead, 1, -1 do
        table.remove(clients, dead[i])
    end
end

function MCP.stop()
    for _, c in ipairs(clients) do pcall(function() c.sock:close() end) end
    if server then server:close() end
    clients = {}
    server  = nil
    print   = _origPrint
end

return MCP
