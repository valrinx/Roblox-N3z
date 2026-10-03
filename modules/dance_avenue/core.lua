-- ============================================================
-- N3Z Dance Avenue - Core Module
-- v1.1.0 - Full Auto Play (Auto Arrows + Auto Perfect Hit)
-- Direct Game Engine Hook + VIM Keyboard Emulation
-- Compliant with AGENT.MD platform separation contract
-- ============================================================

return function(Window, ctx, adapter)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Workspace = game:GetService("Workspace")
    local UserInputService = game:GetService("UserInputService")

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

    -- State
    local state = {
        autoArrows = true,     -- ออโต้กดลูกศรทั้งหมด (ระดับ 1 ถึง 11)
        autoHit = true,        -- ออโต้เคาะ Spacebar / Perfect
        hitAccuracy = "PERFECT",
        humanDelay = 0.04,     -- ดีเลย์ระหว่างกดลูกศร (ป้องกันค้าง/เนียน)
        walkSpeed = 26,
        speedEnabled = false,
        infJump = false,
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
    local MiscTab = Window:CreateTab("Misc")

    -- ----------------------------------------------------
    -- 1. AUTO PLAY CONTROLS
    -- ----------------------------------------------------
    MainTab:CreateToggle({
        Name = "Auto Arrows (กดลูกศรทั้งหมด)",
        Default = true,
        Callback = function(v)
            state.autoArrows = v
        end,
    })

    MainTab:CreateToggle({
        Name = "Auto Spacebar (เคาะ Perfect)",
        Default = true,
        Callback = function(v)
            state.autoHit = v
        end,
    })

    MainTab:CreateSlider({
        Name = "Arrow Press Delay (sec)",
        Min = 0,
        Max = 0.1,
        Default = 0.04,
        Callback = function(v)
            state.humanDelay = v
        end,
    })

    -- Game Cache Helper
    local cachedGame = nil
    local function getActiveGame()
        if cachedGame and cachedGame.slots and cachedGame.state then
            return cachedGame
        end
        for _, obj in ipairs(getgc(true)) do
            if type(obj) == "table" and rawget(obj, "arrowPresses") ~= nil and rawget(obj, "slots") ~= nil then
                cachedGame = obj
                return obj
            end
        end
        return nil
    end

    local Judge = nil
    pcall(function()
        Judge = require(ReplicatedStorage:WaitForChild("Audition"):WaitForChild("Judge"))
    end)

    -- Engine Auto-Player Loop
    local lastSolvedSlot = -1
    local hasHitCurrentSlot = false

    local autoLoop = RunService.Heartbeat:Connect(function()
        local g = getActiveGame()
        if not g or g.state ~= "playing" then
            lastSolvedSlot = -1
            hasHitCurrentSlot = false
            return
        end

        local curIdx = g.cur
        if not curIdx or not g.slots then return end

        local slot = g.slots[curIdx]
        if not slot then return end

        -- 1. Auto Solve Arrow Keys for the current slot
        if state.autoArrows and slot.dirs and #slot.dirs > 0 and lastSolvedSlot ~= curIdx then
            local arrowCount = slot.arrowCount or #slot.dirs
            local entered = slot.entered or 0

            if entered < arrowCount then
                for i = (entered + 1), arrowCount do
                    local dir = slot.dirs[i]
                    local isRed = slot.reds and slot.reds[i] == true
                    local keyToPress = dir

                    -- If note is RED (Chance mode), expectedKey is opposite!
                    if isRed and Judge and Judge.expectedKey then
                        keyToPress = Judge.expectedKey(dir, true)
                    end

                    -- Feed into game's onArrow
                    if g.onArrow then
                        pcall(g.onArrow, g, keyToPress)
                    end

                    if state.humanDelay > 0 then
                        task.wait(state.humanDelay)
                    end
                end
            end
            lastSolvedSlot = curIdx
            hasHitCurrentSlot = false
        end

        -- 2. Auto Hit (Spacebar) on timing
        if state.autoHit and not hasHitCurrentSlot then
            local playerGui = localPlayer:FindFirstChild("PlayerGui")
            local auditionUI = playerGui and playerGui:FindFirstChild("AuditionUI")
            local cluster = auditionUI and auditionUI:FindFirstChild("Cluster")
            local rhythmBar = cluster and cluster:FindFirstChild("RhythmBar")
            local ball = rhythmBar and rhythmBar:FindFirstChild("Ball")

            if ball and cluster.Visible then
                local ballX = ball.Position.X.Scale
                -- Perfect target zone: 0.795 - 0.825
                if ballX >= 0.795 and ballX <= 0.825 then
                    hasHitCurrentSlot = true
                    if g.onHit then
                        pcall(g.onHit, g)
                    else
                        actuator.triggerSpace()
                    end
                end
            end
        end
    end)
    addCleanup(function()
        if autoLoop then autoLoop:Disconnect() end
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

    local speedConn = RunService.Stepped:Connect(function()
        if state.speedEnabled then
            local char = localPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.WalkSpeed ~= state.walkSpeed then
                hum.WalkSpeed = state.walkSpeed
            end
        end
    end)
    addCleanup(function()
        if speedConn then speedConn:Disconnect() end
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
    -- 3. MISC
    -- ----------------------------------------------------
    MiscTab:CreateButton({
        Name = "Force Native Autoplay (Human Mode)",
        Callback = function()
            local g = getActiveGame()
            if g then
                g.autoplay = "human"
                print("[N3Z] Forced native autoplay = human")
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
