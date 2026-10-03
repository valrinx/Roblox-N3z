-- ============================================================
-- N3Z legacy platform adapter factory
-- Used only by newly ported Roblox--Library modules.
-- ============================================================

return function(platformName, ctx)
    assert(platformName == "pc" or platformName == "mobile",
        "legacy_platform: platform must be pc or mobile")

    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local Workspace = game:GetService("Workspace")

    local localPlayer = Players.LocalPlayer
    local adapter = { id = platformName }
    local nativeGui = nil
    local nativeObjects = {}

    local function resolveGuiParent()
        if type(gethui) == "function" then
            local ok, parent = pcall(gethui)
            if ok and parent then return parent end
        end

        local okCore, coreGui = pcall(game.GetService, game, "CoreGui")
        if okCore and coreGui then return coreGui end

        if localPlayer then
            local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
            if playerGui then return playerGui end
        end
        return nil
    end

    adapter.gethui = resolveGuiParent

    local function ensureNativeGui()
        if nativeGui and nativeGui.Parent then return nativeGui end
        local parent = resolveGuiParent()
        if not parent then return nil end

        local gui = Instance.new("ScreenGui")
        local moduleId = ctx and ctx.module and ctx.module.id or "legacy"
        gui.Name = "N3zLegacyVisuals_" .. tostring(moduleId)
        gui.IgnoreGuiInset = true
        gui.ResetOnSpawn = false
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.DisplayOrder = platformName == "mobile" and 998 or 20
        pcall(function() gui.ScreenInsets = Enum.ScreenInsets.None end)

        local ok = pcall(function() gui.Parent = parent end)
        if not ok then
            pcall(function() gui:Destroy() end)
            return nil
        end

        nativeGui = gui
        return gui
    end

    local function fontFromDrawing(value)
        if value == 3 then return Enum.Font.Code end
        if value == 2 then return Enum.Font.Gotham end
        if value == 1 then return Enum.Font.SourceSans end
        return Enum.Font.SourceSans
    end

    local function newNativeDrawing(kind)
        local gui = ensureNativeGui()
        if not gui then return nil end

        local state = {
            Visible = false,
            Color = Color3.new(1, 1, 1),
            Transparency = 1,
            Thickness = 1,
            Filled = false,
            Position = Vector2.zero,
            Size = kind == "Text" and 14 or Vector2.zero,
            Text = "",
            Center = false,
            Outline = false,
            From = Vector2.zero,
            To = Vector2.zero,
            Radius = 0,
            Font = 0,
            ZIndex = 0,
            NumSides = 32,
        }

        local inst
        local stroke

        if kind == "Text" then
            local label = Instance.new("TextLabel")
            label.Name = "NativeText"
            label.BackgroundTransparency = 1
            label.BorderSizePixel = 0
            label.AutomaticSize = Enum.AutomaticSize.XY
            label.Size = UDim2.fromOffset(0, 0)
            label.Text = ""
            label.TextSize = 14
            label.Font = Enum.Font.SourceSans
            label.Visible = false
            label.Parent = gui
            inst = label
        elseif kind == "Line" then
            local frame = Instance.new("Frame")
            frame.Name = "NativeLine"
            frame.BorderSizePixel = 0
            frame.AnchorPoint = Vector2.new(0.5, 0.5)
            frame.Visible = false
            frame.Parent = gui
            inst = frame
        elseif kind == "Square" or kind == "Circle" then
            local frame = Instance.new("Frame")
            frame.Name = kind == "Circle" and "NativeCircle" or "NativeSquare"
            frame.BorderSizePixel = 0
            frame.BackgroundTransparency = 1
            frame.Visible = false
            frame.Parent = gui
            inst = frame

            stroke = Instance.new("UIStroke")
            stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            stroke.Parent = frame

            if kind == "Circle" then
                frame.AnchorPoint = Vector2.new(0.5, 0.5)
                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(1, 0)
                corner.Parent = frame
            end
        else
            return nil
        end

        local removed = false
        local proxy = {}

        local function apply()
            if removed or not inst or not inst.Parent then return end

            local alpha = math.clamp(tonumber(state.Transparency) or 1, 0, 1)
            inst.Visible = state.Visible == true
            inst.ZIndex = math.max(1, math.floor(tonumber(state.ZIndex) or 0) + 1)

            if kind == "Text" then
                inst.Text = tostring(state.Text or "")
                inst.TextSize = math.max(1, tonumber(state.Size) or 14)
                inst.TextColor3 = state.Color
                inst.TextTransparency = 1 - alpha
                inst.TextStrokeColor3 = Color3.new(0, 0, 0)
                inst.TextStrokeTransparency = state.Outline and (1 - alpha) or 1
                inst.Font = fontFromDrawing(state.Font)
                inst.AnchorPoint = state.Center and Vector2.new(0.5, 0) or Vector2.zero
                inst.Position = UDim2.fromOffset(state.Position.X, state.Position.Y)
            elseif kind == "Line" then
                local from = state.From or Vector2.zero
                local to = state.To or Vector2.zero
                local delta = to - from
                local length = delta.Magnitude
                inst.Position = UDim2.fromOffset(
                    (from.X + to.X) * 0.5,
                    (from.Y + to.Y) * 0.5
                )
                inst.Size = UDim2.fromOffset(
                    math.max(0.01, length),
                    math.max(1, tonumber(state.Thickness) or 1)
                )
                inst.Rotation = math.deg(math.atan2(delta.Y, delta.X))
                inst.BackgroundColor3 = state.Color
                inst.BackgroundTransparency = 1 - alpha
            elseif kind == "Square" then
                inst.AnchorPoint = Vector2.zero
                inst.Position = UDim2.fromOffset(state.Position.X, state.Position.Y)
                local size = state.Size
                if typeof(size) ~= "Vector2" then size = Vector2.zero end
                inst.Size = UDim2.fromOffset(math.max(0, size.X), math.max(0, size.Y))
                inst.BackgroundColor3 = state.Color
                inst.BackgroundTransparency = state.Filled and (1 - alpha) or 1
                stroke.Enabled = not state.Filled
                stroke.Color = state.Color
                stroke.Thickness = math.max(1, tonumber(state.Thickness) or 1)
                stroke.Transparency = 1 - alpha
            elseif kind == "Circle" then
                local diameter = math.max(0, (tonumber(state.Radius) or 0) * 2)
                inst.Position = UDim2.fromOffset(state.Position.X, state.Position.Y)
                inst.Size = UDim2.fromOffset(diameter, diameter)
                inst.BackgroundColor3 = state.Color
                inst.BackgroundTransparency = state.Filled and (1 - alpha) or 1
                stroke.Enabled = not state.Filled
                stroke.Color = state.Color
                stroke.Thickness = math.max(1, tonumber(state.Thickness) or 1)
                stroke.Transparency = 1 - alpha
            end
        end

        local mt = {}

        function mt.__index(_, key)
            if key == "Remove" or key == "Destroy" then
                return function()
                    if removed then return end
                    removed = true
                    nativeObjects[proxy] = nil
                    if inst then pcall(function() inst:Destroy() end) end
                    inst = nil
                end
            end
            if key == "TextBounds" and kind == "Text" then
                local ok, bounds = pcall(function() return inst.TextBounds end)
                return ok and bounds or Vector2.zero
            end
            return state[key]
        end

        function mt.__newindex(_, key, value)
            state[key] = value
            apply()
        end

        setmetatable(proxy, mt)
        nativeObjects[proxy] = true
        apply()
        return proxy
    end

    local nativeDrawing = {
        Fonts = {
            UI = 0,
            System = 1,
            Plex = 2,
            Monospace = 3,
        },
    }
    nativeDrawing.new = newNativeDrawing

    local realDrawing = nil
    pcall(function() realDrawing = Drawing end)

    local baseDrawing
    if platformName == "pc"
        and type(realDrawing) == "table"
        and type(realDrawing.new) == "function" then
        baseDrawing = realDrawing
    else
        baseDrawing = nativeDrawing
    end

    local visualDrawing = baseDrawing
    if type(ctx) == "table" and type(ctx.loadModuleFile) == "function" then
        local okFactory, factory = pcall(
            ctx.loadModuleFile,
            "modules/_shared/visual_occlusion.lua"
        )
        if okFactory and type(factory) == "function" then
            local okWrap, wrapped = pcall(factory, baseDrawing, ctx)
            if okWrap and type(wrapped) == "table" then
                visualDrawing = wrapped
            end
        end
    end
    adapter.Drawing = visualDrawing

    local function cameraMouseMove(dx, dy)
        local camera = Workspace.CurrentCamera
        if not camera then return end
        local x = tonumber(dx) or 0
        local y = tonumber(dy) or 0
        local sensitivity = 0.0025
        camera.CFrame = camera.CFrame * CFrame.Angles(-y * sensitivity, -x * sensitivity, 0)
    end

    local rawMouseMove = nil
    pcall(function() rawMouseMove = mousemoverel end)
    adapter.mousemoverel = platformName == "pc" and type(rawMouseMove) == "function"
        and rawMouseMove
        or cameraMouseMove

    local function pointerPosition()
        local ok, pos = pcall(function() return UserInputService:GetMouseLocation() end)
        if ok and typeof(pos) == "Vector2" and pos.X > 0 and pos.Y > 0 then
            return pos
        end
        local camera = Workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
        return viewport / 2
    end

    local function sendMouse(button, down)
        local pos = pointerPosition()
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(
                pos.X, pos.Y, button, down, game, 0
            )
        end)
    end

    local function fallbackMouseClick(button)
        sendMouse(button, true)
        task.wait()
        sendMouse(button, false)
    end

    local rawMouse1Click, rawMouse1Press, rawMouse1Release
    local rawMouse2Click, rawMouse2Press, rawMouse2Release
    pcall(function() rawMouse1Click = mouse1click end)
    pcall(function() rawMouse1Press = mouse1press end)
    pcall(function() rawMouse1Release = mouse1release end)
    pcall(function() rawMouse2Click = mouse2click end)
    pcall(function() rawMouse2Press = mouse2press end)
    pcall(function() rawMouse2Release = mouse2release end)

    adapter.mouse1click = platformName == "pc" and rawMouse1Click
        or function() fallbackMouseClick(0) end
    adapter.mouse1press = platformName == "pc" and rawMouse1Press
        or function() sendMouse(0, true) end
    adapter.mouse1release = platformName == "pc" and rawMouse1Release
        or function() sendMouse(0, false) end
    adapter.mouse2click = platformName == "pc" and rawMouse2Click
        or function() fallbackMouseClick(1) end
    adapter.mouse2press = platformName == "pc" and rawMouse2Press
        or function() sendMouse(1, true) end
    adapter.mouse2release = platformName == "pc" and rawMouse2Release
        or function() sendMouse(1, false) end

    local function resolveKeyCode(value)
        if typeof(value) == "EnumItem" then return value end
        if type(value) == "string" then
            local ok, code = pcall(function() return Enum.KeyCode[value] end)
            if ok then return code end
        elseif type(value) == "number" then
            for _, code in ipairs(Enum.KeyCode:GetEnumItems()) do
                if code.Value == value then return code end
            end
        end
        return Enum.KeyCode.Unknown
    end

    local rawKeyPress, rawKeyRelease
    pcall(function() rawKeyPress = keypress end)
    pcall(function() rawKeyRelease = keyrelease end)

    adapter.keypress = platformName == "pc" and rawKeyPress
        or function(value)
            local code = resolveKeyCode(value)
            if code ~= Enum.KeyCode.Unknown then
                pcall(function()
                    VirtualInputManager:SendKeyEvent(true, code, false, game)
                end)
            end
        end

    adapter.keyrelease = platformName == "pc" and rawKeyRelease
        or function(value)
            local code = resolveKeyCode(value)
            if code ~= Enum.KeyCode.Unknown then
                pcall(function()
                    VirtualInputManager:SendKeyEvent(false, code, false, game)
                end)
            end
        end

    function adapter.destroy()
        if visualDrawing ~= baseDrawing
            and type(visualDrawing.destroy) == "function" then
            pcall(visualDrawing.destroy)
        end
        local objects = {}
        for obj in pairs(nativeObjects) do
            objects[#objects + 1] = obj
        end
        for _, obj in ipairs(objects) do
            pcall(function() obj:Remove() end)
        end
        table.clear(nativeObjects)
        if nativeGui then
            pcall(function() nativeGui:Destroy() end)
            nativeGui = nil
        end
    end

    return adapter
end
