local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

assert(game.PlaceId == 84448037861644, "Urban Reload cases: wrong place")

local env = (type(getgenv) == "function" and getgenv()) or _G
if type(env.N3Z_UrbanCaseOpener) == "table" and type(env.N3Z_UrbanCaseOpener.Stop) == "function" then
    env.N3Z_UrbanCaseOpener.Stop()
end

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("OpenCase")
local weaponCases = require(ReplicatedStorage:WaitForChild("WeaponCases"))
local attachmentCases = require(ReplicatedStorage:WaitForChild("AttachmentCases"))

local state = {
    Enabled = false,
    Category = "Weapon",
    WeaponCase = "Basic",
    AttachmentCase = "AttSights",
    ReserveMoney = 0,
    MaxOpens = 10,
    Opened = 0,
    BusyRetries = 0,
    Status = "stopped",
    LastItem = nil,
    LastError = nil,
}

local generation = 0

function state.CanOpen(money, cost, reserve)
    return type(money) == "number" and type(cost) == "number"
        and money >= cost + (tonumber(reserve) or 0)
end

function state.RetryDelay(result)
    if type(result) == "table" and result.err == "busy" then
        return math.max(0.05, tonumber(result.left) or 0.5)
    end
    return 0.05
end

local function selection()
    if state.Category == "Weapon" then
        return state.WeaponCase, weaponCases.INFO[state.WeaponCase], "WeaponStation"
    end
    if state.Category == "Attachment" then
        return state.AttachmentCase, attachmentCases.INFO[state.AttachmentCase], "AttachmentStation"
    end
end

local function nearStation(name)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local stations = Workspace:FindFirstChild("CaseStations")
    local station = stations and stations:FindFirstChild(name)
    local pad = station and station:FindFirstChild("Pad", true)
    if not root or not pad or not pad:IsA("BasePart") then return false end
    local delta = root.Position - pad.Position
    local radius = tonumber(station:GetAttribute("PadRadius")) or 2.56
    return Vector2.new(delta.X, delta.Z).Magnitude <= radius + 1
        and math.abs(delta.Y) <= 8
end

local function run(token)
    while state.Enabled and generation == token do
        local caseId, info, stationName = selection()
        if not info then
            state.Status = "invalid-case"
            state.LastError = tostring(caseId)
            break
        end
        if state.Opened >= math.max(1, tonumber(state.MaxOpens) or 10) then
            state.Status = "limit-reached"
            break
        end
        local money = tonumber(player:GetAttribute("Money"))
        if not state.CanOpen(money, info.Cost, state.ReserveMoney) then
            state.Status = "insufficient-funds"
            break
        end
        if not nearStation(stationName) then
            state.Status = "move-to-" .. stationName
            task.wait(0.5)
        else
            state.Status = "opening"
            local ok, result = pcall(function()
                return remote:InvokeServer(caseId)
            end)
            if not state.Enabled or generation ~= token then break end
            if not ok then
                state.Status = "remote-error"
                state.LastError = tostring(result)
                break
            end
            if type(result) ~= "table" or result.ok ~= true then
                local err = type(result) == "table" and result.err or tostring(result)
                state.LastError = tostring(err)
                if err == "far" then
                    state.Status = "move-to-" .. stationName
                    task.wait(0.5)
                elseif err == "busy" then
                    state.BusyRetries += 1
                    state.Status = "server-cooldown"
                    task.wait(state.RetryDelay(result))
                else
                    state.Status = "server-rejected"
                    break
                end
            else
                state.Opened += 1
                state.LastItem = result.item or result.reward or result.id
                    or result.weapon
                state.LastError = nil
                state.Status = "opened"
                task.wait(state.RetryDelay(result))
            end
        end
    end
    if generation == token then state.Enabled = false end
end

function state.Start()
    if state.Enabled then return end
    state.Enabled = true
    state.Opened = 0
    state.BusyRetries = 0
    state.LastItem = nil
    state.LastError = nil
    generation += 1
    task.spawn(run, generation)
end

function state.Stop()
    generation += 1
    state.Enabled = false
    state.Status = "stopped"
end

function state.Report()
    local caseId, info, stationName = selection()
    return {
        enabled = state.Enabled,
        category = state.Category,
        caseId = caseId,
        cost = info and info.Cost,
        station = stationName,
        reserveMoney = state.ReserveMoney,
        maxOpens = state.MaxOpens,
        opened = state.Opened,
        busyRetries = state.BusyRetries,
        money = player:GetAttribute("Money"),
        status = state.Status,
        lastItem = state.LastItem,
        lastError = state.LastError,
    }
end

env.N3Z_UrbanCaseOpener = state
return state
