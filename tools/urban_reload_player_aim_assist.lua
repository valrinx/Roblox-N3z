local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

assert(game.PlaceId == 84448037861644, "Urban Reload aim assist: wrong place")

local env = (type(getgenv) == "function" and getgenv()) or _G
if type(env.N3Z_PlayerAimAssist) == "table" and type(env.N3Z_PlayerAimAssist.Stop) == "function" then
    env.N3Z_PlayerAimAssist.Stop()
end
if type(env.N3Z_UrbanFarm) == "table" and env.N3Z_UrbanFarm.Running
    and type(env.N3Z_UrbanFarm.Stop) == "function" then
    env.N3Z_UrbanFarm.Stop()
end

local localPlayer = Players.LocalPlayer
local state = {
    Enabled = false,
    Target = nil,
    AimPart = nil,
    AimName = nil,
    AimGroup = nil,
    FovCenter = nil,
    MaxDistance = 450,
    FovPixels = 180,
    FovVisible = true,
    Smoothness = 0.18,
    MaxTurnDegreesPerSecond = 120,
    RequireRightMouse = false,
    Status = "starting",
}

local bound = false
local fovBound = false
local cameraStep
local lastPriorityScan = 0
local lastPartSwitch = 0
local fovGui
local fovCircle
local fovStroke

assert(type(getgc) == "function" and type(debug) == "table"
    and type(debug.getinfo) == "function" and type(debug.getupvalues) == "function"
    and type(debug.setupvalue) == "function",
    "Urban Reload aim assist: camera introspection unavailable")

for _, candidate in ipairs(getgc(true)) do
    if type(candidate) == "function" then
        local ok, info = pcall(debug.getinfo, candidate)
        if ok and info and info.currentline == 383
            and tostring(info.source):find("CameraClient", 1, true) then
            local upvalues = debug.getupvalues(candidate)
            if type(upvalues[8]) == "number" and type(upvalues[9]) == "number" then
                cameraStep = candidate
                break
            end
        end
    end
end
assert(cameraStep, "Urban Reload aim assist: CameraClient update unavailable")

local function equippedWeapon(character)
    local tool = character and character:FindFirstChildOfClass("Tool")
    if not tool or not tool.Enabled or not tool:GetAttribute("Weapon") then return nil end
    return tool
end

local function muzzlePosition(tool)
    local handle = tool:FindFirstChild("Handle")
    local muzzle = handle and handle:FindFirstChild("Muzzle")
    if muzzle and muzzle:IsA("Attachment") then return muzzle.WorldPosition end
    return handle and handle.Position or nil
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

local function clearLine(origin, point, model, params)
    local hit = Workspace:Raycast(origin, point - origin, params)
    return not hit or hit.Instance:IsDescendantOf(model)
end

local aimPoints = {
    {"Head", "Head"}, {"Neck", "Neck"},
    {"UpperTorso", "Body"}, {"LowerTorso", "Body"},
    {"Torso", "Body"}, {"HumanoidRootPart", "Body"},
    {"LeftUpperArm", "Arm"}, {"LeftLowerArm", "Arm"}, {"LeftHand", "Arm"},
    {"RightUpperArm", "Arm"}, {"RightLowerArm", "Arm"}, {"RightHand", "Arm"},
    {"Left Arm", "Arm"}, {"Right Arm", "Arm"},
    {"LeftUpperLeg", "Leg"}, {"LeftLowerLeg", "Leg"}, {"LeftFoot", "Leg"},
    {"RightUpperLeg", "Leg"}, {"RightLowerLeg", "Leg"}, {"RightFoot", "Leg"},
    {"Left Leg", "Leg"}, {"Right Leg", "Leg"},
}

local groupPriority = {Head = 1, Body = 2, Neck = 3, Arm = 4, Leg = 5}

local function pointFor(character, name)
    if name == "Neck" then
        local head = character:FindFirstChild("Head")
        local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
        if not head or not torso then return nil end
        local joint = torso:FindFirstChild("Neck")
        if joint and joint:IsA("Motor6D") and joint.Part0 then
            return head, (joint.Part0.CFrame * joint.C0).Position
        end
        return head, head.Position:Lerp(torso.Position, 0.3)
    end
    local part = character:FindFirstChild(name)
    if part and part:IsA("BasePart") then return part, part.Position end
    return nil
end

local function validPlayer(other)
    if other == localPlayer then return nil end
    if not localPlayer.Neutral and not other.Neutral and localPlayer.Team == other.Team then
        return nil
    end
    local character = other.Character
    if not character or character:GetAttribute("PvPSafe") == true then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return nil end
    return character
end

