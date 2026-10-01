-- ============================================================
-- N3Z HUB · n3z-dock-mobile.lua
-- Mobile entry point (thin wrapper). Returns the Dock class with
-- the touch layout preselected: 46px tabs, 52x30 switches,
-- viewport-fitted panel, tap-to-collapse footer — matching the
-- landscape phone mockup (n3z-dock-mobile.html).
--
-- Loads the sibling n3z-dock.lua (local executor file first, then
-- GitHub), so there is exactly ONE implementation to maintain.
--
-- Usage:
--   local Dock = assert(loadstring(game:HttpGet(URL)))()
--   local dock = Dock.new()            -- mobile layout by default
--   local dock = Dock.new({layout="pc"}) -- explicit override still wins
-- ============================================================

local HUB_URL = "https://raw.githubusercontent.com/valrinx/Roblox--Library/main/N3z%20HUB/"

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
local src = fetchLocal("n3z-dock.lua") or fetchLocal("N3z HUB/n3z-dock.lua")
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
