-- ============================================================
-- N3Z HUB · dock.lua
-- Native-GUI bottom dock for N3z Hub. No Drawing API.
-- Returns the Dock class. n3z.lua loads this via loadstring.
--
-- UX: boot shows the dock bar only. Clicking a tab opens the
-- floating panel above it; clicking the active tab collapses it.
-- Every interactive row is clickable across its full width
-- (the switch pill itself is a visual, like the HTML mockup).
-- ============================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local localPlayer = Players.LocalPlayer

-- ---------- theme (matches n3z-dock.html mockup) ----------
local C = {
    panelBg  = Color3.fromRGB(13, 17, 28),    -- rgba(13,17,28,.97)
    dockBg   = Color3.fromRGB(13, 17, 28),    -- rgba(13,17,28,.96)
    rowHover = Color3.fromRGB(22, 29, 49),    -- #161d31
    text     = Color3.fromRGB(223, 227, 238), -- #dfe3ee
    dark     = Color3.fromRGB(4, 18, 26),     -- #04121a active-tab text
    muted    = Color3.fromRGB(139, 147, 167), -- #8b93a7 inactive tabs
    soft     = Color3.fromRGB(125, 138, 160), -- #7d8aa0 descriptions
    accent   = Color3.fromRGB(34, 211, 238),  -- #22d3ee cyan
    accent2  = Color3.fromRGB(167, 139, 250), -- #a78bfa avatar gradient
    danger   = Color3.fromRGB(248, 113, 113),
    good     = Color3.fromRGB(52, 211, 153),  -- #34d399 toggle ON / ACTIVE
    track    = Color3.fromRGB(42, 47, 66),    -- #2a2f42 toggle OFF track
    knobOff  = Color3.fromRGB(138, 144, 166), -- #8a90a6
    border   = Color3.fromRGB(38, 49, 74),    -- #26314a panel/dock border
    line     = Color3.fromRGB(28, 35, 56),    -- #1c2338 hairlines
    footText = Color3.fromRGB(95, 104, 128),  -- #5f6880 footer
    kbdText  = Color3.fromRGB(159, 179, 200), -- #9fb3c8 key chips
    kbdBd    = Color3.fromRGB(58, 74, 99),    -- #3a4a63 key chip border
}
local FONT      = Enum.Font.Gotham
local FONT_MED  = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold
local FONT_MONO = Enum.Font.Code

-- ---------- layouts: pc vs mobile (touch) ----------
-- Mobile values mirror the landscape phone mockup (n3z-dock-mobile.html):
-- 46px touch tabs, 52x30 switches, viewport-fitted panel, tap hint footer.
local LAYOUTS = {
    pc = {
        panelW = 460, contentH = 330,
        barW = 460, barH = 52, barCorner = 18,
        tabH = 36, tabFont = 12, tabPad = 12,
        indH = 36, indCorner = 12,
        showAvatar = true,
        rowPadL = 12, rowPadT = 11, rowCorner = 12,
        nameFont = 13, nameH = 17, descFont = 11,
        tglW = 40, tglH = 22, knob = 16, tglOnX = 29, tglOffX = 11,
        sliderW = 150, sliderH = 30, sliderKnob = 12,
        ddW = 130, ddH = 28, ddOptH = 26,
        footerKeyChip = true,
    },
    mobile = {
        panelW = 560, contentH = 220, -- refined from viewport below
        barH = 62, barCorner = 20,
        tabH = 46, tabFont = 11, tabPad = 15,
        indH = 46, indCorner = 14,
        showAvatar = false,
        rowPadL = 12, rowPadT = 13, rowCorner = 14,
        nameFont = 14, nameH = 18, descFont = 11,
        tglW = 52, tglH = 30, knob = 24, tglOnX = 37, tglOffX = 15,
        sliderW = 170, sliderH = 34, sliderKnob = 16,
        ddW = 150, ddH = 34, ddOptH = 32,
        footerKeyChip = false,
    },
}

local function corner(inst, r)
    local u = Instance.new("UICorner")
    u.CornerRadius = UDim.new(0, r)
    u.Parent = inst
    return u
end

local function cornerRound(inst)
    local u = Instance.new("UICorner")
    u.CornerRadius = UDim.new(1, 0)
    u.Parent = inst
    return u
end

local function stroke(inst, color, transp, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(255, 255, 255)
    s.Transparency = transp or 0.9
    s.Thickness = thickness or 1
    s.Parent = inst
    return s
end

local function pad(inst, l, t, r, b)
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, l or 10)
    p.PaddingTop = UDim.new(0, t or 8)
    p.PaddingRight = UDim.new(0, r or 10)
    p.PaddingBottom = UDim.new(0, b or 8)
    p.Parent = inst
    return p
end

-- Soft outer glow. Parented as a CHILD so it follows position/size
-- tweens automatically; the solid center covers its middle, the
-- oversized faint edge reads as light bloom.
local function glow(inst, color, extra, transp, round)
    local h = Instance.new("Frame")
    h.Name = "GlowFx"
    h.BackgroundColor3 = color
    h.BackgroundTransparency = transp or 0.85
    h.BorderSizePixel = 0
    h.AnchorPoint = Vector2.new(0.5, 0.5)
    h.Position = UDim2.new(0.5, 0, 0.5, 0)
    local e = extra or 10
    h.Size = UDim2.new(1, e, 1, e)
    h.Parent = inst
    if round then cornerRound(h) else corner(h, 14) end
    return h
end

local function label(text, size, color, font)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextSize = size
    l.TextColor3 = color or C.text
    l.Font = font or FONT
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextTruncate = Enum.TextTruncate.AtEnd
    return l
end

local function getGuiParent()
    local ok, hui = pcall(function() return gethui() end)
    if ok and typeof(hui) == "Instance" then return hui end
    local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and cg then return cg end
    return localPlayer:WaitForChild("PlayerGui")
end

local function keyName(kc)
    if type(kc) == "string" then
        return (kc:gsub("^ENUM_", ""))
    end
    if typeof(kc) == "EnumItem" then return kc.Name end
    return tostring(kc)
end

local KEY_SHORT = {
    RightShift = "RShift", LeftShift = "LShift",
    RightControl = "RCtrl", LeftControl = "LCtrl",
    RightAlt = "RAlt", LeftAlt = "LAlt",
}
local function keyShort(kc)
    local n = keyName(kc)
    return KEY_SHORT[n] or n
end

-- ============================================================
-- Dock class
-- ============================================================
local Dock = {}
Dock.__index = Dock

local TAB_ORDER = { "combat", "visuals", "modules", "settings" }
local TAB_LABEL = { combat = "COMBAT", visuals = "VISUALS", modules = "MODULES", settings = "SETTINGS" }