local function targetPart(character, camera, muzzle, params, center, fovLimit)
    local best, nearestPixels
    for _, option in ipairs(aimPoints) do
        local name, group = option[1], option[2]
        local part, point = pointFor(character, name)
        if part then
            local screen, onScreen = camera:WorldToViewportPoint(point)
            local pixels = (Vector2.new(screen.X, screen.Y) - center).Magnitude
            local distance = (point - camera.CFrame.Position).Magnitude
            if onScreen and screen.Z > 0 and pixels <= fovLimit
                and distance <= state.MaxDistance
                and clearLine(camera.CFrame.Position, point, character, params)
                and clearLine(muzzle, point, character, params) then
                if not nearestPixels or pixels < nearestPixels then
                    nearestPixels = pixels
                end
                local priority = groupPriority[group]
                if not best or priority < best.priority
                    or (priority == best.priority and pixels < best.score) then
                    best = {part = part, point = point, name = name, group = group,
                        priority = priority, score = pixels}
                end
            end
        end
    end
    return best, nearestPixels
end

local function aimCenter(camera)
    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    local crosshair = playerGui and playerGui:FindFirstChild("Crosshair")
    local root = crosshair and crosshair:FindFirstChild("CrosshairRoot")
    if root and root:IsA("GuiObject") then
        return root.AbsolutePosition + root.AbsoluteSize / 2
    end
    return camera.ViewportSize / 2
end

local function findTarget(camera, muzzle, params, center)
    local bestPlayer, best, bestPlayerScore
    for _, other in ipairs(Players:GetPlayers()) do
        local character = validPlayer(other)
        if character then
            local candidate, nearestPixels = targetPart(character, camera, muzzle, params,
                center, state.FovPixels)
            if candidate and (not bestPlayerScore or nearestPixels < bestPlayerScore) then
                bestPlayer = other
                best = candidate
                bestPlayerScore = nearestPixels
            end
        end
    end
    return bestPlayer, best
end

local function clearTarget()
    state.Target = nil
    state.AimPart = nil
    state.AimName = nil
    state.AimGroup = nil
    lastPartSwitch = 0
end

local function createFovCircle()
    local playerGui = localPlayer:WaitForChild("PlayerGui", 10)
    if not playerGui then return end
    local previous = playerGui:FindFirstChild("N3Z_PlayerAimFov")
    if previous then previous:Destroy() end

    fovGui = Instance.new("ScreenGui")
    fovGui.Name = "N3Z_PlayerAimFov"
    fovGui.IgnoreGuiInset = true
    fovGui.ResetOnSpawn = false
    fovGui.DisplayOrder = 1000
    fovGui.Parent = playerGui

    fovCircle = Instance.new("Frame")
    fovCircle.Name = "Circle"
    fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
    fovCircle.Position = UDim2.fromScale(0.5, 0.5)
    fovCircle.BackgroundTransparency = 1
    fovCircle.BorderSizePixel = 0
    fovCircle.Active = false
    fovCircle.Parent = fovGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = fovCircle

    fovStroke = Instance.new("UIStroke")
    fovStroke.Thickness = 1.5
    fovStroke.Transparency = 0.15
    fovStroke.Color = Color3.fromRGB(90, 180, 255)
    fovStroke.Parent = fovCircle
end

local function updateFovCircle(character, center)
    if not fovGui or not fovCircle then return end
    local radius = math.max(10, tonumber(state.FovPixels) or 180)
    fovGui.Enabled = state.FovVisible
    fovCircle.Visible = equippedWeapon(character) ~= nil
    if center then
        local origin = fovGui.AbsolutePosition
        fovCircle.Position = UDim2.fromOffset(center.X - origin.X, center.Y - origin.Y)
    end
    fovCircle.Size = UDim2.fromOffset(radius * 2, radius * 2)
    fovStroke.Color = state.Target
        and Color3.fromRGB(255, 105, 105) or Color3.fromRGB(90, 180, 255)
end

