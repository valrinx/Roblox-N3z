-- ============================================================
-- N3Z HUB v2.2.4 - n3z.lua (entrypoint)
-- Native-GUI dock hub. Run:
--   loadstring(game:HttpGet(
--     "https://raw.githubusercontent.com/valrinx/Roblox-N3z/main/n3z.lua"))()
-- ============================================================

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

-- Mobile routing is platform-based so Android/iOS always use the mobile dock
-- even when an executor reports KeyboardEnabled/MouseEnabled as true.
-- Desktop platforms never fall into the mobile path because of touch flags.
local function detectMobilePlatform()
    local platform = nil
    pcall(function()
        platform = UserInputService:GetPlatform()
    end)

    if platform == Enum.Platform.Android or platform == Enum.Platform.IOS then
        return true
    end

    -- Fallback only for runtimes where GetPlatform is unavailable.
    if platform == nil then
        return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    end

    return false
end

local isMobile = detectMobilePlatform()

local REPO_URL = "https://raw.githubusercontent.com/valrinx/Roblox-N3z/main/"
local HUB_DIR = "Roblox-N3z/"          -- local executor workspace path
local HUB_URL = REPO_URL

local N3Z_VERSION = "v2.2.4"

-- ---------- module registry (mirror of the old project's registry) ----------
-- add a module: one object {id, name, version, game, placeIds, file, envKey?}
local MODULES = {
    { id = "warzpvp", name = "WarZPVP", configName = "WarZ", version = "v1.6.3", game = "WarZPVP OPEN BETA",
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

local function looksLikeLuaSource(content)
    if type(content) ~= "string" or #content <= 100 then
        return false
    end
    local head = string.lower(content:sub(1, 512))
    if string.find(head, "<!doctype", 1, true)
        or string.find(head, "<html", 1, true)
        or string.find(head, "<body", 1, true)
        or string.find(head, "bad gateway", 1, true)
        or string.find(head, "upstream connect error", 1, true)
        or string.find(head, "rate limit", 1, true)
        or string.find(head, "service unavailable", 1, true) then
        return false
    end
    return true
end

local function fetchGitHub(urlPath)
    local sep = string.find(urlPath, "?", 1, true) and "&" or "?"
    for attempt = 1, 3 do
        local cacheBust = tostring(os.time()) .. "-" .. tostring(attempt)
        local ok, content = pcall(function()
            return game:HttpGet(REPO_URL .. urlPath .. sep .. "_cb=" .. cacheBust)
        end)
        if ok and looksLikeLuaSource(content) then
            return content
        end
        if attempt < 3 then
            task.wait(0.18 * attempt)
        end
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
        or error("N3Z: GitHub fetch failed for " .. tostring(urlPath) .. " (no local fallback in production)")
end

local function fetchHub(name)
    return fetch(name, name)
end

-- ---------- per-game executor-workspace config ----------
-- Relative paths resolve inside the executor workspace:
--   N3zHUB/<safe game name>/setting/config.json
local function safeFolderName(name, fallback)
    local value = tostring(name or "")
    value = value:gsub("[^%w%s_%-]", "")
    value = value:gsub("%s+", " ")
    value = value:match("^%s*(.-)%s*$") or ""
    if value == "" then value = tostring(fallback or "Game") end
    return value:sub(1, 64)
end

local function ensureFolderTree(path)
    if type(makefolder) ~= "function" then return false end
    local current = ""
    for part in tostring(path):gmatch("[^/]+") do
        current = (current == "") and part or (current .. "/" .. part)
        local exists = false
        if type(isfolder) == "function" then
            local ok, result = pcall(isfolder, current)
            exists = ok and result == true
        end
        if not exists then pcall(makefolder, current) end
    end
    return true
end

local function createConfigStore(folderName)
    folderName = safeFolderName(folderName, "Game" .. tostring(game.PlaceId))
    local dir = "N3zHUB/" .. folderName .. "/setting"
    local path = dir .. "/config.json"
    local values = {}
    local loaded = false

    if type(readfile) == "function" and type(isfile) == "function" then
        local okExists, exists = pcall(isfile, path)
        if okExists and exists then
            local okRead, rawConfig = pcall(readfile, path)
            if okRead and type(rawConfig) == "string" and rawConfig ~= "" then
                local okDecode, decoded = pcall(function()
                    return HttpService:JSONDecode(rawConfig)
                end)
                if okDecode and type(decoded) == "table" then
                    if type(decoded.values) == "table" then
                        values = decoded.values
                    else
                        values = decoded
                    end
                    loaded = true
                end
            end
        end
    end

    local store = {
        path = path,
        dir = dir,
        game = folderName,
        values = values,
        loaded = loaded,
        dirty = false,
        _saveToken = 0,
    }

    function store:Has(key)
        return type(key) == "string" and self.values[key] ~= nil
    end

    function store:Get(key, defaultValue)
        local value = self.values[key]
        if value == nil then return defaultValue end
        return value
    end

    function store:Ensure(key, value)
        if type(key) ~= "string" or key == "" then return value end
        if self.values[key] == nil then
            self.values[key] = value
            self.dirty = true
        end
        return self.values[key]
    end

    function store:Flush()
        if not self.dirty then return true end
        if type(writefile) ~= "function" then return false end
        ensureFolderTree(self.dir)
        local payload = {
            version = 1,
            game = self.game,
            placeId = game.PlaceId,
            values = self.values,
        }
        local okEncode, encoded = pcall(function()
            return HttpService:JSONEncode(payload)
        end)
        if not okEncode then return false end
        local okWrite = pcall(writefile, self.path, encoded)
        if okWrite then self.dirty = false end
        return okWrite
    end

    function store:ScheduleSave()
        self._saveToken += 1
        local token = self._saveToken
        task.delay(0.12, function()
            if token == self._saveToken then
                pcall(function() self:Flush() end)
            end
        end)
    end

    function store:Set(key, value)
        if type(key) ~= "string" or key == "" then return end
        if self.values[key] == value then return end
        self.values[key] = value
        self.dirty = true
        self:ScheduleSave()
    end

    return store
end

-- ---------- game detect + source preflight ----------
local placeId = game.PlaceId
local activeMod = nil
for _, m in ipairs(MODULES) do
    for _, pid in ipairs(m.placeIds) do
        if pid == placeId then
            activeMod = m
            break
        end
    end
    if activeMod then break end
end

-- Fetch and compile everything before tearing down a working instance. This
-- prevents transient raw-GitHub failures from leaving only an empty dock.
local dockSrc = fetchHub(isMobile and "n3z-dock-mobile.lua" or "n3z-dock.lua")
local dockChunk, dockLoadErr = loadstring(dockSrc, "@n3z-dock")
assert(dockChunk, "N3Z: failed to compile dock: " .. tostring(dockLoadErr))
local Dock = dockChunk()
assert(type(Dock) == "table", "N3Z: dock source did not return a table")

local compatSrc = fetchHub("n3z-compat.lua")
local compatChunk, compatLoadErr = loadstring(compatSrc, "@n3z-compat")
assert(compatChunk, "N3Z: failed to compile compat: " .. tostring(compatLoadErr))
local makeWindow = compatChunk()
assert(type(makeWindow) == "function", "N3Z: compat source did not return a function")

local activeModuleFn = nil
if activeMod then
    local moduleSrc = fetch(activeMod.file, activeMod.file)
    local moduleChunk, moduleLoadErr = loadstring(moduleSrc, "@" .. activeMod.id)
    assert(moduleChunk, "N3Z: failed to compile module " .. activeMod.id .. ": " .. tostring(moduleLoadErr))

    local okFactory, factoryOrErr = pcall(moduleChunk)
    assert(okFactory, "N3Z: failed to prepare module " .. activeMod.id .. ": " .. tostring(factoryOrErr))
    assert(type(factoryOrErr) == "function", "N3Z: module did not return function(Window, ctx)")
    activeModuleFn = factoryOrErr
end

-- ---------- env ----------
local env = (type(getgenv) == "function" and getgenv()) or _G

-- destroy previous instance (clean re-execute)
if type(env.__N3Z_WINDOW) == "table" and type(env.__N3Z_WINDOW.Destroy) == "function" then
    pcall(function() env.__N3Z_WINDOW:Destroy() end)
end
env.__N3Z_WINDOW = nil

-- sweep orphan N3zDock guis (covers case where __N3Z_WINDOW was lost)
pcall(function() Dock.destroyAllGuis() end)

-- ---------- build ----------
local dock = Dock.new({ menuKey = Enum.KeyCode.K })
local Window = makeWindow(dock)
env.__N3Z_WINDOW = Window
-- NOTE: __RAVEN_WINDOW alias is set AFTER the module loads (see below).
-- Old modules destroy getgenv().__RAVEN_WINDOW on load; setting it before
-- loadstring would make the module kill the window we just built.

local gameName = activeMod and activeMod.game or tostring(game.Name)
local modLine = (activeMod and activeMod.version or "no module")
local configFolderName = activeMod and (activeMod.configName or activeMod.name or activeMod.id)
    or ("Game" .. tostring(placeId))
local configStore = createConfigStore(configFolderName)
Window:SetConfigStore(configStore)

local savedBlockInput = configStore:Ensure("__hub.BlockGameInput", false)
dock:SetInputBlockEnabled(savedBlockInput == true)

local savedMenuKeyName = configStore:Ensure("__hub.MenuKey", "K")
local savedMenuKey = nil
if type(savedMenuKeyName) == "string" then
    pcall(function() savedMenuKey = Enum.KeyCode[savedMenuKeyName] end)
end
if typeof(savedMenuKey) ~= "EnumItem" then savedMenuKey = Enum.KeyCode.K end
dock:SetMenuKey(savedMenuKey)
dock:SetMenuKeyChangedCallback(function(keyCode)
    if typeof(keyCode) == "EnumItem" then
        configStore:Set("__hub.MenuKey", keyCode.Name)
    end
end)
dock:SetHeader(gameName, "place " .. tostring(placeId) .. " - " .. localPlayer.Name, modLine)
dock:SetMenuKeyName(isMobile and "TAP" or savedMenuKey.Name)

if isMobile then
    local toggleX = tonumber(configStore:Ensure("__hub.MobileToggleX", 0.92)) or 0.92
    local toggleY = tonumber(configStore:Ensure("__hub.MobileToggleY", 0.12)) or 0.12
    dock:SetMobileTogglePosition(toggleX, toggleY)
    dock:SetMobileToggleChangedCallback(function(x, y)
        x = math.floor((tonumber(x) or 0.92) * 10000 + 0.5) / 10000
        y = math.floor((tonumber(y) or 0.12) * 10000 + 0.5) / 10000
        configStore:Set("__hub.MobileToggleX", x)
        configStore:Set("__hub.MobileToggleY", y)
    end)
end

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
        sub = m.version .. " - " .. (isActive and ("matched: " .. m.game) or "not in this game"),
        active = isActive,
    })
end

-- ---------- SETTINGS tab ----------
local profileName = configStore.path
if isMobile then
    dock:AddRow("settings", {
        kind = "action",
        name = "Mobile Menu",
        desc = "Use the floating N3Z button anywhere, or tap the active tab to collapse the panel",
        buttonText = "TOGGLE",
        onPress = function() dock:Toggle() end,
    })
    dock:AddRow("settings", {
        kind = "action",
        name = "Reset Mobile Button",
        desc = "Move the floating N3Z button back to its default position",
        buttonText = "RESET",
        onPress = function()
            dock:SetMobileTogglePosition(0.92, 0.12)
            configStore:Set("__hub.MobileToggleX", 0.92)
            configStore:Set("__hub.MobileToggleY", 0.12)
        end,
    })
else
    dock:AddRow("settings", {
        kind = "action", name = "Menu Toggle Key", desc = "Press this row, then press a key to change the menu hotkey",
        chip = savedMenuKey.Name, rebindKey = true,
    })
end
dock:AddRow("settings", {
    kind = "action", name = "Config Profile", desc = profileName,
    chip = "EDIT", clipboard = profileName,
})

dock:AddRow("settings", {
    kind = "toggle",
    name = "Block Game Input",
    desc = "Block mouse / touch input from reaching the game while a menu tab is open",
    value = dock:IsInputBlockEnabled(),
    onChange = function(v)
        dock:SetInputBlockEnabled(v)
        configStore:Set("__hub.BlockGameInput", v == true)
    end,
})

local unloadAll
local unloadDone = false
unloadAll = function()
    if unloadDone then return end
    unloadDone = true

    -- Make the menu disappear before any module cleanup runs. Cleanup may
    -- yield/error internally, but the hub itself should already be gone.
    pcall(function() dock:SetVisible(false) end)

    local moduleHandle = activeMod and activeMod.envKey and env[activeMod.envKey] or nil
    if type(moduleHandle) == "table" and type(moduleHandle.Destroy) == "function" then
        pcall(moduleHandle.Destroy)
    end

    env.__N3Z_WINDOW = nil
    env.__RAVEN_WINDOW = nil

    pcall(function() Window:Destroy() end)
    pcall(function() Dock.destroyAllGuis() end)

    -- One deferred sweep catches a GUI that was still inside its click event
    -- when the first destroy ran.
    task.defer(function()
        pcall(function() Dock.destroyAllGuis() end)
    end)
end

dock:AddRow("settings", {
    kind = "action", name = "Unload Module", desc = "Clean teardown of module & dock",
    buttonText = "UNLOAD", danger = true, onPress = unloadAll,
})
dock:SetTabInfo("modules", #MODULES .. " modules · " .. (activeMod and "1 ACTIVE" or "none in this game"))
dock:SetTabInfo("settings", "settings")

-- ---------- load the preflighted game module ----------
if activeMod then
    local ctx = { game = activeMod.game, placeId = placeId, module = activeMod, dock = dock }
    local ok, runErr = pcall(activeModuleFn, Window, ctx)
    if not ok then
        local message = tostring(runErr or "unknown module error")
        warn("[N3Z] module error: " .. message)

        -- Never leave a half-built/blank module page behind. Clear any rows
        -- created before the exception and surface the failure in the dock.
        pcall(function()
            dock:ClearRows("combat")
            dock:ClearRows("visuals")

            local short = message:gsub("[%c]+", " ")
            if #short > 300 then
                short = short:sub(1, 300) .. "..."
            end

            dock:AddRow("combat", {
                kind = "label",
                text = "Module failed to start.\n" .. short,
            })
            dock:AddRow("visuals", {
                kind = "label",
                text = "Module failed to start. Check Combat for details.",
            })
            dock:SetTabInfo("combat", "module error")
            dock:SetTabInfo("visuals", "module error")
        end)
    end
else
    dock:AddRow("visuals", { kind = "label", text = "No module for this game yet." })
end

-- compat alias for old modules (set after load so the module's own
-- startup cleanup can't destroy the window we just built)
env.__RAVEN_WINDOW = Window

-- First run writes one complete per-game config. Later UI changes autosave.
pcall(function() configStore:Flush() end)


-- boot: dock bar only. The panel opens when the user picks a tab.
return Window