function Dock.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Dock)
    self._conns = {}
    self._unloadFns = {}
    self._tabs = {}       -- tabId -> {btn=, page=}
    self._tabIds = {}
    self._primaryTabIds = {}
    self._tabToggles = {} -- tabId -> {toggle handles} (footer count)
    self._tabInfo = {}    -- tabId -> static footer text
    self._activeTab = nil -- boot: dock bar only, nothing selected
    self._menuKey = opts.menuKey or Enum.KeyCode.K
    self._visible = true
    self._dead = false
    self._inputBlockEnabled = (opts.blockInputEnabled ~= false)
    self._inputBlockBound = false
    self._inputActionName = "N3Z_MENU_INPUT_BLOCK"
    -- clear a stale blocker left by an interrupted/re-executed dock
    pcall(function() ContextActionService:UnbindAction(self._inputActionName) end)
    -- layout: "pc" default, "mobile" for touch devices.
    local layoutName = (opts.layout == "mobile") and "mobile" or "pc"
    local L = LAYOUTS[layoutName]

    local function mobileViewportMetrics()
        local vx, vy = 844, 390
        pcall(function()
            local cam = workspace.CurrentCamera
            local vs = cam and cam.ViewportSize
            if vs then
                vx, vy = vs.X, vs.Y
            end
        end)
        local compactTabs = vx <= 520
        local narrowTabs = vx <= 380
        local tabPad = narrowTabs and 6 or (compactTabs and 9 or 15)
        local tabFont = narrowTabs and 9 or (compactTabs and 10 or 11)
        return math.min(560, math.max(300, vx - 24)),
            math.clamp(vy - 190, 150, 420),
            tabPad,
            tabFont
    end

    if layoutName == "mobile" then
        local panelW, contentH, tabPad, tabFont = mobileViewportMetrics()
        L = setmetatable({
            panelW = panelW,
            contentH = contentH,
            tabPad = tabPad,
            tabFont = tabFont,
        }, { __index = L })
    end
    self._layout = L
    self._isMobile = (layoutName == "mobile")

    local function conn(c) table.insert(self._conns, c) return c end
    self._conn = conn

    -- root
    local gui = Instance.new("ScreenGui")
    gui.Name = "N3zDock"
    gui.IgnoreGuiInset = true
    if self._isMobile then
        pcall(function()
            gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
        end)
    end
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999
    gui.Parent = getGuiParent()
    self._gui = gui

    -- Full-screen transparent mouse shield. It sits below every N3Z control
    -- (ZIndex 0) but above the 3D game while a panel is open, so clicks outside
    -- the menu are still marked as UI input instead of firing weapons/actions.
    local inputShield = Instance.new("TextButton")
    inputShield.Name = "InputShield"
    inputShield.BackgroundTransparency = 1
    inputShield.Text = ""
    inputShield.TextTransparency = 1
    inputShield.AutoButtonColor = false
    inputShield.Active = true
    inputShield.Modal = true
    inputShield.Visible = false
    inputShield.ZIndex = 0
    inputShield.Position = UDim2.fromScale(0, 0)
    inputShield.Size = UDim2.fromScale(1, 1)
    inputShield.Parent = gui
    self._inputShield = inputShield

    if self._isMobile then
        local mobileToggle = Instance.new("TextButton")
        mobileToggle.Name = "MobileMenuToggle"
        mobileToggle.AnchorPoint = Vector2.new(0.5, 0.5)
        mobileToggle.Position = UDim2.fromScale(0.92, 0.12)
        mobileToggle.Size = UDim2.fromOffset(54, 54)
        mobileToggle.BackgroundColor3 = C.dockBg
        mobileToggle.BackgroundTransparency = 0.04
        mobileToggle.BorderSizePixel = 0
        mobileToggle.AutoButtonColor = false
        mobileToggle.Text = "N3Z"
        mobileToggle.TextSize = 12
        mobileToggle.TextColor3 = C.accent
        mobileToggle.Font = FONT_BOLD
        mobileToggle.ZIndex = 50
        mobileToggle.Parent = gui
        corner(mobileToggle, 16)
        stroke(mobileToggle, C.border, 0)
        self._mobileToggle = mobileToggle
        self._mobileToggleX = 0.92
        self._mobileToggleY = 0.12

        local dragging = false
        local dragInput = nil
        local dragStart = nil
        local moved = false

        local function updateTogglePosition(input)
            local cam = workspace.CurrentCamera
            local size = cam and cam.ViewportSize
            if not size or size.X <= 0 or size.Y <= 0 then return end

            local x = math.clamp(input.Position.X / size.X, 0.06, 0.94)
            local y = math.clamp(input.Position.Y / size.Y, 0.08, 0.92)
            self:SetMobileTogglePosition(x, y)

            if dragStart and not moved then
                local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
                if delta.Magnitude >= 8 then
                    moved = true
                    self._mobileToggleSuppressUntil = os.clock() + 0.25
                end
            end
        end

        self._conn(mobileToggle.InputBegan:Connect(function(input)
            local inputType = input.UserInputType
            if inputType ~= Enum.UserInputType.Touch
                and inputType ~= Enum.UserInputType.MouseButton1 then
                return
            end
            dragging = true
            moved = false
            dragInput = (inputType == Enum.UserInputType.Touch) and input or nil
            dragStart = Vector2.new(input.Position.X, input.Position.Y)
        end))

        self._conn(UserInputService.InputChanged:Connect(function(input)
            if not dragging then return end
            if dragInput then
                if input ~= dragInput then return end
            elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then
                return
            end
            updateTogglePosition(input)
        end))

        self._conn(UserInputService.InputEnded:Connect(function(input)
            if not dragging then return end
            if dragInput then
                if input ~= dragInput then return end
            elseif input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                return
            end
            dragging = false
            dragInput = nil
            dragStart = nil
            if moved and type(self._mobileToggleChanged) == "function" then
                task.spawn(pcall, self._mobileToggleChanged, self._mobileToggleX, self._mobileToggleY)
            end
        end))

        self._conn(mobileToggle.Activated:Connect(function()
            if self._dead or os.clock() < (self._mobileToggleSuppressUntil or 0) then return end
            self:Toggle()
        end))
    end
    -- stage: bottom center column
    local stage = Instance.new("Frame")
    stage.Name = "Stage"
    stage.BackgroundTransparency = 1
    stage.AnchorPoint = Vector2.new(0.5, 1)
    stage.Position = UDim2.new(0.5, 0, 1, -14)
    stage.AutomaticSize = Enum.AutomaticSize.XY
    stage.Parent = gui
    local stageLayout = Instance.new("UIListLayout")
    stageLayout.FillDirection = Enum.FillDirection.Vertical
    stageLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    stageLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    stageLayout.Padding = UDim.new(0, 10)
    stageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    stageLayout.Parent = stage
    self._stage = stage

    -- panel (hidden until a tab is picked)
    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.BackgroundColor3 = C.panelBg
    panel.BackgroundTransparency = 0.03
    panel.Size = UDim2.new(0, L.panelW, 0, 0)
    panel.AutomaticSize = Enum.AutomaticSize.Y
    panel.LayoutOrder = 1
    panel.Visible = false
    panel.Parent = stage
    corner(panel, 16)
    stroke(panel, C.border, 0)
    self._panel = panel

    local panelPad = Instance.new("UIPadding")
    panelPad.PaddingLeft = UDim.new(0, 14)
    panelPad.PaddingRight = UDim.new(0, 14)
    panelPad.PaddingTop = UDim.new(0, 12)
    panelPad.PaddingBottom = UDim.new(0, 10)
    panelPad.Parent = panel
    local panelLayout = Instance.new("UIListLayout")
    panelLayout.FillDirection = Enum.FillDirection.Vertical
    panelLayout.Padding = UDim.new(0, 8)
    panelLayout.SortOrder = Enum.SortOrder.LayoutOrder
    panelLayout.Parent = panel

    -- header: game context (single source — no duplicates)
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.LayoutOrder = 1
    header.BackgroundTransparency = 1
    header.Size = UDim2.new(1, 0, 0, 40)
    header.Parent = panel

    local dot = Instance.new("Frame")
    dot.Name = "LiveDot"
    dot.Size = UDim2.new(0, 9, 0, 9)
    dot.Position = UDim2.new(0, 2, 0.5, -4)
    dot.BackgroundColor3 = C.good
    dot.BorderSizePixel = 0
    dot.Parent = header
    cornerRound(dot)
    local dotGlow = glow(dot, C.good, 10, 0.8, true)
    -- pulse like the mockup's .ctx .dot (2.6s breathe)
    task.delay(0.5, function()
        local function breathe()
            if self._dead or not dot.Parent then return end
            TweenService:Create(dotGlow,
                TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                { BackgroundTransparency = 0.55 }):Play()
            task.delay(1.3, function()
                if self._dead or not dot.Parent then return end
                TweenService:Create(dotGlow,
                    TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                    { BackgroundTransparency = 0.85 }):Play()
                task.delay(1.3, breathe)
            end)
        end
        breathe()
    end)

    local gameLabel = label("…", 13, C.text, FONT_MED)
    gameLabel.Position = UDim2.new(0, 20, 0, 2)
    gameLabel.Size = UDim2.new(1, -160, 0, 18)
    gameLabel.Parent = header
    self._gameLabel = gameLabel

    local placeLabel = label("…", 10, C.soft, FONT)
    placeLabel.Position = UDim2.new(0, 20, 0, 21)
    placeLabel.Size = UDim2.new(1, -160, 0, 14)
    placeLabel.Parent = header
    self._placeLabel = placeLabel

    local verLabel = label("…", 11, C.accent, FONT_MONO)
    verLabel.AnchorPoint = Vector2.new(1, 0)
    verLabel.Position = UDim2.new(1, 0, 0, 12)
    verLabel.Size = UDim2.new(0, 140, 0, 16)
    verLabel.TextXAlignment = Enum.TextXAlignment.Right
    verLabel.Parent = header
    self._verLabel = verLabel

    local hairline = Instance.new("Frame")
    hairline.Name = "Hairline"
    hairline.BackgroundColor3 = C.line
    hairline.BorderSizePixel = 0
    hairline.AnchorPoint = Vector2.new(0, 1)
    hairline.Position = UDim2.new(0, 0, 1, 0)
    hairline.Size = UDim2.new(1, 0, 0, 1)
    hairline.Parent = header

    -- content (scrolling, fixed height)
    local content = Instance.new("ScrollingFrame")
    content.Name = "Content"
    content.LayoutOrder = 2
    content.BackgroundTransparency = 1
    content.Size = UDim2.new(1, 0, 0, L.contentH)
    content.ScrollBarThickness = 3
    content.ScrollBarImageColor3 = C.border
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    content.CanvasSize = UDim2.new(0, 0, 0, 0)
    content.ScrollingDirection = Enum.ScrollingDirection.Y
    content.Parent = panel
    local contentLayout = Instance.new("UIListLayout")
    contentLayout.FillDirection = Enum.FillDirection.Vertical
    contentLayout.Padding = UDim.new(0, 6)
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    contentLayout.Parent = content
    self._content = content

    -- footer: count left, menu-key chip right
    local footer = Instance.new("Frame")
    footer.Name = "Footer"
    footer.LayoutOrder = 3
    footer.BackgroundTransparency = 1
    footer.Size = UDim2.new(1, 0, 0, 22)
    footer.Parent = panel

    local footLine = Instance.new("Frame")
    footLine.BackgroundColor3 = C.line
    footLine.BorderSizePixel = 0
    footLine.Size = UDim2.new(1, 0, 0, 1)
    footLine.Parent = footer

    local countLabel = label("N3Z HUB", 11, C.footText, FONT)
    countLabel.Position = UDim2.new(0, 0, 0, 5)
    countLabel.Size = UDim2.new(1, -80, 0, 16)
    countLabel.Parent = footer
    self._countLabel = countLabel

    if L.footerKeyChip then
        local kbdChip = Instance.new("TextLabel")
        kbdChip.BackgroundTransparency = 1
        kbdChip.Text = keyShort(self._menuKey)
        kbdChip.TextSize = 10
        kbdChip.TextColor3 = C.kbdText
        kbdChip.Font = FONT_MONO
        kbdChip.AutomaticSize = Enum.AutomaticSize.XY
        kbdChip.AnchorPoint = Vector2.new(1, 0)
        kbdChip.Position = UDim2.new(1, 0, 0, 3)
        kbdChip.Parent = footer
        corner(kbdChip, 5)
        stroke(kbdChip, C.kbdBd, 0)
        pad(kbdChip, 8, 3, 8, 3)
        self._footKbd = kbdChip
    else
        -- mobile: no keyboard — hint label replaces the key chip (mockup footer)
        local hint = label("⌄ tap tab to collapse", 11, C.accent, FONT)
        hint.AnchorPoint = Vector2.new(1, 0)
        hint.Position = UDim2.new(1, 0, 0, 5)
        hint.Size = UDim2.new(0, 180, 0, 16)
        hint.TextXAlignment = Enum.TextXAlignment.Right
        hint.Parent = footer
    end

    -- dock bar
    local bar = Instance.new("Frame")
    bar.Name = "DockBar"
    bar.BackgroundColor3 = C.dockBg
    bar.BackgroundTransparency = 0.04
    bar.Active = true
    if self._isMobile then
        bar.AutomaticSize = Enum.AutomaticSize.X
        bar.Size = UDim2.new(0, 0, 0, L.barH)
    else
        bar.AutomaticSize = Enum.AutomaticSize.None
        bar.Size = UDim2.new(0, L.barW or L.panelW, 0, L.barH)
    end
    bar.LayoutOrder = 2
    bar.Parent = stage
    corner(bar, L.barCorner)
    stroke(bar, C.border, 0)
    local barPad = Instance.new("UIPadding")
    barPad.PaddingLeft = UDim.new(0, 8)
    barPad.PaddingRight = UDim.new(0, 8)
    barPad.PaddingTop = UDim.new(0, 8)
    barPad.PaddingBottom = UDim.new(0, 8)
    barPad.Parent = bar
    self._bar = bar

    if self._isMobile then
        local viewportConnection = nil

        local function clampDockToViewport()
            if self._dead or not bar.Parent then return end
            local cam = workspace.CurrentCamera
            local vs = cam and cam.ViewportSize
            if not vs then return end

            local bp = bar.AbsolutePosition
            local bs = bar.AbsoluteSize
            if bs.X <= 0 or bs.Y <= 0 then return end

            local margin = 8
            local desiredX = math.clamp(bp.X, margin, math.max(margin, vs.X - bs.X - margin))
            local desiredY = math.clamp(bp.Y, margin, math.max(margin, vs.Y - bs.Y - margin))
            local delta = Vector2.new(desiredX - bp.X, desiredY - bp.Y)
            if delta.Magnitude > 0.5 then
                local sp = stage.Position
                stage.Position = UDim2.new(
                    sp.X.Scale, sp.X.Offset + delta.X,
                    sp.Y.Scale, sp.Y.Offset + delta.Y
                )
            end
        end

        local function applyMobileViewport()
            if self._dead then return end
            local panelW, contentH, tabPad, tabFont = mobileViewportMetrics()
            L.panelW = panelW
            L.contentH = contentH
            L.tabPad = tabPad
            L.tabFont = tabFont
            panel.Size = UDim2.new(0, panelW, 0, 0)
            content.Size = UDim2.new(1, 0, 0, contentH)

            for _, tab in pairs(self._tabs) do
                local button = tab.btn
                if button then
                    button.TextSize = tabFont
                    local padding = button:FindFirstChildOfClass("UIPadding")
                    if padding then
                        padding.PaddingLeft = UDim.new(0, tabPad)
                        padding.PaddingRight = UDim.new(0, tabPad)
                    end
                end
            end
            if self._logo then
                self._logo.TextSize = panelW <= 380 and 12 or 14
            end
            if self._mobileToggle then
                self:SetMobileTogglePosition(self._mobileToggleX or 0.92, self._mobileToggleY or 0.12)
            end
            task.defer(clampDockToViewport)
        end

        local function bindViewportCamera()
            if viewportConnection then
                pcall(function() viewportConnection:Disconnect() end)
                viewportConnection = nil
            end
            local cam = workspace.CurrentCamera
            if cam then
                viewportConnection = cam:GetPropertyChangedSignal("ViewportSize"):Connect(applyMobileViewport)
                table.insert(self._conns, viewportConnection)
            end
            applyMobileViewport()
        end

        self._conn(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindViewportCamera))
        self._applyMobileViewport = applyMobileViewport
        bindViewportCamera()
    end
    -- Draggable dock. Listen at UserInputService level instead of only
    -- bar.InputBegan: most of the visible bar is covered by tab/avatar
    -- children, so child hit-testing otherwise prevents drag from starting.
    -- A movement threshold preserves normal tab clicks.
    do
        local uis = game:GetService("UserInputService")
        local dragging = false
        local dragMoved = false
        local dragInput = nil
        local grabOffset = nil
        local grabPos = nil

        self._flipped = false

        local function setFlipped(f)
            f = (f == true)
            if self._flipped == f then return end

            -- Keep the dock bar pinned to the exact same screen position while
            -- the panel changes sides. Without this, changing LayoutOrder makes
            -- the bar jump by roughly the panel height and "escape" the cursor.
            local oldBarPos = bar.AbsolutePosition
            self._flipped = f

            if f then
                bar.LayoutOrder = 1
                panel.LayoutOrder = 2
                stageLayout.VerticalAlignment = Enum.VerticalAlignment.Top
            else
                panel.LayoutOrder = 1
                bar.LayoutOrder = 2
                stageLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
            end

            local function repinBar()
                if self._dead or not stage.Parent or not bar.Parent then return end
                local delta = oldBarPos - bar.AbsolutePosition
                if delta.Magnitude > 0.5 then
                    local p = stage.Position
                    stage.Position = UDim2.new(
                        p.X.Scale, p.X.Offset + delta.X,
                        p.Y.Scale, p.Y.Offset + delta.Y
                    )
                end
            end

            -- Layout may settle immediately or on the next scheduler step
            -- depending on executor/frame timing, so correct both times.
            repinBar()
            task.defer(repinBar)
        end

        local function applyFlipByY()
            local cam = workspace.CurrentCamera
            local vy = cam and cam.ViewportSize.Y or 1080
            local barCenterY = bar.AbsolutePosition.Y + bar.AbsoluteSize.Y * 0.5
            setFlipped(barCenterY < vy * 0.4)
        end

        local function pointerPos(input)
            local p = input.Position
            return Vector2.new(p.X, p.Y)
        end

        local function insideBar(pos)
            local p = bar.AbsolutePosition
            local sz = bar.AbsoluteSize
            return pos.X >= p.X and pos.X <= p.X + sz.X
                and pos.Y >= p.Y and pos.Y <= p.Y + sz.Y
        end

        local function beginDrag(input)
            local t = input.UserInputType
            if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
                return
            end
            local pos = pointerPos(input)
            if not insideBar(pos) then return end

            dragging = true
            dragMoved = false
            dragInput = (t == Enum.UserInputType.Touch) and input or nil
            grabPos = pos
            -- Preserve the exact point inside the dock bar that the cursor
            -- grabbed. The panel can be much taller than the bar, so using
            -- stage.AbsolutePosition makes the cursor drift near screen edges.
            grabOffset = pos - bar.AbsolutePosition
        end

        self._conn(uis.InputBegan:Connect(function(input)
            if self._dead then return end
            beginDrag(input)
        end))

        self._conn(uis.InputChanged:Connect(function(input)
            if self._dead or not dragging then return end
            local t = input.UserInputType
            if dragInput then
                if input ~= dragInput then return end
            elseif t ~= Enum.UserInputType.MouseMovement then
                return
            end

            local pos = pointerPos(input)
            if not dragMoved then
                if (pos - grabPos).Magnitude < 8 then return end
                dragMoved = true
                self._dragSuppressUntil = os.clock() + 0.20
                local absPos = stage.AbsolutePosition
                stage.AnchorPoint = Vector2.new(0, 0)
                stage.Position = UDim2.fromOffset(absPos.X, absPos.Y)
            end

            local cam = workspace.CurrentCamera
            local vx = cam and cam.ViewportSize.X or 1920
            local vy = cam and cam.ViewportSize.Y or 1080

            -- Clamp the BAR, not the full stage. This keeps the grabbed point
            -- under the cursor even while an open panel extends above/below it.
            local desiredBar = Vector2.new(
                math.clamp(pos.X - grabOffset.X, 0, math.max(0, vx - bar.AbsoluteSize.X)),
                math.clamp(pos.Y - grabOffset.Y, 0, math.max(0, vy - bar.AbsoluteSize.Y))
            )
            local delta = desiredBar - bar.AbsolutePosition
            local sp = stage.Position
            stage.Position = UDim2.new(
                sp.X.Scale, sp.X.Offset + delta.X,
                sp.Y.Scale, sp.Y.Offset + delta.Y
            )
        end))

        self._conn(uis.InputEnded:Connect(function(input)
            if not dragging then return end
            local t = input.UserInputType
            if dragInput then
                if input ~= dragInput then return end
            elseif t ~= Enum.UserInputType.MouseButton1 then
                return
            end

            dragging = false
            dragInput = nil
            if dragMoved then
                self._dragSuppressUntil = os.clock() + 0.20
                applyFlipByY()
            end
        end))
    end

    -- sliding indicator: sibling of tab containers, NOT in any layout, so the
    -- layout engine never fights the tween. Absolutely positioned in bar space.
    local ind = Instance.new("Frame")
    ind.Name = "Indicator"
    ind.BackgroundColor3 = C.accent
    ind.BackgroundTransparency = 0
    ind.BorderSizePixel = 0
    ind.AnchorPoint = Vector2.new(0, 0.5)
    ind.Position = UDim2.new(0, 8, 0.5, 0)
    ind.Size = UDim2.new(0, 60, 0, L.indH)
    ind.ZIndex = 0
    ind.Visible = false
    ind.Parent = bar
    corner(ind, L.indCorner)
    glow(ind, C.accent, 12, 0.85, false)
    self._indicator = ind

    -- pin the indicator under the active tab. Waits for real layout sizes
    -- (buttons use AutomaticSize.X) before measuring; instant on boot,
    -- spring-tweened on tab switches, re-pinned when the bar resizes.
    local function pinIndicator(animate)
        if not self._activeTab then
            ind.Visible = false
            return
        end
        task.spawn(function()
            local t = self._tabs[self._activeTab]
            if not t then return end
            local btn = t.btn
            local tries = 0
            while btn.Parent and btn.AbsoluteSize.X <= 0 and tries < 120 do
                RunService.RenderStepped:Wait()
                tries = tries + 1
            end
            local barInst, indInst = self._bar, self._indicator
            if not btn.Parent or not barInst or not indInst or not indInst.Parent then return end
            if btn.AbsoluteSize.X <= 0 then return end
            -- The active tab may have changed or been removed while we waited.
            local cur = self._activeTab and self._tabs[self._activeTab]
            if not cur or cur.btn ~= btn then
                if not cur then indInst.Visible = false end
                return
            end

            local drawLeft = btn.AbsolutePosition.X
            local drawRight = drawLeft + btn.AbsoluteSize.X
            -- PC primary tabs: clip the indicator to the primary viewport so a
            -- partially scrolled tab never paints under the Logo / SETTINGS.
            if not self._isMobile and self._primaryScroll and btn.Parent == self._primaryScroll then
                local ps = self._primaryScroll
                local psLeft = ps.AbsolutePosition.X
                local psRight = psLeft + ps.AbsoluteSize.X
                drawLeft = math.max(drawLeft, psLeft)
                drawRight = math.min(drawRight, psRight)
                if drawRight - drawLeft <= 1 then
                    indInst.Visible = false
                    return
                end
            end

            -- NOTE: UIPadding offsets ALL children, even manually positioned
            -- ones, so measure the button relative to the bar's padding box.
            local padL = 0
            local padInst = barInst:FindFirstChildOfClass("UIPadding")
            if padInst then padL = padInst.PaddingLeft.Offset end
            local relX = drawLeft - barInst.AbsolutePosition.X
            local size = UDim2.new(0, drawRight - drawLeft, 0, L.indH)
            local pos = UDim2.new(0, relX - padL, 0.5, 0)
            indInst.Visible = true
            if animate then
                indInst:TweenSizeAndPosition(size, pos,
                    Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.32, true)
            else
                indInst.Size = size
                indInst.Position = pos
            end
        end)
    end
    self._pinIndicator = pinIndicator
    conn(bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        pinIndicator(false)
    end))

    if self._isMobile then
        -- Mobile tabs row: unchanged flat row
        local tabsRow = Instance.new("Frame")
        tabsRow.Name = "TabsRow"
        tabsRow.BackgroundTransparency = 1
        tabsRow.AutomaticSize = Enum.AutomaticSize.XY
        tabsRow.ZIndex = 1
        tabsRow.Parent = bar
        local tabsLayout = Instance.new("UIListLayout")
        tabsLayout.FillDirection = Enum.FillDirection.Horizontal
        tabsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        tabsLayout.Padding = UDim.new(0, 4)
        tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
        tabsLayout.Parent = tabsRow
        self._tabsRow = tabsRow

        -- N3Z logo at the start of the mobile bar
        local logo = Instance.new("TextLabel")
        logo.Name = "Logo"
        logo.BackgroundTransparency = 1
        logo.RichText = true
        logo.Text = '<font color="#DFE3EE"><b>N3Z</b></font><font color="#22D3EE"><b>·</b></font>'
        logo.TextSize = 14
        logo.Font = FONT_BOLD
        logo.AutomaticSize = Enum.AutomaticSize.X
        logo.Size = UDim2.new(0, 0, 0, L.tabH)
        logo.LayoutOrder = -1
        logo.Parent = tabsRow
        self._logo = logo

        for _, id in ipairs(TAB_ORDER) do
            self:AddTab(TAB_LABEL[id], id)
        end

        if self._applyMobileViewport then
            self._applyMobileViewport()
        end
    else
        -- Desktop PC: 2-zone top bar
        -- 1. Logo pinned to the left
        local logo = Instance.new("TextLabel")
        logo.Name = "Logo"
        logo.BackgroundTransparency = 1
        logo.RichText = true
        logo.Text = '<font color="#DFE3EE"><b>N3Z</b></font><font color="#22D3EE"><b>·</b></font>'
        logo.TextSize = 14
        logo.Font = FONT_BOLD
        logo.AutomaticSize = Enum.AutomaticSize.X
        logo.Size = UDim2.new(0, 0, 0, L.tabH)
        logo.AnchorPoint = Vector2.new(0, 0.5)
        logo.Position = UDim2.new(0, 0, 0.5, 0)
        logo.ZIndex = 1
        logo.Parent = bar
        self._logo = logo

        -- 2. Utility Zone pinned to the right (SETTINGS + Avatar)
        local utilityZone = Instance.new("Frame")
        utilityZone.Name = "UtilityZone"
        utilityZone.BackgroundTransparency = 1
        utilityZone.AnchorPoint = Vector2.new(1, 0.5)
        utilityZone.Position = UDim2.new(1, 0, 0.5, 0)
        utilityZone.AutomaticSize = Enum.AutomaticSize.X
        utilityZone.Size = UDim2.new(0, 0, 0, L.tabH)
        utilityZone.ZIndex = 1
        utilityZone.Parent = bar
        local utilityLayout = Instance.new("UIListLayout")
        utilityLayout.FillDirection = Enum.FillDirection.Horizontal
        utilityLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        utilityLayout.Padding = UDim.new(0, 4)
        utilityLayout.SortOrder = Enum.SortOrder.LayoutOrder
        utilityLayout.Parent = utilityZone
        self._utilityZone = utilityZone

        -- 3. Primary Tabs scroll area (occupies space between Logo and Utility Zone)
        local primaryScroll = Instance.new("ScrollingFrame")
        primaryScroll.Name = "PrimaryScroll"
        primaryScroll.BackgroundTransparency = 1
        primaryScroll.BorderSizePixel = 0
        primaryScroll.AnchorPoint = Vector2.new(0, 0.5)
        primaryScroll.Position = UDim2.new(0, 42, 0.5, 0)
        primaryScroll.Size = UDim2.new(1, -182, 0, L.tabH)
        primaryScroll.ScrollingDirection = Enum.ScrollingDirection.X
        -- Hidden when everything fits; clampPrimaryScroll exposes a thin
        -- horizontal thumb only while more primary tabs exist off-screen.
        primaryScroll.ScrollBarThickness = 0
        primaryScroll.ScrollBarImageColor3 = C.accent
        primaryScroll.ScrollBarImageTransparency = 0.12
        -- Canvas is sized explicitly from the layout's real content width
        -- (see clampPrimaryScroll) so it never lags behind add/remove.
        primaryScroll.AutomaticCanvasSize = Enum.AutomaticSize.None
        primaryScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        primaryScroll.ScrollingEnabled = false
        primaryScroll.ClipsDescendants = true
        primaryScroll.ZIndex = 1
        primaryScroll.Parent = bar
        self._primaryScroll = primaryScroll
        self._tabsRow = primaryScroll

        local primaryLayout = Instance.new("UIListLayout")
        primaryLayout.FillDirection = Enum.FillDirection.Horizontal
        primaryLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        primaryLayout.Padding = UDim.new(0, 4)
        primaryLayout.SortOrder = Enum.SortOrder.LayoutOrder
        primaryLayout.Parent = primaryScroll
        self._primaryLayout = primaryLayout

        -- Overflow source of truth: real layout content width vs the actual
        -- primary viewport width. Scrolling is enabled ONLY on true overflow;
        -- otherwise the canvas is pinned at zero so no stale offset can clip
        -- a label (e.g. "MODULES" -> "ULES") when everything already fits.
        local function primaryMaxScroll()
            local contentW = math.ceil(primaryLayout.AbsoluteContentSize.X)
            local viewW = math.floor(primaryScroll.AbsoluteSize.X)
            if viewW <= 0 then return 0, contentW end
            return math.max(0, contentW - viewW), contentW
        end

        local function clampPrimaryScroll()
            if self._dead or not primaryScroll.Parent then return end
            local maxScroll, contentW = primaryMaxScroll()
            primaryScroll.CanvasSize = UDim2.new(0, contentW, 0, 0)
            if maxScroll <= 1 then
                primaryScroll.ScrollingEnabled = false
                primaryScroll.ScrollBarThickness = 0
                if primaryScroll.CanvasPosition ~= Vector2.zero then
                    primaryScroll.CanvasPosition = Vector2.zero
                end
            else
                primaryScroll.ScrollingEnabled = true
                primaryScroll.ScrollBarThickness = 3
                local x = math.clamp(primaryScroll.CanvasPosition.X, 0, maxScroll)
                if x ~= primaryScroll.CanvasPosition.X or primaryScroll.CanvasPosition.Y ~= 0 then
                    primaryScroll.CanvasPosition = Vector2.new(x, 0)
                end
            end
        end
        self._clampPrimaryScroll = clampPrimaryScroll

        local function updatePrimaryBounds()
            if self._dead or not bar.Parent then return end
            local logoW = logo.AbsoluteSize.X
            if logoW <= 0 then logoW = 36 end
            local utilW = utilityZone.AbsoluteSize.X
            if utilW <= 0 then utilW = 134 end
            local gap = 6
            local startX = logoW + gap
            primaryScroll.Position = UDim2.new(0, startX, 0.5, 0)
            primaryScroll.Size = UDim2.new(1, -(startX + utilW + gap), 0, L.tabH)
            clampPrimaryScroll()
        end
        conn(logo:GetPropertyChangedSignal("AbsoluteSize"):Connect(updatePrimaryBounds))
        conn(utilityZone:GetPropertyChangedSignal("AbsoluteSize"):Connect(updatePrimaryBounds))
        conn(bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(updatePrimaryBounds))
        conn(primaryScroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(clampPrimaryScroll))
        conn(primaryLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(clampPrimaryScroll))
        task.defer(updatePrimaryBounds)

        -- Mouse wheel horizontal scroll: only when the primary zone overflows.
        conn(primaryScroll.InputChanged:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
            local maxScroll = primaryMaxScroll()
            if maxScroll <= 1 then return end
            local targetX = math.clamp(primaryScroll.CanvasPosition.X - input.Position.Z * 45, 0, maxScroll)
            primaryScroll.CanvasPosition = Vector2.new(targetX, 0)
        end))

        -- Scroll the given primary button fully into view (no-op without overflow).
        local function ensureVisible(btn)
            if not btn or btn.Parent ~= primaryScroll then return end
            clampPrimaryScroll()
            local maxScroll = primaryMaxScroll()
            if maxScroll <= 1 then return end
            local pLeft = primaryScroll.AbsolutePosition.X
            local pRight = pLeft + primaryScroll.AbsoluteSize.X
            local bLeft = btn.AbsolutePosition.X
            local bRight = bLeft + btn.AbsoluteSize.X
            local x = primaryScroll.CanvasPosition.X
            if bLeft < pLeft then
                x = x - (pLeft - bLeft)
            elseif bRight > pRight then
                x = x + (bRight - pRight)
            end
            primaryScroll.CanvasPosition = Vector2.new(math.clamp(x, 0, maxScroll), 0)
        end
        self._ensureVisible = ensureVisible

        conn(primaryScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
            if self._activeTab and self._activeTab ~= "settings" then
                pinIndicator(false)
            end
        end))

        -- fixed tabs: primary tabs added to primaryScroll, settings added to utilityZone
        for _, id in ipairs(TAB_ORDER) do
            self:AddTab(TAB_LABEL[id], id)
        end

        -- Avatar / Profile in UtilityZone (pinned right, after settings)
        if L.showAvatar then
            local spacer = Instance.new("Frame")
            spacer.Name = "AvatarGap"
            spacer.BackgroundTransparency = 1
            spacer.Size = UDim2.new(0, 2, 0, 1)
            spacer.LayoutOrder = 2
            spacer.Parent = utilityZone

            local avWrap = Instance.new("Frame")
            avWrap.Name = "Avatar"
            avWrap.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            avWrap.BorderSizePixel = 0
            avWrap.Size = UDim2.new(0, 38, 0, 38)
            avWrap.LayoutOrder = 3
            avWrap.Parent = utilityZone
            cornerRound(avWrap)
            local grad = Instance.new("UIGradient")
            grad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, C.accent),
                ColorSequenceKeypoint.new(1, C.accent2),
            })
            grad.Rotation = 135
            grad.Parent = avWrap
            glow(avWrap, C.accent, 8, 0.85, true)
            local av = Instance.new("ImageLabel")
            av.Name = "AvatarImage"
            av.BackgroundColor3 = C.panelBg
            av.BorderSizePixel = 0
            av.AnchorPoint = Vector2.new(0.5, 0.5)
            av.Position = UDim2.new(0.5, 0, 0.5, 0)
            av.Size = UDim2.new(0, 34, 0, 34)
            av.Image = ""
            av.Parent = avWrap
            cornerRound(av)
            self._avatar = av
        end
    end

    -- menu key
    conn(UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == self._menuKey then
            self:Toggle()
        end
    end))

    return self
