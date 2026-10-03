-- ============================================================
-- N3Z Dance Avenue - Core Module
-- v1.2.0 - 100% Guaranteed Perfect + Native Human Autoplay
-- Directly hooks Audition.Config.Windows and Audition.Judge.grade
-- ============================================================

return function(Window, ctx, adapter)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Workspace = game:GetService("Workspace")
    local UserInputService = game:GetService("UserInputService")

    local localPlayer = Players.LocalPlayer

    -- Cleanup previous instance
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
    -- 1. AUDITION HOOK (ALWAYS PERFECT)
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
        -- ขยาย Window ให้กว้าง ไม่ว่าจะเคาะตรงไหนหรือตอนไหน = PERFECT เสมอ
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

    -- Persistent Game Finder
    local function getGameInstance()
        for _, obj in ipairs(getgc(true)) do
            if type(obj) == "table" and rawget(obj, "offsetMs") ~= nil then
                return obj
            end
        end
        return nil
    end

    -- Loop ensure autoplay & perfect
    local loopConn = RunService.Heartbeat:Connect(function()
        local g = getGameInstance()
        if g then
            if state.autoPlay then
                if g.autoplay ~= "human" then
                    g.autoplay = "human"
                end
            else
                if g.autoplay == "human" then
                    g.autoplay = nil
                end
            end
        end
    end)
    addCleanup(function()
        if loopConn then loopConn:Disconnect() end
        local g = getGameInstance()
        if g then g.autoplay = nil end
    end)

    -- ----------------------------------------------------
    -- 2. UI TABS
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
        Name = "Full Auto Play (บอทกดลูกศร + เคาะ Spacebar ให้อัตโนมัติ)",
        Default = true,
        Callback = function(v)
            state.autoPlay = v
            local g = getGameInstance()
            if g then
                g.autoplay = v and "human" or nil
            end
        end,
    })

    -- ----------------------------------------------------
    -- 3. MOVEMENT MODIFIERS
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
    -- 4. MISC
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
