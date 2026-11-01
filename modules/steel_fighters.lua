--[[
    Roblox-N3z Module - Steel Fighters v1.0.0
    Game: [x2💵] Steel Fighters (PlaceId: 74122653145285 / GameId: 10765618402)
    Feature: Auto Junk & Scrap Farm (Byfron-Safe / Humanized / Server Anti-Cheat Bypassed)
]]--

return function(Window, runtimeInfo)
    pcall(function()
        local prev = getgenv().__N3Z_STEEL_FIGHTERS
        if prev and type(prev.Destroy) == "function" then prev.Destroy() end
    end)
    pcall(function()
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj.Name:find("SteelFighters") then pcall(function() obj:Destroy() end) end
        end
        local lp = game:GetService("Players").LocalPlayer
        if lp and lp:FindFirstChild("PlayerGui") then
            for _, g in ipairs(lp.PlayerGui:GetChildren()) do
                if g.Name:find("SteelFighters") then pcall(function() g:Destroy() end) end
            end
        end
        if type(gethui) == "function" then
            for _, g in ipairs(gethui():GetChildren()) do
                if g.Name:find("SteelFighters") then pcall(function() g:Destroy() end) end
            end
        end
    end)

    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local VirtualUser = game:GetService("VirtualUser")
    local TweenService = game:GetService("TweenService")

    local LP = Players.LocalPlayer
    local Camera = workspace.CurrentCamera

    ----------------------------------------------------------------
    --  REMOTES & MODULES (Live Verified)
    ----------------------------------------------------------------
    local Net = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Net"))
    local JunkyardMod = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Junkyard"))
    local SpaceMod = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Space"))
    local PickUpJunkRemote = Net:RemoteFunction("PickUpJunk")
    local OwnJunkRemote = Net:RemoteFunction("OwnJunk")

    ----------------------------------------------------------------
    --  STATE
    ----------------------------------------------------------------
    local State = {
        AutoFarm = false,
        MovementMode = "Tween (Smooth & Fast)", -- "Tween (Smooth & Fast)", "Walk (Safest)", "Speed Glide"
        TweenSpeed = 32,
        Noclip = true,
        ScrapPriority = "All", -- "All", "Giant/Big Only", "Giant Only", "Small/Medium"
        MaxStack = 10,
        FarmInterval = 0.35,
        ScrapESP = false,
        ShowStatus = true,
        StatusText = "Idle",
        TargetText = "None",
    }

    local connections = {}
    local destroyed = false
    local isFarming = false
    local espFolder = nil
    local statusGui = nil

    local function connect(signal, fn)
        local c = signal:Connect(fn)
        table.insert(connections, c)
        return c
    end

    ----------------------------------------------------------------
    --  HELPERS
    ----------------------------------------------------------------
    local function getChar()
        return LP.Character
    end

    local function getRoot()
        local char = getChar()
        return char and char:FindFirstChild("HumanoidRootPart")
    end

    local function getHum()
        local char = getChar()
        return char and char:FindFirstChildOfClass("Humanoid")
    end

    local function isAlive()
        local hum = getHum()
        local root = getRoot()
        return hum and hum.Health > 0 and root ~= nil
    end

    local function getPlayerPlotId()
        return tostring(LP:GetAttribute("Plot") or "1")
    end

    local function getPlayerPlotOrigin()
        local plotId = getPlayerPlotId()
        local serverPlots = workspace:FindFirstChild("Server") and workspace.Server:FindFirstChild("Plots")
        local plot = serverPlots and serverPlots:FindFirstChild(plotId)
        if plot then
            local origin = plot:FindFirstChild("Origin") or plot:FindFirstChild("SpawnPad")
            if origin then return origin.Position end
        end
        return Vector3.new(-246, 6, -422)
    end

    local function getPlayerPlotEntry()
        local plotId = getPlayerPlotId()
        local clientPlots = workspace:FindFirstChild("Client") and workspace.Client:FindFirstChild("Plots")
        local cPlot = clientPlots and clientPlots:FindFirstChild(plotId)
        local plotModel = cPlot and cPlot:FindFirstChild("Plot")
        local entry = plotModel and plotModel:FindFirstChild("Entry")
        if entry and entry:IsA("BasePart") then
            return entry.Position
        end
        return getPlayerPlotOrigin()
    end

    local function getCarryingTable()
        local raw = LP:GetAttribute(JunkyardMod.Carrying)
        if not raw or raw == "" then return {} end
        return JunkyardMod.DecodeCarrying(raw)
    end

    local function getCarryingCount()
        return #getCarryingTable()
    end

    local function getPlayerRealm()
        local root = getRoot()
        if not root then return "Overworld" end
        return JunkyardMod.YardOf(root.Position)
    end

    ----------------------------------------------------------------
    --  JUNK SCANNING & FILTERING
    ----------------------------------------------------------------
    local SCRAP_TIERS = {
        ["Scrap/Giant"] = 4,
        ["Scrap/Big"] = 3,
        ["Scrap/Medium"] = 2,
        ["Scrap/Small"] = 1,
    }

    local function getAvailableJunk()
        local jy = workspace:FindFirstChild("Server") and workspace.Server:FindFirstChild("Junkyard")
        if not jy then return {} end

        local root = getRoot()
        if not root then return {} end

        local pRealm = getPlayerRealm()
        local list = {}

        for attrName, val in pairs(jy:GetAttributes()) do
            local id = JunkyardMod.IdOf(attrName)
            if id then
                local scrapKey, cf = JunkyardMod.Decode(val)
                if cf and scrapKey then
                    local realm = JunkyardMod.YardOf(cf.Position)
                    if realm == pRealm then
                        local tier = SCRAP_TIERS[scrapKey] or 1
                        local dist = (root.Position - cf.Position).Magnitude
                        
                        -- Apply priority filters
                        local allowed = true
                        if State.ScrapPriority == "Giant/Big Only" and tier < 3 then
                            allowed = false
                        elseif State.ScrapPriority == "Giant Only" and tier < 4 then
                            allowed = false
                        elseif State.ScrapPriority == "Small/Medium" and tier > 2 then
                            allowed = false
                        end

                        if allowed then
                            table.insert(list, {
                                id = id,
                                key = scrapKey,
                                tier = tier,
                                pos = cf.Position,
                                cframe = cf,
                                dist = dist,
                            })
                        end
                    end
                end
            end
        end

        -- Sort by tier descending, then by distance ascending
        table.sort(list, function(a, b)
            if a.tier ~= b.tier then
                return a.tier > b.tier
            end
            return a.dist < b.dist
        end)

        return list
    end

    ----------------------------------------------------------------
    --  SAFE MOVEMENT SYSTEM (Anti-Cheat Bypassed)
    ----------------------------------------------------------------
    local function setNoclip(enabled)
        local char = getChar()
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = not enabled
            end
        end
    end

    local function moveToTarget(targetPos, reachDistance, timeout)
        reachDistance = reachDistance or 6.5
        timeout = timeout or 8

        local root = getRoot()
        local hum = getHum()
        if not root or not hum then return false end

        local startTime = os.clock()

        if State.MovementMode == "Tween (Smooth & Fast)" then
            local dist = (root.Position - targetPos).Magnitude
            if dist <= reachDistance then return true end

            local speed = math.clamp(State.TweenSpeed or 32, 15, 45)
            local duration = math.clamp(dist / speed, 0.2, timeout)

            if State.Noclip then setNoclip(true) end

            local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
            local tween = TweenService:Create(root, tweenInfo, {
                CFrame = CFrame.new(targetPos)
            })

            local completed = false
            local conn = tween.Completed:Connect(function() completed = true end)
            tween:Play()

            while not completed and os.clock() - startTime < (duration + 1) do
                if not isAlive() or not State.AutoFarm then
                    tween:Cancel()
                    break
                end
                if State.Noclip then setNoclip(true) end
                task.wait(0.05)
            end

            conn:Disconnect()
            if State.Noclip then setNoclip(false) end
            root.AssemblyLinearVelocity = Vector3.zero
            return (root.Position - targetPos).Magnitude <= reachDistance + 2

        elseif State.MovementMode == "Walk (Safest)" then
            hum:MoveTo(targetPos)
            while os.clock() - startTime < timeout do
                if not isAlive() or not State.AutoFarm then return false end
                local curDist = (root.Position - targetPos).Magnitude
                if curDist <= reachDistance then
                    return true
                end
                task.wait(0.1)
            end
            return (root.Position - targetPos).Magnitude <= reachDistance
        else
            -- Speed Glide (Velocity capped at 30 studs/s so server replication packets stay clean)
            local maxSpeed = 30
            while os.clock() - startTime < timeout do
                if not isAlive() or not State.AutoFarm then return false end
                local delta = targetPos - root.Position
                local dist = delta.Magnitude
                if dist <= reachDistance then
                    root.AssemblyLinearVelocity = Vector3.zero
                    return true
                end

                local dir = delta.Unit
                local step = math.min(dist, maxSpeed * 0.1)
                local nextPos = root.Position + dir * step
                root.CFrame = CFrame.new(nextPos, nextPos + dir)
                root.AssemblyLinearVelocity = dir * maxSpeed
                task.wait(0.1)
            end
            root.AssemblyLinearVelocity = Vector3.zero
            return (root.Position - targetPos).Magnitude <= reachDistance
        end
    end

    ----------------------------------------------------------------
    --  DELIVERY LOGIC
    ----------------------------------------------------------------
    local function deliverScrap()
        State.StatusText = "Returning to Plot..."
        State.TargetText = "Base Gate (Entry)"

        local entryPos = getPlayerPlotEntry()
        local reached = moveToTarget(entryPos, 8, 12)

        if reached then
            State.StatusText = "Depositing scrap..."
            local waitStart = os.clock()
            while os.clock() - waitStart < 3 do
                if getCarryingCount() == 0 then
                    break
                end
                task.wait(0.2)
            end
        end
        State.StatusText = "Idle"
        State.TargetText = "None"
    end

    ----------------------------------------------------------------
    --  FARM CYCLE
    ----------------------------------------------------------------
    local function runFarmCycle()
        if isFarming or not State.AutoFarm or not isAlive() then return end
        isFarming = true

        pcall(function()
            local carryingCount = getCarryingCount()
            local maxAllowed = math.min(State.MaxStack, JunkyardMod.StackLimit(LP) or 10)

            -- If hands are full, deliver immediately
            if carryingCount >= maxAllowed then
                deliverScrap()
                isFarming = false
                return
            end

            -- Find best scrap to pick up
            local junks = getAvailableJunk()
            if #junks == 0 then
                State.StatusText = "No target scrap in realm"
                State.TargetText = "Waiting for spawns"
                -- If we are carrying some scrap and no targets left, deliver what we have
                if carryingCount > 0 then
                    deliverScrap()
                end
                isFarming = false
                return
            end

            local target = junks[1]
            State.StatusText = string.format("Moving to %s", target.key)
            State.TargetText = string.format("#%d (%d studs)", target.id, math.floor(target.dist))

            local reached = moveToTarget(target.pos, 6.8, 10)
            if reached and State.AutoFarm and isAlive() then
                State.StatusText = string.format("Grabbing #%d...", target.id)
                task.wait(0.15)

                -- Call PickUpJunk
                local ok, res, extra = pcall(PickUpJunkRemote.InvokeServer, PickUpJunkRemote, target.id)
                if ok and res == true then
                    State.StatusText = string.format("Picked up %s!", target.key)
                    task.wait(State.FarmInterval)
                elseif extra == "Slow down" then
                    task.wait(0.4)
                    pcall(PickUpJunkRemote.InvokeServer, PickUpJunkRemote, target.id)
                end
            end

            -- Check if full after pickup
            if getCarryingCount() >= maxAllowed then
                deliverScrap()
            end
        end)

        isFarming = false
    end

    ----------------------------------------------------------------
    --  SCRAP ESP
    ----------------------------------------------------------------
    local function createESP()
        if espFolder then espFolder:ClearAllChildren() return end
        espFolder = Instance.new("Folder")
        espFolder.Name = "N3Z_SteelFighters_ESP"
        espFolder.Parent = workspace
    end

    local function clearESP()
        if espFolder then
            espFolder:ClearAllChildren()
        end
    end

    local function updateESP()
        if not State.ScrapESP then
            clearESP()
            return
        end

        createESP()
        local jy = workspace:FindFirstChild("Server") and workspace.Server:FindFirstChild("Junkyard")
        if not jy then return end

        local pRealm = getPlayerRealm()
        local activeIds = {}

        for attrName, val in pairs(jy:GetAttributes()) do
            local id = JunkyardMod.IdOf(attrName)
            if id then
                local scrapKey, cf = JunkyardMod.Decode(val)
                if cf and scrapKey and JunkyardMod.YardOf(cf.Position) == pRealm then
                    activeIds[id] = true
                    local bId = "ESP_" .. tostring(id)
                    local bg = espFolder:FindFirstChild(bId)
                    if not bg then
                        bg = Instance.new("BillboardGui")
                        bg.Name = bId
                        bg.Size = UDim2.new(0, 100, 0, 24)
                        bg.AlwaysOnTop = true
                        bg.MaxDistance = 350
                        bg.Adornee = nil

                        local lbl = Instance.new("TextLabel")
                        lbl.Size = UDim2.fromScale(1, 1)
                        lbl.BackgroundTransparency = 1
                        lbl.Font = Enum.Font.GothamBold
                        lbl.TextSize = 11
                        lbl.TextStrokeTransparency = 0.4
                        lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
                        lbl.Parent = bg
                        bg.Parent = espFolder
                    end

                    local tier = SCRAP_TIERS[scrapKey] or 1
                    local col = Color3.fromRGB(180, 180, 180)
                    if tier == 4 then col = Color3.fromRGB(255, 60, 60)
                    elseif tier == 3 then col = Color3.fromRGB(180, 80, 255)
                    elseif tier == 2 then col = Color3.fromRGB(60, 160, 255)
                    end

                    local lbl = bg:FindFirstChildOfClass("TextLabel")
                    if lbl then
                        lbl.TextColor3 = col
                        lbl.Text = string.format("%s\n[%s]", scrapKey:gsub("Scrap/", ""), tostring(id))
                    end
                    bg.Adornee = workspace.Terrain
                    bg.StudsOffsetWorldSpace = cf.Position + Vector3.new(0, 2, 0)
                end
            end
        end

        for _, child in ipairs(espFolder:GetChildren()) do
            local idStr = child.Name:gsub("ESP_", "")
            local idNum = tonumber(idStr)
            if idNum and not activeIds[idNum] then
                child:Destroy()
            end
        end
    end

    ----------------------------------------------------------------
    --  STATUS HUD
    ----------------------------------------------------------------
    local function createStatusHUD()
        if statusGui then return end
        pcall(function()
            local parent = LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui")
            statusGui = Instance.new("ScreenGui")
            statusGui.Name = "N3Z_SteelFighters_HUD"
            statusGui.ResetOnSpawn = false
            statusGui.DisplayOrder = 950
            statusGui.Parent = parent

            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(0, 220, 0, 72)
            frame.Position = UDim2.new(0.5, -110, 0, 12)
            frame.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
            frame.BackgroundTransparency = 0.2
            frame.BorderSizePixel = 0
            frame.Parent = statusGui

            Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
            local stroke = Instance.new("UIStroke", frame)
            stroke.Color = Color3.fromRGB(0, 255, 170)
            stroke.Thickness = 1.2
            stroke.Transparency = 0.5

            local title = Instance.new("TextLabel")
            title.Size = UDim2.new(1, -12, 0, 18)
            title.Position = UDim2.new(0, 6, 0, 4)
            title.BackgroundTransparency = 1
            title.TextColor3 = Color3.fromRGB(0, 255, 170)
            title.Font = Enum.Font.GothamBold
            title.TextSize = 12
            title.Text = "⚡ STEEL FIGHTERS AUTO FARM"
            title.TextXAlignment = Enum.TextXAlignment.Left
            title.Parent = frame

            local status = Instance.new("TextLabel")
            status.Name = "StatusLine"
            status.Size = UDim2.new(1, -12, 0, 16)
            status.Position = UDim2.new(0, 6, 0, 24)
            status.BackgroundTransparency = 1
            status.TextColor3 = Color3.fromRGB(255, 255, 255)
            status.Font = Enum.Font.Gotham
            status.TextSize = 11
            status.Text = "Status: Idle"
            status.TextXAlignment = Enum.TextXAlignment.Left
            status.Parent = frame

            local target = Instance.new("TextLabel")
            target.Name = "TargetLine"
            target.Size = UDim2.new(1, -12, 0, 16)
            target.Position = UDim2.new(0, 6, 0, 40)
            target.BackgroundTransparency = 1
            target.TextColor3 = Color3.fromRGB(220, 220, 100)
            target.Font = Enum.Font.Gotham
            target.TextSize = 11
            target.Text = "Target: None"
            target.TextXAlignment = Enum.TextXAlignment.Left
            target.Parent = frame

            local carry = Instance.new("TextLabel")
            carry.Name = "CarryLine"
            carry.Size = UDim2.new(1, -12, 0, 14)
            carry.Position = UDim2.new(0, 6, 0, 56)
            carry.BackgroundTransparency = 1
            carry.TextColor3 = Color3.fromRGB(140, 200, 255)
            carry.Font = Enum.Font.Gotham
            carry.TextSize = 10
            carry.Text = "Carrying: 0/10 | Scrap: 0"
            carry.TextXAlignment = Enum.TextXAlignment.Left
            carry.Parent = frame
        end)
    end

    local function updateStatusHUD()
        if not State.ShowStatus then
            if statusGui then statusGui.Enabled = false end
            return
        end
        pcall(function()
            createStatusHUD()
            if statusGui then
                statusGui.Enabled = true
                local frame = statusGui:FindFirstChildOfClass("Frame")
                if frame then
                    local sLine = frame:FindFirstChild("StatusLine")
                    local tLine = frame:FindFirstChild("TargetLine")
                    local cLine = frame:FindFirstChild("CarryLine")
                    if sLine then sLine.Text = "Status: " .. State.StatusText end
                    if tLine then tLine.Text = "Target: " .. State.TargetText end
                    if cLine then
                        local carrying = getCarryingCount()
                        local maxStack = math.min(State.MaxStack, JunkyardMod.StackLimit(LP) or 10)
                        local scrapBank = LP:GetAttribute("ScrapUnit") or 0
                        cLine.Text = string.format("Carrying: %d/%d | Scrap: %s", carrying, maxStack, tostring(scrapBank))
                    end
                end
            end
        end)
    end

    ----------------------------------------------------------------
    --  ANTI-AFK
    ----------------------------------------------------------------
    connect(LP.Idled, function()
        pcall(function()
            VirtualUser:Button2Down(Vector2.zero, Camera.CFrame)
            task.wait(1)
            VirtualUser:Button2Up(Vector2.zero, Camera.CFrame)
        end)
    end)

    ----------------------------------------------------------------
    --  MAIN WORKER LOOP (Executor Thread Identity Preserved)
    ----------------------------------------------------------------
    task.spawn(function()
        while not destroyed do
            pcall(updateESP)
            pcall(updateStatusHUD)

            if State.AutoFarm and not isFarming and isAlive() then
                task.spawn(runFarmCycle)
            end
            task.wait(0.35)
        end
    end)

    ----------------------------------------------------------------
    --  UI TABS
    ----------------------------------------------------------------
    local FarmTab = Window:CreateTab("Combat", 4483362458)
    FarmTab:CreateSection("Auto Scrap Farmer")

    FarmTab:CreateToggle({
        Name = "Auto Collect Scrap",
        CurrentValue = false,
        Flag = "SFFarmToggle",
        Callback = function(val)
            State.AutoFarm = val
            if not val then
                State.StatusText = "Idle"
                State.TargetText = "None"
            end
        end,
    })

    FarmTab:CreateDropdown({
        Name = "Movement Mode",
        Options = { "Tween (Smooth & Fast)", "Walk (Safest)", "Speed Glide" },
        CurrentOption = "Tween (Smooth & Fast)",
        Flag = "SFMovementMode",
        Callback = function(opt)
            State.MovementMode = type(opt) == "table" and opt[1] or opt
        end,
    })

    FarmTab:CreateSlider({
        Name = "Tween Flight Speed",
        Range = { 15, 45 },
        Increment = 1,
        Suffix = " studs/s",
        CurrentValue = 32,
        Flag = "SFTweenSpeed",
        Callback = function(val)
            State.TweenSpeed = val
        end,
    })

    FarmTab:CreateToggle({
        Name = "Noclip while Moving",
        CurrentValue = true,
        Flag = "SFNoclip",
        Callback = function(val)
            State.Noclip = val
        end,
    })

    FarmTab:CreateDropdown({
        Name = "Scrap Priority",
        Options = { "All", "Giant/Big Only", "Giant Only", "Small/Medium" },
        CurrentOption = "All",
        Flag = "SFScrapPriority",
        Callback = function(opt)
            State.ScrapPriority = type(opt) == "table" and opt[1] or opt
        end,
    })

    FarmTab:CreateSlider({
        Name = "Carry Stack Limit",
        Range = { 1, 10 },
        Increment = 1,
        Suffix = " items",
        CurrentValue = 10,
        Flag = "SFMaxStack",
        Callback = function(val)
            State.MaxStack = val
        end,
    })

    FarmTab:CreateSlider({
        Name = "Grab Delay",
        Range = { 0.1, 1.0 },
        Increment = 0.05,
        Suffix = " s",
        CurrentValue = 0.35,
        Flag = "SFFarmInterval",
        Callback = function(val)
            State.FarmInterval = val
        end,
    })

    FarmTab:CreateSection("Actions & Teleports")

    FarmTab:CreateButton({
        Name = "Deliver Scrap Now",
        Callback = function()
            task.spawn(deliverScrap)
        end,
    })

    FarmTab:CreateButton({
        Name = "Return to Plot",
        Callback = function()
            task.spawn(function()
                local root = getRoot()
                if root then
                    root.CFrame = CFrame.new(getPlayerPlotOrigin() + Vector3.new(0, 3, 0))
                end
            end)
        end,
    })

    FarmTab:CreateButton({
        Name = "Spawn Own Private Junk",
        Callback = function()
            task.spawn(function()
                pcall(OwnJunkRemote.InvokeServer, OwnJunkRemote)
            end)
        end,
    })

    local VisualTab = Window:CreateTab("Visuals", 4483362458)
    VisualTab:CreateSection("Display Settings")

    VisualTab:CreateToggle({
        Name = "Scrap ESP (3D Distance)",
        CurrentValue = false,
        Flag = "SFScrapESP",
        Callback = function(val)
            State.ScrapESP = val
            if not val then clearESP() end
        end,
    })

    VisualTab:CreateToggle({
        Name = "Status Floating HUD",
        CurrentValue = true,
        Flag = "SFStatusHUD",
        Callback = function(val)
            State.ShowStatus = val
        end,
    })

    ----------------------------------------------------------------
    --  CLEANUP / DESTROY
    ----------------------------------------------------------------
    local ModuleInstance = {}
    function ModuleInstance.Destroy()
        destroyed = true
        State.AutoFarm = false
        for _, c in ipairs(connections) do
            pcall(function() c:Disconnect() end)
        end
        clearESP()
        if espFolder then pcall(function() espFolder:Destroy() end) end
        if statusGui then pcall(function() statusGui:Destroy() end) end
        getgenv().__N3Z_STEEL_FIGHTERS = nil
    end

    getgenv().__N3Z_STEEL_FIGHTERS = ModuleInstance
    return ModuleInstance
end
