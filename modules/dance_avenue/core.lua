-- ============================================================
-- N3Z Dance Avenue - Core Module
-- v1.3.0 - Ultra-Lightweight Zero Lag + 100% Guaranteed Perfect
-- Single GC cache (NO per-frame getgc scan), instant FPS recovery
-- ============================================================

return function(Window, ctx, adapter)
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Workspace = game:GetService("Workspace")
    local UserInputService = game:GetService("UserInputService")

    local localPlayer = Players.LocalPlayer

    -- Clean up previous instance
    local env = (type(getgenv) == "function" and getgenv()) or _G
    if env.__N3Z_DANCE_AVENUE_CLEANUP then
        pcall(env.__N3Z_DANCE_AVENUE_CLEANUP)
    end

    local cleanups = {}
    local function addCleanup(fn)
        table.insert(cleanups, fn)
    end

    local state = {
        alwaysPerfect = true,
        autoPlay = true,
        walkSpeed = 26,
        speedEnabled = false,
        infJump = false,
    }

    -- ----------------------------------------------------
    -- 1. ZERO-LAG PERFECT HOOK (Static Module Hook)
    -- ----------------------------------------------------
    local audition = ReplicatedStorage:WaitForChild("Audition")
    local Config = require(audition:WaitForChild("Config"))
    local Judge = require(audition:WaitForChild("Judge"))

    local origWindows = {}
    for k, v in pairs(Config.Windows) do
        origWindows[k] = v
    end
    local origGrade = Judge.grade

    local function applyPerfectHook()
        Config.Windows.PERFECT = 999.0
        Config.Windows.GREAT = 999.0
        Config.Windows.COOL = 999.0
        Config.Windows.BAD = 999.0

        Judge.grade = function(delta, windows)
            return "PERFECT", 0
        end
    end

    local function restorePerfectHook()
        for k, v in pairs(origWindows) do
            Config.Windows[k] = v
        end
        Judge.grade = origGrade
    end

    applyPerfectHook()
    addCleanup(restorePerfectHook)

    -- ----------------------------------------------------
    -- 2. ZERO-LAG SINGLETON GAME FINDER (Run ONCE only!)
    -- ----------------------------------------------------
    local cachedGame = nil
    local function findGameOnce()
        if cachedGame then return cachedGame end
        for _, obj in ipairs(getgc(true)) do
            if type(obj) == "table" and rawget(obj, "offsetMs") ~= nil then
                cachedGame = obj
                return obj
            end
        end
        return nil
    end

    local g = findGameOnce()
    if g then
        g.autoplay = "human"
    end

    -- Run check only every 1.5 seconds (zero FPS drop)
    local activeCheckRunning = true
    task.spawn(function()
        while activeCheckRunning do
            local gameInst = findGameOnce()
            if gameInst then
                if state.autoPlay and gameInst.autoplay ~= "human" then
                    gameInst.autoplay = "human"
                elseif not state.autoPlay and gameInst.autoplay == "human" then
                    gameInst.autoplay = nil
                end
            end
            task.wait(1.5)
        end
    end)
    addCleanup(function()
        activeCheckRunning = false
        if cachedGame then cachedGame.autoplay = nil end
    end)

    -- ----------------------------------------------------
    -- 3. UI TABS
    -- ----------------------------------------------------
    local MainTab = Window:CreateTab("Auto Play")
    local MovementTab = Window:CreateTab("Movement")
    local MiscTab = Window:CreateTab("Misc")

    MainTab:CreateToggle({
        Name = "100% Always Perfect (เคาะเมื่อไหร่ก็ Perfect)",
        Default = true,
        Callback = function(v)
            state.alwaysPerfect = v
            if v then
                applyPerfectHook()
            else
                restorePerfectHook()
            end
        end,
    })

    MainTab:CreateToggle({
        Name = "Full Auto Play (บอทกดลูกศร + เคาะ Spacebar อัตโนมัติ)",
        Default = true,
        Callback = function(v)
            state.autoPlay = v
            local gameInst = findGameOnce()
            if gameInst then
                gameInst.autoplay = v and "human" or nil
            end
        end,
    })

    -- ----------------------------------------------------
    -- 4. MOVEMENT MODIFIERS (Event based, no RenderStepped spam)
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

    local charConn = localPlayer.CharacterAdded:Connect(function(char)
        if state.speedEnabled then
            local hum = char:WaitForChild("Humanoid", 3)
            if hum then hum.WalkSpeed = state.walkSpeed end
        end
    end)
    addCleanup(function()
        if charConn then charConn:Disconnect() end
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
    -- 5. MISC
    -- ----------------------------------------------------
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