end

-- ---------- tabs ----------
function Dock:AddTab(tabLabel, tabId)
    local L = self._layout
    tabId = tabId or string.lower(tostring(tabLabel))
    if self._tabs[tabId] then return tabId end
    if self._prunedTabs then self._prunedTabs[tabId] = nil end

    local btn = Instance.new("TextButton")
    btn.Name = "Tab_" .. tabId
    btn.BackgroundTransparency = 1
    btn.AutoButtonColor = false
    btn.Text = string.upper(tostring(tabLabel))
    btn.TextSize = L.tabFont
    btn.TextColor3 = C.muted
    btn.Font = FONT_MED
    btn.AutomaticSize = Enum.AutomaticSize.X
    btn.Size = UDim2.new(0, 0, 0, L.tabH)
    if self._isMobile then
        btn.LayoutOrder = #self._tabIds
        btn.Parent = self._tabsRow
    else
        if string.lower(tostring(tabId)) == "settings" then
            btn.LayoutOrder = 1
            btn.Parent = self._utilityZone
        else
            table.insert(self._primaryTabIds, tabId)
            btn.LayoutOrder = #self._primaryTabIds
            btn.Parent = self._primaryScroll
        end
    end
    local btnPad = Instance.new("UIPadding")
    btnPad.PaddingLeft = UDim.new(0, L.tabPad)
    btnPad.PaddingRight = UDim.new(0, L.tabPad)
    btnPad.Parent = btn
    local pressScale = Instance.new("UIScale")
    pressScale.Parent = btn

    local page = Instance.new("Frame")
    page.Name = "Page_" .. tabId
    page.BackgroundTransparency = 1
    page.Size = UDim2.new(1, 0, 0, 0)
    page.AutomaticSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = self._content
    local pageLayout = Instance.new("UIListLayout")
    pageLayout.FillDirection = Enum.FillDirection.Vertical
    pageLayout.Padding = UDim.new(0, 6)
    pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    pageLayout.Parent = page

    local id = tabId
    local this = self
    local tabClick = self._isMobile and btn.Activated or btn.MouseButton1Click
    self._conn(tabClick:Connect(function()
        if os.clock() < (this._dragSuppressUntil or 0) then return end
        this:SetActiveTab(id)
    end))
    -- hover: brighten (mockup .di:hover)
    self._conn(btn.MouseEnter:Connect(function()
        if this._activeTab ~= id then btn.TextColor3 = C.text end
    end))
    self._conn(btn.MouseLeave:Connect(function()
        if this._activeTab ~= id then btn.TextColor3 = C.muted end
    end))
    -- press: subtle scale (mockup .di:active)
    self._conn(btn.MouseButton1Down:Connect(function()
        TweenService:Create(pressScale, TweenInfo.new(0.1), { Scale = 0.96 }):Play()
    end))
    self._conn(btn.MouseButton1Up:Connect(function()
        TweenService:Create(pressScale, TweenInfo.new(0.12), { Scale = 1 }):Play()
    end))

    table.insert(self._tabIds, tabId)
    self._tabs[tabId] = { btn = btn, page = page, order = #self._tabIds }
    self._tabToggles[tabId] = {}
    return tabId
end

-- Re-pin the dock bar after any layout mutation (panel open/close,
-- switching pages with different heights, flip, etc.). After a manual drag the
-- Stage uses absolute positioning, so AutomaticSize/UIListLayout changes must
-- not be allowed to move the bar the user placed.
function Dock:_repinBar(oldBarPos, holdSeconds)
    local stage = self._stage
    local bar = self._bar
    if self._dead or not stage or not bar or not stage.Parent or not bar.Parent then return end

    self._barPinToken = (self._barPinToken or 0) + 1
    local token = self._barPinToken
    local deadline = os.clock() + (holdSeconds or 0.65)
    local correcting = false

    local function repin()
        if correcting or self._dead or token ~= self._barPinToken
            or not stage.Parent or not bar.Parent then return end
        local delta = oldBarPos - bar.AbsolutePosition
        if delta.Magnitude > 0.25 then
            correcting = true
            local p = stage.Position
            stage.Position = UDim2.new(
                p.X.Scale, p.X.Offset + delta.X,
                p.Y.Scale, p.Y.Offset + delta.Y
            )
            correcting = false
        end
    end

    -- Correct immediately whenever UIListLayout/AutomaticSize moves the bar.
    local posConn
    posConn = bar:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
        if self._dead or token ~= self._barPinToken or os.clock() >= deadline then
            if posConn then posConn:Disconnect(); posConn = nil end
            return
        end
        repin()
    end)
    self._conn(posConn)

    -- Keep a render-step guard for the whole open/close animation window.
    local frameConn
    frameConn = RunService.RenderStepped:Connect(function()
        if self._dead or token ~= self._barPinToken or os.clock() >= deadline then
            if frameConn then frameConn:Disconnect(); frameConn = nil end
            if posConn then posConn:Disconnect(); posConn = nil end
            return
        end
        repin()
    end)
    self._conn(frameConn)

    repin()
