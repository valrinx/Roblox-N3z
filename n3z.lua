-- ============================================================
-- N3Z HUB v2.1.0 · n3z.lua (entrypoint)
-- Native-GUI dock hub. Run:
--   loadstring(game:HttpGet(
--     "https://raw.githubusercontent.com/valrinx/Roblox-N3z/main/n3z.lua"))()
-- ============================================================

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")

-- mobile: touch device without a keyboard -> mobile dock layout (mockup parity)
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local REPO_URL = "https://raw.githubusercontent.com/valrinx/Roblox-N3z/main/"
local HUB_DIR = "Roblox-N3z/"          -- local executor workspace path
local HUB_URL = REPO_URL

local N3Z_VERSION = "v2.1.1"

-- ---------- module registry (mirror of the old project's registry) ----------
-- add a module: one object {id, name, version, game, placeIds, file, envKey?}
local MODULES = {
    { id = "warzpvp", name = "WarZPVP", version = "v1.4.8", game = "WarZPVP OPEN BETA",
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

-- ---------- source resolution ----------
-- Production/raw GitHub boot must use GitHub first so stale executor files
-- cannot silently override freshly pushed modules. For local development:
--     getgenv().__N3Z_DEV_LOCAL = true
local bootEnv = (type(getgenv) == "function" and getgenv()) or _G
local DEV_LOCAL = bootEnv.__N3Z_DEV_LOCAL == true

local function fetchGitHub(urlPath)
    local sep = string.find(urlPath, "?", 1, true) and "&" or "?"
    local ok, content = pcall(function()
        return game:HttpGet(REPO_URL .. urlPath .. sep .. "_cb=" .. tostring(os.time()))
    end)
    if ok and type(content) == "string" and #content > 100 then
        return content
    end
    return nil
end

local function fetchLocal(localPath)
    if type(readfile) ~= "function" or type(isfile) ~= "function" then
        return nil
    end
    for _, path in ipairs({ HUB_DIR .. localPath, localPath }) do
        local ok, exists = pcall(isfile, path)
        if ok and exists then
            local ok2, content = pcall(readfile, path)
            if ok2 and type(content) == "string" and #content > 0 then
                return content
            end
        end
    end
    return nil
end

local function fetchDevHttp(localPath)
    for _, base in ipairs({
        "http://localhost:8999/N3z%20HUB/",
        "http://localhost:8999/",
    }) do
        local ok, content = pcall(function()
            return game:HttpGet(base .. localPath .. "?_cb=" .. tostring(os.time()))
        end)
        if ok and type(content) == "string" and #content > 100 then
            return content
        end
    end
    return nil
end

local function fetch(localPath, urlPath)
    if DEV_LOCAL then
        return fetchDevHttp(localPath)
            or fetchLocal(localPath)
            or fetchGitHub(urlPath)
            or error("N3Z: failed to fetch " .. tostring(urlPath))
    end
    return fetchGitHub(urlPath)
        or fetchLocal(localPath)
        or error("N3Z: failed to fetch " .. tostring(urlPath))
end

local function fetchHub(name)
    return fetch(name, name)
end

-- ---------- env ----------
local env = (type(getgenv) == "function" and getgenv()) or _G

-- destroy previous instance (clean re-execute)
if type(env.__N3Z_WINDOW) == "table" and type(env.__N3Z_WINDOW.Destroy) == "function" then
    pcall(function() env.__N3Z_WINDOW:Destroy() end)
end
env.__N3Z_WINDOW = nil

-- ---------- load hub pieces ----------
local dockSrc = fetchHub(isMobile and "n3z-dock-mobile.lua" or "n3z-dock.lua")
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
dock:SetMenuKeyName(isMobile and "TAP" or "RShift")

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
if isMobile then
    -- mobile: no keyboard — tap the active tab to collapse/expand (mockup footer)
    dock:AddRow("settings", {
        kind = "action", name = "Menu Toggle", desc = "แตะแท็บที่เปิดอยู่ซ้ำเพื่อยุบ / กางเมนู",
    })
else
    dock:AddRow("settings", {
        kind = "action", name = "Menu Toggle Key", desc = "กดที่แถวแล้วกดปุ่มใหม่เพื่อเปลี่ยน",
        chip = "RShift", rebindKey = true,
    })
end
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