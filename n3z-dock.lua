-- ============================================================
-- N3Z HUB · dock.lua
-- Native-GUI bottom dock for N3z Hub. No Drawing API.
-- Returns the Dock class. n3z.lua loads this via loadstring.
-- ============================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer

-- ---------- theme ----------
local C = {
    panelBg  = Color3.fromRGB(11, 14, 20),
    dockBg   = Color3.fromRGB(18, 21, 29),
    rowBg    = Color3.fromRGB(17, 20, 28),
    rowHover = Color3.fromRGB(23, 27, 38),
    text     = Color3.fromRGB(232, 236, 244),
    dark     = Color3.fromRGB(4, 18, 26),
    muted    = Color3.fromRGB(139, 147, 167),
    accent   = Color3.fromRGB(34, 211, 238),
    accent2  = Color3.fromRGB(167, 139, 250),
    danger   = Color3.fromRGB(248, 113, 113),
    good     = Color3.fromRGB(52, 211, 153),
    track    = Color3.fromRGB(38, 43, 56),
}
local FONT      = Enum.Font.Gotham
local FONT_MED  = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold

local function corner(inst, r)
    local u = Instance.new("UICorner")
    u.CornerRadius = UDim.new(0, r)
    u.Parent = inst
    return u
end

local function stroke(inst, transp)
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(255, 255, 255)
    s.Transparency = transp or 0.93
    s.Thickness = 1
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
    if ok and typeof(hui) == "Instance" and hui.Name ~= "RobloxGui" and not hui:IsA("ScreenGui") then
        return hui
    end
    local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and cg then return cg end
    return localPlayer:WaitForChild("PlayerGui")
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
    self._activeTab = "combat"
    self._menuKey = opts.menuKey or Enum.KeyCode.RightShift
    self._visible = true

    local function conn(c) table.insert(self._conns, c) return c end
    self._conn = conn

    -- root
    local gui = Instance.new("ScreenGui")
    gui.Name = "N3zDock"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999
    gui.Parent = getGuiParent()
    self._gui = gui

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

    -- panel
    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.BackgroundColor3 = C.panelBg
    panel.BackgroundTransparency = 0.06
    panel.Size = UDim2.new(0, 470, 0, 0)
    panel.AutomaticSize = Enum.AutomaticSize.Y
    panel.LayoutOrder = 1
    panel.Parent = stage
    corner(panel, 14)
    stroke(panel, 0.9)
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
    dot.Size = UDim2.new(0, 8, 0, 8)
    dot.Position = UDim2.new(0, 2, 0.5, -4)
    dot.BackgroundColor3 = C.good
    dot.Parent = header
    corner(dot, 4)

    local gameLabel = label("…", 13, C.text, FONT_MED)
    gameLabel.Position = UDim2.new(0, 18, 0, 2)
    gameLabel.Size = UDim2.new(1, -150, 0, 18)
    gameLabel.Parent = header
    self._gameLabel = gameLabel

    local placeLabel = label("…", 10, C.muted, FONT)
    placeLabel.Position = UDim2.new(0, 18, 0, 21)
    placeLabel.Size = UDim2.new(1, -150, 0, 14)
    placeLabel.Parent = header
    self._placeLabel = placeLabel

    local verLabel = label("…", 10, C.accent, FONT_MED)
    verLabel.AnchorPoint = Vector2.new(1, 0)
    verLabel.Position = UDim2.new(1, 0, 0, 12)
    verLabel.Size = UDim2.new(0, 130, 0, 16)
    verLabel.TextXAlignment = Enum.TextXAlignment.Right
    verLabel.Parent = header
    self._verLabel = verLabel

    -- content (scrolling, fixed height)
    local content = Instance.new("ScrollingFrame")
    content.Name = "Content"
    content.LayoutOrder = 2
    content.BackgroundTransparency = 1
    content.Size = UDim2.new(1, 0, 0, 330)
    content.ScrollBarThickness = 3
    content.ScrollBarImageColor3 = C.track
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

    -- footer
    local footer = Instance.new("Frame")
    footer.Name = "Footer"
    footer.LayoutOrder = 3
    footer.BackgroundTransparency = 1
    footer.Size = UDim2.new(1, 0, 0, 18)
    footer.Parent = panel
    local footLabel = label("RShift — toggle dock", 10, C.muted, FONT)
    footLabel.AnchorPoint = Vector2.new(1, 0.5)
    footLabel.Position = UDim2.new(1, 0, 0.5, 0)
    footLabel.Size = UDim2.new(1, 0, 0, 16)
    footLabel.TextXAlignment = Enum.TextXAlignment.Right
    footLabel.Parent = footer
    self._footLabel = footLabel

    -- dock bar
    local bar = Instance.new("Frame")
    bar.Name = "DockBar"
    bar.BackgroundColor3 = C.dockBg
    bar.BackgroundTransparency = 0.06
    bar.AutomaticSize = Enum.AutomaticSize.X
    bar.Size = UDim2.new(0, 0, 0, 52)
    bar.LayoutOrder = 2
    bar.Parent = stage
    corner(bar, 16)
    stroke(bar, 0.9)
    local barPad = Instance.new("UIPadding")
    barPad.PaddingLeft = UDim.new(0, 8)
    barPad.PaddingRight = UDim.new(0, 8)
    barPad.PaddingTop = UDim.new(0, 8)
    barPad.PaddingBottom = UDim.new(0, 8)
    barPad.Parent = bar
    self._bar = bar

    -- tabs row: the only layout-managed child of the bar.
    -- SortOrder=LayoutOrder keeps logo -> tabs -> avatar in fixed order.
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

    -- sliding indicator: sibling of TabsRow, NOT in any layout, so the
    -- layout engine never fights the tween. Absolutely positioned in bar space.
    local ind = Instance.new("Frame")
    ind.Name = "Indicator"
    ind.BackgroundColor3 = C.accent
    ind.BackgroundTransparency = 0
    ind.AnchorPoint = Vector2.new(0, 0.5)
    ind.Position = UDim2.new(0, 8, 0.5, 0)
    ind.Size = UDim2.new(0, 60, 0, 36)
    ind.ZIndex = 0
    ind.Visible = false
    ind.Parent = bar
    corner(ind, 10)
    self._indicator = ind

    -- pin the indicator under the active tab. Waits for real layout sizes
    -- (buttons use AutomaticSize.X) before measuring; instant on boot,
    -- spring-tweened on tab switches, re-pinned when the bar resizes.
    local function pinIndicator(animate)
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
            -- NOTE: UIPadding offsets ALL children, even manually positioned
            -- ones, so measure the button relative to the bar's padding box.
            local padL = 0
            local padInst = barInst:FindFirstChildOfClass("UIPadding")
            if padInst then padL = padInst.PaddingLeft.Offset end
            local bp = btn.AbsolutePosition - barInst.AbsolutePosition
            local size = UDim2.new(0, btn.AbsoluteSize.X, 0, 36)
            local pos = UDim2.new(0, bp.X - padL, 0.5, 0)
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

    -- N3Z logo at the start of the bar
    local logo = Instance.new("TextLabel")
    logo.Name = "Logo"
    logo.BackgroundTransparency = 1
    logo.RichText = true
    logo.Text = '<font color="#E8ECF4"><b>N3Z</b></font><font color="#22D3EE"><b>·</b></font>'
    logo.TextSize = 14
    logo.Font = FONT_BOLD
    logo.AutomaticSize = Enum.AutomaticSize.X
    logo.Size = UDim2.new(0, 0, 0, 36)
    logo.LayoutOrder = -1
    logo.Parent = tabsRow

    -- fixed tabs
    for _, id in ipairs(TAB_ORDER) do
        self:AddTab(TAB_LABEL[id], id)
    end

    -- avatar at the end of the bar
    local av = Instance.new("ImageLabel")
    av.Name = "Avatar"
    av.BackgroundColor3 = C.track
    av.Size = UDim2.new(0, 34, 0, 34)
    av.Image = ""
    av.LayoutOrder = 1000
    av.Parent = tabsRow
    corner(av, 17)
    stroke(av, 0.75)
    self._avatar = av

    self:SetActiveTab("combat")

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
    tabId = tabId or string.lower(tostring(tabLabel))
    if self._tabs[tabId] then return tabId end

    local btn = Instance.new("TextButton")
    btn.Name = "Tab_" .. tabId
    btn.BackgroundTransparency = 1
    btn.AutoButtonColor = false
    btn.Text = string.upper(tostring(tabLabel))
    btn.TextSize = 12
    btn.TextColor3 = C.muted
    btn.Font = FONT_BOLD
    btn.AutomaticSize = Enum.AutomaticSize.X
    btn.Size = UDim2.new(0, 0, 0, 36)
    btn.ZIndex = 1
    btn.LayoutOrder = #self._tabIds
    btn.Parent = self._tabsRow
    local btnPad = Instance.new("UIPadding")
    btnPad.PaddingLeft = UDim.new(0, 12)
    btnPad.PaddingRight = UDim.new(0, 12)
    btnPad.Parent = btn

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
    self._conn(btn.MouseButton1Click:Connect(function()
        self:SetActiveTab(id)
    end))

    table.insert(self._tabIds, tabId)
    self._tabs[tabId] = { btn = btn, page = page, order = #self._tabIds }
    return tabId
end

function Dock:SetActiveTab(tabId)
    if not self._tabs[tabId] then return end
    self._activeTab = tabId
    for id, t in pairs(self._tabs) do
        local active = (id == tabId)
        t.page.Visible = active
        t.btn.TextColor3 = active and C.dark or C.muted
    end
    -- slide the indicator under the active button (robust pin: waits for layout)
    if self._pinIndicator then self._pinIndicator(true) end
end

function Dock:ClearRows(tabId)
    local t = self._tabs[tabId]
    if not t then return end
    for _, child in ipairs(t.page:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
end

-- ---------- header ----------
function Dock:SetHeader(gameName, placeLine, modLine)
    self._gameLabel.Text = gameName or "…"
    self._placeLabel.Text = placeLine or ""
    self._verLabel.Text = modLine or ""
end

function Dock:SetAvatar(content)
    if content and content ~= "" then
        self._avatar.Image = content
    end
end

function Dock:SetMenuKey(key, name)
    if typeof(key) == "EnumItem" then
        self._menuKey = key
    elseif type(key) == "string" then
        local found = Enum.KeyCode[key]
        if found then self._menuKey = found end
    end
    self:SetMenuKeyName(name or (self._menuKey and self._menuKey.Name) or tostring(key))
end

function Dock:SetMenuKeyName(name)
    self._footLabel.Text = tostring(name) .. " — toggle dock"
end

function Dock:SetTabInfo(tabId, info)
    local t = self._tabs[tabId]
    if t then
        t.info = info
    end
end

-- ---------- rows ----------
local _rowOrder = 0
function Dock:_baseRow(tabId, height)
    local t = self._tabs[tabId]
    assert(t, "Dock:AddRow unknown tab " .. tostring(tabId))
    _rowOrder += 1
    local row = Instance.new("TextButton")
    row.Name = "Row"
    row.BackgroundColor3 = C.rowBg
    row.BackgroundTransparency = 0.25
    row.AutoButtonColor = false
    row.Text = ""
    row.Size = UDim2.new(1, 0, 0, 0)
    row.AutomaticSize = Enum.AutomaticSize.Y
    row.LayoutOrder = _rowOrder
    row.Parent = t.page
    corner(row, 10)
    pad(row, 12, 9, 12, 9)
    -- hover
    self._conn(row.MouseEnter:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.15), { BackgroundColor3 = C.rowHover }):Play()
    end))
    self._conn(row.MouseLeave:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.15), { BackgroundColor3 = C.rowBg }):Play()
    end))
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
    l.Parent = z
    return z