end

-- Clicking a tab opens its panel; clicking the active tab collapses it.
function Dock:SetActiveTab(tabId)
    if not self._tabs[tabId] then return end

    local oldBarPos = self._bar and self._bar.AbsolutePosition or nil

    if self._activeTab == tabId then
        self:_collapsePanel(oldBarPos)
        return
    end

    self._activeTab = tabId
    self._panel.Visible = true
    for id, t in pairs(self._tabs) do
        local active = (id == tabId)
        t.page.Visible = active
        t.btn.TextColor3 = active and C.dark or C.muted
        t.btn.Font = active and FONT_BOLD or FONT_MED
    end
    if not self._isMobile and tabId ~= "settings" and self._ensureVisible then
        local t = self._tabs[tabId]
        if t and t.btn then
            self._ensureVisible(t.btn)
        end
    end
    -- slide the indicator under the active button (robust pin: waits for layout)
    if self._pinIndicator then self._pinIndicator(true) end
    self:_animateRows(self._tabs[tabId].page)
    self:_updateFooter()
    self:_syncInputBlock()

    if oldBarPos then self:_repinBar(oldBarPos, 0.8) end
end

-- staggered row entrance (mockup rowIn): fresh snapshot each switch so
-- dynamic colors (toggles) restore to their CURRENT state, then fade in.
function Dock:_animateRows(page)
    local rows = {}
    for _, c in ipairs(page:GetChildren()) do
        if c:IsA("GuiObject") and c.Name == "Row" then rows[#rows + 1] = c end
    end
    table.sort(rows, function(a, b) return (a.LayoutOrder or 0) < (b.LayoutOrder or 0) end)
    for i, row in ipairs(rows) do
        local snap = {}
        local function rec(inst)
            if inst:IsA("GuiObject") then
                local bt = inst.BackgroundTransparency
                if type(bt) == "number" and bt < 1 then
                    snap[#snap + 1] = { inst = inst, prop = "BackgroundTransparency", target = bt }
                end
            end
            if inst:IsA("TextLabel") or inst:IsA("TextButton") then
                local tt = inst.TextTransparency
                if type(tt) == "number" and tt < 1 then
                    snap[#snap + 1] = { inst = inst, prop = "TextTransparency", target = tt }
                end
            end
            if inst:IsA("ImageLabel") then
                local it = inst.ImageTransparency
                if type(it) == "number" and it < 1 then
                    snap[#snap + 1] = { inst = inst, prop = "ImageTransparency", target = it }
                end
            end
            for _, ch in ipairs(inst:GetChildren()) do
                if ch.ClassName == "UIStroke" then
                    local st = ch.Transparency
                    if type(st) == "number" and st < 1 then
                        snap[#snap + 1] = { inst = ch, prop = "Transparency", target = st }
                    end
                else
                    rec(ch)
                end
            end
        end
        rec(row)
        if #snap > 0 then
            for _, s in ipairs(snap) do
                if s.prop == "Transparency" then s.inst.Transparency = 1
                elseif s.prop == "BackgroundTransparency" then s.inst.BackgroundTransparency = 1
                elseif s.prop == "TextTransparency" then s.inst.TextTransparency = 1
                elseif s.prop == "ImageTransparency" then s.inst.ImageTransparency = 1 end
            end
            task.delay((i - 1) * 0.04, function()
                if self._dead or not row.Parent then return end
                for _, s in ipairs(snap) do
                    local goal = {}
                    goal[s.prop] = s.target
                    TweenService:Create(s.inst, TweenInfo.new(0.25,
                        Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
                end
            end)
        end
    end
end

function Dock:_refreshToggleCount()
    local id = self._activeTab
    if not id then return end
    local hs = self._tabToggles[id]
    if hs and #hs > 0 then
        local on = 0
        for _, h in ipairs(hs) do
            if h:Get() then on = on + 1 end
        end
        self._countLabel.Text = string.upper(id) .. " — " .. on .. "/" .. #hs .. " ON"
    end
end

function Dock:_updateFooter()
    local id = self._activeTab
    if not id then
        self._countLabel.Text = "N3Z HUB"
        return
    end
    local hs = self._tabToggles[id]
    if hs and #hs > 0 then
        self:_refreshToggleCount()
    elseif self._tabInfo[id] then
        self._countLabel.Text = self._tabInfo[id]
    else
        self._countLabel.Text = string.upper(id)
    end
end

function Dock:SetTabInfo(tabId, text)
    self._tabInfo[tabId] = text
    self:_updateFooter()
end

function Dock:ClearRows(tabId)
    local t = self._tabs[tabId]
    if not t then return end
    for _, child in ipairs(t.page:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
end

-- ---------- tab lifecycle (Dock owns it) ----------
-- Tabs that must never be removed by RemoveTab/PruneEmptyTabs.
local PROTECTED_TABS = { settings = true }

-- A tab has content when its page holds at least one real GuiObject
-- (Row, label row, custom control). Section headers alone do not count:
-- a header with nothing under it is still an empty tab.
function Dock:HasTabContent(tabId)
    local t = self._tabs[tabId]
    if not t or not t.page then return false end
    for _, child in ipairs(t.page:GetChildren()) do
        if child:IsA("GuiObject") and child:GetAttribute("N3ZSection") ~= true then
            return true
        end
    end
    return false
end

function Dock:GetTabIds()
    local out = {}
    for i, id in ipairs(self._tabIds) do out[i] = id end
    return out
end

-- Close the panel and clear every piece of active-tab state.
function Dock:_collapsePanel(oldBarPos)
    self._activeTab = nil
    for _, t in pairs(self._tabs) do
        t.page.Visible = false
        t.btn.TextColor3 = C.muted
        t.btn.Font = FONT_MED
    end
    if self._panel then self._panel.Visible = false end
    if self._indicator then self._indicator.Visible = false end
    self:_updateFooter()
    self:_syncInputBlock()
    if oldBarPos then self:_repinBar(oldBarPos, 0.8) end
end

-- Re-number LayoutOrder after a removal so ordering stays dense and stable.
function Dock:_relayoutTabs()
    if self._isMobile then
        for i, id in ipairs(self._tabIds) do
            local t = self._tabs[id]
            if t then t.btn.LayoutOrder = i - 1; t.order = i end
        end
    else
        for i, id in ipairs(self._primaryTabIds) do
            local t = self._tabs[id]
            if t then t.btn.LayoutOrder = i end
        end
        for i, id in ipairs(self._tabIds) do
            local t = self._tabs[id]
            if t then t.order = i end
        end
    end
end

local function removeValue(list, value)
    for i = #list, 1, -1 do
        if list[i] == value then table.remove(list, i) end
    end
end

-- Fully remove a tab: button, page, bookkeeping, active state, indicator,
-- scroll bounds. Returns true when something was removed.
function Dock:RemoveTab(tabId)
    if self._dead then return false end
    local t = self._tabs[tabId]
    if not t or PROTECTED_TABS[tabId] then return false end

    local wasActive = (self._activeTab == tabId)
    local oldBarPos = self._bar and self._bar.AbsolutePosition or nil

    self._prunedTabs = self._prunedTabs or {}
    self._prunedTabs[tabId] = t.btn.Text

    self._tabs[tabId] = nil
    removeValue(self._tabIds, tabId)
    removeValue(self._primaryTabIds, tabId)
    self._tabToggles[tabId] = nil
    self._tabInfo[tabId] = nil

    pcall(function() t.btn:Destroy() end)
    pcall(function() t.page:Destroy() end)

    self:_relayoutTabs()

    if wasActive then
        self:_collapsePanel(oldBarPos)
    end
    if self._clampPrimaryScroll then
        self._clampPrimaryScroll()
        -- Layout recomputes AbsoluteContentSize next frame; clamp again then.
        task.defer(function()
            if not self._dead and self._clampPrimaryScroll then self._clampPrimaryScroll() end
        end)
    end
    if not wasActive and self._pinIndicator then
        self._pinIndicator(false)
    end
    return true
end

-- Remove every tab without real content, except those in keepTabs
-- (array or set of ids). SETTINGS is always kept. Returns removed ids.
function Dock:PruneEmptyTabs(keepTabs)
    local keep = { settings = true }
    if type(keepTabs) == "table" then
        for k, v in pairs(keepTabs) do
            if type(k) == "number" and type(v) == "string" then
                keep[v] = true
            elseif type(k) == "string" and v then
                keep[k] = true
            end
        end
    end
    local removed = {}
    for _, id in ipairs(self:GetTabIds()) do
        if not keep[id] and not self:HasTabContent(id) then
            if self:RemoveTab(id) then removed[#removed + 1] = id end
        end
    end
    return removed
end

-- Resolve a tab for AddRow. A tab that was pruned as empty is recreated
-- transparently if a module adds content to it later; unknown ids still error.
function Dock:_ensureTab(tabId)
    local t = self._tabs[tabId]
    if t then return t end
    local label = self._prunedTabs and self._prunedTabs[tabId]
    assert(label, "Dock:AddRow unknown tab " .. tostring(tabId))
    self._prunedTabs[tabId] = nil
    self:AddTab(label, tabId)
    return self._tabs[tabId]
end

-- ---------- header ----------
function Dock:SetHeader(gameName, placeLine, modLine)
    self._gameLabel.Text = gameName or "…"
    self._placeLabel.Text = placeLine or ""
    self._verLabel.Text = modLine or ""
end

function Dock:SetAvatar(content)
    if self._avatar and content and content ~= "" then
        self._avatar.Image = content
    end
end

function Dock:SetMenuKeyName(name)
    if self._footKbd then self._footKbd.Text = tostring(name) end
end

-- Rebind the menu toggle key: click the chip, press any key.
function Dock:StartKeyRebind(chip)
    if self._rebinding then return end
    self._rebinding = true
    local old = chip and chip.Text or nil
    if chip then chip.Text = "…" end
    local conn
    conn = UserInputService.InputBegan:Connect(function(input, gpe)
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if input.KeyCode ~= Enum.KeyCode.Escape then
            self._menuKey = input.KeyCode
            local short = keyShort(input.KeyCode)
            if chip then chip.Text = short end
            self:SetMenuKeyName(short)
            if type(self._menuKeyChanged) == "function" then
                task.spawn(pcall, self._menuKeyChanged, input.KeyCode)
            end
        elseif chip and old then
            chip.Text = old
        end
        conn:Disconnect()
        self._rebinding = false
    end)
end

-- ---------- rows ----------
local _rowOrder = 0
function Dock:_baseRow(tabId, noHover)
    local t = self:_ensureTab(tabId)
    local L = self._layout
    _rowOrder = _rowOrder + 1
    -- The row is ONE button: clicking anywhere on it activates the control,
    -- exactly like the mockup's .frow. Nested buttons are avoided on purpose.
    local row = Instance.new("TextButton")
    row.Name = "Row"
    row.BackgroundColor3 = C.rowHover
    row.BackgroundTransparency = 1 -- transparent until hover (mockup)
    row.AutoButtonColor = false
    row.Text = ""
    row.Size = UDim2.new(1, 0, 0, 0)
    row.AutomaticSize = Enum.AutomaticSize.Y
    row.LayoutOrder = _rowOrder
    row.Parent = t.page
    corner(row, L.rowCorner)
    local rp = pad(row, L.rowPadL, L.rowPadT, L.rowPadL, L.rowPadT)
    if not noHover then
        -- hover: highlight + slight right nudge (mockup translateX via padding)
        self._conn(row.MouseEnter:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.15),
                { BackgroundColor3 = C.rowHover, BackgroundTransparency = 0 }):Play()
            TweenService:Create(rp, TweenInfo.new(0.15),
                { PaddingLeft = UDim.new(0, L.rowPadL + 3) }):Play()
        end))
        self._conn(row.MouseLeave:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.15),
                { BackgroundTransparency = 1 }):Play()
            TweenService:Create(rp, TweenInfo.new(0.15),
                { PaddingLeft = UDim.new(0, L.rowPadL) }):Play()
        end))
    end
    return row
end

function Dock:_rightZone(row)
    local z = Instance.new("Frame")
    z.Name = "Right"
    z.BackgroundTransparency = 1
    z.AnchorPoint = Vector2.new(1, 0.5)
    z.Position = UDim2.new(1, -12, 0.5, 0)
    z.AutomaticSize = Enum.AutomaticSize.XY
    z.Parent = row
    local l = Instance.new("UIListLayout")
    l.FillDirection = Enum.FillDirection.Horizontal
    l.VerticalAlignment = Enum.VerticalAlignment.Center
    l.Padding = UDim.new(0, 8)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = z
    return z
end

function Dock:_textBlock(row, name, desc)
    local L = self._layout
    local holder = Instance.new("Frame")
    holder.BackgroundTransparency = 1
    holder.Size = UDim2.new(1, -170, 0, 0)
    holder.AutomaticSize = Enum.AutomaticSize.Y
    holder.Parent = row
    local nl = label(name or "", L.nameFont, C.text, FONT_BOLD)
    nl.Size = UDim2.new(1, 0, 0, L.nameH)
    nl.Parent = holder
    if desc and desc ~= "" then
        local dl = label(desc, L.descFont, C.soft, FONT)
        dl.Size = UDim2.new(1, 0, 0, 14)
        dl.Position = UDim2.new(0, 0, 0, 18)
        dl.Parent = holder
        holder.Size = UDim2.new(1, -170, 0, 34)
    else
        holder.Size = UDim2.new(1, -170, 0, 18)
    end
    return holder
end

-- key chip (mockup .kbd): mono, bordered
local function makeKbd(parent, text)
    local chip = Instance.new("TextLabel")
    chip.Name = "KeyChip"
    chip.BackgroundTransparency = 1
    chip.Text = text
    chip.TextSize = 10
    chip.TextColor3 = C.kbdText
    chip.Font = FONT_MONO
    chip.AutomaticSize = Enum.AutomaticSize.XY
    chip.Parent = parent
    corner(chip, 5)
    stroke(chip, C.kbdBd, 0)
    pad(chip, 8, 3, 8, 3)
    return chip
end

-- toggle switch (mockup .tgl): the pill is a pure visual — the ROW
-- handles the click. ON = green track/knob with glow, springy motion.
local function makeToggle(parent, initial, onFlip, dock)
    local L = dock._layout
    local pill = Instance.new("Frame")
    pill.Name = "Toggle"
    pill.BackgroundColor3 = initial and C.accent or C.track
    pill.BackgroundTransparency = initial and 0.15 or 0.2
    pill.BorderSizePixel = 0
    pill.Size = UDim2.new(0, L.tglW, 0, L.tglH)
    pill.Parent = parent
    corner(pill, L.tglH / 2)

    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Size = UDim2.new(0, L.knob, 0, L.knob)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = initial and UDim2.new(0, L.tglOnX, 0.5, 0) or UDim2.new(0, L.tglOffX, 0.5, 0)
    knob.Parent = pill
    cornerRound(knob)

    local state = initial == true
    local handle = {}
    local function fire(v)
        if onFlip then task.spawn(pcall, onFlip, v) end
    end
    function handle:Set(v)
        v = (v == true)
        if v == state then return end
        state = v
        pill.BackgroundColor3 = state and C.accent or C.track
        pill.BackgroundTransparency = state and 0.15 or 0.2
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob:TweenPosition(
            state and UDim2.new(0, L.tglOnX, 0.5, 0) or UDim2.new(0, L.tglOffX, 0.5, 0),
            Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.3, true
        )
        fire(state)
        dock:_refreshToggleCount()
    end
    function handle:Get() return state end
    return handle
end

function Dock:AddRow(tabId, def)
    def = def or {}
    local L = self._layout
    local kind = def.kind or "toggle"

    if kind == "section" then
        local t = self:_ensureTab(tabId)
        _rowOrder = _rowOrder + 1
        local s = label(string.upper(tostring(def.text or "")), 10, C.soft, FONT_BOLD)
        s.Size = UDim2.new(1, 0, 0, 16)
        s.LayoutOrder = _rowOrder
        s:SetAttribute("N3ZSection", true)
        s.Parent = t.page
        return {}
    end

    if kind == "label" then
        local row = self:_baseRow(tabId, true)
        local l = label(tostring(def.text or ""), 11, C.soft, FONT)
        l.Size = UDim2.new(1, -24, 0, 0)
        l.AutomaticSize = Enum.AutomaticSize.Y
        l.TextWrapped = true
        l.Parent = row

        local handle = { label = l }
        function handle:Set(value)
            if type(value) == "table" then
                local title = value.Title or value.Name
                local content = value.Content or value.Text
                if title ~= nil and content ~= nil then
                    l.Text = tostring(title) .. "\n" .. tostring(content)
                elseif content ~= nil then
                    l.Text = tostring(content)
                elseif title ~= nil then
                    l.Text = tostring(title)
                end
            else
                l.Text = tostring(value or "")
            end
        end
        function handle:SetText(value) l.Text = tostring(value or "") end
        function handle:SetName(value) l.Text = tostring(value or "") end
        function handle:Get() return l.Text end
        return handle
    end

    if kind == "modulecard" then
        local row = self:_baseRow(tabId, true) -- no hover nudge on cards
        local st = stroke(row, def.active and C.accent or C.border, 0)
        if def.active then
            row.BackgroundColor3 = C.accent
            row.BackgroundTransparency = 0.94
            glow(row, C.accent, 12, 0.88, false)
        end
        local holder = Instance.new("Frame")
        holder.BackgroundTransparency = 1
        holder.Size = UDim2.new(1, -120, 0, 36)
        holder.Parent = row
        local nl = label(def.name or "", 14, C.text, FONT_BOLD)
        nl.Size = UDim2.new(1, 0, 0, 18)
        nl.Parent = holder
        local sl = label(def.sub or "", 10, C.soft, FONT_MONO)
        sl.Size = UDim2.new(1, 0, 0, 14)
        sl.Position = UDim2.new(0, 0, 0, 20)
        sl.Parent = holder
        local z = self:_rightZone(row)
        local pill = Instance.new("TextLabel")
        pill.Name = "StatePill"
        pill.Text = def.active and "ACTIVE" or "IDLE"
        pill.TextSize = 10
        pill.Font = FONT_BOLD
        pill.TextColor3 = def.active and C.dark or C.muted
        pill.BackgroundColor3 = def.active and C.accent or C.track
        pill.BackgroundTransparency = def.active and 0 or 0
        pill.AutomaticSize = Enum.AutomaticSize.XY
        pill.Parent = z
        corner(pill, 8)
        pad(pill, 10, 5, 10, 5)
        if def.onPress then
            local lastFire = 0
            local actionClick = self._isMobile and row.Activated or row.MouseButton1Click
            self._conn(actionClick:Connect(function()
                local now = os.clock()
                if now - lastFire < 0.25 then return end
                lastFire = now
                task.spawn(pcall, def.onPress)
            end))
        end
        return {}
    end

    -- interactive rows: text block left, control right
    local row = self:_baseRow(tabId)
    self:_textBlock(row, def.name, def.desc)
    local z = self:_rightZone(row)

    if kind == "toggle" then
        if def.key then makeKbd(z, tostring(def.key)) end
        local h = makeToggle(z, def.value == true, def.onChange, self)
        -- clicking anywhere on the row flips the switch (mockup .frow)
        local toggleClick = self._isMobile and row.Activated or row.MouseButton1Click
        self._conn(toggleClick:Connect(function()
            h:Set(not h:Get())
        end))
        -- hover: knob grows slightly (mockup .tgl:hover::after)
        local knob = z:FindFirstChild("Toggle", true) and z:FindFirstChild("Toggle", true):FindFirstChild("Knob")
        if knob then
            self._conn(row.MouseEnter:Connect(function()
                TweenService:Create(knob, TweenInfo.new(0.12), { Size = UDim2.new(0, L.knob + 2, 0, L.knob + 2) }):Play()
            end))
            self._conn(row.MouseLeave:Connect(function()
                TweenService:Create(knob, TweenInfo.new(0.12), { Size = UDim2.new(0, L.knob, 0, L.knob) }):Play()
            end))
        end
        if not self._tabToggles[tabId] then self._tabToggles[tabId] = {} end
        table.insert(self._tabToggles[tabId], h)
        return h
    end

    if kind == "action" then
        local chipRef = nil
        if def.chip then chipRef = makeKbd(z, tostring(def.chip)) end
        local lastFire = 0
        local function firePress()
            -- guard: the inner button and the row can both observe the same
            -- physical click (no nested-button double-fire)
            local now = os.clock()
            if now - lastFire < 0.25 then return end
            lastFire = now
            if def.rebindKey then
                self:StartKeyRebind(chipRef)
                return
            end
            if def.clipboard then
                pcall(setclipboard, tostring(def.clipboard))
                if chipRef then
                    local oldText = chipRef.Text
                    chipRef.Text = "COPIED"
                    task.delay(1, function()
                        if not self._dead and chipRef.Parent then
                            chipRef.Text = oldText
                        end
                    end)
                end
            end
            if def.onPress then task.spawn(pcall, def.onPress) end
        end
        local rowClick = self._isMobile and row.Activated or row.MouseButton1Click
        self._conn(rowClick:Connect(firePress))
        if def.buttonText then
            local b = Instance.new("TextButton")
            b.Name = "ActionButton"
            b.Text = tostring(def.buttonText)
            b.TextSize = 11
            b.Font = FONT_BOLD
            b.TextColor3 = def.danger and C.danger or C.text
            b.BackgroundColor3 = C.track
            b.BackgroundTransparency = 0.2
            b.AutoButtonColor = false
            b.AutomaticSize = Enum.AutomaticSize.XY
            b.Parent = z
            corner(b, 8)
            pad(b, 12, 6, 12, 6)
            if def.danger then stroke(b, C.danger, 0.5).ApplyStrokeMode = Enum.ApplyStrokeMode.Border end
            local buttonClick = self._isMobile and b.Activated or b.MouseButton1Click
            self._conn(buttonClick:Connect(firePress))
        end
        return {}
    end

    if kind == "button" then
        local b = Instance.new("TextButton")
        b.Text = tostring(def.name or "Button")
        b.TextSize = 11
        b.Font = FONT_MED
        b.TextColor3 = C.text
        b.BackgroundColor3 = C.track
        b.BackgroundTransparency = 0.2
        b.AutoButtonColor = false
        b.AutomaticSize = Enum.AutomaticSize.XY
        b.Parent = z
        corner(b, 8)
        pad(b, 12, 6, 12, 6)
        local handle = {}
        function handle:SetName(n) b.Text = tostring(n) end
        if def.onPress then
            local buttonClick = self._isMobile and b.Activated or b.MouseButton1Click
            self._conn(buttonClick:Connect(function()
                task.spawn(pcall, def.onPress)
            end))
        end
        return handle
    end

    if kind == "input" then
        local box = Instance.new("TextBox")
        box.Name = "Input"
        box.BackgroundColor3 = C.track
        box.BackgroundTransparency = 0.2
        box.BorderSizePixel = 0
        box.ClearTextOnFocus = false
        box.Text = tostring(def.value or "")
        box.PlaceholderText = tostring(def.placeholder or "")
        box.PlaceholderColor3 = C.muted
        box.TextColor3 = C.text
        box.TextSize = 11
        box.Font = FONT_MONO
        box.TextXAlignment = Enum.TextXAlignment.Left
        box.Size = UDim2.new(0, math.max(L.ddW, 150), 0, L.ddH)
        box.Parent = z
        corner(box, 8)
        stroke(box, C.border, 0.4)
        pad(box, 9, 5, 9, 5)

        local handle = { box = box }
        function handle:Set(value)
            box.Text = tostring(value or "")
        end
        function handle:Get()
            return box.Text
        end
        function handle:Focus()
            pcall(function() box:CaptureFocus() end)
        end

        self._conn(box.FocusLost:Connect(function(_enterPressed)
            local value = box.Text
            if def.onChange then
                task.spawn(pcall, def.onChange, value)
            end
            if def.clearAfter then
                box.Text = ""
            end
        end))
        return handle
    end

    if kind == "slider" then
        local minV, maxV = def.min or 0, def.max or 100
        local step = def.step or 1
        local suffix = def.suffix or ""
        local value = math.clamp(def.value or minV, minV, maxV)

        local wrap = Instance.new("Frame")
        wrap.BackgroundTransparency = 1
        wrap.Size = UDim2.new(0, L.sliderW, 0, L.sliderH)
        wrap.Parent = z

        local valLabel = label("", 11, C.accent, FONT_MONO)
        valLabel.AnchorPoint = Vector2.new(1, 0)
        valLabel.Position = UDim2.new(1, 0, 0, 0)
        valLabel.Size = UDim2.new(1, 0, 0, 14)
        valLabel.TextXAlignment = Enum.TextXAlignment.Right
        valLabel.Parent = wrap

        local track = Instance.new("TextButton")
        track.BackgroundColor3 = C.track
        track.BorderSizePixel = 0
        track.Text = ""
        track.AutoButtonColor = false
        track.AnchorPoint = Vector2.new(0, 1)
        track.Position = UDim2.new(0, 0, 1, 0)
        track.Size = UDim2.new(1, 0, 0, 6)
        track.Parent = wrap
        corner(track, 3)

        local fill = Instance.new("Frame")
        fill.BackgroundColor3 = C.accent
        fill.BorderSizePixel = 0
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.Parent = track
        corner(fill, 3)

        local knob = Instance.new("Frame")
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.BorderSizePixel = 0
        knob.Size = UDim2.new(0, L.sliderKnob, 0, L.sliderKnob)
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.Parent = track
        cornerRound(knob)

        local handle = {}
        local function render()
            local r = (value - minV) / math.max(1e-6, (maxV - minV))
            fill.Size = UDim2.new(r, 0, 1, 0)
            knob.Position = UDim2.new(r, 0, 0.5, 0)
            local disp = value
            if step >= 1 then disp = math.floor(value + 0.5) end
            valLabel.Text = tostring(disp) .. suffix
        end
        function handle:Set(v)
            v = math.clamp(v or minV, minV, maxV)
            if step > 0 then v = minV + math.floor((v - minV) / step + 0.5) * step end
            v = math.clamp(v, minV, maxV)
            value = v
            render()
        end
        function handle:Get() return value end

        local dragging = false
        local dragInput = nil
        local function fromX(x)
            local p0 = track.AbsolutePosition.X
            local w = math.max(1, track.AbsoluteSize.X)
            handle:Set(minV + math.clamp((x - p0) / w, 0, 1) * (maxV - minV))
            if def.onChange then task.spawn(pcall, def.onChange, value) end
        end
        self._conn(track.InputBegan:Connect(function(input)
            if self._isMobile then
                local inputType = input.UserInputType
                if inputType == Enum.UserInputType.MouseButton1
                    or inputType == Enum.UserInputType.Touch then
                    dragging = true
                    dragInput = (inputType == Enum.UserInputType.Touch) and input or nil
                    fromX(input.Position.X)
                end
                return
            end

            -- Desktop path intentionally matches the pre-mobile implementation.
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                fromX(input.Position.X)
            end
        end))
        self._conn(UserInputService.InputChanged:Connect(function(input)
            if not dragging then return end
            if self._isMobile then
                if dragInput then
                    if input ~= dragInput then return end
                elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then
                    return
                end
                fromX(input.Position.X)
                return
            end

            -- Desktop path intentionally matches the pre-mobile implementation.
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                fromX(input.Position.X)
            end
        end))
        self._conn(UserInputService.InputEnded:Connect(function(input)
            if self._isMobile then
                if not dragging then return end
                if dragInput then
                    if input ~= dragInput then return end
                elseif input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                    return
                end
                dragging = false
                dragInput = nil
                return
            end

            -- Desktop path intentionally matches the pre-mobile implementation.
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end))
        render()
        return handle
    end

    if kind == "dropdown" then
        local options = def.options or {}
        local multiple = def.multiple == true
        local value = def.value

        local function copyArray(input)
            local out = {}
            if type(input) == "table" then
                for _, item in ipairs(input) do
                    out[#out + 1] = item
                end
            elseif input ~= nil then
                out[1] = input
            end
            return out
        end

        if multiple then
            value = copyArray(value)
        elseif type(value) == "table" then
            value = value[1]
        end
        if not multiple and value == nil then value = options[1] end

        local btn = Instance.new("TextButton")
        btn.BackgroundColor3 = C.track
        btn.BackgroundTransparency = 0.2
        btn.BorderSizePixel = 0
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.Size = UDim2.new(0, L.ddW, 0, L.ddH)
        btn.Parent = z
        corner(btn, 8)
        stroke(btn, C.border, 0.4)

        local btnLabel = label("", 11, C.text, FONT_MED)
        btnLabel.Position = UDim2.new(0, 10, 0, 0)
        btnLabel.Size = UDim2.new(1, -30, 1, 0)
        btnLabel.Parent = btn

        local arrow = label("v", 12, C.muted, FONT)
        arrow.AnchorPoint = Vector2.new(1, 0.5)
        arrow.Position = UDim2.new(1, -8, 0.5, 0)
        arrow.Size = UDim2.new(0, 16, 0, 16)
        arrow.TextXAlignment = Enum.TextXAlignment.Right
        arrow.Parent = btn

        -- Options expand inside the row so both mouse and touch retain the
        -- existing Dock interaction model.
        local opts = Instance.new("Frame")
        opts.BackgroundTransparency = 1
        opts.Size = UDim2.new(1, 0, 0, 0)
        opts.AutomaticSize = Enum.AutomaticSize.Y
        opts.Visible = false
        opts.Parent = row

        local optsLayout = Instance.new("UIListLayout")
        optsLayout.FillDirection = Enum.FillDirection.Vertical
        optsLayout.Padding = UDim.new(0, 4)
        optsLayout.SortOrder = Enum.SortOrder.LayoutOrder
        optsLayout.Parent = opts

        local optsPad = Instance.new("UIPadding")
        optsPad.PaddingTop = UDim.new(0, 8)
        optsPad.Parent = opts

        local function selectedSet()
            local set = {}
            if multiple then
                for _, item in ipairs(value) do set[item] = true end
            elseif value ~= nil then
                set[value] = true
            end
            return set
        end

        local function updateButtonText()
            if multiple then
                local count = #value
                if count == 0 then
                    btnLabel.Text = "None"
                elseif count == 1 then
                    btnLabel.Text = tostring(value[1])
                else
                    btnLabel.Text = tostring(count) .. " selected"
                end
            else
                btnLabel.Text = tostring(value or "")
            end
        end

        local handle = {}
        local rebuild

        rebuild = function()
            for _, c in ipairs(opts:GetChildren()) do
                if c:IsA("GuiObject") then c:Destroy() end
            end

            local selected = selectedSet()
            for _, opt in ipairs(options) do
                local isSelected = selected[opt] == true
                local ob = Instance.new("TextButton")
                ob.BackgroundColor3 = isSelected and C.track or C.panelBg
                ob.BackgroundTransparency = 0.1
                ob.BorderSizePixel = 0
                ob.AutoButtonColor = false
                ob.Text = ""
                ob.Size = UDim2.new(1, 0, 0, L.ddOptH)
                ob.Parent = opts
                corner(ob, 7)

                local ol = label(
                    tostring(opt),
                    11,
                    isSelected and C.accent or C.text,
                    FONT
                )
                ol.Position = UDim2.new(0, 10, 0, 0)
                ol.Size = UDim2.new(1, -20, 1, 0)
                ol.Parent = ob

                local optionClick = self._isMobile and ob.Activated or ob.MouseButton1Click
                self._conn(optionClick:Connect(function()
                    if multiple then
                        local nextValue = {}
                        local removed = false
                        for _, current in ipairs(value) do
                            if current == opt then
                                removed = true
                            else
                                nextValue[#nextValue + 1] = current
                            end
                        end
                        if not removed then nextValue[#nextValue + 1] = opt end
                        value = nextValue
                    else
                        value = opt
                        opts.Visible = false
                    end

                    updateButtonText()
                    rebuild()
                    if def.onChange then
                        local emitted = multiple and copyArray(value) or value
                        task.spawn(pcall, def.onChange, emitted)
                    end
                end))
            end
        end

        function handle:Set(v)
            if multiple then
                value = copyArray(v)
            else
                value = type(v) == "table" and v[1] or v
            end
            updateButtonText()
            rebuild()
        end

        function handle:Get()
            return multiple and copyArray(value) or value
        end

        function handle:Refresh(newOptions, _keepSelection)
            options = newOptions or {}
            if multiple then
                local allowed = {}
                for _, opt in ipairs(options) do allowed[opt] = true end
                local nextValue = {}
                for _, current in ipairs(value) do
                    if allowed[current] then nextValue[#nextValue + 1] = current end
                end
                value = nextValue
            elseif value == nil then
                value = options[1]
            end
            updateButtonText()
            rebuild()
        end

        local dropdownClick = self._isMobile and btn.Activated or btn.MouseButton1Click
        self._conn(dropdownClick:Connect(function()
            opts.Visible = not opts.Visible
        end))

        updateButtonText()
        rebuild()
        return handle
    end

    return {}
end

-- ---------- visibility / lifecycle ----------
function Dock:IsPanelOpen()
    return not self._dead
        and self._visible == true
        and self._activeTab ~= nil
        and self._panel ~= nil
        and self._panel.Visible == true
end

function Dock:SetMenuKey(keyCode)
    if typeof(keyCode) == "EnumItem" and keyCode.EnumType == Enum.KeyCode then
        self._menuKey = keyCode
        self:SetMenuKeyName(keyShort(keyCode))
        return true
    end
    return false
end

function Dock:SetMenuKeyChangedCallback(fn)
    self._menuKeyChanged = type(fn) == "function" and fn or nil
end

function Dock:SetMobileTogglePosition(x, y)
    if not self._mobileToggle then return false end
    x = math.clamp(tonumber(x) or 0.92, 0.06, 0.94)
    y = math.clamp(tonumber(y) or 0.12, 0.08, 0.92)
    self._mobileToggleX = x
    self._mobileToggleY = y
    self._mobileToggle.Position = UDim2.fromScale(x, y)
    return true
end

function Dock:GetMobileTogglePosition()
    return self._mobileToggleX or 0.92, self._mobileToggleY or 0.12
end

function Dock:SetMobileToggleChangedCallback(fn)
    self._mobileToggleChanged = type(fn) == "function" and fn or nil
end
function Dock:IsInputBlockEnabled()
    return self._inputBlockEnabled == true
end

function Dock:SetInputBlockEnabled(v)
    self._inputBlockEnabled = (v ~= false)
    self:_syncInputBlock()
end

function Dock:_syncInputBlock()
    local shouldBlock = self:IsInputBlockEnabled() and self:IsPanelOpen()

    if self._inputShield then
        pcall(function()
            self._inputShield.Visible = shouldBlock
            self._inputShield.Active = shouldBlock
        end)
    end

    if shouldBlock == self._inputBlockBound then return end
    self._inputBlockBound = shouldBlock

    pcall(function()
        ContextActionService:UnbindAction(self._inputActionName)
    end)

    if shouldBlock then
        pcall(function()
            ContextActionService:BindActionAtPriority(
                self._inputActionName,
                function()
                    return Enum.ContextActionResult.Sink
                end,
                false,
                10000,
                Enum.UserInputType.MouseButton1,
                Enum.UserInputType.MouseButton2,
                Enum.UserInputType.MouseButton3,
                Enum.UserInputType.MouseWheel,
                Enum.UserInputType.Touch
            )
        end)
    end
end

function Dock:SetVisible(v)
    self._visible = (v ~= false)
    self._stage.Visible = self._visible
    self:_syncInputBlock()
end

function Dock:Toggle()
    self:SetVisible(not self._visible)
end

function Dock:OnUnload(fn)
    table.insert(self._unloadFns, fn)
end

function Dock:Destroy()
    if self._dead then return end
    self._dead = true
    self._visible = false
    self._activeTab = nil

    if self._inputBlockBound then
        self._inputBlockBound = false
        pcall(function() ContextActionService:UnbindAction(self._inputActionName) end)
    end
    pcall(function()
        if self._inputShield then
            self._inputShield.Visible = false
            self._inputShield.Active = false
        end
    end)

    -- Hide immediately. This makes unload deterministic even when Destroy()
    -- is called from the button's own click callback.
    pcall(function()
        if self._stage then self._stage.Visible = false end
        if self._gui then self._gui.Enabled = false end
    end)

    local unloadFns = self._unloadFns
    self._unloadFns = {}
    for _, fn in ipairs(unloadFns) do
        pcall(fn)
    end

    local conns = self._conns
    self._conns = {}
    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end

    local gui = self._gui
    self._gui = nil
    self._stage = nil
    self._bar = nil
    self._panel = nil
    self._inputShield = nil
    if gui then pcall(function() gui:Destroy() end) end
end

local function guiRoots()
    local roots, seen = {}, {}
    local function add(root)
        if typeof(root) == "Instance" and not seen[root] then
            seen[root] = true
            roots[#roots + 1] = root
        end
    end
    pcall(function()
        if type(gethui) == "function" then add(gethui()) end
    end)
    pcall(function() add(game:GetService("CoreGui")) end)
    pcall(function() add(localPlayer:FindFirstChildOfClass("PlayerGui")) end)
    return roots
end

-- Sweep orphan N3zDock GUIs from every parent the executor may have used.
function Dock.destroyAllGuis()
    local n = 0
    for _, parent in ipairs(guiRoots()) do
        for _, c in ipairs(parent:GetChildren()) do
            if c.Name == "N3zDock" and c:IsA("ScreenGui") then
                local ok = pcall(function()
                    c.Enabled = false
                    c:Destroy()
                end)
                if ok then n = n + 1 end
            end
        end
    end
    return n
end

return Dock
