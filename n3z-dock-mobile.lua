-- ============================================================
-- N3Z HUB - n3z-dock-mobile.lua
-- Mobile entry point. Reuses n3z-dock.lua with the touch layout selected by
-- default so desktop/mobile share one implementation.
-- ============================================================

local HUB_URL = "https://raw.githubusercontent.com/valrinx/Roblox-N3z/main/"

local function fetchLocal(name)
    if type(readfile) == "function" and type(isfile) == "function" then
        local ok, isF = pcall(isfile, name)
        if ok and isF then
            local ok2, content = pcall(readfile, name)
            if ok2 and type(content) == "string" and #content > 0 then
                return content
            end
        end
    end
    return nil
end

-- same-dir first (flat repos), then the N3z HUB subfolder layout
local src = fetchLocal("n3z-dock.lua") or fetchLocal("Roblox-N3z/n3z-dock.lua")
if not src then
    src = game:HttpGet(HUB_URL .. "n3z-dock.lua")
end

local Dock = assert(loadstring(src, "@n3z-dock"))()

-- default to the mobile layout; an explicit opts.layout still wins
local rawNew = Dock.new
function Dock.new(opts)
    opts = opts or {}
    if opts.layout == nil then opts.layout = "mobile" end
    return rawNew(opts)
end

return Dock
