-- .luacheckrc
std = "max+love"
globals = {
    "Engine",
    "Studio",
    "g3d",
    "_g3d",
    "Theme",
    "vectorAdd",
    "finalLength",
    "vectorMagnitude",
    "game",
    "Instance",
    "Vector3",
    "Color3",
}

-- If you use common LÖVE libraries, you can add them here too
read_globals = {
    "inspect",
    "hump",
    "_G",
}

-- Optional: Ignore specific warnings common in game dev
ignore = {
    "212", -- Ignore unused arguments (common in love.update(dt) if you don't use dt)
    "213", -- Ignore unused loop variables
    "611", -- Ignore line contains only whitespace
    "612", -- Ignore line contains trailing whitespace
    "111", -- Ignore setting non-standard global variable
    "113", -- Ignore accessing undefined variable (sometimes needed for dynamic globals)
    "142", -- Ignore setting read-only global variable (e.g. print override)
    "143", -- Ignore setting read-only field (e.g. love.draw)
}

max_line_length = 300
exclude_files = {
    "g3d/", -- Expose g3d folder if it's external library
}
