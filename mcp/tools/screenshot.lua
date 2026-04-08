-- mcp/tools/screenshot.lua
-- Captures the Love2D framebuffer and returns path + base64 PNG data
-- Asynchronous version to avoid blocking the main update thread

local Screenshot = {}

-- State
local _pending = false
local _resReady = false
local _resData = nil
local _resErr = nil

-- base64 encoder
local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function base64Encode(data)
    local result = {}
    local padding = (3 - (#data % 3)) % 3
    data = data .. string.rep("\0", padding)
    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i+2)
        local n = a * 65536 + b * 256 + c
        table.insert(result, b64chars:sub(math.floor(n/262144)%64+1, math.floor(n/262144)%64+1))
        table.insert(result, b64chars:sub(math.floor(n/4096)%64+1,   math.floor(n/4096)%64+1))
        table.insert(result, b64chars:sub(math.floor(n/64)%64+1,     math.floor(n/64)%64+1))
        table.insert(result, b64chars:sub(n%64+1,                     n%64+1))
    end
    -- Replace padding
    if padding == 2 then
        result[#result]   = "="
        result[#result-1] = "="
    elseif padding == 1 then
        result[#result] = "="
    end
    return table.concat(result)
end

local screenshotIndex = 0

-- Initiates a capture. Returns "pending" to signal the caller to wait.
function Screenshot.capture(_args)
    if _pending then return "pending" end

    _pending = true
    _resReady = false
    _resData = nil
    _resErr = nil

    local ok, errMsg = pcall(function()
        love.graphics.captureScreenshot(function(imageData)
            local w, h = imageData:getDimensions()
            screenshotIndex = screenshotIndex + 1
            local filename = string.format("screenshots/mcp_%04d.png", screenshotIndex)
            love.filesystem.createDirectory("screenshots")

            local fileData = imageData:encode("png")
            love.filesystem.write(filename, fileData:getString())

            local raw = fileData:getString()
            local b64 = base64Encode(raw)
            local savePath = love.filesystem.getSaveDirectory() .. "/" .. filename

            _resData = {
                path    = savePath,
                relpath = filename,
                width   = w,
                height  = h,
                base64  = b64,
                format  = "image/png"
            }
            _resReady = true
            _pending  = false
        end)
    end)

    if not ok then
        _resErr = "captureScreenshot failed: " .. tostring(errMsg)
        _resReady = true
        _pending = false
    end

    return "pending"
end

-- Checks if the result is ready
function Screenshot.poll()
    if _resReady then
        _resReady = false
        if _resData then
            return true, _resData
        else
            return false, nil, _resErr or "Unknown screenshot error"
        end
    end
    return "pending"
end

-- Compatibility hook (not needed with the new async dispatch but kept for safety)
function Screenshot.captureNow()
    -- No-op in async mode as it relies on love's main loop
end

return Screenshot
