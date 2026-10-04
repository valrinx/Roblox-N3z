-- N3Z HOOD RIVALS PC adapter
local UserInputService = game:GetService("UserInputService")

return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "hood_rivals/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "hood_rivals/pc: shared platform factory missing")

    local adapter = makePlatform("pc", ctx)
    adapter.isMobile = false

    local currentAimKey = "Right Click (Mouse2)"
    local keyboardAimKey = nil
    local isCustomKeyActive = false
    local inputBeganConn = nil
    local inputEndedConn = nil

    local function updateKeyMapping(keyName)
        currentAimKey = tostring(keyName or "Right Click (Mouse2)")
        if currentAimKey == "Custom Keyboard Key" then
            -- keep existing keyboardAimKey or default Q
            if not keyboardAimKey then keyboardAimKey = Enum.KeyCode.Q end
        end
    end

    inputBeganConn = UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if currentAimKey == "Custom Keyboard Key" and keyboardAimKey then
            if input.KeyCode == keyboardAimKey then
                isCustomKeyActive = true
            end
        end
    end)

    inputEndedConn = UserInputService.InputEnded:Connect(function(input)
        if currentAimKey == "Custom Keyboard Key" and keyboardAimKey then
            if input.KeyCode == keyboardAimKey then
                isCustomKeyActive = false
            end
        end
    end)

    function adapter.setAimKey(keyName)
        updateKeyMapping(keyName)
    end

    function adapter.setCustomKeyCode(code)
        if typeof(code) == "EnumItem" then
            keyboardAimKey = code
        elseif type(code) == "string" then
            local ok, enumItem = pcall(function() return Enum.KeyCode[code] end)
            if ok and enumItem and enumItem ~= Enum.KeyCode.Unknown then
                keyboardAimKey = enumItem
            end
        end
    end

    function adapter.isAimActive(activationMode)
        if activationMode == "Always" then
            return true
        end

        if currentAimKey == "Right Click (Mouse2)" then
            return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        elseif currentAimKey == "Left Click (Mouse1)" then
            return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        elseif currentAimKey == "Middle Click (Mouse3)" then
            return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton3)
        elseif currentAimKey == "Custom Keyboard Key" then
            if isCustomKeyActive then return true end
            if keyboardAimKey then
                return UserInputService:IsKeyDown(keyboardAimKey)
            end
        end

        return false
    end

    local origDestroy = adapter.destroy
    function adapter.destroy()
        if inputBeganConn then pcall(function() inputBeganConn:Disconnect() end) end
        if inputEndedConn then pcall(function() inputEndedConn:Disconnect() end) end
        if type(origDestroy) == "function" then
            pcall(origDestroy)
        end
    end

    return adapter
end
