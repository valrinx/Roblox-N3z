-- ============================================================
-- Roblox-N3z v2.1.0 · init.lua
-- Entrypoint wrapper for N3z HUB
-- ============================================================

local ok, res = pcall(function()
    return game:HttpGet("https://raw.githubusercontent.com/valrinx/Roblox-N3z/main/n3z.lua?_cb=" .. tostring(os.time()))
end)

if not ok or not res or #res < 50 then
    error("[N3Z] Failed to load n3z.lua from GitHub: " .. tostring(res))
end

local fn, compileErr = loadstring(res, "@Roblox-N3z/n3z")
if not fn then
    error("[N3Z] Compilation error: " .. tostring(compileErr))
end

return fn()
