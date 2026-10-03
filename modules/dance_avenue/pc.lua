-- ============================================================
-- N3Z Dance Avenue - PC Adapter
-- Desktop input, Key simulation, Drawing visual fallback
-- ============================================================

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
