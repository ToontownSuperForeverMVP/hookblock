local ToolManager = {}

ToolManager.currentTool = "Select"
ToolManager.tools = {}

function ToolManager.load()
    ToolManager.tools["Select"] = require("studio.tools.select")
    ToolManager.tools["Move"] = require("studio.tools.move")
    ToolManager.tools["Scale"] = require("studio.tools.scale")
    ToolManager.tools["Rotate"] = require("studio.tools.rotate")
end

function ToolManager.setTool(name)
    if ToolManager.tools[name] then
        ToolManager.currentTool = name
        print("Equipped tool: " .. name)
    end
end

function ToolManager.update(dt)
    if ToolManager.tools[ToolManager.currentTool].update then
        ToolManager.tools[ToolManager.currentTool].update(dt)
    end
end

function ToolManager.draw()
    if ToolManager.tools[ToolManager.currentTool].draw then
        ToolManager.tools[ToolManager.currentTool].draw()
    end
end

function ToolManager.mousepressed(x, y, button)
    if ToolManager.tools[ToolManager.currentTool].mousepressed then
        ToolManager.tools[ToolManager.currentTool].mousepressed(x, y, button)
    end
end

function ToolManager.mousereleased(x, y, button)
    if ToolManager.tools[ToolManager.currentTool].mousereleased then
        ToolManager.tools[ToolManager.currentTool].mousereleased(x, y, button)
    end
end

function ToolManager.mousemoved(x, y, dx, dy)
    if ToolManager.tools[ToolManager.currentTool].mousemoved then
        ToolManager.tools[ToolManager.currentTool].mousemoved(x, y, dx, dy)
    end
end

function ToolManager.wheelmoved(x, y)
    if ToolManager.tools[ToolManager.currentTool].wheelmoved then
        ToolManager.tools[ToolManager.currentTool].wheelmoved(x, y)
    end
end

function ToolManager.keypressed(key)
    if key == "1" then ToolManager.setTool("Select") end
    if key == "2" then ToolManager.setTool("Move") end
    if key == "3" then ToolManager.setTool("Scale") end
    if key == "4" then ToolManager.setTool("Rotate") end
end

return ToolManager
