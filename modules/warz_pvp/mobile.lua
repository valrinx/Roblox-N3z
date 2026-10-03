return {
    id = "mobile",

    createVisualBackend = function(api)
        return api.createNativeBackend({
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
    end,

    createAimController = function(api)
        local settings = api.settings
        local UserInputService = api.UserInputService
        local GuiService = api.GuiService

        local aimHeld = false
        local aimTouch = nil
        local graceUntil = 0
        local fireTokens = {
            "fire", "shoot", "attack", "trigger", "bullet", "ammo",
        }

        local function touchLooksLikeFire(input)
            if input.UserInputType ~= Enum.UserInputType.Touch then
                return false
            end

            local pos = input.Position
            local okGui, guiObjects = pcall(function()
                return GuiService:GetGuiObjectsAtPosition(pos.X, pos.Y)
            end)
            if okGui and type(guiObjects) == "table" then
                for _, guiObject in ipairs(guiObjects) do
                    local current = guiObject
                    for _ = 1, 5 do
                        if not current then break end
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
            if api.isMenuOpen() or not settings.aimbot then return end
            if not touchLooksLikeFire(input) then return end
            aimHeld = true
            aimTouch = input
            graceUntil = os.clock() + 0.16
        end))

        api.connect(UserInputService.InputEnded:Connect(function(input)
            if aimTouch ~= input then return end
            aimHeld = false
            aimTouch = nil
            graceUntil = os.clock() + 0.10
        end))

        local controller = {}

        function controller:update(dt)
            if not settings.aimbot then
                aimHeld = false
                aimTouch = nil
                graceUntil = 0
                api.clearAimLock()
                return
            end
            if api.isMenuOpen() then
                aimHeld = false
                aimTouch = nil
                api.clearAimLock()
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
            local current = camera.CFrame
            local delta = target - current.Position
            if delta.Magnitude <= 0.01 then return end

            local desired = CFrame.lookAt(current.Position, target, Vector3.yAxis)
            local response = math.clamp(settings.aimResponse, 0.01, 1)
            local alpha = 1 - math.pow(1 - response, (dt or 1 / 60) * 60)
            camera.CFrame = current:Lerp(desired, math.clamp(alpha, 0, 1))
        end

        function controller:release()
            aimHeld = false
            aimTouch = nil
            graceUntil = 0
            api.clearAimLock()
        end

        function controller:destroy()
            self:release()
        end

        function controller:status()
            return {
                mode = "FireTouch",
                key = nil,
                held = aimHeld or os.clock() <= graceUntil,
            }
        end

        return controller
    end,
}
