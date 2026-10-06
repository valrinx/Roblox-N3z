-- ============================================================
-- Roblox-N3z v2.4.6 · init.lua
-- Commit-pinned entrypoint wrapper for N3z HUB
-- ============================================================

local HttpService = game:GetService("HttpService")
local ref = "main"

pcall(function()
    local body = game:HttpGet(
        "https://api.github.com/repos/valrinx/Roblox-N3z/commits/main?_cb="
        .. HttpService:GenerateGUID(false)
    )
    local data = HttpService:JSONDecode(body)
    if type(data) == "table" and type(data.sha) == "string"
        and #data.sha == 40 and data.sha:match("^[%da-fA-F]+$") then
        ref = data.sha
    end
end)

local env = (type(getgenv) == "function" and getgenv()) or _G
env.__N3Z_SOURCE_REF = ref

local url = "https://raw.githubusercontent.com/valrinx/Roblox-N3z/"
    .. ref .. "/n3z.lua?_cb=" .. HttpService:GenerateGUID(false)
local ok, res = pcall(function() return game:HttpGet(url) end)

if not ok or type(res) ~= "string" or #res < 50 then
    error("[N3Z] Failed to load pinned n3z.lua: " .. tostring(res))
end

local fn, compileErr = loadstring(res, "@Roblox-N3z/n3z@" .. ref)
if not fn then error("[N3Z] Compilation error: " .. tostring(compileErr)) end
return fn()
