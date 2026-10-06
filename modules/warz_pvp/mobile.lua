-- N3Z WarZPVP v1.8.7 - Mobile adapter
return {
    id = "mobile",

    createVisualBackend = function(api)
        local native = api.createNativeBackend({
            name = "NativeGui",
            displayOrder = 998,
            resolveParent = function()
                if type(gethui) == "function" then
                    local ok, parent = pcall(gethui)
                    if ok and parent then return parent end
                end

                local okCore, coreGui = pcall(game.GetService, game, "CoreGui")
                if okCore and coreGui then return coreGui end

                local playerGui = api.localPlayer:FindFirstChildOfClass("PlayerGui")
                if not playerGui then
                    pcall(function()
                        playerGui = api.localPlayer:WaitForChild("PlayerGui", 2)
                    end)
                end
                return playerGui
            end,
        })
        native.newImage = function()
            return native.new("Image")
        end
        return native
    end,

    createAimController = function(api)
        local settings = api.settings
        local UserInputService = api.UserInputService
        local aimHeld = false
        local aimTouches = {}
        local touchCount = 0
        local graceUntil = 0
        local destroyed = false
        local fireTokens = {
            "fire", "shoot", "attack", "trigger",
        }

        local function releaseInput()
            aimHeld = false
            table.clear(aimTouches)
            touchCount = 0
            graceUntil = 0
            api.clearAimLock()
        end

        local function touchLooksLikeFire(input)
            if input.UserInputType ~= Enum.UserInputType.Touch then
                return false
            end

            local pos = input.Position
            local okGui, guiObjects = pcall(function()
                local playerGui = api.localPlayer:FindFirstChildOfClass("PlayerGui")
                return playerGui and playerGui:GetGuiObjectsAtPosition(pos.X, pos.Y)
            end)
            if okGui and type(guiObjects) == "table" then
                for _, guiObject in ipairs(guiObjects) do
                    local overControl = false
                    local current = guiObject
                    for _ = 1, 5 do
                        if not current then break end
                        if current:IsA("GuiButton") or current:IsA("TextBox") then
                            overControl = true
                        end
                        local blob = string.lower(tostring(current.Name or ""))
                        if current:IsA("TextButton") or current:IsA("TextLabel") then
                            blob = blob .. " " .. string.lower(tostring(current.Text or ""))
                        end
                        for _, token in ipairs(fireTokens) do
                            if string.find(blob, token, 1, true) then
                                return true
                            end
                        end
                        current = current.Parent
                    end
                    -- The first foreground control owns this touch, even if a
                    -- fire button is underneath it in the hit-test results.
                    if overControl then return false end
                end
            end

            local camera = api.getCamera()
            local viewport = camera and camera.ViewportSize
            if not viewport or viewport.X <= 0 or viewport.Y <= 0 then
                return false
            end

            local nx = pos.X / viewport.X
            local ny = pos.Y / viewport.Y
            return nx >= 0.54 and nx <= 0.92
                and ny >= 0.28 and ny <= 0.86
        end

        api.CombatTab:CreateLabel("Mobile Aim: fire-touch")

        api.connect(UserInputService.InputBegan:Connect(function(input)
            if destroyed or api.isMenuOpen() or not settings.aimbot then return end
            if not touchLooksLikeFire(input) then return end
            if not aimTouches[input] then
                aimTouches[input] = true
                touchCount = touchCount + 1
            end
            aimHeld = true
            graceUntil = os.clock() + 0.16
        end))

        api.connect(UserInputService.InputEnded:Connect(function(input)
            if not aimTouches[input] then return end
            aimTouches[input] = nil
            touchCount = touchCount - 1
            aimHeld = touchCount > 0
            if not aimHeld then graceUntil = os.clock() + 0.10 end
        end))
        api.connect(UserInputService.WindowFocusReleased:Connect(releaseInput))

        local controller = {}

        function controller:update(dt)
            if destroyed or not settings.aimbot or api.isMenuOpen() then
                releaseInput()
                return
            end
            if not aimHeld and os.clock() > graceUntil then
                api.clearAimLock()
                return
            end

            local target = api.getAimTarget()
            if not target then return end
            target = api.applyAimPrediction(target, api.getAimLockCharacter())

            local camera = api.getCamera()
            if not camera then return end
            local current = camera.CFrame
            local delta = target - current.Position
            if delta.Magnitude <= 0.01 then return end

            local desired = CFrame.lookAt(current.Position, target, Vector3.yAxis)
            local response = math.clamp(settings.aimResponse, 0.01, 1)
            local alpha = 1 - math.pow(1 - response, (dt or 1 / 60) * 60)
            camera.CFrame = current:Lerp(desired, math.clamp(alpha, 0, 1))
        end

        function controller:release()
            releaseInput()
        end

        function controller:destroy()
            destroyed = true
            self:release()
        end

        function controller:status()
            return {
                mode = "FireTouch",
                backend = "camera",
                key = nil,
                held = aimHeld or os.clock() <= graceUntil,
            }
        end

        return controller
    end,
}
