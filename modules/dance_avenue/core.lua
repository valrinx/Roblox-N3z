-- ============================================================
-- N3Z Dance Avenue - Core Module
-- v1.3.1 - opt-in Perfect/Autoplay with exact state restoration
-- No startup/per-frame getgc scan; controller scan runs only while Autoplay is enabled
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
        alwaysPerfect = false,
        autoPlay = false,
        walkSpeed = 26,
        speedEnabled = false,
        infJump = false,
    }

    -- ----------------------------------------------------
    -- 1. OPT-IN PERFECT HOOK
    -- ----------------------------------------------------
    local audition = ReplicatedStorage:WaitForChild("Audition")
    local Config = require(audition:WaitForChild("Config"))
    local Judge = require(audition:WaitForChild("Judge"))

    local perfectSnapshot = nil

    local function applyPerfectHook()
        if perfectSnapshot then return end

        local windows = {}
        for k, v in pairs(Config.Windows) do
            windows[k] = v
        end
        perfectSnapshot = {
            windows = windows,
            grade = Judge.grade,
        }

        Config.Windows.PERFECT = 999.0
        Config.Windows.GREAT = 999.0
        Config.Windows.COOL = 999.0
        Config.Windows.BAD = 999.0

        Judge.grade = function(_delta, _windows)
            return "PERFECT", 0
        end
    end

    local function restorePerfectHook()
        local snapshot = perfectSnapshot
        if not snapshot then return end
        perfectSnapshot = nil

        -- Restore the table exactly to the state captured immediately before
        -- this enable operation.
        local currentKeys = {}
        for k in pairs(Config.Windows) do
            currentKeys[#currentKeys + 1] = k
        end
        for _, k in ipairs(currentKeys) do
            if snapshot.windows[k] == nil then
                Config.Windows[k] = nil
            end
        end
        for k, v in pairs(snapshot.windows) do
            Config.Windows[k] = v
        end
        Judge.grade = snapshot.grade
    end

    addCleanup(restorePerfectHook)

    -- ----------------------------------------------------
    -- 2. OPT-IN AUTOPLAY CONTROLLER
    -- ----------------------------------------------------
    local autoplaySnapshots = setmetatable({}, { __mode = "k" })
    local autoplayRunId = 0

    local function isGameplayController(obj)
        return type(obj) == "table"
            and rawget(obj, "offsetMs") ~= nil
            and rawget(obj, "state") ~= nil
            and rawget(obj, "beat") ~= nil
            and type(rawget(obj, "slots")) == "table"
            and type(rawget(obj, "bots")) == "table"
    end

    local function findGameController()
        local fallback = nil
        for _, obj in ipairs(getgc(true)) do
            if isGameplayController(obj) then
                if rawget(obj, "state") == "playing" then
                    return obj
                end
                fallback = fallback or obj
            end
        end
        return fallback
    end

    local function snapshotAutoplay(gameInst)
        if not gameInst or autoplaySnapshots[gameInst] then return end
        local original = rawget(gameInst, "autoplay")
        autoplaySnapshots[gameInst] = {
            hadValue = original ~= nil,
            value = original,
        }
    end

    local function restoreAutoplay()
        for gameInst, snapshot in pairs(autoplaySnapshots) do
            if type(gameInst) == "table" and type(snapshot) == "table" then
                if snapshot.hadValue then
                    gameInst.autoplay = snapshot.value
                else
                    gameInst.autoplay = nil
                end
            end
            autoplaySnapshots[gameInst] = nil
        end
    end

    local function stopAutoplay()
        state.autoPlay = false
        autoplayRunId += 1
        restoreAutoplay()
    end

    local function startAutoplay()
        if state.autoPlay then return end
        state.autoPlay = true
        autoplayRunId += 1
        local runId = autoplayRunId

        task.spawn(function()
            while state.autoPlay and autoplayRunId == runId do
                local gameInst = findGameController()
                if gameInst then
                    snapshotAutoplay(gameInst)
                    if gameInst.autoplay ~= "human" then
                        gameInst.autoplay = "human"
                    end
                end
                task.wait(1.5)
            end
        end)
    end

    addCleanup(function()
        stopAutoplay()
    end)

    -- ----------------------------------------------------
    -- 3. UI TABS
    -- ----------------------------------------------------
    local MainTab = Window:CreateTab("Auto Play")
    local MovementTab = Window:CreateTab("Movement")
    local MiscTab = Window:CreateTab("Misc")

    MainTab:CreateToggle({
        Name = "100% Always Perfect (เคาะเมื่อไหร่ก็ Perfect)",
        Default = false,
        Callback = function(v)
            state.alwaysPerfect = v == true
            if state.alwaysPerfect then
                applyPerfectHook()
            else
                restorePerfectHook()
            end
        end,
    })

    MainTab:CreateToggle({
        Name = "Full Auto Play (บอทกดลูกศร + เคาะ Spacebar อัตโนมัติ)",
        Default = false,
        Callback = function(v)
            if v then
                startAutoplay()
            else
                stopAutoplay()
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
