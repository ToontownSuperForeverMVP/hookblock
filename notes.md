# Fix Viewport Visual Phasing and Translucency

The issue where parts appeared translucent or "phased" through each other was caused primarily by the **missing depth buffer** in the engine configuration, which made depth testing (Z-buffering) non-functional.

## Changes Made:

1.  **Enabled Depth Buffer:** Added `t.window.depth = 24` to `conf.lua`. This is the most critical fix, as it allows the GPU to correctly determine which surfaces are in front of others.
2.  **Enabled Back-Face Culling:** Added `love.graphics.setMeshCullMode("back")` to the 3D rendering pass in `main.lua`. This prevents the "inside" of parts from being rendered, which often created a "holographic" or translucent effect.
3.  **Improved Depth Precision:** Increased `nearClip` from `0.01` to `0.1` in `g3d/camera.lua`. This significantly improves Z-buffer precision at distances, reducing "Z-fighting" (where overlapping parts flicker).
4.  **Optimized Transparency Sorting:** Modified `Part:render()` in `engine/part.lua` to disable depth writing for semi-transparent parts (`Transparency > 0`). This ensures that transparent objects do not "cut holes" into objects behind them, while still correctly appearing behind other opaque objects.

These fixes together ensure that parts in the viewport look solid, opaque, and correctly layered.
