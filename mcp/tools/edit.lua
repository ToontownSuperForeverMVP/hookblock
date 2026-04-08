-- mcp/tools/edit.lua
-- Tools for editing the workspace (creating/destroying instances, editing scripts)

local Edit = {}

-- Helper to resolve a path to an instance
local function resolvePath(path)
    if not Engine then return nil, "Engine not ready" end
    local root = Engine.Game or Engine.Workspace
    if not root then return nil, "Game/Workspace not ready" end
    if not path or path == "" then return root, nil end

    local parts = {}
    for segment in path:gmatch("[^%./]+") do
        table.insert(parts, segment)
    end

    local node = root
    local start = 1
    
    if node.ClassName == "DataModel" then
        if parts[1] == "game" or parts[1] == "Game" then
            start = 2
        end
    else
        if parts[1] == "Workspace" then
            start = 2
        end
    end

    for i = start, #parts do
        local seg = parts[i]
        local found = false
        if node.GetChildren then
            for _, child in ipairs(node:GetChildren()) do
                if child.Name == seg then
                    node = child
                    found = true
                    break
                end
            end
        end
        -- Handle GetService dynamically for Game root
        if not found and node.ClassName == "DataModel" and node.GetService then
            pcall(function() 
                local svc = node:GetService(seg)
                if svc then
                    node = svc
                    found = true
                end
            end)
        end
        if not found then
            return nil, "Instance not found at segment: " .. seg
        end
    end
    return node, nil
end

function Edit.createInstance(args)
    local className = args.className
    if not className then return false, nil, "className required" end

    local name = args.name
    local parentPath = args.parent or "Workspace"
    local properties = args.properties

    local parentInst, err = resolvePath(parentPath)
    if not parentInst then return false, nil, "Parent not found: " .. tostring(err) end

    local Instance = require("engine.instance")
    local ok, newInst = pcall(Instance.new, className, name)
    if not ok or not newInst then
        return false, nil, "Failed to create instance of class: " .. tostring(className)
    end

    -- Apply properties if given
    if properties and type(properties) == "table" then
        for k, v in pairs(properties) do
            pcall(function() newInst[k] = v end)
        end
    end

    newInst.Parent = parentInst

    return true, {
        message = "Created instance",
        className = newInst.ClassName,
        name = newInst.Name,
        path = parentPath .. "/" .. newInst.Name
    }
end

function Edit.destroyInstance(args)
    local path = args.path
    if not path then return false, nil, "path required" end

    local inst, err = resolvePath(path)
    if not inst then return false, nil, err end

    if inst == Engine.Workspace then
        return false, nil, "Cannot destroy Workspace"
    end

    inst:Destroy()
    return true, {message = "Instance destroyed", path = path}
end

function Edit.reparentInstance(args)
    local path = args.path
    local newParentPath = args.newParent
    if not path or not newParentPath then return false, nil, "path and newParent required" end

    local inst, err = resolvePath(path)
    if not inst then return false, nil, err end

    local newParent, err2 = resolvePath(newParentPath)
    if not newParent then return false, nil, err2 end

    inst.Parent = newParent
    return true, {message = "Instance reparented", path = path, newParent = newParentPath}
end

function Edit.readScript(args)
    local path = args.path
    if not path then return false, nil, "path required" end

    local inst, err = resolvePath(path)
    if not inst then return false, nil, err end

    if not inst:IsA("Script") and not inst:IsA("ModuleScript") then
        return false, nil, "Instance is not a Script or ModuleScript"
    end

    return true, {source = inst.Source or ""}
end

function Edit.writeScript(args)
    local path = args.path
    local source = args.source
    if not path or not source then return false, nil, "path and source required" end

    local inst, err = resolvePath(path)
    if not inst then return false, nil, err end

    if not inst:IsA("Script") and not inst:IsA("ModuleScript") then
        return false, nil, "Instance is not a Script or ModuleScript"
    end

    inst.Source = source
    return true, {message = "Script updated", path = path}
end

function Edit.cameraMove(args)
    if not _G._UI or not _G._UI.camera then
        return false, nil, "Camera not available"
    end

    local cam = _G._UI.camera
    local g3d = require("g3d")

    if args.x then g3d.camera.position[1] = tonumber(args.x) end
    if args.y then g3d.camera.position[2] = tonumber(args.y) end
    if args.z then g3d.camera.position[3] = tonumber(args.z) end

    if args.pitch then cam.pitch = tonumber(args.pitch) end
    if args.yaw then cam.yaw = tonumber(args.yaw) end

    cam:updateTarget()

    return true, {
        position = {x=g3d.camera.position[1], y=g3d.camera.position[2], z=g3d.camera.position[3]},
        pitch = cam.pitch,
        yaw = cam.yaw
    }
end

function Edit.getChildren(args)
    local path = args.path
    local inst, err = resolvePath(path or "Workspace")
    if not inst then return false, nil, err end

    local children = {}
    if inst.GetChildren then
        for _, child in ipairs(inst:GetChildren()) do
            table.insert(children, {
                name = child.Name,
                class = child.ClassName
            })
        end
    end
    children.__IS_ARRAY = true
    return true, {children = children}
end

function Edit.findInstances(args)
    local className = args.className
    local name = args.name
    local rootPath = args.root or "Workspace"
    
    local rootInst, err = resolvePath(rootPath)
    if not rootInst then return false, nil, err end

    local results = {}
    
    local function search(inst, currentPath)
        local match = true
        if className and not inst:IsA(className) then match = false end
        if name and inst.Name ~= name then match = false end
        
        if match and inst ~= rootInst then
            table.insert(results, {
                name = inst.Name,
                class = inst.ClassName,
                path = currentPath
            })
            if #results >= 100 then return true end -- cap at 100
        end
        
        if inst.GetChildren then
            for _, child in ipairs(inst:GetChildren()) do
                local childPath = currentPath == "" and child.Name or (currentPath .. "/" .. child.Name)
                if search(child, childPath) then return true end
            end
        end
        return false
    end
    
    local startPath = rootPath == "Workspace" and "" or rootPath
    search(rootInst, startPath)
    
    results.__IS_ARRAY = true
    return true, {instances = results}
end

return Edit
