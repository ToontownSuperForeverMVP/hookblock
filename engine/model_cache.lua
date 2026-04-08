-- engine/model_cache.lua
local g3d = require("g3d")

local ModelCache = {}
local models = {}

function ModelCache.get(path)
    if not models[path] then
        print("[ModelCache] Loading model: " .. path)
        local ok, model = pcall(g3d.newModel, path)
        if ok then
            -- Optional: compress for potato PCs
            model:compress()
            models[path] = model
        else
            print("[ModelCache] Error loading model " .. path .. ": " .. tostring(model))
            -- Fallback to cube
            if path ~= "cube.obj" then
                models[path] = ModelCache.get("cube.obj")
            end
        end
    end
    return models[path]
end

return ModelCache
