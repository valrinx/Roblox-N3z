-- ============================================================
-- N3Z Dance Avenue - Mobile Adapter
-- NativeGui visual backend, touch-friendly rhythm actuation
-- ============================================================

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
                return playerGui
            end,
        })
    end,

    createRhythmActuator = function(api)
        local VIM = game:GetService("VirtualInputManager")
        local keyMapping = {
            LEFT = Enum.KeyCode.Left,
            RIGHT = Enum.KeyCode.Right,
            UP = Enum.KeyCode.Up,
            DOWN = Enum.KeyCode.Down,
            HIT = Enum.KeyCode.Space,
        }

        return {
            pressKey = function(keyName)
                local keyCode = keyMapping[keyName]
                if not keyCode then return false end
                pcall(function()
                    VIM:SendKeyEvent(true, keyCode, false, game)
                    task.wait(0.02)
                    VIM:SendKeyEvent(false, keyCode, false, game)
                end)
                return true
            end,

            triggerSpace = function()
                pcall(function()
                    VIM:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                    task.wait(0.02)
                    VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                end)
                return true
            end,

            destroy = function() end,
        }
    end,
}