local function update(dt)
    local character = localPlayer.Character
    local camera = Workspace.CurrentCamera
    local center = camera and aimCenter(camera)
    state.FovCenter = center
    if state.RequireRightMouse
        and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        clearTarget()
        state.Status = "waiting-for-right-mouse"
        return
    end

    local weapon = equippedWeapon(character)
    local muzzle = weapon and muzzlePosition(weapon)
    if not camera or not muzzle then
        clearTarget()
        state.Status = "equip-ranged-weapon"
        return
    end

    local params = rayParams(character)
    local other, chosen = state.Target, nil
    local lockedCharacter = other and validPlayer(other)
    local part, point
    if lockedCharacter and state.AimName then
        part, point = pointFor(lockedCharacter, state.AimName)
    end
    if lockedCharacter and part and part == state.AimPart then
        local screen, onScreen = camera:WorldToViewportPoint(point)
        local pixels = (Vector2.new(screen.X, screen.Y) - center).Magnitude
        if not onScreen or screen.Z <= 0 or pixels > state.FovPixels * 1.4
            or (point - camera.CFrame.Position).Magnitude > state.MaxDistance
            or not clearLine(camera.CFrame.Position, point, lockedCharacter, params)
            or not clearLine(muzzle, point, lockedCharacter, params) then
            other = nil
        else
            chosen = {part = part, point = point, name = state.AimName,
                group = state.AimGroup, priority = groupPriority[state.AimGroup], score = pixels}
        end
    else
        other = nil
    end
    if not other then other, chosen = findTarget(camera, muzzle, params, center) end
    if other and other == state.Target and chosen and lockedCharacter
        and os.clock() - lastPriorityScan >= 0.2 then
        lastPriorityScan = os.clock()
        local preferred = targetPart(lockedCharacter, camera, muzzle, params,
            center, state.FovPixels)
        if preferred and preferred.priority < chosen.priority
            and os.clock() - lastPartSwitch >= 0.25 then
            chosen = preferred
        end
    end
    if not other or not chosen then
        clearTarget()
        state.Status = "no-visible-player"
        return
    end

    if state.AimName ~= chosen.name or state.Target ~= other then
        lastPartSwitch = os.clock()
    end
    state.Target = other
    state.AimPart = chosen.part
    state.AimName = chosen.name
    state.AimGroup = chosen.group
    state.Status = "tracking"
    local direction = (chosen.point - camera.CFrame.Position).Unit
    local look = camera.CFrame.LookVector
    local yaw = math.atan2(-look.X, -look.Z)
    local pitch = math.asin(math.clamp(look.Y, -1, 1))
    local desiredYaw = math.atan2(-direction.X, -direction.Z)
    local desiredPitch = math.asin(math.clamp(direction.Y, -1, 1))
    local alpha = 1 - (1 - math.clamp(state.Smoothness, 0.01, 1)) ^ (math.max(dt, 0) * 60)
    local limit = math.rad(state.MaxTurnDegreesPerSecond) * math.max(dt, 0)
    local yawError = math.atan2(math.sin(desiredYaw - yaw), math.cos(desiredYaw - yaw))
    local nextYaw = yaw + math.clamp(yawError * alpha, -limit, limit)
    local nextPitch = pitch + math.clamp((desiredPitch - pitch) * alpha, -limit, limit)
    local yawOk = pcall(debug.setupvalue, cameraStep, 8, nextYaw)
    local pitchOk = pcall(debug.setupvalue, cameraStep, 9, nextPitch)
    if not yawOk or not pitchOk then state.Status = "camera-controller-unavailable" end
end

function state.Start()
    if state.Enabled then return end
    state.Enabled = true
    createFovCircle()
    RunService:BindToRenderStep("N3Z_PlayerAimAssist", Enum.RenderPriority.Camera.Value - 1, update)
    bound = true
    RunService:BindToRenderStep("N3Z_PlayerAimFov", Enum.RenderPriority.Last.Value + 1,
        function()
            local camera = Workspace.CurrentCamera
            local center = camera and aimCenter(camera)
            state.FovCenter = center
            updateFovCircle(localPlayer.Character, center)
        end)
    fovBound = true
end

function state.Stop()
    if bound then
        RunService:UnbindFromRenderStep("N3Z_PlayerAimAssist")
        bound = false
    end
    if fovBound then
        RunService:UnbindFromRenderStep("N3Z_PlayerAimFov")
        fovBound = false
    end
    state.Enabled = false
    clearTarget()
    if fovGui then fovGui:Destroy() end
    fovGui, fovCircle, fovStroke = nil, nil, nil
    state.Status = "stopped"
end

function state.Report()
    return {
        enabled = state.Enabled,
        target = state.Target and state.Target.Name or nil,
        aimPart = state.AimName,
        aimGroup = state.AimGroup,
        holdRightMouse = state.RequireRightMouse,
        fovPixels = state.FovPixels,
        fovCenter = state.FovCenter,
        fovCircleVisible = fovCircle and fovCircle.Visible and fovGui.Enabled or false,
        maxDistance = state.MaxDistance,
        smoothness = state.Smoothness,
        maxTurnDegreesPerSecond = state.MaxTurnDegreesPerSecond,
        status = state.Status,
    }
end

env.N3Z_PlayerAimAssist = state
state.Start()
return state
