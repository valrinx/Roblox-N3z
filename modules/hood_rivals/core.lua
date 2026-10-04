-- ============================================================
-- N3Z HOOD RIVALS core module
-- PlaceId: 77463332823746 | GameId: 10648640958
-- Full AGENT.MD Compliance:
--   - Accurate 3D -> 2D Projection (ScreenPoint vs ViewportPoint / GUI Inset aware)
--   - Tight Head + Foot Bounding Box
--   - AimLock targeting precise AimPart Center
--   - Full PC / Mobile Separation
-- ============================================================

return function(Window, scriptInfo)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")
    local UserInputService = game:GetService("UserInputService")
    local GuiService = game:GetService("GuiService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local localPlayer = Players.LocalPlayer
    local camera = Workspace.CurrentCamera

    -- Clean up previous instance
    local environment = (type(getgenv) == "function" and getgenv()) or _G
    if type(environment.__RAVEN_HOOD_RIVALS) == "table"
        and type(environment.__RAVEN_HOOD_RIVALS.Destroy) == "function" then
        pcall(environment.__RAVEN_HOOD_RIVALS.Destroy)
    end
    environment.RAVEN_HOOD_RIVALS_VER = "1.2.0"

    local running = true
    local connections = {}
    local espCache = {}

    local isMobilePlatform = scriptInfo and (scriptInfo.platform == "mobile" or (scriptInfo.platformAdapter and scriptInfo.platformAdapter.isMobile))

    local settings = {
        -- Combat / Aim
        aimbot = false,
        aimPart = "Head",
        aimFov = 150,
        aimSmooth = 0.25,
        aimActivation = isMobilePlatform and "Always" or "Hold Key",
        noRecoil = false,

        -- Visuals / ESP
        espEnabled = false,
        boxEsp = false,
        nameEsp = false,
        healthEsp = false,
        tracerEsp = false,
        maxDistance = 2000,

        -- Movement
        speedHack = false,
        walkSpeed = 35,
        infiniteJump = false,
    }

    -- Platform Adapter Drawing wrapper (handles visual occlusion and platform fallbacks)
    local adapter = scriptInfo and scriptInfo.platformAdapter
    local rawDrawing = nil
    if adapter and adapter.Drawing then
        rawDrawing = adapter.Drawing
    else
        pcall(function() rawDrawing = Drawing end)
    end

    local drawingApi = rawDrawing
    local hasDrawing = type(drawingApi) == "table" and type(drawingApi.new) == "function"

    local function safeDrawing(drawingType)
        if not hasDrawing then return nil end
        local ok, obj = pcall(drawingApi.new, drawingType)
        if ok and obj then
            pcall(function() obj.ZIndex = 0 end)
            return obj
        end
        return nil
    end

    local function getHealthColor(ratio)
        return Color3.fromHSV(math.clamp(ratio, 0, 1) * 0.33, 0.9, 1)
    end

    local function getEntry(p)
        local e = espCache[p]
        if e then return e end
        e = {}
        e.box = safeDrawing("Square")
        if e.box then
            e.box.Thickness = 1.5
            e.box.Filled = false
            e.box.Color = Color3.fromRGB(255, 50, 75)
            e.box.Visible = false
        end

        e.barBack = safeDrawing("Square")
        if e.barBack then
            e.barBack.Thickness = 1
            e.barBack.Filled = true
            e.barBack.Color = Color3.new(0, 0, 0)
            e.barBack.Transparency = 0.5
            e.barBack.Visible = false
        end

        e.bar = safeDrawing("Square")
        if e.bar then
            e.bar.Thickness = 1
            e.bar.Filled = true
            e.bar.Visible = false
        end

        e.name = safeDrawing("Text")
        if e.name then
            e.name.Size = 13
            e.name.Center = true
            e.name.Outline = true
            e.name.Color = Color3.new(1, 1, 1)
            e.name.Visible = false
        end

        e.tracer = safeDrawing("Line")
        if e.tracer then
            e.tracer.Thickness = 1
            e.tracer.Color = Color3.fromRGB(0, 255, 170)
            e.tracer.Visible = false
        end

        espCache[p] = e
        return e
    end

    local function hideEntry(e)
        for _, k in ipairs({ "box", "barBack", "bar", "name", "tracer" }) do
            local d = e[k]
            if d then pcall(function() d.Visible = false end) end
        end
    end

    local function destroyEntry(p)
        local e = espCache[p]
        if e then
            for _, k in ipairs({ "box", "barBack", "bar", "name", "tracer" }) do
                local d = e[k]
                if d then pcall(function() d:Remove() end) end
            end
            espCache[p] = nil
        end
    end

    -- FOV Circle
    local fovCircle = safeDrawing("Circle")
    if fovCircle then
        fovCircle.Thickness = 1.5
        fovCircle.NumSides = 40
        fovCircle.Radius = settings.aimFov
        fovCircle.Filled = false
        fovCircle.Visible = false
        fovCircle.Color = Color3.fromRGB(0, 255, 170)
        fovCircle.Transparency = 0.8
    end

    -- Universal 3D to 2D Point Converter
    -- Native Drawing API uses Viewport coordinates directly.
    -- ScreenPoint differs by GuiInset Y (usually 58px top bar).
    -- Using WorldToViewportPoint directly matches Drawing API positions 1:1!
    local function to2D(worldPos)
        local pos, onScreen = camera:WorldToViewportPoint(worldPos)
        return Vector2.new(pos.X, pos.Y), onScreen, pos.Z
    end

    -- Target Selector (Precise screen distance to mouse)
    local function getClosestTarget()
        local mousePos = UserInputService:GetMouseLocation()
        local closest = nil
        local shortestDist = settings.aimFov

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= localPlayer and p.Character then
                local char = p.Character
                local hum = char:FindFirstChildOfClass("Humanoid")
                local part = char:FindFirstChild(settings.aimPart) or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
                if hum and hum.Health > 0 and part then
                    local screenPos, onScreen, depth = to2D(part.Position)
                    if onScreen and depth > 0 then
                        local dist = (screenPos - mousePos).Magnitude
                        if dist < shortestDist then
                            shortestDist = dist
                            closest = part
                        end
                    end
                end
            end
        end
        return closest
    end

    -- RenderStepped: Aimbot & ESP Update
    local renderConn = RunService.RenderStepped:Connect(function()
        if not running then return end

        local mousePos = UserInputService:GetMouseLocation()

        -- FOV Circle Update
        if fovCircle then
            fovCircle.Position = mousePos
            fovCircle.Radius = settings.aimFov
            fovCircle.Visible = settings.aimbot
        end

        -- Aimbot Actuation via Platform Adapter
        local aimTriggered = false
        if settings.aimbot then
            if adapter and type(adapter.isAimActive) == "function" then
                aimTriggered = adapter.isAimActive(settings.aimActivation)
            else
                aimTriggered = (settings.aimActivation == "Always") or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
            end
        end

        if aimTriggered then
            local target = getClosestTarget()
            if target then
                local currentCF = camera.CFrame
                local targetPos = target.Position
                local goalCF = CFrame.new(currentCF.Position, targetPos)
                camera.CFrame = currentCF:Lerp(goalCF, settings.aimSmooth)
            end
        end

        -- ESP Render Loop
        local bottomScreen = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
        local myRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= localPlayer then
                local e = getEntry(p)
                local char = p.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HeadHitbox"))

                if settings.espEnabled and char and hum and hum.Health > 0 and root and head then
                    local dist = myRoot and (root.Position - myRoot.Position).Magnitude or 0
                    if dist <= settings.maxDistance then
                        -- Precision Bounding: Head top to feet ground
                        local headTopPos = head.Position + Vector3.new(0, head.Size.Y * 0.6, 0)
                        local footBottomPos = root.Position - Vector3.new(0, 3.0, 0)

                        local headScreen, headOn, headZ = to2D(headTopPos)
                        local footScreen, footOn, footZ = to2D(footBottomPos)
                        local rootScreen, rootOn, rootZ = to2D(root.Position)

                        local isVisible = (headZ > 0 or rootZ > 0) and (headOn or footOn or rootOn)

                        if isVisible then
                            local height = math.abs(headScreen.Y - footScreen.Y)
                            if height < 6 then height = 6 end
                            local width = height * 0.62
                            local centerX = rootOn and rootScreen.X or headScreen.X
                            local topY = headScreen.Y

                            local boxTopLeft = Vector2.new(centerX - width / 2, topY)

                            -- Box ESP (Aligned exactly with top head and feet)
                            if e.box then
                                if settings.boxEsp then
                                    e.box.Size = Vector2.new(width, height)
                                    e.box.Position = boxTopLeft
                                    e.box.Visible = true
                                else
                                    e.box.Visible = false
                                end
                            end

                            -- Health Bar
                            if e.bar and e.barBack then
                                if settings.healthEsp then
                                    local barWidth = 3
                                    local barX = boxTopLeft.X - barWidth - 3
                                    local barY = topY
                                    local ratio = math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1)

                                    e.barBack.Size = Vector2.new(barWidth, height)
                                    e.barBack.Position = Vector2.new(barX, barY)
                                    e.barBack.Visible = true

                                    e.bar.Size = Vector2.new(barWidth, height * ratio)
                                    e.bar.Position = Vector2.new(barX, barY + (height * (1 - ratio)))
                                    e.bar.Color = getHealthColor(ratio)
                                    e.bar.Visible = true
                                else
                                    e.bar.Visible = false
                                    e.barBack.Visible = false
                                end
                            end

                            -- Name & Distance
                            if e.name then
                                if settings.nameEsp then
                                    e.name.Text = string.format("%s [%dm]", p.DisplayName or p.Name, math.floor(dist))
                                    e.name.Position = Vector2.new(centerX, topY - 16)
                                    e.name.Visible = true
                                else
                                    e.name.Visible = false
                                end
                            end

                            -- Tracers (From bottom center of screen to player feet)
                            if e.tracer then
                                if settings.tracerEsp then
                                    e.tracer.From = bottomScreen
                                    e.tracer.To = Vector2.new(centerX, footScreen.Y)
                                    e.tracer.Visible = true
                                else
                                    e.tracer.Visible = false
                                end
                            end
                        else
                            hideEntry(e)
                        end
                    else
                        hideEntry(e)
                    end
                else
                    hideEntry(e)
                end
            end
        end
    end)
    table.insert(connections, renderConn)

    -- Heartbeat Loop: Speed & Anti-Recoil
    local heartbeatConn = RunService.Heartbeat:Connect(function()
        if not running then return end
        local char = localPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        if hum and settings.speedHack and hum.WalkSpeed < settings.walkSpeed then
            hum.WalkSpeed = settings.walkSpeed
        end

        if settings.noRecoil then
            pcall(function()
                local wm = require(ReplicatedStorage:WaitForChild("Weapon_Module"))
                if wm and wm.RecoilSpring then
                    wm.RecoilSpring._velocity0 = Vector3.zero
                    wm.RecoilSpring._position0 = Vector3.zero
                    wm.RecoilSpring._target = Vector3.zero
                end
            end)
        end
    end)
    table.insert(connections, heartbeatConn)

    -- Infinite Jump
    local jumpConn = UserInputService.JumpRequest:Connect(function()
        if not running or not settings.infiniteJump then return end
        local char = localPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
    table.insert(connections, jumpConn)

    -- Player Removing
    local removeConn = Players.PlayerRemoving:Connect(function(p)
        destroyEntry(p)
    end)
    table.insert(connections, removeConn)

    -- ============================================================
    -- N3Z HUB TABS & CONTROLS SETUP
    -- ============================================================
    local CombatTab = Window:CreateTab("Combat", 4483362458)
    local VisualsTab = Window:CreateTab("Visuals", 4483362458)
    local MovementTab = Window:CreateTab("Movement", 4483362458)

    -- Combat Tab
    CombatTab:CreateSection("Aimbot")
    CombatTab:CreateToggle({
        Name = "Enable Aimbot",
        Flag = "HR_Aimbot",
        CurrentValue = false,
        Callback = function(v) settings.aimbot = v end,
    })
    CombatTab:CreateDropdown({
        Name = "Target Bone",
        Flag = "HR_AimPart",
        Options = { "Head", "HumanoidRootPart" },
        CurrentOption = "Head",
        Callback = function(v) settings.aimPart = v end,
    })
    CombatTab:CreateSlider({
        Name = "FOV Radius",
        Flag = "HR_AimFov",
        Range = { 50, 400 },
        Increment = 5,
        Suffix = " px",
        CurrentValue = 150,
        Callback = function(v) settings.aimFov = v end,
    })
    CombatTab:CreateSlider({
        Name = "Smoothing",
        Flag = "HR_AimSmooth",
        Range = { 0.05, 1 },
        Increment = 0.05,
        CurrentValue = 0.25,
        Callback = function(v) settings.aimSmooth = v end,
    })

    if not isMobilePlatform then
        CombatTab:CreateDropdown({
            Name = "Aim Activation",
            Flag = "HR_AimActivation",
            Options = { "Hold Key", "Always" },
            CurrentOption = "Hold Key",
            Callback = function(v) settings.aimActivation = v end,
        })
        CombatTab:CreateDropdown({
            Name = "Aim Trigger (Mouse / Key)",
            Flag = "HR_AimKeyChoice",
            Options = { "Right Click (Mouse2)", "Left Click (Mouse1)", "Middle Click (Mouse3)", "Custom Keyboard Key" },
            CurrentOption = "Right Click (Mouse2)",
            Callback = function(choice)
                if adapter and type(adapter.setAimKey) == "function" then
                    adapter.setAimKey(choice)
                end
            end,
        })
        CombatTab:CreateKeybind({
            Name = "Custom Keyboard Key",
            Flag = "HR_CustomAimKey",
            CurrentKeybind = "Q",
            Callback = function(key)
                if adapter and type(adapter.setCustomKeyCode) == "function" then
                    adapter.setCustomKeyCode(key)
                end
            end,
        })
    else
        CombatTab:CreateLabel("Mobile Aim: Active while enabled")
    end

    CombatTab:CreateSection("Weapon Mod")
    CombatTab:CreateToggle({
        Name = "Zero Recoil",
        Flag = "HR_NoRecoil",
        CurrentValue = false,
        Callback = function(v) settings.noRecoil = v end,
    })

    -- Visuals Tab
    VisualsTab:CreateSection("Player ESP")
    VisualsTab:CreateToggle({
        Name = "Enable ESP Master",
        Flag = "HR_EspMaster",
        CurrentValue = false,
        Callback = function(v) settings.espEnabled = v end,
    })
    VisualsTab:CreateToggle({
        Name = "Box ESP",
        Flag = "HR_BoxEsp",
        CurrentValue = false,
        Callback = function(v) settings.boxEsp = v end,
    })
    VisualsTab:CreateToggle({
        Name = "Name & Distance",
        Flag = "HR_NameEsp",
        CurrentValue = false,
        Callback = function(v) settings.nameEsp = v end,
    })
    VisualsTab:CreateToggle({
        Name = "Health Bar",
        Flag = "HR_HealthEsp",
        CurrentValue = false,
        Callback = function(v) settings.healthEsp = v end,
    })
    VisualsTab:CreateToggle({
        Name = "Tracers (Snaplines)",
        Flag = "HR_TracerEsp",
        CurrentValue = false,
        Callback = function(v) settings.tracerEsp = v end,
    })
    VisualsTab:CreateSlider({
        Name = "Max Render Distance",
        Flag = "HR_MaxDist",
        Range = { 200, 4000 },
        Increment = 100,
        Suffix = " studs",
        CurrentValue = 2000,
        Callback = function(v) settings.maxDistance = v end,
    })

    -- Movement Tab
    MovementTab:CreateSection("Character Physics")
    MovementTab:CreateToggle({
        Name = "SpeedBoost",
        Flag = "HR_SpeedHack",
        CurrentValue = false,
        Callback = function(v) settings.speedHack = v end,
    })
    MovementTab:CreateSlider({
        Name = "WalkSpeed",
        Flag = "HR_WalkSpeed",
        Range = { 20, 60 },
        Increment = 1,
        CurrentValue = 35,
        Callback = function(v) settings.walkSpeed = v end,
    })
    MovementTab:CreateToggle({
        Name = "Infinite Jump",
        Flag = "HR_InfiniteJump",
        CurrentValue = false,
        Callback = function(v) settings.infiniteJump = v end,
    })

    -- API / Lifecycle
    local api = {}
    function api.Destroy()
        running = false
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        table.clear(connections)
        for p, _ in pairs(espCache) do destroyEntry(p) end
        table.clear(espCache)
        if fovCircle then pcall(function() fovCircle:Remove() end) end
        environment.__RAVEN_HOOD_RIVALS = nil
    end

    if type(scriptInfo) == "table" and type(scriptInfo.registerCleanup) == "function" then
        scriptInfo.registerCleanup(api.Destroy)
    end

    environment.__RAVEN_HOOD_RIVALS = api
    return api
end
