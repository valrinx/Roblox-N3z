local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

assert(game.PlaceId == 84448037861644, "Urban Reload auto farm: wrong place")

local env = (type(getgenv) == "function" and getgenv()) or _G
if type(env.N3Z_UrbanFarm) == "table" and type(env.N3Z_UrbanFarm.Stop) == "function" then
    env.N3Z_UrbanFarm.Stop()
end

local player = Players.LocalPlayer
local zombies = Workspace:WaitForChild("HoodLocal", 10)
assert(zombies, "Urban Reload auto farm: HoodLocal is missing")

local state = {
    Running = false,
    StartMoney = player:GetAttribute("Money") or 0,
    Target = nil,
    AimPart = nil,
    MaxDistance = 95,
    FireInterval = 0.14,
    MinHealth = 35,
    LootAttempts = 0,
}

local connection
local aimBound = false
local lastShot = 0
local lastLoot = 0
local fireWeapon
local lootNow

if type(getgc) == "function" and type(debug) == "table" and type(debug.getinfo) == "function" then
    for _, candidate in ipairs(getgc(true)) do
        if type(candidate) == "function" then
            local ok, info = pcall(debug.getinfo, candidate)
            if ok and info and info.name == "fire" and info.currentline == 662
                and tostring(info.source):find("WeaponClient", 1, true) then
                fireWeapon = candidate
                local upvalues = debug.getupvalues and debug.getupvalues(candidate)
                local clientState = upvalues and upvalues[7]
                if type(clientState) == "table" and type(clientState.HoodLootNow) == "function" then
                    lootNow = clientState.HoodLootNow
                end
                break
            end
        end
    end
end
assert(fireWeapon, "Urban Reload auto farm: WeaponClient fire handler unavailable")
assert(lootNow, "Urban Reload auto farm: HoodLootNow handler unavailable")

local function characterParts()
    local character = player.Character
    if not character then return nil end
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then return nil end
    return character, root, humanoid
end

local function isFarmZone(character)
    return character:GetAttribute("InFarmZone") == true
end

local function rayParams(character)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignored = {character}
    local fx = Workspace:FindFirstChild("FX")
    if fx then table.insert(ignored, fx) end
    params.FilterDescendantsInstances = ignored
    pcall(function() params.CollisionGroup = "Bullet" end)
    return params
end

local function rayReaches(origin, part, model, params)
    local hit = Workspace:Raycast(origin, part.Position - origin, params)
    return not hit or hit.Instance:IsDescendantOf(model)
end

local function muzzlePosition(tool)
    local handle = tool:FindFirstChild("Handle")
    local muzzle = handle and handle:FindFirstChild("Muzzle")
    if muzzle and muzzle:IsA("Attachment") then return muzzle.WorldPosition end
    return handle and handle.Position or nil
end

local function exposedPart(model, camera, muzzle, params)
    for _, name in ipairs({"Head", "UpperTorso", "HumanoidRootPart"}) do
        local part = model:FindFirstChild(name)
        if part and part:IsA("BasePart")
            and rayReaches(camera.CFrame.Position, part, model, params)
            and rayReaches(muzzle, part, model, params) then
            return part
        end
    end
    return nil
end

local function findTarget(root, character, tool)
    local camera = Workspace.CurrentCamera
    local muzzle = muzzlePosition(tool)
    if not camera or not muzzle then return nil end
    local params = rayParams(character)
    local best, bestPart, bestDistance
    for _, model in ipairs(zombies:GetChildren()) do
        if model:IsA("Model") then
            local humanoid = model:FindFirstChildOfClass("Humanoid")
            local zombieRoot = model:FindFirstChild("HumanoidRootPart")
            if humanoid and humanoid.Health > 0 and zombieRoot then
                local distance = (zombieRoot.Position - root.Position).Magnitude
                if distance <= state.MaxDistance and (not bestDistance or distance < bestDistance) then
                    local part = exposedPart(model, camera, muzzle, params)
                    if part then
                        best = model
                        bestPart = part
                        bestDistance = distance
                    end
                end
            end
        end
    end
    return best, bestPart
end

local function trackTarget(model, part)
    state.Target = model
    state.AimPart = part
end

local function step()
    local character, root, humanoid = characterParts()
    if not character or not isFarmZone(character) then
        if state.Target then trackTarget(nil) end
        return
    end
    if os.clock() - lastLoot >= 0.1 then
        lastLoot = os.clock()
        local ok, requested = pcall(lootNow)
        if ok and requested == true then
            state.LootAttempts += 1
        end
    end
    if humanoid.Health < state.MinHealth then
        state.Stop()
        return
    end

    local tool = character:FindFirstChildOfClass("Tool")
    local camera = Workspace.CurrentCamera
    if not camera or not tool or not tool.Enabled or not tool:GetAttribute("Weapon") then
        trackTarget(nil)
        return
    end

    local target = state.Target
    local targetHumanoid = target and target:FindFirstChildOfClass("Humanoid")
    local targetRoot = target and target:FindFirstChild("HumanoidRootPart")
    local muzzle = muzzlePosition(tool)
    local part = state.AimPart
    if not targetHumanoid or targetHumanoid.Health <= 0 or not targetRoot
        or (targetRoot.Position - root.Position).Magnitude > state.MaxDistance
        or not part or not part:IsDescendantOf(target) or not muzzle
        or not rayReaches(camera.CFrame.Position, part, target, rayParams(character))
        or not rayReaches(muzzle, part, target, rayParams(character)) then
        target, part = findTarget(root, character, tool)
        trackTarget(target, part)
    end
    if not target then return end

    if os.clock() - lastShot >= state.FireInterval then
        lastShot = os.clock()
        pcall(fireWeapon, os.clock())
    end
end

function state.Stop()
    if not state.Running then return end
    state.Running = false
    if connection then connection:Disconnect() end
    if aimBound then
        RunService:UnbindFromRenderStep("N3Z_UrbanFarmAim")
        aimBound = false
    end
    trackTarget(nil)
    local character = player.Character
    local tool = character and character:FindFirstChildOfClass("Tool")
    if tool then pcall(function() tool:Deactivate() end) end
end

function state.Start()
    if state.Running then return end
    state.Running = true
    RunService:BindToRenderStep("N3Z_UrbanFarmAim", Enum.RenderPriority.Camera.Value + 10, function()
        local target = state.Target
        local part = state.AimPart
        local camera = Workspace.CurrentCamera
        if part and part.Parent and camera then
            camera.CFrame = CFrame.lookAt(camera.CFrame.Position, part.Position)
        end
    end)
    aimBound = true
    connection = RunService.Heartbeat:Connect(step)
end

function state.Report()
    return {
        running = state.Running,
        moneyEarned = (player:GetAttribute("Money") or 0) - state.StartMoney,
        lootAttempts = state.LootAttempts,
        target = state.Target and state.Target.Name or nil,
        inFarmZone = player.Character and isFarmZone(player.Character) or false,
    }
end

env.N3Z_UrbanFarm = state
state.Start()
return state
