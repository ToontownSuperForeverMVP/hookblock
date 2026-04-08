-- studio/error_catcher.lua
-- Custom error handler for HookBlock Studio
-- Copies error to clipboard and saves to a crash log file

local function error_printer(msg, layer)
    print((debug.traceback("Error: " .. tostring(msg), 1 + (layer or 1)):gsub("\n[^\n]+$", "")))
end

local function error_handler(msg)
    print("\n[ErrorCatcher] !!! CRASH DETECTED !!!")
    print("[ErrorCatcher] Error: " .. tostring(msg))
    msg = tostring(msg)

    error_printer(msg, 2)

    if not love.window or not love.graphics or not love.event then
        return
    end

    if not love.graphics.isCreated() or not love.window.isOpen() then
        local success, status = pcall(love.window.setMode, 800, 600)
        if not success or not status then
            return
        end
    end

    -- Format full traceback
    local traceback = debug.traceback()
    local full_error = "Luvoxel Studio Crash Report\n"
    full_error = full_error .. "============================\n\n"
    full_error = full_error .. "Error: " .. msg .. "\n\n"
    full_error = full_error .. "Traceback:\n" .. traceback .. "\n"

    -- Copy to clipboard
    pcall(love.system.setClipboardText, full_error)

    -- Write to crashes folder in the project root
    pcall(function()
        -- Ensure 'crashes' directory exists
        if love.system.getOS() == "Windows" then
            os.execute('if not exist crashes mkdir crashes')
        else
            os.execute("mkdir -p crashes")
        end
        local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
        local filename = "crashes/crash_" .. timestamp .. ".txt"

        local f = io.open(filename, "w")
        if f then
            f:write(full_error)
            f:close()
            print("[ErrorCatcher] Crash report saved to " .. filename)
        else
            print("[ErrorCatcher] Failed to save crash report to " .. filename)
        end
    end)

    -- Basic error screen setup
    local buttons = {"Quit"}
    if love.window.showMessageBox("Luvoxel Studio crashed!",
        "The studio has encountered an unexpected error and needs to close.\n\n" ..
        "The error report has been COPIED to your clipboard and saved to the 'crashes' folder.\n\n" ..
        "Error: " .. msg,
        buttons) then
        return
    end

    -- Fallback to default Love error screen logic if message box fails or user just wants to see it
    return function()
        love.event.pump()

        for e, a in love.event.poll() do
            if e == "quit" then
                return
            end
            if e == "keypressed" and a == "escape" then
                return
            end
        end

        love.graphics.clear(0.1, 0.1, 0.1)
        love.graphics.printf("Luvoxel Studio Crash", 40, 40, love.graphics.getWidth() - 80)
        love.graphics.printf(full_error, 40, 80, love.graphics.getWidth() - 80)
        love.graphics.present()
    end
end

return error_handler
