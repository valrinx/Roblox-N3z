-- ============================================================
-- N3Z Dance Avenue - Core Module
-- v1.0.0 - Auto Rhythm (Perfect/Great), Speed, Teleport, Visuals
-- Compliant with AGENT.MD platform separation contract
-- ============================================================

return function(Window, ctx, adapter)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Workspace = game:GetService("Workspace")
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")

    local localPlayer = Players.LocalPlayer
    local camera = Workspace.CurrentCamera

    -- Cleanup previous instance if running
    local env = (type(getgenv) == "function" and getgenv()) or _G
    if env.__N3Z_DANCE_AVENUE_CLEANUP then
        pcall(env.__N3Z_DANCE_AVENUE_CLEANUP)
    end

    local cleanups = {}
    local function addCleanup(fn)
        table.insert(cleanups, fn)
    end

    -- Settings state
    local state = {
        autoHit = false,
        hitAccuracy = "PERFECT", -- PERFECT (0.80), GREAT (0.76)
        hitChance = 100,
        walkSpeed = 26,
        speedEnabled = false,
        infJump = false,
        roomAnnounce = false,
    }

    -- Actuator from adapter
    local actuator = adapter.createRhythmActuator({
        localPlayer = localPlayer,
        settings = state,
    })
    addCleanup(function()
        if actuator and actuator.destroy then pcall(actuator.destroy) end
    end)

    -- UI Tabs
    local MainTab = Window:CreateTab("Auto Play")
    local MovementTab = Window:CreateTab("Movement")
    local TeleportTab = Window:CreateTab("Teleport")
    local MiscTab = Window:CreateTab("Misc")

    -- ----------------------------------------------------
    -- 1. AUTO RHYTHM LOGIC
    -- ----------------------------------------------------
    MainTab:CreateToggle({
        Name = "Auto Spacebar (Perfect)",
        Default = false,
        Callback = function(v)
            state.autoHit = v
        end,
    })

    MainTab:CreateDropdown({
        Name = "Timing Accuracy",
        Options = { "PERFECT (Exact)", "GREAT (Safe)" },
        Default = "PERFECT (Exact)",
        Callback = function(v)
            if string.find(v, "PERFECT") then
                state.hitAccuracy = "PERFECT"
            else
                state.hitAccuracy = "GREAT"
            end
        end,
    })

    MainTab:CreateSlider({
        Name = "Success Rate (%)",
        Min = 50,
        Max = 100,
        Default = 100,
        Callback = function(v)
            state.hitChance = v
        end,
    })

    -- Game UI rhythm tracker
    local hasHitThisBeat = false
    local heartbeatConn = RunService.RenderStepped:Connect(function()
        if not state.autoHit then return end

        local playerGui = localPlayer:FindFirstChild("PlayerGui")
        local auditionUI = playerGui and playerGui:FindFirstChild("AuditionUI")
        if not auditionUI then return end

        local cluster = auditionUI:FindFirstChild("Cluster")
        if not cluster or not cluster.Visible then
            hasHitThisBeat = false
            return
        end

        local rhythmBar = cluster:FindFirstChild("RhythmBar")
        local ball = rhythmBar and rhythmBar:FindFirstChild("Ball")
        if not ball then return end

        local ballX = ball.Position.X.Scale
        local targetMin = state.hitAccuracy == "PERFECT" and 0.79 or 0.74
        local targetMax = state.hitAccuracy == "PERFECT" and 0.82 or 0.84

        if ballX >= targetMin and ballX <= targetMax then
            if not hasHitThisBeat then
                hasHitThisBeat = true
                -- Roll chance
                if math.random(1, 100) <= state.hitChance then
                    actuator.triggerSpace()
                end
            end
        elseif ballX < 0.5 then
            hasHitThisBeat = false
        end
    end)
    addCleanup(function()
        if heartbeatConn then heartbeatConn:Disconnect() end
    end)

    -- ----------------------------------------------------
    -- 2. MOVEMENT MODIFIERS
    -- ----------------------------------------------------
    MovementTab:CreateToggle({
        Name = "Speed Hack",
        Default = false,
        Callback = function(v)
            state.speedEnabled = v
            local char = localPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = v and state.walkSpeed or 26
            end
        end,
    })

    MovementTab:CreateSlider({
        Name = "WalkSpeed Value",
        Min = 26,
        Max = 120,
        Default = 50,
        Callback = function(v)
            state.walkSpeed = v
            if state.speedEnabled then
                local char = localPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = v end
            end
        end,
    })

    local speedLoop = RunService.Stepped:Connect(function()
        if state.speedEnabled then
            local char = localPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.WalkSpeed ~= state.walkSpeed then
                hum.WalkSpeed = state.walkSpeed
            end
        end
    end)
    addCleanup(function()
        if speedLoop then speedLoop:Disconnect() end
        local char = localPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 26 end
    end)

    MovementTab:CreateToggle({
        Name = "Infinite Jump",
        Default = false,
        Callback = function(v)
            state.infJump = v
        end,
    })

    local jumpConn = UserInputService.JumpRequest:Connect(function()
        if state.infJump then
            local char = localPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end)
    addCleanup(function()
        if jumpConn then jumpConn:Disconnect() end
    end)

    -- ----------------------------------------------------
    -- 3. TELEPORT & STAGES
    -- ----------------------------------------------------
    local knownLocations = {
        ["Lobby Spawn"] = Vector3.new(30, 4, 41),
        ["Stage 1 (Street)"] = Vector3.new(0, 5, 0),
        ["Stage 2 (Club)"] = Vector3.new(100, 5, 100),
        ["Leaderboard Area"] = Vector3.new(30, 4, 80),
    }

    for name, pos in pairs(knownLocations) do
        TeleportTab:CreateButton({
            Name = "Teleport to " .. name,
            Callback = function()
                local char = localPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
                end
            end,
        })
    end

    -- ----------------------------------------------------
    -- 4. MISC & LOGS
    -- ----------------------------------------------------
    MiscTab:CreateButton({
        Name = "Dump Songs Count",
        Callback = function()
            local songsMod = ReplicatedStorage:FindFirstChild("Audition") and ReplicatedStorage.Audition:FindFirstChild("Songs")
            if songsMod then
                local songs = require(songsMod)
                local count = 0
                for _ in pairs(songs.All or songs) do count = count + 1 end
                print("[N3Z Dance Avenue] Available tracks:", count)
            end
        end,
    })

    MiscTab:CreateButton({
        Name = "Rejoin Server",
        Callback = function()
            game:GetService("TeleportService"):TeleportToPlaceInstance(
                game.PlaceId,
                game.JobId,
                localPlayer
            )
        end,
    })

    -- Final cleanup registrar
    local function destroy()
        for _, cleanupFn in ipairs(cleanups) do
            pcall(cleanupFn)
        end
        env.__N3Z_DANCE_AVENUE_CLEANUP = nil
    end

    env.__N3Z_DANCE_AVENUE_CLEANUP = destroy

    return {
        destroy = destroy,
    }
end