end

function Dock:_textBlock(row, name, desc)
    local holder = Instance.new("Frame")
    holder.BackgroundTransparency = 1
    holder.Size = UDim2.new(1, -170, 0, 0)
    holder.AutomaticSize = Enum.AutomaticSize.Y
    holder.Parent = row
    local nl = label(name or "", 13, C.text, FONT_MED)
    nl.Size = UDim2.new(1, 0, 0, 17)
    nl.Parent = holder
    if desc and desc ~= "" then
        local dl = label(desc, 11, C.muted, FONT)
        dl.Size = UDim2.new(1, 0, 0, 14)
        dl.Position = UDim2.new(0, 0, 0, 18)
        dl.Parent = holder
        holder.Size = UDim2.new(1, -170, 0, 34)
    else
        holder.Size = UDim2.new(1, -170, 0, 18)
    end
    return nl, dl, holder
end

local function makeChip(parent, text, accentColor)
    local chip = Instance.new("TextLabel")
    chip.BackgroundColor3 = C.track
    chip.BackgroundTransparency = 0.2
    chip.Text = text
    chip.TextSize = 10
    chip.TextColor3 = accentColor or C.muted
    chip.Font = FONT_BOLD
    chip.AutomaticSize = Enum.AutomaticSize.XY
    chip.Parent = parent
    corner(chip, 6)
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, 8)
    p.PaddingRight = UDim.new(0, 8)
    p.PaddingTop = UDim.new(0, 4)
    p.PaddingBottom = UDim.new(0, 4)
    p.Parent = chip
    return chip
