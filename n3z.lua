-- ============================================================
-- N3Z HUB v2.1.0 · n3z.lua (entrypoint)
-- Native-GUI dock hub. Run:
--   loadstring(game:HttpGet(
--     "https://raw.githubusercontent.com/valrinx/Roblox-N3z/main/n3z.lua"))()
-- ============================================================

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local REPO_URL = "https://raw.githubusercontent.com/valrinx/Roblox-N3z/main/"
local HUB_DIR = "Roblox-N3z/"          -- local executor workspace path
local HUB_URL = REPO_URL

local N3Z_VERSION = "v2.1.0"

-- ---------- module registry (mirror of the old project's registry) ----------
-- add a module: one object {id, name, version, game, placeIds, file, envKey?}
local MODULES = {
    { id = "warzpvp", name = "WarZPVP", version = "v1.4.5", game = "WarZPVP OPEN BETA",
      placeIds = { 135187059974536 }, file = "modules/warz_pvp.lua", envKey = "__RAVEN_WARZPVP" },
    { id = "stealanegg", name = "Steal An Egg", version = "v1.2.7", game = "Steal An Egg",
      placeIds = { 107778070777162 }, file = "modules/steal_an_egg.lua" },
    { id = "illegalsoccer", name = "Illegal Soccer", version = "v1.4.4", game = "Illegal Soccer",
      placeIds = { 126987974021910 }, file = "modules/illegal_soccer.lua" },
    { id = "wanted", name = "Wanted", version = "v1.2.9", game = "Wanted",
      placeIds = { 14438406081 }, file = "modules/wanted.lua" },
    { id = "wartycoon", name = "War Tycoon", version = "v1.1.0", game = "War Tycoon",
      placeIds = { 4639625707 }, file = "modules/war_tycoon.lua" },
    { id = "frisbeefrenzy", name = "Frisbee Frenzy", version = "v1.0.0", game = "Frisbee Frenzy",
      placeIds = { 106986181033085 }, file = "modules/frisbee_frenzy.lua" },
}

-- ---------- fetch: dev server first, then local file (dev), then GitHub ----------
local function fetch(localPath, urlPath)
    local devOk, devRes = pcall(function()
        return game:HttpGet("http://localhost:8999/N3z%20HUB/" .. localPath .. "?_cb=" .. tostring(os.time()))
    end)
    if devOk and type(devRes) == "string" and #devRes > 100 then
        return devRes
    end
    local devOk2, devRes2 = pcall(function()
        return game:HttpGet("http://localhost:8999/" .. localPath .. "?_cb=" .. tostring(os.time()))
    end)
    if devOk2 and type(devRes2) == "string" and #devRes2 > 100 then
        return devRes2
    end
    if type(readfile) == "function" and type(isfile) == "function" then
        local ok, isF = pcall(isfile, HUB_DIR .. localPath)
        if ok and isF then
            local ok2, content = pcall(readfile, HUB_DIR .. localPath)
            if ok2 and type(content) == "string" and #content > 0 then
                return content
            end
        end
        local ok3, isF2 = pcall(isfile, localPath)
        if ok3 and isF2 then
            local ok4, content = pcall(readfile, localPath)
            if ok4 and type(content) == "string" and #content > 0 then
                return content
            end
        end
    end
    return game:HttpGet(REPO_URL .. urlPath)
end

local function fetchHub(name)
    local devOk, devRes = pcall(function()
        return game:HttpGet("http://localhost:8999/N3z%20HUB/" .. name .. "?_cb=" .. tostring(os.time()))
    end)
    if devOk and type(devRes) == "string" and #devRes > 100 then
        return devRes
    end
    if type(readfile) == "function" and type(isfile) == "function" then
        local lp = HUB_DIR .. name
        local ok, isF = pcall(isfile, lp)
        if ok and isF then
            local ok2, content = pcall(readfile, lp)
            if ok2 and type(content) == "string" and #content > 0 then
                return content
            end
        end
    end
    return game:HttpGet(HUB_URL .. name)
end

-- ---------- env ----------
local env = (type(getgenv) == "function" and getgenv()) or _G

-- destroy previous instance (clean re-execute)
if type(env.__N3Z_WINDOW) == "table" and type(env.__N3Z_WINDOW.Destroy) == "function" then
    pcall(function() env.__N3Z_WINDOW:Destroy() end)
end
env.__N3Z_WINDOW = nil

-- ---------- load hub pieces ----------
local dockSrc = fetchHub("n3z-dock.lua")
local Dock = assert(loadstring(dockSrc, "@n3z-dock"))()
local compatSrc = fetchHub("n3z-compat.lua")
local makeWindow = assert(loadstring(compatSrc, "@n3z-compat"))()

-- ---------- build ----------
local dock = Dock.new({ menuKey = Enum.KeyCode.RightShift })
local Window = makeWindow(dock)
env.__N3Z_WINDOW = Window
-- NOTE: __RAVEN_WINDOW alias is set AFTER the module loads (see below).
-- Old modules destroy getgenv().__RAVEN_WINDOW on load; setting it before
-- loadstring would make the module kill the window we just built.

-- ---------- game detect ----------
local placeId = game.PlaceId
local activeMod = nil
for _, m in ipairs(MODULES) do
    for _, pid in ipairs(m.placeIds) do
        if pid == placeId then activeMod = m break end
    end
    if activeMod then break end
end

local gameName = activeMod and activeMod.game or tostring(game.Name)
local modLine = (activeMod and (activeMod.name .. " " .. activeMod.version) or "no module") .. " • " .. N3Z_VERSION
dock:SetHeader(gameName, "place " .. tostring(placeId) .. " · " .. localPlayer.Name, modLine)
dock:SetMenuKeyName("RShift")

-- avatar (async, never blocks boot)
task.spawn(function()
    local ok, content = pcall(function()
        return Players:GetUserThumbnailAsync(
            localPlayer.UserId,
            Enum.ThumbnailType.HeadShot,
            Enum.ThumbnailSize.Size100x100
        )
    end)
    if ok and type(content) == "string" and content ~= "" then
        dock:SetAvatar(content)
    end
end)

-- ---------- MODULES tab: cards from registry ----------
for _, m in ipairs(MODULES) do
    local isActive = (m == activeMod)
    dock:AddRow("modules", {
        kind = "modulecard",
        name = m.name,
        sub = m.version .. " · " .. (isActive and ("matched: " .. m.game) or "not in this game"),
        active = isActive,
    })
end

-- ---------- SETTINGS tab ----------
local profileName = "N3ZHUB/" .. (activeMod and activeMod.id or "global") .. "/settings/default.json"
dock:AddRow("settings", {
    kind = "action", name = "Menu Toggle Key", desc = "กดที่แถวแล้วกดปุ่มใหม่เพื่อเปลี่ยน",
    chip = "RShift", rebindKey = true,
})
dock:AddRow("settings", {
    kind = "action", name = "Config Profile", desc = profileName,
    chip = "EDIT", clipboard = profileName,
})

local unloadAll
local unloadDone = false
unloadAll = function()
    if unloadDone then return end
    unloadDone = true
    if activeMod and activeMod.envKey then
        pcall(function()
            local t = env[activeMod.envKey]
            if type(t) == "table" and type(t.Destroy) == "function" then
                t.Destroy()
            end
        end)
    end
    pcall(function() Window:Destroy() end)
    pcall(function() dock:Destroy() end)
    env.__N3Z_WINDOW = nil
    env.__RAVEN_WINDOW = nil
end

dock:AddRow("settings", {
    kind = "action", name = "Unload Module", desc = "Clean teardown of module & dock",
    buttonText = "UNLOAD", danger = true, onPress = unloadAll,
})
dock:SetTabInfo("modules", #MODULES .. " modules · " .. (activeMod and "1 ACTIVE" or "none in this game"))
dock:SetTabInfo("settings", "settings")

-- ---------- load the game module (unchanged old-project code) ----------
if activeMod then
    local src = fetch(activeMod.file, activeMod.file)
    local chunk, loadErr = loadstring(src, "@" .. activeMod.id)
    assert(chunk, "N3Z: failed to compile module " .. activeMod.id .. ": " .. tostring(loadErr))
    local modFn = chunk() -- modules return function(Window, ctx)
    assert(type(modFn) == "function", "N3Z: module did not return function(Window, ctx)")
    local ctx = { game = activeMod.game, placeId = placeId, module = activeMod, dock = dock }
    local ok, runErr = pcall(modFn, Window, ctx)
    if not ok then
        warn("[N3Z] module error: " .. tostring(runErr))
    end
else
    dock:AddRow("visuals", { kind = "label", text = "No module for this game yet." })
end

-- compat alias for old modules (set after load so the module's own
-- startup cleanup can't destroy the window we just built)
env.__RAVEN_WINDOW = Window

-- boot: dock bar only. The panel opens when the user picks a tab.
return Window
