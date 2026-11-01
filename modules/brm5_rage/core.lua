-- ==============================================================================
-- N3Z HUB — Blackhawk Rescue Mission 5 (BRM5 / Sawang)
-- Version: v4.0.0 (Zero-Lag Architecture)
-- Compatible PlaceIds: 2916899287, 3701546109, 13622622708
-- Supported GameId: 1054526971
-- Features:
--   - Silent / Smooth AimLock with FOV Circle (AI Bot priority)
--   - No Recoil & No Sway (Optimized GC spring cache, zero CPU stutter)
--   - GPU Hardware-Accelerated Chams ESP (Zero Drawing lag, AI vs Player color)
--   - Speed Hack (WalkSpeed controller, event-safe)
--   - Stepped NoClip
--   - Fullbright & Atmosphere / Fog Stripper
-- Note: Teleport strictly excluded per repository policy.
-- ==============================================================================

return function(Window, info)
    -- ═══════════════════════════════════════════════
    -- CLEANUP PREVIOUS SCRIPT INSTANCE
    -- ═══════════════════════════════════════════════
    if getgenv().__RAVEN_CLEANUP then
        for _, fn in ipairs(getgenv().__RAVEN_CLEANUP) do
            pcall(fn)
        end
    end
    getgenv().__RAVEN_CLEANUP = {}

    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Lighting = game:GetService("Lighting")
    local camera = workspace.CurrentCamera

    -- ═══════════════════════════════════════════════
    -- CONFIGURATION STATE
    -- ═══════════════════════════════════════════════
    local state = {
        aimbot = {
            enabled = false,
            fov = 150,
            smoothness = 0.35,
            targetAIOnly = true,
            targetPart = "Head",
            showFOV = true
        },
        combat = {
            noRecoil = true,
            noSway = true,
            fullbright = false
        },
        movement = {
            speedEnabled = false,
            speedValue = 24,
            noclip = false
        },
        esp = {
            enabled = true,
            chams = true,
            aiColor = Color3.fromRGB(255, 45, 45),
            playerColor = Color3.fromRGB(0, 165, 255)
        }
    }

    -- ═══════════════════════════════════════════════
    -- CONTAINER RESOLUTION (O(1) CACHING)
    -- ═══════════════════════════════════════════════
    local charContainer = nil

    local function resolveContainer()
        if charContainer and charContainer.Parent == workspace then
            return charContainer
        end
        for _, child in ipairs(workspace:GetChildren()) do
            if child.Name == "Model" and child:IsA("Model") then
                if child:FindFirstChild("Male") or child:FindFirstChild("Female") then
                    charContainer = child
                    return charContainer
                end
            end
        end
        return nil
    end

    charContainer = resolveContainer()

    local function getSelfChar()
        local container = resolveContainer()
        if not container then return nil end
        local camPos = camera.CFrame.Position
        local selfModel, minDist = nil, 25
        for _, m in ipairs(container:GetChildren()) do
            local root = m:FindFirstChild("Root")
            if root then
                local d = (root.Position - camPos).Magnitude
                if d < minDist then
                    minDist = d
                    selfModel = m
                end
            end
        end
        return selfModel
    end

    -- ═══════════════════════════════════════════════
    -- TABS
    -- ═══════════════════════════════════════════════
    local TabCombat = Window:CreateTab("Combat", "rbxassetid://7734053495")
    local TabVisuals = Window:CreateTab("Visuals", "rbxassetid://7734009413")
    local TabMovement = Window:CreateTab("Movement", "rbxassetid://7734042071")

    -- ═══════════════════════════════════════════════
    -- COMBAT: WEAPON GC PATCH (ZERO-STUTTER)
    -- ═══════════════════════════════════════════════
    TabCombat:CreateSection("Weapon Modifications")

    local cachedSprings = {}
    local cachedTables = {}

    local function scanGC()
        cachedSprings = {}
        cachedTables = {}
        for _, obj in ipairs(getgc(true)) do
            if type(obj) == "table" then
                if rawget(obj, "_recoilSpring") then
                    table.insert(cachedSprings, obj)
                end
                if rawget(obj, "_doSway") ~= nil or rawget(obj, "_recoilAmount") ~= nil then
                    table.insert(cachedTables, obj)
                end
            end
        end
    end
    task.spawn(scanGC)

    local recoilThread = task.spawn(function()
        while true do
            if state.combat.noRecoil or state.combat.noSway then
                for i = 1, #cachedSprings do
                    local rs = rawget(cachedSprings[i], "_recoilSpring")
                    if type(rs) == "table" then
                        for k, v in pairs(rs) do
                            if type(v) == "number" then rawset(rs, k, 0) end
                        end
                    end
                end
                for i = 1, #cachedTables do
                    local obj = cachedTables[i]
                    if state.combat.noSway and rawget(obj, "_doSway") ~= nil then
                        rawset(obj, "_doSway", false)
                    end
                    if state.combat.noRecoil and rawget(obj, "_recoilAmount") ~= nil then
                        rawset(obj, "_recoilAmount", 0)
                    end
                    if state.combat.noSway and rawget(obj, "_swayAmount") ~= nil then
                        rawset(obj, "_swayAmount", 0)
                    end
                end
            end
            task.wait(1.5)
        end
    end)

    TabCombat:CreateToggle({
        Name = "No Recoil",
        CurrentValue = state.combat.noRecoil,
        Callback = function(val)
            state.combat.noRecoil = val
        end
    })

    TabCombat:CreateToggle({
        Name = "No Sway",
        CurrentValue = state.combat.noSway,
        Callback = function(val)
            state.combat.noSway = val
        end
    })

    -- ───────────────────────────────────────────────
    -- COMBAT: AIMLOCK ENGINE
    -- ───────────────────────────────────────────────
    TabCombat:CreateSection("AimLock (Hold RMB)")

    local fovCircle = Drawing.new("Circle")
    fovCircle.Thickness = 1.5
    fovCircle.NumSides = 32
    fovCircle.Filled = false
    fovCircle.Color = Color3.fromRGB(0, 255, 170)
    fovCircle.Visible = false

    local aimbotConn = RunService.RenderStepped:Connect(function()
        local mousePos = UserInputService:GetMouseLocation()
        fovCircle.Position = mousePos
        fovCircle.Radius = state.aimbot.fov
        fovCircle.Visible = state.aimbot.enabled and state.aimbot.showFOV

        if not state.aimbot.enabled then return end
        if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end

        local container = resolveContainer()
        if not container then return end

        local selfChar = getSelfChar()
        local bestTarget = nil
        local shortestDist = state.aimbot.fov

        for _, m in ipairs(container:GetChildren()) do
            if m ~= selfChar and m:IsA("Model") then
                local isAI = false
                for _, sub in ipairs(m:GetChildren()) do
                    if string.sub(sub.Name, 1, 3) == "AI_" then
                        isAI = true
                        break
                    end
                end

                if not state.aimbot.targetAIOnly or isAI then
                    local targetPart = state.aimbot.targetPart == "Head"
                        and (m:FindFirstChild("Head") or m:FindFirstChild("FakeHead"))
                        or m:FindFirstChild("Root")

                    if targetPart then
                        local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                        if onScreen then
                            local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                            if screenDist < shortestDist then
                                shortestDist = screenDist
                                bestTarget = targetPart
                            end
                        end
                    end
                end
            end
        end

        if bestTarget then
            local camCFrame = camera.CFrame
            local targetCFrame = CFrame.new(camCFrame.Position, bestTarget.Position)
            camera.CFrame = camCFrame:Lerp(targetCFrame, state.aimbot.smoothness)
        end
    end)

    TabCombat:CreateToggle({
        Name = "Enable AimLock",
        CurrentValue = state.aimbot.enabled,
        Callback = function(val)
            state.aimbot.enabled = val
        end
    })

    TabCombat:CreateToggle({
        Name = "Target AI Bots Only",
        CurrentValue = state.aimbot.targetAIOnly,
        Callback = function(val)
            state.aimbot.targetAIOnly = val
        end
    })

    TabCombat:CreateToggle({
        Name = "Show FOV Circle",
        CurrentValue = state.aimbot.showFOV,
        Callback = function(val)
            state.aimbot.showFOV = val
        end
    })

    TabCombat:CreateSlider({
        Name = "FOV Radius",
        Range = {60, 400},
        Increment = 10,
        CurrentValue = state.aimbot.fov,
        Callback = function(val)
            state.aimbot.fov = val
        end
    })

    TabCombat:CreateSlider({
        Name = "Smoothness",
        Range = {1, 10},
        Increment = 1,
        CurrentValue = 3,
        Callback = function(val)
            state.aimbot.smoothness = val / 10
        end
    })

    -- ═══════════════════════════════════════════════
    -- VISUALS: GPU NATIVE CHAMS
    -- ═══════════════════════════════════════════════
    TabVisuals:CreateSection("Hardware-Accelerated ESP")

    local function applyChams(model)
        if not state.esp.enabled or not state.esp.chams or not model:IsA("Model") then return end
        if model == getSelfChar() then return end

        local isAI = false
        for _, sub in ipairs(model:GetChildren()) do
            if string.sub(sub.Name, 1, 3) == "AI_" then
                isAI = true
                break
            end
        end

        local hl = model:FindFirstChild("N3Z_Chams") or Instance.new("Highlight")
        hl.Name = "N3Z_Chams"
        hl.FillColor = isAI and state.esp.aiColor or state.esp.playerColor
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.5
        hl.OutlineTransparency = 0.1
        hl.Adornee = model
        hl.Parent = model
    end

    local function removeAllChams()
        local container = resolveContainer()
        if not container then return end
        for _, m in ipairs(container:GetChildren()) do
            local hl = m:FindFirstChild("N3Z_Chams")
            if hl then hl:Destroy() end
        end
    end

    local function updateAllChams()
        local container = resolveContainer()
        if not container then return end
        for _, m in ipairs(container:GetChildren()) do
            applyChams(m)
        end
    end

    local childAddedConn = nil
    if charContainer then
        childAddedConn = charContainer.ChildAdded:Connect(function(child)
            task.wait(0.2)
            applyChams(child)
        end)
    end

    TabVisuals:CreateToggle({
        Name = "Wallhack Chams (AI Red / Player Blue)",
        CurrentValue = state.esp.chams,
        Callback = function(val)
            state.esp.chams = val
            if val then
                updateAllChams()
            else
                removeAllChams()
            end
        end
    })

    -- Initial apply
    if state.esp.chams then
        updateAllChams()
    end

    TabVisuals:CreateSection("World & Lighting")

    local function applyFullbright()
        pcall(function()
            Lighting.Brightness = 3
            Lighting.ClockTime = 14
            Lighting.FogEnd = 1000000
            Lighting.GlobalShadows = false
            for _, v in ipairs(Lighting:GetDescendants()) do
                if v:IsA("Atmosphere") then v.Density = 0 end
                if v:IsA("PostEffect") then v.Enabled = false end
            end
        end)
    end

    TabVisuals:CreateToggle({
        Name = "Fullbright + No Fog",
        CurrentValue = state.combat.fullbright,
        Callback = function(val)
            state.combat.fullbright = val
            if val then applyFullbright() end
        end
    })

    -- ═══════════════════════════════════════════════
    -- MOVEMENT: SPEED & NOCLIP
    -- ═══════════════════════════════════════════════
    TabMovement:CreateSection("Character Movement")

    local speedConn = nil
    local function setSpeed(enabled)
        if speedConn then speedConn:Disconnect(); speedConn = nil end
        if enabled then
            speedConn = RunService.Heartbeat:Connect(function()
                local selfChar = getSelfChar()
                if selfChar then
                    local hum = selfChar:FindFirstChildOfClass("Humanoid")
                    if hum and hum.WalkSpeed ~= state.movement.speedValue then
                        hum.WalkSpeed = state.movement.speedValue
                    end
                end
            end)
        else
            local selfChar = getSelfChar()
            if selfChar then
                local hum = selfChar:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = 16 end
            end
        end
    end

    TabMovement:CreateToggle({
        Name = "Speed Hack",
        CurrentValue = state.movement.speedEnabled,
        Callback = function(val)
            state.movement.speedEnabled = val
            setSpeed(val)
        end
    })

    TabMovement:CreateSlider({
        Name = "Walk Speed Value",
        Range = {16, 60},
        Increment = 2,
        CurrentValue = state.movement.speedValue,
        Callback = function(val)
            state.movement.speedValue = val
        end
    })

    local noclipConn = nil
    TabMovement:CreateToggle({
        Name = "NoClip",
        CurrentValue = state.movement.noclip,
        Callback = function(val)
            state.movement.noclip = val
            if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
            if val then
                noclipConn = RunService.Stepped:Connect(function()
                    local selfChar = getSelfChar()
                    if selfChar then
                        for _, part in ipairs(selfChar:GetDescendants()) do
                            if part:IsA("BasePart") then
                                part.CanCollide = false
                            end
                        end
                    end
                end)
            end
        end
    })

    -- ═══════════════════════════════════════════════
    -- CLEANUP HOOK
    -- ═══════════════════════════════════════════════
    local function cleanup()
        if aimbotConn then aimbotConn:Disconnect() end
        if speedConn then speedConn:Disconnect() end
        if noclipConn then noclipConn:Disconnect() end
        if childAddedConn then childAddedConn:Disconnect() end
        if recoilThread then pcall(task.cancel, recoilThread) end
        pcall(function() fovCircle:Remove() end)
        removeAllChams()

        local selfChar = getSelfChar()
        if selfChar then
            local hum = selfChar:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
        end
    end

    table.insert(getgenv().__RAVEN_CLEANUP, cleanup)
    if info and info.registerCleanup then
        info.registerCleanup(cleanup)
    end
end