end

local function makeToggle(parent, initial, onFlip, dock)
    local pill = Instance.new("TextButton")
    pill.BackgroundColor3 = initial and C.accent or C.track
    pill.BackgroundTransparency = initial and 0.15 or 0.2
    pill.Text = ""
    pill.AutoButtonColor = false
    pill.Size = UDim2.new(0, 40, 0, 22)
    pill.Parent = parent
    corner(pill, 11)
    local knob = Instance.new("Frame")
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.Position = initial and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
    knob.Parent = pill
    corner(knob, 8)

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
        knob:TweenPosition(
            state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
            Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.22, true
        )
        fire(state)
    end
    function handle:Get() return state end
    dock._conn(pill.MouseButton1Click:Connect(function()
        handle:Set(not state)
    end))
    return handle
end

function Dock:AddRow(tabId, def)
    def = def or {}
    local kind = def.kind or "toggle"

    if kind == "section" then
        local t = self._tabs[tabId]
        _rowOrder += 1
        local s = label(string.upper(tostring(def.text or "")), 10, C.muted, FONT_BOLD)
        s.Size = UDim2.new(1, 0, 0, 16)
        s.LayoutOrder = _rowOrder
        s.Parent = t.page
        return {}
    end

    if kind == "label" then
        local row = self:_baseRow(tabId)
        local l = label(tostring(def.text or ""), 11, C.muted, FONT)
        l.Size = UDim2.new(1, -24, 0, 0)
        l.AutomaticSize = Enum.AutomaticSize.Y
        l.TextWrapped = true
        l.Parent = row
        return {}
    end

    if kind == "modulecard" then
        local row = self:_baseRow(tabId)
        if def.active then
            stroke(row, 0.55).Color = C.accent
        end
        local holder = Instance.new("Frame")
        holder.BackgroundTransparency = 1
        holder.Size = UDim2.new(1, -120, 0, 34)
        holder.Parent = row
        local nl = label(def.name or "", 13, C.text, FONT_MED)
        nl.Size = UDim2.new(1, 0, 0, 17)
        nl.Parent = holder
        local sl = label(def.sub or "", 11, C.muted, FONT)
        sl.Size = UDim2.new(1, 0, 0, 14)
        sl.Position = UDim2.new(0, 0, 0, 18)
        sl.Parent = holder
        local z = self:_rightZone(row)
        local pill = Instance.new("TextLabel")
        pill.Text = def.active and "ACTIVE" or "IDLE"
        pill.TextSize = 10
        pill.Font = FONT_BOLD
        pill.TextColor3 = def.active and Color3.fromRGB(4, 18, 26) or C.muted
        pill.BackgroundColor3 = def.active and C.accent or C.track
        pill.BackgroundTransparency = def.active and 0 or 0.2
        pill.AutomaticSize = Enum.AutomaticSize.XY
        pill.Parent = z
        corner(pill, 8)
        pad(pill, 10, 5, 10, 5)
        if def.onPress then
            self._conn(row.MouseButton1Click:Connect(function()
                task.spawn(pcall, def.onPress)
            end))
        end
        return {}
    end

    -- interactive rows: text block left, control right
    local row = self:_baseRow(tabId)
    local nameLabel, descLabel, textHolder = self:_textBlock(row, def.name, def.desc)
    local z = self:_rightZone(row)

    if kind == "toggle" then
        if def.key then makeChip(z, tostring(def.key)) end
        local h = makeToggle(z, def.value == true, def.onChange, self)
        return h
    end

    if kind == "action" then
        if def.chip then
            local chipBtn = Instance.new("TextButton")
            chipBtn.BackgroundColor3 = C.track
            chipBtn.BackgroundTransparency = 0.2
            chipBtn.Text = tostring(def.chip)
            chipBtn.TextSize = 10
            chipBtn.TextColor3 = C.accent
            chipBtn.Font = FONT_BOLD
            chipBtn.AutomaticSize = Enum.AutomaticSize.XY
            chipBtn.AutoButtonColor = false
            chipBtn.Parent = z
            corner(chipBtn, 6)
            local p = Instance.new("UIPadding")
            p.PaddingLeft = UDim.new(0, 8)
            p.PaddingRight = UDim.new(0, 8)
            p.PaddingTop = UDim.new(0, 4)
            p.PaddingBottom = UDim.new(0, 4)
            p.Parent = chipBtn

            local handle = { button = chipBtn }
            function handle:SetText(t) chipBtn.Text = tostring(t) end

            if def.rebindKey then
                local capturing = false
                local connInput
                local function startCapture()
                    if capturing then return end
                    capturing = true
                    chipBtn.Text = "[...]"
                    chipBtn.TextColor3 = C.accent2
                    if connInput then connInput:Disconnect() end
                    local armedAt = os.clock()
                    connInput = UserInputService.InputBegan:Connect(function(input, gpe)
                        if os.clock() - armedAt < 0.12 then return end
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                            if input.KeyCode == Enum.KeyCode.Escape then
                                capturing = false
                                chipBtn.Text = self._menuKey and self._menuKey.Name or tostring(def.chip)
                                chipBtn.TextColor3 = C.accent
                                if connInput then connInput:Disconnect() connInput = nil end
                                return
                            end
                            if input.KeyCode ~= Enum.KeyCode.Unknown then
                                self:SetMenuKey(input.KeyCode, input.KeyCode.Name)
                                chipBtn.Text = input.KeyCode.Name
                                chipBtn.TextColor3 = C.accent
                                capturing = false
                                if connInput then connInput:Disconnect() connInput = nil end
                                if def.onRebind then
                                    task.spawn(pcall, def.onRebind, input.KeyCode, input.KeyCode.Name)
                                end
                            end
                        end
                    end)
                    self._conn(connInput)
                end

                self._conn(row.MouseButton1Click:Connect(startCapture))
                self._conn(chipBtn.MouseButton1Click:Connect(startCapture))
            elseif def.clipboard then
                local function copyClip()
                    pcall(function()
                        if setclipboard then setclipboard(def.clipboard)
                        elseif toclipboard then toclipboard(def.clipboard)
                        end
                    end)
                    chipBtn.Text = "COPIED"
                    chipBtn.TextColor3 = C.good
                    task.delay(1.2, function()
                        chipBtn.Text = tostring(def.chip)
                        chipBtn.TextColor3 = C.accent
                    end)
                end
                self._conn(row.MouseButton1Click:Connect(copyClip))
                self._conn(chipBtn.MouseButton1Click:Connect(copyClip))
            elseif def.onPress then
                local function fire()
                    task.spawn(pcall, def.onPress)
                end
                self._conn(row.MouseButton1Click:Connect(fire))
                self._conn(chipBtn.MouseButton1Click:Connect(fire))
            end
            return handle
        elseif def.buttonText then
            local b = Instance.new("TextButton")
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
            if def.danger then stroke(b, 0.5).Color = C.danger end
            local handle = { button = b }
            function handle:SetText(t) b.Text = tostring(t) end
            if def.onPress then
                local function fire()
                    task.spawn(pcall, def.onPress)
                end
                self._conn(b.MouseButton1Click:Connect(fire))
                self._conn(row.MouseButton1Click:Connect(fire))
            end
            return handle
        end
        return {}
    end

    if kind == "button" then
        local b = Instance.new("TextButton")
        b.Text = tostring(def.buttonText or def.name or "Button")
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

        local handle = { button = b }
        function handle:SetName(n)
            local str = tostring(n)
            b.Text = str
            if nameLabel then nameLabel.Text = str end
        end
        function handle:Set(t)
            if type(t) == "table" and t.Name ~= nil then
                handle:SetName(t.Name)
            elseif type(t) == "string" then
                handle:SetName(t)
            end
        end

        local labelProxy = {}
        setmetatable(labelProxy, {
            __index = function(_, k)
                if k == "Text" then return b.Text end
                return b[k]
            end,
            __newindex = function(_, k, v)
                if k == "Text" then
                    handle:SetName(v)
                else
                    pcall(function() b[k] = v end)
                end
            end,
        })
        handle.label = labelProxy

        if def.onPress then
            local function fire()
                task.spawn(pcall, def.onPress)
            end
            self._conn(b.MouseButton1Click:Connect(fire))
            self._conn(row.MouseButton1Click:Connect(fire))
        end
        return handle
    end

    if kind == "keybind" then
        local currentKey = tostring(def.value or def.default or def.key or "None")
        local chip = Instance.new("TextButton")
        chip.BackgroundColor3 = C.track
        chip.BackgroundTransparency = 0.2
        chip.Text = "[" .. currentKey .. "]"
        chip.TextSize = 11
        chip.TextColor3 = C.accent
        chip.Font = FONT_BOLD
        chip.AutomaticSize = Enum.AutomaticSize.XY
        chip.AutoButtonColor = false
        chip.Parent = z
        corner(chip, 6)
        pad(chip, 10, 5, 10, 5)

        local capturing = false
        local connInput
        local handle = { button = chip, key = currentKey }

        function handle:Set(newKey)
            if typeof(newKey) == "EnumItem" then
                newKey = newKey.Name
            end
            newKey = tostring(newKey or "None")
            handle.key = newKey
            chip.Text = "[" .. newKey .. "]"
            chip.TextColor3 = C.accent
            capturing = false
            if connInput then connInput:Disconnect() connInput = nil end
            if def.onChange then task.spawn(pcall, def.onChange, newKey) end
            if def.callback then task.spawn(pcall, def.callback, newKey) end
        end

        local function startCapture()
            if capturing then return end
            capturing = true
            chip.Text = "[...]"
            chip.TextColor3 = C.accent2
            if connInput then connInput:Disconnect() end
            local armedAt = os.clock()
            connInput = UserInputService.InputBegan:Connect(function(input, gpe)
                if os.clock() - armedAt < 0.12 then return end
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    if input.KeyCode == Enum.KeyCode.Escape then
                        capturing = false
                        chip.Text = "[" .. handle.key .. "]"
                        chip.TextColor3 = C.accent
                        if connInput then connInput:Disconnect() connInput = nil end
                        return
                    end
                    if input.KeyCode ~= Enum.KeyCode.Unknown then
                        handle:Set(input.KeyCode.Name)
                    end
                elseif input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.MouseButton2
                    or input.UserInputType == Enum.UserInputType.MouseButton3 then
                    handle:Set(input.UserInputType.Name)
                end
            end)
            self._conn(connInput)
        end

        self._conn(row.MouseButton1Click:Connect(startCapture))
        self._conn(chip.MouseButton1Click:Connect(startCapture))

        handle.label = chip
        handle.keyText = chip
        return handle
    end

    if kind == "slider" then
        local minV, maxV = def.min or 0, def.max or 100
        local step = def.step or 1
        local suffix = def.suffix or ""
        local value = math.clamp(def.value or minV, minV, maxV)

        local wrap = Instance.new("Frame")
        wrap.BackgroundTransparency = 1
        wrap.Size = UDim2.new(0, 150, 0, 30)
        wrap.Parent = z

        local valLabel = label("", 11, C.accent, FONT_MED)
        valLabel.AnchorPoint = Vector2.new(1, 0)
        valLabel.Position = UDim2.new(1, 0, 0, 0)
        valLabel.Size = UDim2.new(1, 0, 0, 14)
        valLabel.TextXAlignment = Enum.TextXAlignment.Right
        valLabel.Parent = wrap

        local track = Instance.new("TextButton")
        track.BackgroundColor3 = C.track
        track.Text = ""
        track.AutoButtonColor = false
        track.AnchorPoint = Vector2.new(0, 1)
        track.Position = UDim2.new(0, 0, 1, 0)
        track.Size = UDim2.new(1, 0, 0, 6)
        track.Parent = wrap
        corner(track, 3)

        local fill = Instance.new("Frame")
        fill.BackgroundColor3 = C.accent
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.Parent = track
        corner(fill, 3)

        local knob = Instance.new("Frame")
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.Size = UDim2.new(0, 12, 0, 12)
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.Parent = track
        corner(knob, 6)

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
        local function fromX(x)
            local p0 = track.AbsolutePosition.X
            local w = math.max(1, track.AbsoluteSize.X)
            handle:Set(minV + math.clamp((x - p0) / w, 0, 1) * (maxV - minV))
            if def.onChange then task.spawn(pcall, def.onChange, value) end
        end
        self._conn(track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                fromX(input.Position.X)
            end
        end))
        self._conn(UserInputService.InputChanged:Connect(function(input)
            if not dragging then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                fromX(input.Position.X)
            end
        end))
        self._conn(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end))
        -- row click (not on track) also toggles nothing; keep row press harmless
        render()
        return handle
    end

    if kind == "dropdown" then
        local options = def.options or {}
        local value = def.value
        if value == nil then value = options[1] end

        local btn = Instance.new("TextButton")
        btn.BackgroundColor3 = C.track
        btn.BackgroundTransparency = 0.2
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.Size = UDim2.new(0, 130, 0, 28)
        btn.Parent = z
        corner(btn, 8)
        local btnLabel = label(tostring(value), 11, C.text, FONT_MED)
        btnLabel.Position = UDim2.new(0, 10, 0, 0)
        btnLabel.Size = UDim2.new(1, -30, 1, 0)
        btnLabel.Parent = btn
        local arrow = label("▾", 12, C.muted, FONT)
        arrow.AnchorPoint = Vector2.new(1, 0.5)
        arrow.Position = UDim2.new(1, -8, 0.5, 0)
        arrow.Size = UDim2.new(0, 16, 0, 16)
        arrow.TextXAlignment = Enum.TextXAlignment.Right
        arrow.Parent = btn

        -- options expand inside the row (row auto-grows)
        local opts = Instance.new("Frame")
        opts.BackgroundTransparency = 1
        opts.Size = UDim2.new(1, 0, 0, 0)
        opts.AutomaticSize = Enum.AutomaticSize.Y
        opts.Visible = false
        opts.Parent = row
        local optsLayout = Instance.new("UIListLayout")
        optsLayout.FillDirection = Enum.FillDirection.Vertical
        optsLayout.Padding = UDim.new(0, 4)
        optsLayout.Parent = opts
        local optsPad = Instance.new("UIPadding")
        optsPad.PaddingTop = UDim.new(0, 8)
        optsPad.Parent = opts

        local handle = {}
        local function rebuild()
            for _, c in ipairs(opts:GetChildren()) do
                if c:IsA("GuiObject") then c:Destroy() end
            end
            for _, opt in ipairs(options) do
                local ob = Instance.new("TextButton")
                ob.BackgroundColor3 = (opt == value) and C.track or C.rowBg
                ob.BackgroundTransparency = 0.1
                ob.AutoButtonColor = false
                ob.Text = ""
                ob.Size = UDim2.new(1, 0, 0, 26)
                ob.Parent = opts
                corner(ob, 7)
                local ol = label(tostring(opt), 11, (opt == value) and C.accent or C.text, FONT)
                ol.Position = UDim2.new(0, 10, 0, 0)
                ol.Size = UDim2.new(1, -20, 1, 0)
                ol.Parent = ob
                self._conn(ob.MouseButton1Click:Connect(function()
                    value = opt
                    btnLabel.Text = tostring(opt)
                    opts.Visible = false
                    rebuild()
                    if def.onChange then task.spawn(pcall, def.onChange, value) end
                end))
            end
        end
        function handle:Set(v)
            value = v
            btnLabel.Text = tostring(v)
            rebuild()
        end
        function handle:Refresh(newOptions)
            options = newOptions or {}
            if value == nil then value = options[1] end
            rebuild()
        end
        self._conn(btn.MouseButton1Click:Connect(function()
            opts.Visible = not opts.Visible
        end))
        rebuild()
        return handle
    end

    return {}
end

-- ---------- visibility / lifecycle ----------
function Dock:SetVisible(v)
    self._visible = (v ~= false)
    self._stage.Visible = self._visible
end

function Dock:Toggle()
    self:SetVisible(not self._visible)
end

function Dock:OnUnload(fn)
    table.insert(self._unloadFns, fn)
end

function Dock:Destroy()
    self._visible = false
    if self._stage then
        pcall(function() self._stage.Visible = false end)
    end
    if self._gui then
        pcall(function() self._gui.Enabled = false end)
    end
    for _, fn in ipairs(self._unloadFns) do
        pcall(fn)
    end
    table.clear(self._unloadFns)
    for _, c in ipairs(self._conns) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(self._conns)
    if self._gui then
        pcall(function() self._gui:Destroy() end)
        self._gui = nil
    end
end

return Dock
