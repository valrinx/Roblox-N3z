return {
    id = "pc",

    createVisualBackend = function(api)
        local hasDrawing = type(Drawing) == "table" and type(Drawing.new) == "function"
        if hasDrawing then
            return {
                name = "Drawing",
                new = function(drawingType)
                    local ok, obj = pcall(Drawing.new, drawingType)
                    if not ok or not obj then return nil end
                    pcall(function() obj.ZIndex = 0 end)
                    return obj
                end,
                destroy = function() end,
            }
        end

        return api.createNativeBackend({
            name = "NativeGui",
            displayOrder = 20,
            resolveParent = function()
                local playerGui = api.localPlayer:FindFirstChildOfClass("PlayerGui")
                if not playerGui then
                    pcall(function()
                        playerGui = api.localPlayer:WaitForChild("PlayerGui", 2)
                    end)
                end
                if playerGui then return playerGui end

                if type(gethui) == "function" then
                    local ok, parent = pcall(gethui)
                    if ok and parent then return parent end
                end

                local ok, coreGui = pcall(game.GetService, game, "CoreGui")
                return ok and coreGui or nil
            end,
        })
    end,

    createAimController = function(api)
        local UserInputService = api.UserInputService
        local settings = api.settings
        local Window = api.Window
        local CombatTab = api.CombatTab
        local aimKeyName = "MouseButton2"
        pcall(function()
            if type(Window.GetConfigValue) == "function" then
                local saved = Window:GetConfigValue("WZP_AimKey", "MouseButton2")
                if type(saved) == "string" and saved ~= "" then
                    aimKeyName = saved
                end
            end
        end)

        local aimHeld = false
        local capturingAimKey = false
        local captureArmedAt = 0
        local aimKeyBtn = nil
        local hasMouseMove = type(mousemoverel) == "function"
        local AIM_MAX_STEP = 60

        local function resolveInputName(input)
            if input.KeyCode ~= Enum.KeyCode.Unknown then
                return input.KeyCode.Name
            end
            local inputType = input.UserInputType
            if inputType == Enum.UserInputType.MouseButton1 then
                return "MouseButton1"
            elseif inputType == Enum.UserInputType.MouseButton2 then
                return "MouseButton2"
            elseif inputType == Enum.UserInputType.MouseButton3 then
                return "MouseButton3"
            end
            return nil
        end

        local function inputMatchesAimKey(input)
            return resolveInputName(input) == aimKeyName
        end

        local function refreshAimKeyLabel()
            local text = capturingAimKey
                and "Aim Key: [...]"
                or ("Aim Key: [" .. aimKeyName .. "]")
            if not aimKeyBtn then return end

            if aimKeyBtn.label then
                pcall(function() aimKeyBtn.label.Text = text end)
            end
            if type(aimKeyBtn.SetName) == "function" then
                pcall(function() aimKeyBtn:SetName(text) end)
            elseif type(aimKeyBtn.Set) == "function" then
                pcall(function() aimKeyBtn:Set({ Name = text }) end)
            end
        end

        local aimKeyProxy = { type = "keybind", key = aimKeyName }
        function aimKeyProxy:Set(newKey)
            if type(newKey) == "string" and newKey ~= "" and newKey ~= "None" then
                aimKeyName = newKey
                self.key = newKey
                pcall(function()
                    if type(Window.SetConfigValue) == "function" then
                        Window:SetConfigValue("WZP_AimKey", newKey)
                    end
                end)
            end
            capturingAimKey = false
            aimHeld = false
            api.clearAimLock()
            refreshAimKeyLabel()
        end

        aimKeyBtn = CombatTab:CreateButton({
            Name = "Aim Key: [" .. aimKeyName .. "]",
            Callback = function()
                if capturingAimKey then return end
                capturingAimKey = true
                captureArmedAt = os.clock()
                api.setInputBlock(false)
                refreshAimKeyLabel()
            end,
        })

        pcall(function()
            if Window.itemsByFlag then
                Window.itemsByFlag.WZP_AimKey = aimKeyProxy
            end
        end)

        api.connect(UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if api.isMenuOpen() or capturingAimKey or not settings.aimbot then return end
            if not inputMatchesAimKey(input) then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if gameProcessed then return end
                local focused = nil
                pcall(function() focused = UserInputService:GetFocusedTextBox() end)
                if focused ~= nil then return end
            end
            aimHeld = true
        end))

        api.connect(UserInputService.InputEnded:Connect(function(input)
            if not inputMatchesAimKey(input) then return end
            aimHeld = false
            api.clearAimLock()
        end))

        api.connect(UserInputService.InputBegan:Connect(function(input)
            if not capturingAimKey then return end
            if os.clock() - captureArmedAt < 0.18 then return end
            if input.KeyCode == Enum.KeyCode.Escape then
                capturingAimKey = false
                refreshAimKeyLabel()
                return
            end
            local name = resolveInputName(input)
            if name then aimKeyProxy:Set(name) end
        end))

        local controller = {}

        function controller:update(dt)
            if not settings.aimbot then
                aimHeld = false
                api.clearAimLock()
                return
            end
            if capturingAimKey then
                aimHeld = false
                api.clearAimLock()
                return
            end
            if api.isMenuOpen() then
                aimHeld = false
                api.clearAimLock()
                return
            end
            if not aimHeld or not hasMouseMove then
                api.clearAimLock()
                return
            end

            local target = api.getAimTarget()
            if not target then return end
            target = api.applyAimPrediction(target, api.getAimLockCharacter())

            local camera = api.getCamera()
            local view, onScreen = camera:WorldToViewportPoint(target)
            if not onScreen or view.Z <= 0 then return end

            local center = camera.ViewportSize / 2
            local offsetX = view.X - center.X
            local offsetY = view.Y - center.Y
            if offsetX * offsetX + offsetY * offsetY <= 4 then return end

            local response = math.clamp(settings.aimResponse, 0.01, 1)
            local alpha = 1 - math.pow(1 - response, (dt or 1 / 60) * 60)
            local dx = math.clamp(offsetX * alpha, -AIM_MAX_STEP, AIM_MAX_STEP)
            local dy = math.clamp(offsetY * alpha, -AIM_MAX_STEP, AIM_MAX_STEP)
            pcall(mousemoverel, dx, dy)
        end

        function controller:release()
            aimHeld = false
            api.clearAimLock()
        end

        function controller:destroy()
            self:release()
            capturingAimKey = false
        end

        function controller:status()
            return {
                mode = "DesktopKey",
                key = aimKeyName,
                held = aimHeld,
            }
        end

        return controller
    end,
}
