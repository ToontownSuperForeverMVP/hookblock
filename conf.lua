function love.conf(t)
    t.window.title = "Luvöxel Studio"
    -- Smallest 16:9 resolution to ensure windowed mode compatibility
    t.window.width = 640
    t.window.height = 360
    t.window.resizable = true
    t.window.fullscreen = false
    -- Enable depth buffer for 3D rendering
    t.window.depth = 24
    -- Enable High DPI for modern displays
    t.window.highdpi = true
    -- Enable MSAA for smoother edges on modern hardware
    t.window.msaa = 4
    -- Enable VSync for 60FPS lock and smoother rendering
    t.window.vsync = 1
    t.console = false

    -- Better color accuracy on modern displays
    t.gammacorrect = true

    -- MCP server needs luasocket
    t.modules.socket = true
end
