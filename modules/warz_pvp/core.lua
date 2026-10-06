-- ============================================================
-- N3Z WarZPVP shared core
-- v1.8.4 - reduce Silent Aim hitbox work outside the FOV
-- ============================================================

return function(Window, ctx, platform)
    assert(type(platform) == "table", "WarZ: platform adapter is required")
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local UserInputService = game:GetService("UserInputService")
    local ContextActionService = game:GetService("ContextActionService")
    local GuiService = game:GetService("GuiService")

    local localPlayer = Players.LocalPlayer
    local lifecycleAlive = true

    -- Some executors can run the Hub but stall when an experience ModuleScript
    -- is required during module startup. Keep every game-module dependency
    -- lazy and non-blocking so ESP/UI always finish initializing first.
    local lazyModules = {}

    local function lazyRequire(key, findModule, validate)
        local state = lazyModules[key]
        if not state then
            state = { value = nil, loading = false, nextRetryAt = 0 }
            lazyModules[key] = state
        end
        if state.value ~= nil then
            return state.value
        end

        local now = os.clock()
        if state.loading or now < state.nextRetryAt then
            return nil
        end

        state.loading = true
        state.nextRetryAt = now + 1
        task.spawn(function()
            local ok, result = pcall(function()
                local module = findModule()
                if not module or not module:IsA("ModuleScript") then
                    return nil
                end
                return require(module)
            end)

            if lifecycleAlive and ok and result ~= nil
                and (not validate or validate(result)) then
                state.value = result
            end
            state.loading = false
        end)
        return nil
    end

    local function getCombatSettings()
        return lazyRequire("CombatSettings", function()
            local client = localPlayer.PlayerScripts:FindFirstChild("Client")
            local input = client and client:FindFirstChild("input")
            return input and input:FindFirstChild("CombatSettings")
        end, function(api)
            return type(api) == "table"
        end)
    end

    local function getWarzProjectile()
        return lazyRequire("WarzProjectile", function()
            local shared = ReplicatedStorage:FindFirstChild("Shared")
            return shared and shared:FindFirstChild("WarzProjectile")
        end, function(api)
            return type(api) == "table"
        end)
    end

    local function getCombatInput()
        return lazyRequire("CombatInput", function()
            local client = localPlayer.PlayerScripts:FindFirstChild("Client")
            local input = client and client:FindFirstChild("input")
            return input and input:FindFirstChild("CombatInput")
        end, function(api)
            return type(api) == "table" and type(api.RequestUseMed) == "function"
        end)
    end

    local function getWarzHitboxes()
        return lazyRequire("WarzHitboxes", function()
            local shared = ReplicatedStorage:FindFirstChild("Shared")
            local warz = shared and shared:FindFirstChild("warz")
            return warz and warz:FindFirstChild("WarzHitboxes")
        end, function(api)
            return type(api) == "table" and type(api.DataShapes) == "function"
        end)
    end

    local function getSharedConfig()
        return lazyRequire("SharedConfig", function()
            local shared = ReplicatedStorage:FindFirstChild("Shared")
            return shared and shared:FindFirstChild("Config")
        end, function(api)
            return type(api) == "table"
        end)
    end

    local function getLootHoldModule()
        return lazyRequire("LootHold", function()
            local client = localPlayer.PlayerScripts:FindFirstChild("Client")
            if not client then return nil end
            for _, child in ipairs(client:GetDescendants()) do
                if child.Name == "LootHold" and child:IsA("ModuleScript") then
                    return child
                end
            end
            return nil
        end, function(api)
            return type(api) == "table" and type(api.Step) == "function"
        end)
    end

    local function getFishingModule()
        return lazyRequire("Fishing", function()
            local client = localPlayer.PlayerScripts:FindFirstChild("Client")
            local world = client and client:FindFirstChild("world")
            return world and world:FindFirstChild("Fishing")
        end, function(api)
            return type(api) == "table" and type(api.Press) == "function"
        end)
    end

    local function getLootPickupModule()
        return lazyRequire("LootPickup", function()
            local client = localPlayer.PlayerScripts:FindFirstChild("Client")
            local world = client and client:FindFirstChild("world")
            return world and world:FindFirstChild("LootPickup")
        end, function(api)
            return type(api) == "table" and type(api.SetTouchHeld) == "function"
        end)
    end

    local function peekLazy(key)
        local state = lazyModules[key]
        return state and state.value or nil
    end

    local camera = Workspace.CurrentCamera
    local dock = (type(ctx) == "table" and type(ctx.dock) == "table" and ctx.dock)
        or (type(Window) == "table" and type(Window.dock) == "table" and Window.dock)
        or nil

    -- Clean up previous instance (ghost UI prevention)
    local environment = (type(getgenv) == "function" and getgenv()) or _G
    if type(environment.__RAVEN_WARZPVP) == "table"
        and type(environment.__RAVEN_WARZPVP.Destroy) == "function" then
        pcall(environment.__RAVEN_WARZPVP.Destroy)
    end
    pcall(function()
        if type(environment.__RAVEN_WINDOW) == "table"
            and type(environment.__RAVEN_WINDOW.Destroy) == "function" then
            environment.__RAVEN_WINDOW.Destroy()
        end
    end)
    environment.RAVEN_WARZPVP_VER = "1.8.4"

    local running = true
    local connections = {}
    local uiSections = {} -- sections this module created (for clean reload)
    local espCache = {}

    local settings = {
        espEnabled = true,
        boxEsp = true,
        nameEsp = true,
        distanceEsp = true,
        healthEsp = true,
        weaponEsp = true,
        skeletonEsp = true,
        selfEsp = false,
        maxDistance = 2000,
        lootEsp = true,
        lootMaxDistance = 1500,
        lootCategory = "All",
        bossEsp = true,
        bossAlert = true,
        aimbot = false,
        aimMaxDist = 500,
        aimFov = 150,
        aimPosition = "Auto",
        aimResponse = 0.35,
        aimPrediction = true,
        vulnerabilityCheck = true,
        autoHeal = false,
        healThreshold = 50,
        healCooldown = 0,
        noRecoil = false,
        instantPickup = false,
        silentAim = false,
        silentAimFov = 120,
        silentFov = 120,
        silentAimBone = "Auto",
        silentAimHitChance = 100,
        silentBone = "Auto",
        infiniteStamina = false,
        lootAura = false,
        lootAuraRange = 10.5,
        autoFishing = false,
    }

    -- Track every section we create so destroy() can remove them from the
    -- tab. The UI library reuses tabs by name (CreateTab returns the existing
    -- tab), so without this a module reload would stack duplicate sections.
    local function trackSection(tab, name)
        local sec = tab:CreateSection(name)
        table.insert(uiSections, sec)
        return sec
    end

    local function removeUiSections()
        -- Visuals/Combat are owned by this module. Use DrawingUI's native
        -- Clear() so the old Drawing objects are actually removed.
        local tabs = {}
        for _, sec in ipairs(uiSections) do
            if sec and sec.tab then tabs[sec.tab] = true end
        end
        for tab in pairs(tabs) do
            if type(tab.Clear) == "function" then
                pcall(function() tab:Clear() end)
            end
        end
        table.clear(uiSections)
    end

    local function createNativeDrawingBackend(options)
        options = options or {}
        local nativeDrawingGui = nil
        local nativeDrawingObjects = {}

        local function ensureNativeDrawingGui()
            if nativeDrawingGui and nativeDrawingGui.Parent then
                return nativeDrawingGui
            end

            local parent = type(options.resolveParent) == "function"
                and options.resolveParent()
                or nil
            if not parent then return nil end

            local gui = Instance.new("ScreenGui")
            gui.Name = "N3zWarzVisuals"
            gui.IgnoreGuiInset = true
            gui.ResetOnSpawn = false
            gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            gui.DisplayOrder = tonumber(options.displayOrder) or 20
            pcall(function()
                gui.ScreenInsets = Enum.ScreenInsets.None
            end)

            local okParent = pcall(function()
                gui.Parent = parent
            end)
            if not okParent then
                pcall(function() gui:Destroy() end)
                return nil
            end

            nativeDrawingGui = gui
            return gui
        end

        local function newNativeDrawing(drawingType)
            local gui = ensureNativeDrawingGui()
            if not gui then return nil end

            local state = {
                Visible = false,
                Color = Color3.new(1, 1, 1),
                Transparency = 1,
                Thickness = 1,
                Filled = false,
                Position = Vector2.zero,
                Size = Vector2.zero,
                Text = "",
                Image = "",
                Center = false,
                Outline = false,
                From = Vector2.zero,
                To = Vector2.zero,
                Radius = 0,
                ZIndex = 0,
            }

            local inst
            local stroke

            if drawingType == "Text" then
                local label = Instance.new("TextLabel")
                label.Name = "NativeText"
                label.BackgroundTransparency = 1
                label.BorderSizePixel = 0
                label.Text = ""
                label.TextSize = 14
                label.TextColor3 = state.Color
                label.TextTransparency = 0
                label.TextStrokeTransparency = 1
                label.Font = Enum.Font.Code
                label.AutomaticSize = Enum.AutomaticSize.XY
                label.Size = UDim2.fromOffset(0, 0)
                label.Visible = false
                label.ZIndex = 1
                label.Parent = gui
                inst = label
                state.Size = 14
            elseif drawingType == "Image" then
                local image = Instance.new("ImageLabel")
                image.Name = "NativeImage"
                image.BackgroundTransparency = 1
                image.BorderSizePixel = 0
                image.Image = ""
                image.ImageColor3 = state.Color
                image.ImageTransparency = 0
                image.ScaleType = Enum.ScaleType.Fit
                image.Visible = false
                image.ZIndex = 1
                image.Parent = gui
                inst = image
            elseif drawingType == "Line" then
                local frame = Instance.new("Frame")
                frame.Name = "NativeLine"
                frame.BorderSizePixel = 0
                frame.AnchorPoint = Vector2.new(0.5, 0.5)
                frame.BackgroundColor3 = state.Color
                frame.BackgroundTransparency = 0
                frame.Visible = false
                frame.ZIndex = 1
                frame.Parent = gui
                inst = frame
            elseif drawingType == "Square" or drawingType == "Circle" then
                local frame = Instance.new("Frame")
                frame.Name = drawingType == "Circle" and "NativeCircle" or "NativeSquare"
                frame.BorderSizePixel = 0
                frame.BackgroundColor3 = state.Color
                frame.BackgroundTransparency = 1
                frame.Visible = false
                frame.ZIndex = 1
                frame.Parent = gui
                inst = frame

                stroke = Instance.new("UIStroke")
                stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                stroke.Color = state.Color
                stroke.Thickness = 1
                stroke.Parent = frame

                if drawingType == "Circle" then
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

                if drawingType == "Text" then
                    inst.Text = tostring(state.Text or "")
                    inst.TextSize = math.max(1, tonumber(state.Size) or 14)
                    inst.TextColor3 = state.Color
                    inst.TextTransparency = 1 - alpha
                    inst.TextStrokeColor3 = Color3.new(0, 0, 0)
                    inst.TextStrokeTransparency = state.Outline and (1 - alpha) or 1
                    inst.AnchorPoint = state.Center and Vector2.new(0.5, 0) or Vector2.new(0, 0)
                    inst.Position = UDim2.fromOffset(state.Position.X, state.Position.Y)
                elseif drawingType == "Image" then
                    inst.Image = tostring(state.Image or "")
                    inst.ImageColor3 = state.Color
                    inst.ImageTransparency = 1 - alpha
                    inst.Position = UDim2.fromOffset(state.Position.X, state.Position.Y)
                    inst.Size = UDim2.fromOffset(math.max(0, state.Size.X), math.max(0, state.Size.Y))
                elseif drawingType == "Line" then
                    local from = state.From
                    local to = state.To
                    local delta = to - from
                    local length = delta.Magnitude
                    inst.Position = UDim2.fromOffset((from.X + to.X) * 0.5, (from.Y + to.Y) * 0.5)
                    inst.Size = UDim2.fromOffset(math.max(0.01, length), math.max(1, tonumber(state.Thickness) or 1))
                    inst.Rotation = math.deg(math.atan2(delta.Y, delta.X))
                    inst.BackgroundColor3 = state.Color
                    inst.BackgroundTransparency = 1 - alpha
                elseif drawingType == "Square" then
                    inst.AnchorPoint = Vector2.zero
                    inst.Position = UDim2.fromOffset(state.Position.X, state.Position.Y)
                    inst.Size = UDim2.fromOffset(math.max(0, state.Size.X), math.max(0, state.Size.Y))
                    inst.BackgroundColor3 = state.Color
                    inst.BackgroundTransparency = state.Filled and (1 - alpha) or 1
                    stroke.Enabled = not state.Filled
                    stroke.Color = state.Color
                    stroke.Thickness = math.max(1, tonumber(state.Thickness) or 1)
                    stroke.Transparency = 1 - alpha
                elseif drawingType == "Circle" then
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
                if key == "Remove" then
                    return function()
                        if removed then return end
                        removed = true
                        nativeDrawingObjects[proxy] = nil
                        if inst then
                            pcall(function() inst:Destroy() end)
                        end
                        inst = nil
                    end
                end
                if key == "TextBounds" and drawingType == "Text" then
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
            nativeDrawingObjects[proxy] = true
            apply()
            return proxy
        end

        local backend = {
            name = options.name or "NativeGui",
            new = newNativeDrawing,
        }

        function backend.destroy()
            local objects = {}
            for obj in pairs(nativeDrawingObjects) do
                table.insert(objects, obj)
            end
            for _, obj in ipairs(objects) do
                pcall(function() obj:Remove() end)
            end
            table.clear(nativeDrawingObjects)
            if nativeDrawingGui then
                pcall(function() nativeDrawingGui:Destroy() end)
                nativeDrawingGui = nil
            end
        end

        return backend
    end

    assert(type(platform.createVisualBackend) == "function",
        "WarZ: platform adapter missing createVisualBackend")
    local visualBackend = platform.createVisualBackend({
        localPlayer = localPlayer,
        createNativeBackend = createNativeDrawingBackend,
    })
    assert(type(visualBackend) == "table" and type(visualBackend.new) == "function",
        "WarZ: invalid visual backend")

    local function safeDrawing(drawingType)
        return visualBackend.new(drawingType)
    end

    local function safeImage()
        if type(visualBackend.newImage) == "function" then
            return visualBackend.newImage()
        end
        return nil
    end

    local function getHealthColor(ratio)
        return Color3.fromHSV(math.clamp(ratio, 0, 1) * 0.33, 0.9, 1)
    end

    -- Relation-aware ESP colors. Party has priority over clan.
    -- Empty IDs never count as a relation.
    local ESP_COLOR = Color3.fromRGB(255, 200, 60)
    local PARTY_COLOR = Color3.fromRGB(80, 220, 255)
    local CLAN_COLOR = Color3.fromRGB(190, 120, 255)

    local function sameNonEmptyPlayerAttribute(a, b, attribute)
        local av = a and a:GetAttribute(attribute)
        local bv = b and b:GetAttribute(attribute)
        return type(av) == "string" and av ~= "" and av == bv
    end

    local function isPartyMember(player)
        return player ~= nil
            and player ~= localPlayer
            and sameNonEmptyPlayerAttribute(localPlayer, player, "WarzPartyId")
    end

    local function isPlayerVulnerable(player, character)
        if not player then return false end
        if player:GetAttribute("CSGO_Dead") == true then return false end
        if character and character:GetAttribute("WarzDead") == true then return false end
        if not settings.vulnerabilityCheck then return true end
        if player:GetAttribute("WarzSaveZone") == true then return false end
        if character and character:GetAttribute("WarzSaveZone") == true then return false end
        local protectUntil = tonumber(player:GetAttribute("WarzProtectUntil")) or 0
        if protectUntil > Workspace.GetServerTimeNow(Workspace) then return false end
        return true
    end

    local function getPlayerRelationColor(player, character)
        if not player or player == localPlayer then return nil end
        if isPartyMember(player) then
            return PARTY_COLOR
        end
        if sameNonEmptyPlayerAttribute(localPlayer, player, "ClanId") then
            return CLAN_COLOR
        end
        if not isPlayerVulnerable(player, character) then
            return Color3.fromRGB(130, 190, 255)
        end
        return nil
    end

    local weaponIconCache = {}
    local weaponIconConfig = nil

    local function rebuildWeaponIconCache(config)
        table.clear(weaponIconCache)
        weaponIconConfig = config
        local shop = type(config) == "table" and config.Shop or nil
        if type(shop) ~= "table" then return end

        for key, item in pairs(shop) do
            if type(item) == "table" then
                local icon = item.StoreIcon
                if type(icon) == "string" and icon ~= "" then
                    weaponIconCache[tostring(key)] = icon
                    if type(item.Id) == "string" and item.Id ~= "" then
                        weaponIconCache[item.Id] = icon
                    end
                    if type(item.FNAME) == "string" and item.FNAME ~= "" then
                        weaponIconCache[item.FNAME] = icon
                    end
                end
            end
        end
    end

    local function getWeaponIconSource(weaponId)
        if type(weaponId) ~= "string" or weaponId == "" then
            return nil
        end

        local cached = weaponIconCache[weaponId]
        if cached then return cached end

        local config = getSharedConfig()
        if config and config ~= weaponIconConfig then
            rebuildWeaponIconCache(config)
            return weaponIconCache[weaponId]
        end
        return nil
    end

    local function getRenderedWeaponId(character, live)
        local drift = live and live.Parent
        local heldModel = drift and drift:FindFirstChild("HeroHeldGunRemote")
        if heldModel then
            local catalogId = heldModel:GetAttribute("WarzCatalogId")
            if type(catalogId) == "string" and catalogId ~= "" then
                return catalogId
            end
        end

        local fallback = character and character:GetAttribute("HeldWeapon")
        return type(fallback) == "string" and fallback ~= "" and fallback or nil
    end

    -- WarZ renders the visible, animated body in
    -- Workspace.HeroVisualsLocal.Drift_<PlayerName>.LiveAim.
    -- LiveAim contains the real animated Bip01 Bone hierarchy under RootPart.
    -- Use those bones directly: WarzHitboxes uses the same Bip01 names.
    local function getLiveAim(player)
        if not player then return nil end
        local hv = Workspace:FindFirstChild("HeroVisualsLocal")
        if not hv then return nil end
        local drift = hv:FindFirstChild("Drift_" .. player.Name)
        if not drift then return nil end
        return drift:FindFirstChild("LiveAim")
    end

    local LIVEAIM_BONES = {
        { "Bip01_Head", "Bip01_Neck" },
        { "Bip01_Neck", "Bip01_Spine2" },
        { "Bip01_Spine2", "Bip01_Spine1" },
        { "Bip01_Spine1", "Bip01_Spine" },
        { "Bip01_Spine", "Bip01_Pelvis" },

        { "Bip01_Neck", "Bip01_L_Clavicle" },
        { "Bip01_L_Clavicle", "Bip01_L_UpperArm" },
        { "Bip01_L_UpperArm", "Bip01_L_Forearm" },
        { "Bip01_L_Forearm", "Bip01_L_Hand" },

        { "Bip01_Neck", "Bip01_R_Clavicle" },
        { "Bip01_R_Clavicle", "Bip01_R_UpperArm" },
        { "Bip01_R_UpperArm", "Bip01_R_Forearm" },
        { "Bip01_R_Forearm", "Bip01_R_Hand" },

        { "Bip01_Pelvis", "Bip01_L_Thigh" },
        { "Bip01_L_Thigh", "Bip01_L_Calf" },
        { "Bip01_L_Calf", "Bip01_L_Foot" },

        { "Bip01_Pelvis", "Bip01_R_Thigh" },
        { "Bip01_R_Thigh", "Bip01_R_Calf" },
        { "Bip01_R_Calf", "Bip01_R_Foot" },
    }
    local LIVEAIM_BONE_COUNT = #LIVEAIM_BONES

    local function findLiveBone(live, name)
        local root = live and live:FindFirstChild("RootPart")
        if not root then return nil end
        local bone = root:FindFirstChild(name, true)
        return bone and bone:IsA("Bone") and bone or nil
    end

    local function boneWorldPosition(bone)
        if not bone or not bone.Parent then return nil end
        local ok, pos = pcall(function()
            return bone.TransformedWorldCFrame.Position
        end)
        if ok and typeof(pos) == "Vector3" then return pos end
        ok, pos = pcall(function()
            return bone.WorldPosition
        end)
        return (ok and typeof(pos) == "Vector3") and pos or nil
    end

    local function bodyPart(model, name)
        if not model then return nil end
        local part = model:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            return part
        end
        return nil
    end

    local function getVisualHead(character)
        local player = Players:GetPlayerFromCharacter(character)
        local live = getLiveAim(player)
        local head = live and live:FindFirstChild("Head")
        if head and head:IsA("BasePart") and head.Transparency < 1 then
            return head, live
        end
        return bodyPart(character, "Head"), live
    end

    -- WarzHitboxes builds its Chest capsule from Bip01_Spine2 -> Bip01_Neck.
    -- Aim at the middle of that exact animated segment instead of guessing
    -- from the merged Body mesh. This stays inside the game's real hit volume.
    local AIM_POSITION_OPTIONS = { "Auto", "Head", "Neck", "Body", "Waist", "Arms", "Legs" }

    local BONE_GROUPS = {
        Head = { "Bip01_Head" },
        Neck = { "Bip01_Neck" },
        Body = { "Bip01_Spine2", "Bip01_Neck" },
        Waist = { "Bip01_Spine", "Bip01_Pelvis" },
        Arms = {
            "Bip01_L_UpperArm", "Bip01_L_Forearm", "Bip01_L_Hand",
            "Bip01_R_UpperArm", "Bip01_R_Forearm", "Bip01_R_Hand",
        },
        Legs = {
            "Bip01_L_Thigh", "Bip01_L_Calf", "Bip01_L_Foot",
            "Bip01_R_Thigh", "Bip01_R_Calf", "Bip01_R_Foot",
        },
        Auto = {
            "Bip01_Head", "Bip01_Neck", "Bip01_Spine2", "Bip01_Spine1",
            "Bip01_Spine", "Bip01_Pelvis",
            "Bip01_L_UpperArm", "Bip01_L_Forearm", "Bip01_L_Hand",
            "Bip01_R_UpperArm", "Bip01_R_Forearm", "Bip01_R_Hand",
            "Bip01_L_Thigh", "Bip01_L_Calf", "Bip01_L_Foot",
            "Bip01_R_Thigh", "Bip01_R_Calf", "Bip01_R_Foot",
        },
    }

    local SHAPE_GROUPS = {
        Head = { Bip01_Head = true },
        Neck = { Throat = true, Bip01_Neck = true },
        Body = { Chest = true, Bip01_Spine2 = true },
        Waist = { Waist = true, Bip01_Spine = true, Bip01_Pelvis = true },
        Arms = {
            Bip01_L_UpperArm = true, Bip01_L_Forearm = true, Bip01_L_Hand = true,
            Bip01_R_UpperArm = true, Bip01_R_Forearm = true, Bip01_R_Hand = true,
        },
        Legs = {
            Bip01_L_Thigh = true, Bip01_L_Calf = true, Bip01_L_Foot = true, Bip01_L_Toe0 = true,
            Bip01_R_Thigh = true, Bip01_R_Calf = true, Bip01_R_Foot = true, Bip01_R_Toe0 = true,
        },
    }

    local function shapeAllowed(mode, name)
        if mode == "Auto" then return true end
        local group = SHAPE_GROUPS[mode]
        return group ~= nil and group[name] == true
    end

    local function closestScreenPoint(points, shapeMode)
        local center = camera.ViewportSize / 2
        local bestPoint, bestName, bestPixels = nil, nil, math.huge
        for _, item in ipairs(points) do
            local point, name = item.point, item.name
            if shapeMode then
                point = shapeAllowed(shapeMode, name) and typeof(item.cf) == "CFrame"
                    and item.cf.Position or nil
            end
            if typeof(point) == "Vector3" then
                local view, on = camera.WorldToViewportPoint(camera, point)
                if on and view.Z > 0 then
                    local pixels = (Vector2.new(view.X, view.Y) - center).Magnitude
                    if pixels < bestPixels then
                        bestPoint, bestName, bestPixels = point, name, pixels
                    end
                end
            end
        end
        return bestPoint, bestName, bestPixels
    end

    local function getBoneAimPoint(character, mode)
        mode = BONE_GROUPS[mode] and mode or "Auto"
        local player = Players:GetPlayerFromCharacter(character)
        local live = getLiveAim(player)
        if live then
            local points = {}
            for _, boneName in ipairs(BONE_GROUPS[mode]) do
                local pos = boneWorldPosition(findLiveBone(live, boneName))
                if pos then
                    table.insert(points, { point = pos, name = boneName })
                end
            end

            -- Chest/Waist represent volumes between two bones; their midpoint
            -- is a better broad-phase estimate than either endpoint alone.
            if mode == "Body" then
                local a = boneWorldPosition(findLiveBone(live, "Bip01_Spine2"))
                local b = boneWorldPosition(findLiveBone(live, "Bip01_Neck"))
                if a and b then return a:Lerp(b, 0.5), "ChestBone" end
            elseif mode == "Waist" then
                local a = boneWorldPosition(findLiveBone(live, "Bip01_Spine"))
                local b = boneWorldPosition(findLiveBone(live, "Bip01_Pelvis"))
                if a and b then return a:Lerp(b, 0.5), "WaistBone" end
            end

            local point, name = closestScreenPoint(points)
            if point then return point, name end
        end

        local fallback = bodyPart(character, "UpperTorso")
            or bodyPart(character, "Torso")
            or bodyPart(character, "Head")
            or bodyPart(character, "HumanoidRootPart")
        return fallback and fallback.Position or nil, fallback and fallback.Name or nil
    end

    local function getExactAimPoint(character, mode, requireDataShapes)
        mode = BONE_GROUPS[mode] and mode or "Auto"

        -- WarzHitboxes.DataShapes returns the exact current geometry used by
        -- the game. Resolve it lazily; bone aim remains the safe fallback.
        local warzHitboxes = getWarzHitboxes()
        if warzHitboxes and type(warzHitboxes.DataShapes) == "function" then
            local ok, shapes = pcall(warzHitboxes.DataShapes, character, false)
            if ok and type(shapes) == "table" then
                local point, name = closestScreenPoint(shapes, mode)
                if point then return point, name end
            end
        end
        if requireDataShapes and character:GetAttribute("WarzDataHitboxes") == true then return nil end
        return getBoneAimPoint(character, mode)
    end

    -- Lightweight screen bounds. The old path projected every corner of
    -- every visible body mesh (32+ WorldToViewportPoint calls per player, and
    -- up to 120 on the fallback character). WarZ's LiveAim already exposes
    -- Head/Arms/Body/Legs, so a few extremity samples give the same useful ESP
    -- Highly optimized 2-point screen bounds. Eliminates 8-point extremity projections
    -- and closure allocations per player per frame. Standard WarZPVP character proportions:
    -- height ~5.8 studs, width ~0.58 ratio.
    local function characterScreenBounds(model)
        local root = bodyPart(model, "HumanoidRootPart") or bodyPart(model, "Torso")
        if not root then return nil end

        local rootPos = root.Position
        local topPos = rootPos + Vector3.new(0, 2.7, 0)
        local botPos = rootPos - Vector3.new(0, 3.1, 0)

        local topView = camera.WorldToViewportPoint(camera, topPos)
        if topView.Z <= 0 then return nil end
        local botView = camera.WorldToViewportPoint(camera, botPos)
        if botView.Z <= 0 then return nil end

        local h = math.abs(botView.Y - topView.Y)
        local w = h * 0.58
        local centerY = (topView.Y + botView.Y) * 0.5
        local centerX = (topView.X + botView.X) * 0.5
        local minX = centerX - w * 0.5
        local minY = centerY - h * 0.5

        local vs = camera.ViewportSize
        if h < 4 or w < 2 or h > vs.Y * 2 or w > vs.X * 2
            or minX + w < 0 or minX > vs.X or minY + h < 0 or minY > vs.Y then
            return nil
        end
        return {
            x = minX, y = minY, w = w, h = h,
            centerX = centerX,
        }
    end

    -- [[ Player ESP entries (Drawing API, zero instances) ]]
    local function getEntry(p)
        local e = espCache[p]
        if e then return e end
        e = {
            box = safeDrawing("Square"),
            name = safeDrawing("Text"),
            hpBack = safeDrawing("Square"),
            hpFill = safeDrawing("Square"),
            weaponIcon = nil,
            weaponIconSource = nil,
        }
        if e.box then
            e.box.Thickness = 2
            e.box.Filled = false
            e.box.Color = ESP_COLOR
            e.box.Visible = false
        end
        if e.name then
            e.name.Size = 14
            e.name.Center = true
            e.name.Outline = true
            e.name.Color = Color3.fromRGB(255, 255, 255)
            e.name.Visible = false
        end
        if e.hpBack then
            e.hpBack.Filled = true
            e.hpBack.Color = Color3.fromRGB(20, 20, 20)
            e.hpBack.Visible = false
        end
        if e.hpFill then
            e.hpFill.Filled = true
            e.hpFill.Visible = false
        end
        if e.weaponIcon then
            e.weaponIcon.Color = Color3.new(1, 1, 1)
            e.weaponIcon.Transparency = 1
            e.weaponIcon.Visible = false
        end
        e.bones = {}
        e.boneParts = {}
        e.boneNodes = {}
        e.boneCharacter = nil
        e.liveAim = nil
        e.liveAimRetryAt = 0
        e.boneResolvedFor = nil
        e.boneReady = false
        espCache[p] = e
        return e
    end

    local function ensureWeaponIcon(e)
        if e.weaponIcon then return e.weaponIcon end
        local icon = safeImage()
        if not icon then return nil end
        icon.Color = Color3.new(1, 1, 1)
        icon.Transparency = 1
        icon.Visible = false
        e.weaponIcon = icon
        return icon
    end

    local function ensureSkeletonDrawings(e)
        if e.bones[1] then return end
        for i = 1, LIVEAIM_BONE_COUNT do
            local ln = safeDrawing("Line")
            if ln then
                ln.Thickness = 2
                ln.Transparency = 1
                ln.Color = ESP_COLOR
                ln.Visible = false
                e.bones[i] = ln
            end
        end
    end

    local function resolveLiveAim(e, ch, player)
        if e.boneCharacter ~= ch then
            e.boneCharacter = ch
            e.liveAim = nil
            e.liveAimRetryAt = 0
            e.boneResolvedFor = nil
            e.boneReady = false
            table.clear(e.boneParts)
            table.clear(e.boneNodes)
        end

        local live = e.liveAim
        if live and live.Parent then
            return live
        end

        local now = os.clock()
        if now < (e.liveAimRetryAt or 0) then
            return nil
        end
        e.liveAimRetryAt = now + 0.5
        live = getLiveAim(player)
        e.liveAim = live
        return live
    end

    local function resolveSkeletonParts(e, ch, player)
        local live = resolveLiveAim(e, ch, player)
        if not live then
            e.boneReady = false
            return nil
        end
        if e.boneResolvedFor == live then
            return live
        end

        e.boneResolvedFor = live
        table.clear(e.boneParts)
        table.clear(e.boneNodes)
        e.boneReady = true

        local seen = {}
        for i, segment in ipairs(LIVEAIM_BONES) do
            local a = findLiveBone(live, segment[1])
            local b = findLiveBone(live, segment[2])
            if a and b then
                e.boneParts[i] = { a, b }
                if not seen[a] then
                    seen[a] = true
                    e.boneNodes[#e.boneNodes + 1] = a
                end
                if not seen[b] then
                    seen[b] = true
                    e.boneNodes[#e.boneNodes + 1] = b
                end
            else
                e.boneParts[i] = false
                e.boneReady = false
            end
        end
        return live
    end

    local function hideEntry(e)
        for _, d in pairs({ e.box, e.name, e.hpBack, e.hpFill, e.weaponIcon }) do
            if d then pcall(function() d.Visible = false end) end
        end
        for _, line in pairs(e.bones or {}) do
            if line then pcall(function() line.Visible = false end) end
        end
    end

    local function destroyEntry(p)
        local e = espCache[p]
        if not e then return end
        for _, d in pairs({ e.box, e.name, e.hpBack, e.hpFill, e.weaponIcon }) do
            if d then pcall(function() d:Remove() end) end
        end
        for _, line in pairs(e.bones or {}) do
            if line then pcall(function() line:Remove() end) end
        end
        espCache[p] = nil
    end

    local function isAlive(ch)
        if not ch then return false end
        if ch:GetAttribute("WarzDead") == true then return false end
        local hum = ch:FindFirstChildOfClass("Humanoid")
        return hum ~= nil and hum.Health > 0
    end

    local menuOpen = false
    local cachedMenuRect = nil

    -- Drawing API may render above ScreenGui on some executors. Instead of
    -- hiding all ESP while N3Z is open, clip only drawings that overlap the
    -- visible panel rectangle. Cached once per frame in updateMenuState().
    local function getMenuPanelRect()
        return cachedMenuRect
    end

    local function rectOverlapsMenu(x, y, w, h, rect)
        if not rect then return false end
        return x < rect.x + rect.w and x + w > rect.x
            and y < rect.y + rect.h and y + h > rect.y
    end

    local function pointInMenu(p, rect)
        return rect ~= nil
            and p.X >= rect.x and p.X <= rect.x + rect.w
            and p.Y >= rect.y and p.Y <= rect.y + rect.h
    end

    local function segmentOverlapsMenu(a, b, rect)
        if not rect then return false end
        if pointInMenu(a, rect) or pointInMenu(b, rect) then return true end

        -- Liang-Barsky segment/rectangle intersection.
        local dx, dy = b.X - a.X, b.Y - a.Y
        local t0, t1 = 0, 1
        local function clip(pv, qv)
            if math.abs(pv) < 1e-6 then return qv >= 0 end
            local r = qv / pv
            if pv < 0 then
                if r > t1 then return false end
                if r > t0 then t0 = r end
            else
                if r < t0 then return false end
                if r < t1 then t1 = r end
            end
            return true
        end
        return clip(-dx, a.X - rect.x)
            and clip(dx, rect.x + rect.w - a.X)
            and clip(-dy, a.Y - rect.y)
            and clip(dy, rect.y + rect.h - a.Y)
    end

    local function textOverlapsMenu(d, rect)
        if not d or not rect then return false end
        local pos = d.Position
        if not pos then return false end
        local bounds = d.TextBounds
        if not bounds then
            return pointInMenu(pos, rect)
        end
        local x = pos.X - ((d.Center == true) and bounds.X * 0.5 or 0)
        local y = pos.Y
        return rectOverlapsMenu(x, y, bounds.X, bounds.Y, rect)
    end

    local espFrameBucket = 0
    local espPerf = {
        lastMs = 0,
        avgMs = 0,
        peakMs = 0,
        bucketCount = 1,
        processed = 0,
    }

    local function updatePlayerEsp(playersList)
        local startedAt = os.clock()
        if not settings.espEnabled then
            for _, e in pairs(espCache) do hideEntry(e) end
            espPerf.lastMs = (os.clock() - startedAt) * 1000
            return
        end

        local players = playersList or Players:GetPlayers()
        local playerCount = math.max(0, #players - (settings.selfEsp and 0 or 1))
        -- At crowded fights split ESP work across alternating frames. On a
        -- 60 Hz client every player still refreshes at 30 Hz; at 120 Hz it is
        -- effectively 60 Hz, while worst-frame cost is roughly halved.
        local bucketCount = playerCount >= 24 and 2 or 1
        espFrameBucket = (espFrameBucket % bucketCount) + 1
        espPerf.bucketCount = bucketCount

        local processed = 0
        local camPos = camera.CFrame.Position
        local camLook = camera.CFrame.LookVector
        local maxDistanceSq = settings.maxDistance * settings.maxDistance
        local menuRect = cachedMenuRect
        local serverTime = Workspace.GetServerTimeNow(Workspace)

        for _, p in ipairs(players) do
            if p ~= localPlayer or settings.selfEsp then
                local bucket = (math.abs(p.UserId) % bucketCount) + 1
                if bucketCount == 1 or bucket == espFrameBucket then
                    processed += 1
                    local e = getEntry(p)
                    local ch = p.Character
                    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                    local alive = ch and ch:GetAttribute("WarzDead") ~= true
                        and hum ~= nil and hum.Health > 0

                    if hrp and alive then
                        local delta = hrp.Position - camPos
                        -- Frustum check: dot product with look vector. If behind the camera, skip completely.
                        if camLook:Dot(delta) > -5 then
                            local distanceSq = delta:Dot(delta)
                            if distanceSq <= maxDistanceSq then
                                local bounds = characterScreenBounds(ch)
                                if bounds then
                                    local h, w = bounds.h, bounds.w
                                    local x0, y0 = bounds.x, bounds.y
                                    local relationColor = getPlayerRelationColor(p, ch)
                                    local live = (settings.skeletonEsp or settings.weaponEsp) and resolveLiveAim(e, ch, p) or nil
                                    local weaponId = settings.weaponEsp and getRenderedWeaponId(ch, live) or nil
                                    local weaponIconSource = getWeaponIconSource(weaponId)

                                    if settings.boxEsp and e.box then
                                        e.box.Color = relationColor or ESP_COLOR
                                        e.box.Size = Vector2.new(w, h)
                                        e.box.Position = Vector2.new(x0, y0)
                                        e.box.Visible = not rectOverlapsMenu(x0, y0, w, h, menuRect)
                                    elseif e.box then
                                        e.box.Visible = false
                                    end

                                    if (settings.nameEsp or settings.distanceEsp) and e.name then
                                        local label = p.Name
                                        local isSafe = p:GetAttribute("WarzSaveZone") == true or (ch and ch:GetAttribute("WarzSaveZone") == true)
                                        local protectUntil = tonumber(p:GetAttribute("WarzProtectUntil")) or 0
                                        local isProtected = protectUntil > serverTime
                                        if isSafe then
                                            label = label .. " [SAFE]"
                                        elseif isProtected then
                                            label = label .. " [PROT]"
                                        end
                                        if settings.weaponEsp and not weaponIconSource
                                            and type(weaponId) == "string" and weaponId ~= "" then
                                            label = label .. " [" .. weaponId .. "]"
                                        end
                                        if settings.distanceEsp then
                                            label = label .. " " .. math.floor(math.sqrt(distanceSq)) .. "m"
                                        end
                                        e.name.Text = label
                                        e.name.Position = Vector2.new(bounds.centerX, y0 - 18)
                                        e.name.Color = relationColor or Color3.fromRGB(255, 255, 255)
                                        e.name.Visible = not textOverlapsMenu(e.name, menuRect)
                                    elseif e.name then
                                        e.name.Visible = false
                                    end

                                    if settings.weaponEsp and weaponIconSource then
                                        local weaponIcon = ensureWeaponIcon(e)
                                        if weaponIcon then
                                            local iconW = math.clamp(w * 0.9, 38, 72)
                                            local iconH = math.clamp(iconW * 0.5, 20, 36)
                                            local iconX = bounds.centerX - iconW * 0.5
                                            local iconY = y0 + h + 4
                                            if e.weaponIconSource ~= weaponIconSource then
                                                e.weaponIconSource = weaponIconSource
                                                weaponIcon.Image = weaponIconSource
                                            end
                                            weaponIcon.Size = Vector2.new(iconW, iconH)
                                            weaponIcon.Position = Vector2.new(iconX, iconY)
                                            weaponIcon.Visible = not rectOverlapsMenu(
                                                iconX, iconY, iconW, iconH, menuRect
                                            )
                                        end
                                    elseif e.weaponIcon then
                                        e.weaponIcon.Visible = false
                                    end

                                    if settings.healthEsp and e.hpBack and e.hpFill then
                                        local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                                        local bw = 4
                                        e.hpBack.Size = Vector2.new(bw, h)
                                        e.hpBack.Position = Vector2.new(x0 - bw - 2, y0)
                                        e.hpBack.Visible = not rectOverlapsMenu(x0 - bw - 2, y0, bw, h, menuRect)
                                        local fillH = h * ratio
                                        local fillY = y0 + h * (1 - ratio)
                                        e.hpFill.Size = Vector2.new(bw, fillH)
                                        e.hpFill.Position = Vector2.new(x0 - bw - 2, fillY)
                                        e.hpFill.Color = getHealthColor(ratio)
                                        e.hpFill.Visible = not rectOverlapsMenu(x0 - bw - 2, fillY, bw, fillH, menuRect)
                                    else
                                        if e.hpBack then e.hpBack.Visible = false end
                                        if e.hpFill then e.hpFill.Visible = false end
                                    end

                                    if settings.skeletonEsp and distanceSq <= 160000 then
                                        ensureSkeletonDrawings(e)
                                        resolveSkeletonParts(e, ch, p)

                                        -- Project each unique bone once.
                                        local projected = {}
                                        for _, bone in ipairs(e.boneNodes) do
                                            local pos = boneWorldPosition(bone)
                                            if pos then
                                                local view, onScreen = camera.WorldToViewportPoint(camera, pos)
                                                if onScreen and view.Z > 0 then
                                                    projected[bone] = Vector2.new(view.X, view.Y)
                                                end
                                            end
                                        end

                                        for i = 1, LIVEAIM_BONE_COUNT do
                                            local ln = e.bones[i]
                                            local pair = e.boneParts[i]
                                            if ln then
                                                ln.Color = relationColor or ESP_COLOR
                                                local from = pair and projected[pair[1]]
                                                local to = pair and projected[pair[2]]
                                                if from and to then
                                                    ln.From = from
                                                    ln.To = to
                                                    ln.Visible = not segmentOverlapsMenu(from, to, menuRect)
                                                else
                                                    ln.Visible = false
                                                end
                                            end
                                        end
                                    else
                                        for _, ln in pairs(e.bones) do
                                            if ln then ln.Visible = false end
                                        end
                                    end
                                else
                                    hideEntry(e)
                                end
                            else
                                hideEntry(e)
                            end
                        else
                            hideEntry(e)
                        end
                    else
                        hideEntry(e)
                    end
                end
            elseif espCache[p] then
                hideEntry(espCache[p])
            end
        end

        local elapsedMs = (os.clock() - startedAt) * 1000
        espPerf.lastMs = elapsedMs
        espPerf.avgMs = espPerf.avgMs == 0 and elapsedMs
            or (espPerf.avgMs * 0.9 + elapsedMs * 0.1)
        espPerf.peakMs = math.max(espPerf.peakMs * 0.995, elapsedMs)
        espPerf.processed = processed
    end

    -- [[ Loot ESP: read-only labels for drops under Workspace.WarzLoot ]]
    -- Loot models look like "Loot_ARMOR_Rebel_Heavy" / "Loot_HEADHELMET"
    -- with PrimaryPart = "LootMarker". No remotes, no hooks â€” Drawing only.
    local lootCache = {} -- [model] = cached metadata + lazily-created Drawing text
    local lootCategories = { "All" }
    local lootCategorySet = { All = true }
    local lootCategoryDropdown = nil
    local lootFolder = nil
    local lootAddedConnection = nil
    local lootRemovedConnection = nil

    local function parseLootName(modelName)
        local rest = modelName
        if rest:sub(1, 5) == "Loot_" then
            rest = rest:sub(6)
        end
        local parts = {}
        for tok in rest:gmatch("[^_]+") do
            table.insert(parts, tok)
        end
        local category = parts[1] or rest
        local itemName = category
        if #parts > 1 then
            itemName = table.concat(parts, " ", 2)
        end
        return category, itemName
    end

    local function lootAnchor(model)
        local pp = model.PrimaryPart
        if pp then return pp end
        local marker = model:FindFirstChild("LootMarker")
        if marker then return marker end
        for _, d in ipairs(model:GetChildren()) do
            if d:IsA("BasePart") then return d end
        end
        return nil
    end

    local function lootAnchorPos(anchor)
        if anchor == nil then return nil end
        if anchor:IsA("BasePart") then return anchor.Position end
        return anchor.WorldPosition
    end

    local function lootCategoryAllowed(category)
        return settings.lootCategory == "All" or settings.lootCategory == category
    end

    local function noteLootCategory(category)
        if lootCategorySet[category] then return end
        lootCategorySet[category] = true
        table.insert(lootCategories, category)
        if lootCategoryDropdown and type(lootCategoryDropdown.SetOptions) == "function" then
            pcall(function() lootCategoryDropdown:SetOptions(lootCategories) end)
        end
    end

    local function ensureLootDrawing(entry)
        if entry.text then return entry.text end
        local t = safeDrawing("Text")
        if t then
            t.Size = 13
            t.Center = true
            t.Outline = true
            t.Color = Color3.fromRGB(255, 255, 255)
            t.Visible = false
        end
        entry.text = t
        return t
    end

    local function registerLoot(model)
        if not model or not model:IsA("Model") then return nil end
        local entry = lootCache[model]
        if entry then
            if not entry.anchor or not entry.anchor.Parent then
                entry.anchor = lootAnchor(model)
            end
            return entry
        end

        local category, itemName = parseLootName(model.Name)
        noteLootCategory(category)
        entry = {
            text = nil,
            anchor = lootAnchor(model),
            category = category,
            itemName = itemName,
            labelPrefix = itemName .. " [" .. category .. "] ",
            lastDistance = nil,
        }
        lootCache[model] = entry
        return entry
    end

    local function destroyLootEntry(model)
        local entry = lootCache[model]
        if not entry then return end
        if entry.text then
            pcall(function() entry.text:Remove() end)
        end
        lootCache[model] = nil
    end

    local function clearLootCache()
        local models = {}
        for model in pairs(lootCache) do
            table.insert(models, model)
        end
        for _, model in ipairs(models) do
            destroyLootEntry(model)
        end
    end

    local function disconnectLootFolder()
        if lootAddedConnection then
            pcall(function() lootAddedConnection:Disconnect() end)
            lootAddedConnection = nil
        end
        if lootRemovedConnection then
            pcall(function() lootRemovedConnection:Disconnect() end)
            lootRemovedConnection = nil
        end
    end

    local function bindLootFolder(folder)
        if folder == lootFolder then return end
        disconnectLootFolder()
        clearLootCache()
        lootFolder = folder
        if not lootFolder then return end

        for _, model in ipairs(lootFolder:GetChildren()) do
            registerLoot(model)
        end

        lootAddedConnection = lootFolder.ChildAdded:Connect(function(model)
            if running then
                registerLoot(model)
            end
        end)
        lootRemovedConnection = lootFolder.ChildRemoved:Connect(function(model)
            destroyLootEntry(model)
        end)
    end

    local function syncLootFolder()
        local folder = Workspace:FindFirstChild("WarzLoot")
        if folder ~= lootFolder then
            bindLootFolder(folder)
        end
    end

    local function hideLootEntry(entry)
        if entry and entry.text then
            entry.text.Visible = false
        end
    end

    local lastLootSync = 0
    local function updateLootEsp()
        local now = os.clock()
        if now - lastLootSync >= 2.0 then
            lastLootSync = now
            syncLootFolder()
        end

        if not settings.lootEsp then
            for _, entry in pairs(lootCache) do
                hideLootEntry(entry)
            end
            return
        end

        local cam = camera
        if not cam then return end

        local camPos = cam.CFrame.Position
        local camLook = cam.CFrame.LookVector
        local maxDistance = settings.lootMaxDistance
        local maxDistanceSq = maxDistance * maxDistance
        local menuRect = cachedMenuRect

        for model, entry in pairs(lootCache) do
            if model.Parent ~= lootFolder or not lootCategoryAllowed(entry.category) then
                hideLootEntry(entry)
            else
                local anchor = entry.anchor
                if not anchor or not anchor.Parent then
                    anchor = lootAnchor(model)
                    entry.anchor = anchor
                end

                local apos = lootAnchorPos(anchor)
                if apos then
                    local delta = apos - camPos
                    if camLook:Dot(delta) > 0 then
                        local distanceSq = delta:Dot(delta)
                        if distanceSq <= maxDistanceSq then
                            local viewport, onScreen = cam.WorldToViewportPoint(cam, apos)
                            if onScreen and viewport.Z > 0 then
                                local text = ensureLootDrawing(entry)
                                if text then
                                    local roundedDistance = math.floor(math.sqrt(distanceSq) + 0.5)
                                    if entry.lastDistance ~= roundedDistance then
                                        entry.lastDistance = roundedDistance
                                        text.Text = entry.labelPrefix .. roundedDistance .. "m"
                                    end
                                    text.Position = Vector2.new(viewport.X, viewport.Y)
                                    text.Visible = not textOverlapsMenu(text, menuRect)
                                end
                            else
                                hideLootEntry(entry)
                            end
                        else
                            hideLootEntry(entry)
                        end
                    else
                        hideLootEntry(entry)
                    end
                else
                    hideLootEntry(entry)
                end
            end
        end
    end

    syncLootFolder()
    -- [[ Boss ESP: read-only box + name/distance + HP bar, spawn alert ]]
    -- Boss lives under Workspace.WarzBoss (observed: "SuperZombie", 5000 HP).
    local bossDraw = nil
    local bossAlertText = nil
    local bossWasPresent = false
    local bossAlertUntil = 0

    local function getBossModel()
        local folder = Workspace:FindFirstChild("WarzBoss")
        if not folder then return nil end
        local named = folder:FindFirstChild("SuperZombie")
        if named and named:IsA("Model") then return named end
        for _, c in ipairs(folder:GetChildren()) do
            if c:IsA("Model") and c:FindFirstChildOfClass("Humanoid") then
                return c
            end
        end
        return nil
    end

    local function ensureBossDraw()
        if bossDraw then return bossDraw end
        local box = safeDrawing("Square")
        if box then
            box.Thickness = 2
            box.Filled = false
            box.Color = Color3.fromRGB(255, 60, 60)
        end
        local name = safeDrawing("Text")
        if name then
            name.Size = 14
            name.Center = true
            name.Outline = true
            name.Color = Color3.fromRGB(255, 120, 120)
        end
        local hpBg = safeDrawing("Square")
        if hpBg then
            hpBg.Filled = true
            hpBg.Color = Color3.fromRGB(20, 20, 20)
        end
        local hpFill = safeDrawing("Square")
        if hpFill then
            hpFill.Filled = true
            hpFill.Color = Color3.fromRGB(60, 220, 90)
        end
        bossDraw = { box = box, name = name, hpBg = hpBg, hpFill = hpFill }
        return bossDraw
    end

    local function hideBossEsp()
        if bossDraw then
            for _, d in pairs(bossDraw) do
                if d then pcall(function() d.Visible = false end) end
            end
        end
    end

    local function updateBossEsp()
        if bossAlertText then
            local showAlert = settings.bossAlert and os.clock() < bossAlertUntil
            local menuRect = getMenuPanelRect()
            pcall(function()
                bossAlertText.Visible = showAlert and not textOverlapsMenu(bossAlertText, menuRect)
            end)
        end
        local model = settings.bossEsp and getBossModel() or nil
        if not model or not isAlive(model) then
            hideBossEsp()
            bossWasPresent = false
            return
        end
        if not bossWasPresent then
            bossWasPresent = true
            if settings.bossAlert then
                if not bossAlertText then
                    local t = safeDrawing("Text")
                    if t then
                        t.Size = 22
                        t.Center = true
                        t.Outline = true
                        t.Color = Color3.fromRGB(255, 80, 80)
                        local vs = camera.ViewportSize
                        t.Position = Vector2.new(vs.X / 2, vs.Y * 0.25)
                    end
                    bossAlertText = t
                end
                if bossAlertText then
                    bossAlertText.Text = "!! BOSS SPAWNED !!"
                    bossAlertUntil = os.clock() + 5
                    pcall(function() bossAlertText.Visible = true end)
                end
            end
        end
        local d = ensureBossDraw()
        local menuRect = getMenuPanelRect()
        local hrp = model:FindFirstChild("HumanoidRootPart")
        local hum = model:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or not hum.MaxHealth or hum.MaxHealth <= 0 then
            hideBossEsp()
            return
        end
        local dist = (hrp.Position - camera.CFrame.Position).Magnitude
        local bounds = characterScreenBounds(model)
        if not bounds then
            hideBossEsp()
            return
        end
        local w, h = bounds.w, bounds.h
        local x0, y0 = bounds.x, bounds.y
        if d.box then
            d.box.Size = Vector2.new(w, h)
            d.box.Position = Vector2.new(x0, y0)
            d.box.Visible = not rectOverlapsMenu(x0, y0, w, h, menuRect)
        end
        if d.name then
            d.name.Position = Vector2.new(bounds.centerX, y0 - 18)
            d.name.Text = string.format("%s %dm", model.Name, math.floor(dist + 0.5))
            d.name.Visible = not textOverlapsMenu(d.name, menuRect)
        end
        local frac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
        if d.hpBg then
            d.hpBg.Position = Vector2.new(x0 - 6, y0)
            d.hpBg.Size = Vector2.new(4, h)
            d.hpBg.Visible = not rectOverlapsMenu(x0 - 6, y0, 4, h, menuRect)
        end
        if d.hpFill then
            local fhh = h * frac
            local fhy = y0 + h - fhh
            d.hpFill.Position = Vector2.new(x0 - 6, fhy)
            d.hpFill.Size = Vector2.new(4, math.max(fhh, 1))
            d.hpFill.Visible = not rectOverlapsMenu(x0 - 6, fhy, 4, math.max(fhh, 1), menuRect)
        end
    end

    -- [[ Shared aim core: target selection, LOS, prediction and ballistics ]]
    local aimLockPlayer = nil
    local aimLockCharacter = nil
    local aimController = nil

    local function clearAimLock()
        aimLockPlayer, aimLockCharacter = nil, nil
    end

    local ballisticCacheWeaponId = nil
    local ballisticCache = nil
    local predictionState = {
        weaponId = nil,
        rawSpeed = 0,
        projectileSpeed = 0,
        mass = 0,
        travelTime = 0,
        immediate = false,
    }

    local function getCurrentBallistics()
        local combatSettings = getCombatSettings()
        if type(combatSettings) ~= "table"
            or type(combatSettings.BallisticsFor) ~= "function" then
            ballisticCacheWeaponId = nil
            ballisticCache = nil
            return nil
        end

        local weaponId = combatSettings.CurrentWeaponId
        if type(weaponId) ~= "string" or weaponId == "" then
            ballisticCacheWeaponId = nil
            ballisticCache = nil
            return nil
        end
        if weaponId == ballisticCacheWeaponId and ballisticCache then
            return ballisticCache
        end

        local ok, data = pcall(combatSettings.BallisticsFor)
        if not ok or type(data) ~= "table" then
            ballisticCacheWeaponId = nil
            ballisticCache = nil
            return nil
        end

        local warzProjectile = getWarzProjectile()
        local rawSpeed = tonumber(data.Speed)
        local scale = type(warzProjectile) == "table" and tonumber(warzProjectile.Scale) or 2.687
        local mass = tonumber(data.Mass) or 1
        if not rawSpeed or rawSpeed <= 0 or not scale or scale <= 0 then
            ballisticCacheWeaponId = nil
            ballisticCache = nil
            return nil
        end

        local gravity = type(warzProjectile) == "table" and warzProjectile.Gravity
            or Vector3.new(0, -9.81 * scale, 0)
        if typeof(gravity) ~= "Vector3" then
            gravity = Vector3.new(0, -9.81 * scale, 0)
        end

        ballisticCacheWeaponId = weaponId
        ballisticCache = {
            weaponId = weaponId,
            rawSpeed = rawSpeed,
            speed = rawSpeed * scale,
            mass = mass,
            immediate = data.Immediate == true,
            gravity = gravity * mass,
            stepSeconds = type(warzProjectile) == "table"
                and tonumber(warzProjectile.StepSeconds) or (1 / 60),
            lifetime = type(warzProjectile) == "table"
                and tonumber(warzProjectile.Lifetime) or 5,
        }
        return ballisticCache
    end

    local function targetLinearVelocity(character)
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root or not root:IsA("BasePart") then
            return Vector3.zero
        end

        local velocity = root.AssemblyLinearVelocity
        if typeof(velocity) ~= "Vector3" then
            return Vector3.zero
        end

        -- Ignore replication/teleport spikes without affecting normal sprint,
        -- jump or dash movement.
        local speed = velocity.Magnitude
        if speed > 300 then
            velocity = velocity.Unit * 300
        elseif speed < 0.05 then
            velocity = Vector3.zero
        end
        return velocity
    end

    local function solveBallisticTime(relative, targetVelocity, ballistics)
        local projectileSpeed = ballistics.speed
        local maxTime = math.max(0.05, tonumber(ballistics.lifetime) or 5)
        local distance = relative.Magnitude
        if distance < 0.01 or projectileSpeed <= 0.01 then
            return 0
        end

        -- Exact constant-velocity intercept provides a stable initial guess.
        local vv = targetVelocity:Dot(targetVelocity)
        local rv = relative:Dot(targetVelocity)
        local a = vv - projectileSpeed * projectileSpeed
        local b = 2 * rv
        local c = relative:Dot(relative)
        local t = distance / projectileSpeed

        if math.abs(a) < 1e-6 then
            if math.abs(b) > 1e-6 then
                local linear = -c / b
                if linear > 0 then t = linear end
            end
        else
            local discriminant = b * b - 4 * a * c
            if discriminant >= 0 then
                local root = math.sqrt(discriminant)
                local t1 = (-b - root) / (2 * a)
                local t2 = (-b + root) / (2 * a)
                local best = math.huge
                if t1 > 0 then best = math.min(best, t1) end
                if t2 > 0 then best = math.min(best, t2) end
                if best < math.huge then t = best end
            end
        end

        t = math.clamp(t, 0, maxTime)

        -- WarzProjectile.Step is semi-implicit Euler:
        -- velocity += Gravity * Mass * dt, then displacement = velocity * dt.
        -- Fixed-point refinement below mirrors its extra +dt gravity term.
        local stepSeconds = tonumber(ballistics.stepSeconds) or (1 / 60)
        for _ = 1, 5 do
            local gravityTravel = ballistics.gravity * (0.5 * t * (t + stepSeconds))
            local required = relative + targetVelocity * t - gravityTravel
            local nextTime = math.clamp(required.Magnitude / projectileSpeed, 0, maxTime)
            if math.abs(nextTime - t) < 0.0001 then
                t = nextTime
                break
            end
            t = nextTime
        end
        return t
    end

    local function applyAimPrediction(point, character, shotOrigin)
        if not settings.aimPrediction or not point or not character then
            predictionState.travelTime = 0
            return point
        end

        local ballistics = getCurrentBallistics()
        if not ballistics then
            predictionState.weaponId = nil
            predictionState.travelTime = 0
            return point
        end

        predictionState.weaponId = ballistics.weaponId
        predictionState.rawSpeed = ballistics.rawSpeed
        predictionState.projectileSpeed = ballistics.speed
        predictionState.mass = ballistics.mass
        predictionState.immediate = ballistics.immediate

        if ballistics.immediate then
            predictionState.travelTime = 0
            return point
        end

        local origin = typeof(shotOrigin) == "Vector3" and shotOrigin or (camera and camera.CFrame.Position)
        if not origin then return point end

        local relative = point - origin
        local targetVelocity = targetLinearVelocity(character)
        local travelTime = solveBallisticTime(relative, targetVelocity, ballistics)
        predictionState.travelTime = travelTime

        if travelTime <= 0 then return point end

        local gravityTravel = ballistics.gravity
            * (0.5 * travelTime * (travelTime + ballistics.stepSeconds))
        return point + targetVelocity * travelTime - gravityTravel
    end
    local aimRayParams = RaycastParams.new()
    aimRayParams.FilterType = Enum.RaycastFilterType.Exclude
    aimRayParams.IgnoreWater = true
    local lastExcludeUpdate = 0
    local cachedExclude = {}

    local function updateAimRayExclude()
        local now = os.clock()
        if now - lastExcludeUpdate < 1.0 and #cachedExclude > 0 then return end
        lastExcludeUpdate = now
        table.clear(cachedExclude)
        if localPlayer.Character then table.insert(cachedExclude, localPlayer.Character) end
        local hvl = Workspace:FindFirstChild("HeroVisualsLocal")
        if hvl then
            local myDrift = hvl:FindFirstChild("Drift_" .. localPlayer.Name)
            if myDrift then
                table.insert(cachedExclude, myDrift)
            else
                table.insert(cachedExclude, hvl)
            end
        end
        aimRayParams.FilterDescendantsInstances = cachedExclude
    end

    local function canSeeAimPoint(character, point, shotOrigin)
        local origin = typeof(shotOrigin) == "Vector3" and shotOrigin or camera.CFrame.Position
        local direction = point - origin
        if direction.Magnitude < 0.01 then return false end

        updateAimRayExclude()

        local hit = Workspace.Raycast(Workspace, origin, direction, aimRayParams)
        if not hit then return true end
        if hit.Instance:IsDescendantOf(character) then return true end
        local hvl = Workspace:FindFirstChild("HeroVisualsLocal")
        if hvl and hit.Instance:IsDescendantOf(hvl) then return true end

        -- CanQuery is disabled on WarZ character/LiveAim parts, so an obstacle
        -- very near the target point should not incorrectly invalidate the lock.
        return (hit.Position - origin).Magnitude >= direction.Magnitude - 1.2
    end

    local function validAimPoint(character, maxFov, exact)
        if not isAlive(character) then return nil, nil end
        local point = exact
            and getExactAimPoint(character, settings.aimPosition)
            or getBoneAimPoint(character, settings.aimPosition)
        if not point then return nil, nil end
        if (point - camera.CFrame.Position).Magnitude > settings.aimMaxDist then
            return nil, nil
        end

        local view, on = camera.WorldToViewportPoint(camera, point)
        if not on or view.Z <= 0 then return nil, nil end
        local center = camera.ViewportSize / 2
        local pixels = (Vector2.new(view.X, view.Y) - center).Magnitude
        if pixels > maxFov then return nil, nil end
        return point, pixels
    end

    local function scanAimTarget(playersList)
        local players = playersList or Players:GetPlayers()
        local bestPoint, bestPlayer = nil, nil
        local bestPixels = settings.aimFov

        -- Single-pass O(N) search with zero candidate table allocations
        for _, p in ipairs(players) do
            local character = p.Character
            if p ~= localPlayer and not isPartyMember(p) and isPlayerVulnerable(p, character) then
                local point, pixels = validAimPoint(character, bestPixels, false)
                if point and pixels and pixels < bestPixels then
                    local exactPoint, exactPixels = validAimPoint(character, settings.aimFov, true)
                    if exactPoint and exactPixels and canSeeAimPoint(character, exactPoint) then
                        bestPixels = exactPixels
                        bestPoint = exactPoint
                        bestPlayer = p
                    end
                end
            end
        end
        return bestPoint, bestPlayer
    end

    local function getAimTarget(playersList)
        local player = aimLockPlayer
        if player then
            if isPartyMember(player) or not isPlayerVulnerable(player, aimLockCharacter) then
                aimLockPlayer, aimLockCharacter = nil, nil
            else
                local character = aimLockCharacter
                if character and player.Character == character then
                    local point = validAimPoint(character, settings.aimFov * 1.25, true)
                    if point and canSeeAimPoint(character, point) then
                        return point
                    end
                end
                aimLockPlayer, aimLockCharacter = nil, nil
            end
        end

        local best, bestP = scanAimTarget(playersList)
        aimLockPlayer = bestP
        aimLockCharacter = bestP and bestP.Character or nil
        return best
    end

    local function getSilentAimPoint(character, boneName)
        if not character then return nil end
        boneName = boneName or settings.silentAimBone or settings.silentBone or "Auto"
        if boneName == "Auto" then
            return getExactAimPoint(character, "Auto", true)
        end
        local hitboxes = getWarzHitboxes()
        if hitboxes then
            local shapeName = boneName == "Head" and "Bip01_Head"
                or boneName == "Chest" and "Chest" or "Bip01_Spine1"
            local ok, shapes = pcall(hitboxes.DataShapes, character)
            if ok and type(shapes) == "table" then
                for _, shape in ipairs(shapes) do
                    if shape.name == shapeName and typeof(shape.cf) == "CFrame" then
                        return shape.cf.Position
                    end
                end
            end
        end
        -- Data-driven characters have offset legacy parts; wait for their real geometry.
        if character:GetAttribute("WarzDataHitboxes") == true then return nil end
        if boneName == "Head" then
            local bHead = character:FindFirstChild("WarzHitboxes") and character.WarzHitboxes:FindFirstChild("Bip01_Head")
            if bHead and bHead:IsA("BasePart") then return bHead.Position end
            local head = character:FindFirstChild("Head")
            if head and head:IsA("BasePart") then return head.Position end
        elseif boneName == "Chest" then
            local chest = character:FindFirstChild("WarzHitboxes") and character.WarzHitboxes:FindFirstChild("Chest")
            if chest and chest:IsA("BasePart") then return chest.Position end
            local ut = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
            if ut and ut:IsA("BasePart") then return ut.Position end
        else
            local spine = character:FindFirstChild("WarzHitboxes") and character.WarzHitboxes:FindFirstChild("Bip01_Spine1")
            if spine and spine:IsA("BasePart") then return spine.Position end
            local lt = character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso")
            if lt and lt:IsA("BasePart") then return lt.Position end
        end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        return hrp and hrp.Position or nil
    end

    local function silentCandidateMinimumSquared(character, root, center, limit)
        -- WarZ data rigs are about 6 studs tall. A 12-stud root envelope
        -- conservatively includes animated limbs; legacy/custom rigs bypass it.
        if character:GetAttribute("WarzDataHitboxes") ~= true then return 0 end
        local radius = 12
        local view = camera.WorldToViewportPoint(camera, root.Position)
        if view.Z <= radius then return 0 end
        local dx, dy = math.abs(view.X - center.X), math.abs(view.Y - center.Y)
        if dx * dx + dy * dy <= limit * limit then return 0 end

        -- Project the envelope's near face to bound perspective expansion.
        -- An offscreen root can still have a visible limb inside the FOV.
        local frame = camera.CFrame
        local nearPoint = root.Position - frame.LookVector * radius
        local nearView = camera.WorldToViewportPoint(camera, nearPoint)
        local cornerView = camera.WorldToViewportPoint(camera,
            nearPoint + frame.RightVector * radius + frame.UpVector * radius)
        local padX = math.abs(nearView.X - view.X) + math.abs(cornerView.X - nearView.X)
        local padY = math.abs(nearView.Y - view.Y) + math.abs(cornerView.Y - nearView.Y)
        local minX, minY = math.max(0, dx - padX), math.max(0, dy - padY)
        return minX * minX + minY * minY
    end

    local function getSilentAimTarget(playersList, shotOrigin)
        if not camera then return nil end
        local bestPoint, bestCharacter = nil, nil
        local bestDist = math.huge
        local center = camera.ViewportSize / 2
        local maxFov = settings.silentAimFov or settings.silentFov or 120
        local camPos = camera.CFrame.Position
        local camLook = camera.CFrame.LookVector
        local players = playersList or Players:GetPlayers()

        for _, p in ipairs(players) do
            if bestDist == 0 then break end
            local ch = p.Character
            if p ~= localPlayer and not isPartyMember(p) and isPlayerVulnerable(p, ch) and isAlive(ch) then
                local hrp = ch:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local delta = hrp.Position - camPos
                    -- Frustum filter & distance filter (within 500 studs: 250000 studs^2)
                    if camLook:Dot(delta) > -5 and delta:Dot(delta) <= 250000 then
                        local minimum = silentCandidateMinimumSquared(ch, hrp, center, math.min(maxFov, bestDist))
                        local rawPoint
                        if minimum <= maxFov * maxFov and minimum < bestDist * bestDist then
                            rawPoint = getSilentAimPoint(ch, settings.silentAimBone or settings.silentBone)
                        end
                        if rawPoint then
                            local view, on = camera.WorldToViewportPoint(camera, rawPoint)
                            if on and view.Z > 0 then
                                local pxDist = (Vector2.new(view.X, view.Y) - center).Magnitude
                                if pxDist <= maxFov and pxDist < bestDist then
                                    if canSeeAimPoint(ch, rawPoint, shotOrigin) then
                                        bestDist = pxDist
                                        bestPoint, bestCharacter = rawPoint, ch
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        if bestPoint and settings.aimPrediction then
            return applyAimPrediction(bestPoint, bestCharacter, shotOrigin)
        end
        return bestPoint
    end

    local fovCircle = safeDrawing("Circle")
    if fovCircle then
        fovCircle.Visible = false
        fovCircle.Thickness = 1
        fovCircle.Filled = false
        fovCircle.Transparency = 1
        fovCircle.Color = Color3.fromRGB(255, 255, 255)
    end

    local silentFovCircle = safeDrawing("Circle")
    if silentFovCircle then
        silentFovCircle.Visible = false
        silentFovCircle.Thickness = 1
        silentFovCircle.Filled = false
        silentFovCircle.Transparency = 0.8
        silentFovCircle.Color = Color3.fromRGB(255, 75, 75)
    end

    local function updateFovCircle()
        if not settings.aimbot and not settings.silentAim then
            if fovCircle and fovCircle.Visible then fovCircle.Visible = false end
            if silentFovCircle and silentFovCircle.Visible then silentFovCircle.Visible = false end
            return
        end

        local menuRect = cachedMenuRect
        local vs = camera.ViewportSize
        local center = Vector2.new(vs.X / 2, vs.Y / 2)

        if fovCircle then
            if settings.aimbot then
                local radius = settings.aimFov
                fovCircle.Position = center
                fovCircle.Radius = radius
                fovCircle.Visible = not rectOverlapsMenu(
                    center.X - radius, center.Y - radius, radius * 2, radius * 2, menuRect
                )
            else
                fovCircle.Visible = false
            end
        end

        if silentFovCircle then
            if settings.silentAim then
                local radius = settings.silentAimFov
                silentFovCircle.Position = center
                silentFovCircle.Radius = radius
                silentFovCircle.Visible = not rectOverlapsMenu(
                    center.X - radius, center.Y - radius, radius * 2, radius * 2, menuRect
                )
            else
                silentFovCircle.Visible = false
            end
        end
    end

    -- [[ Menu-aware input blocking ]]
    -- The UI library never sinks input, so clicks on the open menu also
    -- reached the game. While the menu is open and the cursor is over it,
    -- sink MB1/MB2/Touch at high priority via ContextActionService.
    local inputBlockBound = false

    local function isMenuPanelOpen()
        if dock and type(dock.IsPanelOpen) == "function" then
            local ok, open = pcall(function() return dock:IsPanelOpen() end)
            if ok then return open == true end
        end

        -- Fallback for older/non-N3Z UI adapters.
        local ok, open = pcall(function() return Window.visible == true end)
        return ok and open == true
    end

    local function setInputBlock(on)
        if on == inputBlockBound then return end
        inputBlockBound = on
        if on then
            pcall(function()
                ContextActionService:BindActionAtPriority("RAVEN_WARZPVP_MENU_BLOCK",
                    function()
                        return Enum.ContextActionResult.Sink
                    end,
                    false, 9000,
                    Enum.UserInputType.MouseButton1,
                    Enum.UserInputType.MouseButton2,
                    Enum.UserInputType.MouseButton3,
                    Enum.UserInputType.Touch,
                    Enum.UserInputType.MouseWheel)
            end)
        else
            pcall(function()
                ContextActionService:UnbindAction("RAVEN_WARZPVP_MENU_BLOCK")
            end)
        end
    end

    local function updateMenuState()
        local open = isMenuPanelOpen()
        if open ~= menuOpen then
            menuOpen = open
            if open then
                -- Never carry an aim hold/lock into menu interaction.
                clearAimLock()
                if aimController and type(aimController.release) == "function" then
                    pcall(function() aimController:release() end)
                end
            end
        end

        if open then
            if dock and dock._panel then
                local p = dock._panel
                local pos = p.AbsolutePosition
                local size = p.AbsoluteSize
                if pos and size then
                    cachedMenuRect = { x = pos.X, y = pos.Y, w = size.X, h = size.Y }
                end
            elseif Window and Window.visible and Window.pos and Window.size then
                cachedMenuRect = { x = Window.pos.X, y = Window.pos.Y, w = Window.size.X, h = Window.size.Y }
            else
                cachedMenuRect = nil
            end
        else
            cachedMenuRect = nil
        end

        -- Dock has its own generic blocker; keep this module-level sink as a
        -- fallback for direct/module-only loads, but respect the user's N3Z
        -- Block Game Input setting.
        local blockEnabled = true
        if dock and type(dock.IsInputBlockEnabled) == "function" then
            local okBlock, enabled = pcall(function() return dock:IsInputBlockEnabled() end)
            if okBlock then blockEnabled = enabled == true end
        end
        setInputBlock(open and blockEnabled)
        return open
    end

    local function updateAimbot(dt)
        if aimController and type(aimController.update) == "function" then
            aimController:update(dt)
        end
    end

    -- [[ UI ]]
    local VisualsTab = Window:CreateTab("Visuals", 4483362458)
    trackSection(VisualsTab, "Player ESP")

    VisualsTab:CreateToggle({
        Name = "ESP Enabled",
        CurrentValue = true,
        Flag = "WZP_EspEnabled",
        Callback = function(v) settings.espEnabled = v end,
    })
    VisualsTab:CreateToggle({
        Name = "Box",
        CurrentValue = true,
        Flag = "WZP_BoxEsp",
        Callback = function(v) settings.boxEsp = v end,
    })
    VisualsTab:CreateToggle({
        Name = "Name + Distance",
        CurrentValue = true,
        Flag = "WZP_NameEsp",
        Callback = function(v)
            settings.nameEsp = v
            settings.distanceEsp = v
        end,
    })
    VisualsTab:CreateToggle({
        Name = "Health Bar",
        CurrentValue = true,
        Flag = "WZP_HealthEsp",
        Callback = function(v) settings.healthEsp = v end,
    })
    VisualsTab:CreateToggle({
        Name = "Weapon Icon",
        CurrentValue = true,
        Flag = "WZP_WeaponEsp",
        Callback = function(v) settings.weaponEsp = v end,
    })
    VisualsTab:CreateToggle({
        Name = "Skeleton",
        CurrentValue = true,
        Flag = "WZP_SkeletonEsp",
        Callback = function(v) settings.skeletonEsp = v end,
    })
    VisualsTab:CreateToggle({
        Name = "Self ESP",
        CurrentValue = false,
        Flag = "WZP_SelfEsp",
        Callback = function(v) settings.selfEsp = v end,
    })
    VisualsTab:CreateSlider({
        Name = "Max Distance",
        Range = { 100, 5000 },
        Increment = 50,
        Suffix = " studs",
        CurrentValue = 2000,
        Flag = "WZP_MaxDistance",
        Callback = function(v) settings.maxDistance = v end,
    })

    trackSection(VisualsTab, "Loot ESP")
    VisualsTab:CreateToggle({
        Name = "Loot ESP",
        CurrentValue = true,
        Flag = "WZP_LootEsp",
        Callback = function(v) settings.lootEsp = v end,
    })
    VisualsTab:CreateSlider({
        Name = "Loot Max Distance",
        Range = { 100, 3000 },
        Increment = 50,
        Suffix = " studs",
        CurrentValue = 1500,
        Flag = "WZP_LootMaxDistance",
        Callback = function(v) settings.lootMaxDistance = v end,
    })
    lootCategoryDropdown = VisualsTab:CreateDropdown({
        Name = "Loot Category",
        Options = lootCategories,
        CurrentOption = "All",
        Flag = "WZP_LootCategory",
        Callback = function(v) settings.lootCategory = v end,
    })
    VisualsTab:CreateToggle({
        Name = "Loot Aura",
        CurrentValue = false,
        Flag = "WZP_LootAura",
        Callback = function(v) settings.lootAura = v end,
    })
    VisualsTab:CreateSlider({
        Name = "Loot Aura Range",
        Range = { 5, 20 },
        Increment = 1,
        Suffix = " studs",
        CurrentValue = 12,
        Flag = "WZP_LootAuraRange",
        Callback = function(v) settings.lootAuraRange = v end,
    })

    trackSection(VisualsTab, "Boss ESP")
    VisualsTab:CreateToggle({
        Name = "Boss ESP",
        CurrentValue = true,
        Flag = "WZP_BossEsp",
        Callback = function(v) settings.bossEsp = v end,
    })
    VisualsTab:CreateToggle({
        Name = "Boss Spawn Alert",
        CurrentValue = true,
        Flag = "WZP_BossAlert",
        Callback = function(v) settings.bossAlert = v end,
    })

    local CombatTab = Window:CreateTab("Combat", 4483362458)
    trackSection(CombatTab, "Aimbot")
    CombatTab:CreateToggle({
        Name = "Aimbot Enabled",
        CurrentValue = false,
        Flag = "WZP_Aimbot",
        Callback = function(v)
            settings.aimbot = v
            if not v then
                clearAimLock()
                if aimController and type(aimController.release) == "function" then
                    pcall(function() aimController:release() end)
                end
            end
        end,
    })
    CombatTab:CreateToggle({
        Name = "Auto Prediction",
        CurrentValue = true,
        Flag = "WZP_AimPrediction",
        Callback = function(v)
            settings.aimPrediction = v
            if not v then predictionState.travelTime = 0 end
        end,
    })
    CombatTab:CreateDropdown({
        Name = "Aim Position",
        Options = AIM_POSITION_OPTIONS,
        CurrentOption = "Auto",
        Flag = "WZP_AimPosition",
        Callback = function(v)
            if BONE_GROUPS[v] then
                settings.aimPosition = v
                aimLockPlayer, aimLockCharacter = nil, nil
            end
        end,
    })
    assert(type(platform.createAimController) == "function",
        "WarZ: platform adapter missing createAimController")
    aimController = platform.createAimController({
        localPlayer = localPlayer,
        settings = settings,
        Window = Window,
        CombatTab = CombatTab,
        UserInputService = UserInputService,
        GuiService = GuiService,
        connect = function(connection)
            table.insert(connections, connection)
            return connection
        end,
        getCamera = function() return camera end,
        isMenuOpen = function() return menuOpen end,
        setInputBlock = setInputBlock,
        getAimTarget = getAimTarget,
        getAimLockCharacter = function() return aimLockCharacter end,
        applyAimPrediction = applyAimPrediction,
        clearAimLock = clearAimLock,
    })
    assert(type(aimController) == "table", "WarZ: invalid aim controller")

    CombatTab:CreateSlider({
        Name = "Aim Max Distance",
        Range = { 50, 2000 },
        Increment = 25,
        Suffix = " studs",
        CurrentValue = 500,
        Flag = "WZP_AimMaxDist",
        Callback = function(v) settings.aimMaxDist = v end,
    })
    CombatTab:CreateSlider({
        Name = "Aim FOV",
        Range = { 50, 400 },
        Increment = 10,
        Suffix = " px",
        CurrentValue = 150,
        Flag = "WZP_AimFov",
        Callback = function(v) settings.aimFov = v end,
    })
    -- Higher = smoother (gentler). Maps to the per-frame response fraction:
    -- 100 -> 0.05 (very soft), 5 -> 0.8 (fast, capped below 1.0 so camera
    -- lag can never turn it into an overshoot oscillator). Default 70 -> 0.35.
    CombatTab:CreateSlider({
        Name = "Aim Smooth",
        Range = { 5, 100 },
        Increment = 5,
        Suffix = "%",
        CurrentValue = 70,
        Flag = "WZP_AimSmooth",
        Callback = function(v) settings.aimResponse = math.min(0.8, (105 - v) / 100) end,
    })
    trackSection(CombatTab, "Auto Heal")
    CombatTab:CreateToggle({
        Name = "Auto Heal",
        CurrentValue = false,
        Flag = "WZP_AutoHeal",
        Callback = function(v) settings.autoHeal = v end,
    })
    CombatTab:CreateSlider({
        Name = "Heal Threshold",
        Range = { 10, 90 },
        Increment = 5,
        Suffix = " HP",
        CurrentValue = 50,
        Flag = "WZP_HealThreshold",
        Callback = function(v) settings.healThreshold = v end,
    })
    local recoilTime = 0
    local pickupTime = 0

    -- No Recoil (Tier 2): modify weapon catalog tables directly.
    -- Game modules are resolved lazily so an executor-specific require stall
    -- cannot prevent the WarZ UI/ESP from finishing startup.
    local function applyNoRecoil(cachedOnly)
        local cs = cachedOnly and peekLazy("CombatSettings") or getCombatSettings()
        if type(cs) ~= "table" then return end
        local catalog
        if type(cs.GetCatalog) == "function" then
            local ok2, cat = pcall(cs.GetCatalog)
            if ok2 then catalog = cat end
        end
        if catalog and catalog.Weapons then
            for _, weapon in pairs(catalog.Weapons) do
                if type(weapon) == "table" then
                    if weapon._origRecoil == nil then
                        weapon._origRecoil = weapon.Recoil or 9
                        weapon._origViewRecoil = weapon.ViewRecoil or 0.38
                    end
                    if settings.noRecoil then
                        weapon.Recoil = 0
                        weapon.ViewRecoil = 0
                    else
                        weapon.Recoil = weapon._origRecoil
                        weapon.ViewRecoil = weapon._origViewRecoil
                    end
                    -- Ensure Spread stays at its original legit value for server-authoritative hits
                    if weapon._origSpread ~= nil then
                        weapon.Spread = weapon._origSpread
                    end
                end
            end
        end
        local Config = cachedOnly and peekLazy("SharedConfig") or getSharedConfig()
        if Config and type(Config.Shop) == "table" then
            for _, item in pairs(Config.Shop) do
                if type(item) == "table" then
                    if item.Recoil ~= nil and item._origRecoil == nil then
                        item._origRecoil = item.Recoil
                    end
                    if settings.noRecoil and item.Recoil ~= nil then
                        item.Recoil = 0
                    elseif not settings.noRecoil and item._origRecoil ~= nil then
                        item.Recoil = item._origRecoil
                    end
                    if item._origSpread ~= nil then
                        item.Spread = item._origSpread
                    end
                end
            end
        end
    end
    _G.__WZP_ApplyNoRecoil = applyNoRecoil

    trackSection(CombatTab, "No Recoil")

    -- Instant Pickup (Tier 2): patch LootHold.Step to commit instantly.
    -- LootHold itself is resolved lazily through the shared resolver above.
    local _origLootHoldStep = nil

    local function applyInstantPickup()
        if not settings.instantPickup and _origLootHoldStep == nil then
            return
        end
        local lhMod = settings.instantPickup
            and getLootHoldModule()
            or peekLazy("LootHold")
        if not lhMod then return end
        if settings.instantPickup then
            if not _origLootHoldStep then
                _origLootHoldStep = lhMod.Step
                lhMod.Step = function(self, uid, target, holding, t)
                    if self.uid and not self.committed and holding then
                        self.started = t - 2
                        self.nextUse = t - 1
                    end
                    return _origLootHoldStep(self, uid, target, holding, t)
                end
            end
        elseif _origLootHoldStep then
            lhMod.Step = _origLootHoldStep
            _origLootHoldStep = nil
        end
    end

    CombatTab:CreateToggle({
        Name = "No Recoil",
        CurrentValue = false,
        Flag = "WZP_NoRecoil",
        Callback = function(v)
            settings.noRecoil = v
            recoilTime = 0
            pcall(applyNoRecoil)
        end,
    })
    CombatTab:CreateToggle({
        Name = "Instant Pickup",
        CurrentValue = false,
        Flag = "WZP_InstantPickup",
        Callback = function(v)
            settings.instantPickup = v
            pcall(applyInstantPickup)
        end,
    })
    pcall(function()
        if type(CombatTab.CreateLabel) == "function" then
            CombatTab:CreateLabel("Aim Position: Auto chooses the nearest real WarZ hit-shape to FOV center")
        end
        if type(Window.SortTabs) == "function" then
            Window:SortTabs({ "Overview", "Visuals", "Combat", "Settings" })
        end
    end)

    trackSection(CombatTab, "Silent Aim")
    CombatTab:CreateToggle({
        Name = "Silent Aim",
        CurrentValue = false,
        Flag = "WZP_SilentAim",
        Callback = function(v)
            settings.silentAim = v
            if v then
                getWarzHitboxes()
                if settings.aimPrediction then getCurrentBallistics() end
            end
        end,
    })
    CombatTab:CreateSlider({
        Name = "Silent Hit Chance",
        Range = { 0, 100 },
        Increment = 1,
        Suffix = " %",
        CurrentValue = 100,
        Flag = "WZP_SilentHitChance",
        Callback = function(v)
            settings.silentAimHitChance = math.clamp(tonumber(v) or 100, 0, 100)
        end,
    })
    CombatTab:CreateSlider({
        Name = "Silent FOV",
        Range = { 20, 300 },
        Increment = 10,
        Suffix = " px",
        CurrentValue = 120,
        Flag = "WZP_SilentFov",
        Callback = function(v)
            settings.silentAimFov = v
            settings.silentFov = v
        end,
    })
    CombatTab:CreateDropdown({
        Name = "Silent Aim Position",
        Options = { "Auto", "Head", "Chest", "Spine" },
        CurrentOption = "Auto",
        Flag = "WZP_SilentBone",
        Callback = function(v)
            settings.silentAimBone = v
            settings.silentBone = v
        end,
    })

    trackSection(CombatTab, "Stamina")
    CombatTab:CreateToggle({
        Name = "Infinite Stamina",
        CurrentValue = false,
        Flag = "WZP_InfiniteStamina",
        Callback = function(v) settings.infiniteStamina = v end,
    })

    trackSection(CombatTab, "Auto Fishing")
    CombatTab:CreateToggle({
        Name = "Auto Fishing",
        CurrentValue = false,
        Flag = "WZP_AutoFishing",
        Callback = function(v) settings.autoFishing = v end,
    })

    -- Silent Aim metamethod hook (FireRequest)
    local oldNamecall = nil
    local fireRemotes = ReplicatedStorage:FindFirstChild("Remotes")
    local fireRequest = fireRemotes and fireRemotes:FindFirstChild("FireRequest")
    if fireRequest and fireRequest:IsA("RemoteEvent")
        and type(hookmetamethod) == "function" and type(getnamecallmethod) == "function"
        and type(checkcaller) == "function" then
        local fireServer = fireRequest.FireServer
        local silentAimRandom = Random.new()
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if running and settings.silentAim and self == fireRequest
                and method == "FireServer" and not checkcaller() then
                camera = Workspace.CurrentCamera or camera
                local args = table.pack(...)
                local origin = args[4] or (camera and camera.CFrame.Position)
                local chance = math.clamp(tonumber(settings.silentAimHitChance) or 100, 0, 100)
                if typeof(origin) == "Vector3" and (chance >= 100
                    or (chance > 0 and silentAimRandom:NextNumber(0, 100) < chance)) then
                    -- Read animated hitboxes at shot time; a render-frame cache can be stale.
                    local ok, targetPoint = pcall(getSilentAimTarget, nil, origin)
                    if ok and typeof(targetPoint) == "Vector3" then
                        local direction = targetPoint - origin
                        if direction.Magnitude > 0.001 and direction.Magnitude < math.huge then
                            args[1] = direction.Unit
                        end
                    end
                end
                -- DataShapes and ballistic math issue nested namecalls. Restore
                -- the firing method even when selection fails or finds no target.
                if type(setnamecallmethod) == "function" then
                    setnamecallmethod(method)
                    return oldNamecall(self, table.unpack(args, 1, args.n))
                end
                return fireServer(self, table.unpack(args, 1, args.n))
            end
            return oldNamecall(self, ...)
        end)
    end

    -- Loot Aura implementation (Dual: Native TouchHeld auto-hold + 360-degree Aura vacuum)
    local lootAuraTime = 0
    local lootAuraSeq = 0
    local lootAuraRecent = {}
    local function updateLootAura(dt)
        local lpMod = peekLazy("LootPickup") or getLootPickupModule()
        if not settings.lootAura then
            if lpMod and type(lpMod.SetTouchHeld) == "function" and lpMod.IsTouchHeld() then
                pcall(lpMod.SetTouchHeld, false)
            end
            return
        end

        -- 1. Enable game native touch-hold pickup for currently aimed / close items
        if lpMod and type(lpMod.SetTouchHeld) == "function" and not lpMod.IsTouchHeld() then
            pcall(lpMod.SetTouchHeld, true)
        end

        lootAuraTime += dt
        if lootAuraTime < 0.15 then return end
        lootAuraTime = 0

        local char = localPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local warzLoot = Workspace:FindFirstChild("WarzLoot")
        if not warzLoot then return end
        local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
        local pickupRemote = remotesFolder and remotesFolder:FindFirstChild("PickupLoot")
        if not pickupRemote then return end

        local myPos = hrp.Position
        local maxRange = math.min(settings.lootAuraRange or 10.5, 10.8)
        local now = os.clock()

        for uid, t in pairs(lootAuraRecent) do
            if now - t > 2.5 then lootAuraRecent[uid] = nil end
        end

        for _, item in ipairs(warzLoot:GetChildren()) do
            local uid = item:GetAttribute("LootUid")
            if uid and not lootAuraRecent[uid] then
                local pos = nil
                if item:IsA("Model") then
                    local p = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)
                    pos = p and p.Position
                elseif item:IsA("BasePart") then
                    pos = item.Position
                end

                if pos then
                    local delta = pos - myPos
                    local flatDist = Vector3.new(delta.X, 0, delta.Z).Magnitude
                    if flatDist <= maxRange and math.abs(delta.Y) < 7.5 then
                        lootAuraRecent[uid] = now
                        lootAuraSeq = (lootAuraSeq % 9999) + 1
                        local s = lootAuraSeq
                        local isInstant = settings.instantPickup == true
                        task.spawn(function()
                            pcall(pickupRemote.FireServer, pickupRemote, uid, "prep", s)
                            task.wait(isInstant and 0.06 or 1.05)
                            pcall(pickupRemote.FireServer, pickupRemote, uid, "use", s)
                        end)
                        break
                    end
                end
            end
        end
    end

    -- Auto Fishing implementation
    local autoFishCastTimer = 0
    local function updateAutoFishing(dt)
        if not settings.autoFishing then return end
        autoFishCastTimer += dt
        if autoFishCastTimer >= 1.5 then
            autoFishCastTimer = 0
            local fm = getFishingModule()
            if fm and type(fm.IsActive) == "function" and not fm.IsActive() then
                pcall(fm.Press)
            end
        end
    end

    -- [[ Connections ]]
    -- Refresh aim/UI every frame; cached loot labels update at 60 Hz so they track the camera smoothly.
    -- Do not hold a stale CurrentCamera across death or camera replacement.
    local espTime, lootTime, bossTime = 0, 0, 0
    table.insert(connections, RunService.RenderStepped:Connect(function(dt)
        if not running then return end
        camera = Workspace.CurrentCamera or camera
        local elapsed = math.min(dt or 1 / 60, 0.1)
        espTime += elapsed
        lootTime += elapsed
        bossTime += elapsed
        local panelOpen = false
        pcall(function() panelOpen = updateMenuState() end)

        local currentPlayers = Players:GetPlayers()

        -- Keep ESP active while the menu is open. Each Drawing primitive
        -- clips itself against the panel rectangle, so visuals outside the menu
        -- remain visible instead of disappearing globally.
        pcall(updatePlayerEsp, currentPlayers)
        if lootTime >= 1 / 30 then
            lootTime = 0
            pcall(updateLootEsp)
        end
        if bossTime >= 1 / 12 then
            bossTime = 0
            pcall(updateBossEsp)
        end
        pcall(updateFovCircle)
        pcall(updateAimbot, dt)

        -- Catalog edits persist; refresh at 0.2 Hz (every 5.0s) to catch weapon/config reloads
        -- without scanning every weapon on every render frame.
        if settings.noRecoil then
            recoilTime += dt
            if recoilTime >= 5.0 then
                recoilTime = 0
                pcall(applyNoRecoil)
            end
        else
            recoilTime = 0
        end

        if settings.instantPickup then
            pickupTime += dt
            if pickupTime >= 5.0 then
                pickupTime = 0
                pcall(applyInstantPickup)
            end
        else
            pickupTime = 0
        end

        -- Auto Heal (Tier 1): via CombatInput.RequestUseMed() (correct signature)
        if settings.autoHeal then
            pcall(function()
                local char = localPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 and hum.Health <= settings.healThreshold then
                    local now = os.clock()
                    if now - settings.healCooldown >= 0.5 then
                        local cd = tonumber(localPlayer:GetAttribute("WarzMedCdLeft")) or 0
                        if cd <= 0.05 then
                            local ci = getCombatInput()
                            if ci and type(ci.RequestUseMed) == "function" then
                                local okUse = pcall(ci.RequestUseMed)
                                if okUse then
                                    settings.healCooldown = now
                                end
                            end
                        end
                    end
                end
            end)
        end

        -- Infinite Stamina & No Sprint Lock: only set if changed to avoid listener loops
        if settings.infiniteStamina then
            pcall(function()
                if localPlayer:GetAttribute("CSGO_Stamina") ~= 100 then
                    localPlayer:SetAttribute("CSGO_Stamina", 100)
                end
                if localPlayer:GetAttribute("CSGO_SprintLock") ~= false then
                    localPlayer:SetAttribute("CSGO_SprintLock", false)
                end
                if localPlayer:GetAttribute("CSGO_SprintPenalty") ~= 0 then
                    localPlayer:SetAttribute("CSGO_SprintPenalty", 0)
                end
                if localPlayer:GetAttribute("WarzServerStamina") ~= 100 then
                    localPlayer:SetAttribute("WarzServerStamina", 100)
                end
            end)
        end

        -- Loot Aura (Auto Pickup Nearby Items)
        pcall(updateLootAura, elapsed)

        -- Auto Fishing
        pcall(updateAutoFishing, elapsed)
    end))

    table.insert(connections, localPlayer:GetAttributeChangedSignal("CSGO_Stamina"):Connect(function()
        if running and settings.infiniteStamina then
            localPlayer:SetAttribute("CSGO_Stamina", 100)
        end
    end))
    table.insert(connections, localPlayer:GetAttributeChangedSignal("CSGO_SprintLock"):Connect(function()
        if running and settings.infiniteStamina then
            localPlayer:SetAttribute("CSGO_SprintLock", false)
        end
    end))

    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    local fishingStateRemote = remotesFolder and remotesFolder:FindFirstChild("FishingState")
    if fishingStateRemote then
        table.insert(connections, fishingStateRemote.OnClientEvent:Connect(function(state)
            if not running or not settings.autoFishing then return end
            if type(state) ~= "table" or type(state.phase) ~= "string" then return end
            local fm = getFishingModule()
            if not fm then return end

            if state.phase == "reel" then
                local biteAt = state.biteAt or Workspace.GetServerTimeNow(Workspace)
                local speed = state.speed or 1
                local center = state.zoneCenter or 0.5
                local width = state.zoneWidth or 0.3
                task.spawn(function()
                    while running and settings.autoFishing do
                        local t = Workspace.GetServerTimeNow(Workspace)
                        local pos = (t - biteAt) * speed % 2
                        if pos < 0 then pos = pos + 2 end
                        if pos >= 1 then pos = 2 - pos end
                        if math.abs(pos - center) <= (width * 0.45) then
                            pcall(fm.Press)
                            break
                        end
                        task.wait(0.015)
                    end
                end)
            elseif state.phase == "result" then
                task.delay(2.6, function()
                    if running and settings.autoFishing then
                        pcall(fm.Press)
                    end
                end)
            end
        end))
    end

    table.insert(connections, Players.PlayerRemoving:Connect(function(p)
        if p == aimLockPlayer then aimLockPlayer, aimLockCharacter = nil, nil end
        destroyEntry(p)
    end))

    local moduleHandle
    local function destroy()
        if not running then return end
        running = false
        lifecycleAlive = false
        settings.aimbot = false
        settings.silentAim = false
        settings.infiniteStamina = false
        settings.lootAura = false
        pcall(function()
            local lpMod = peekLazy("LootPickup")
            if lpMod and type(lpMod.SetTouchHeld) == "function" then
                lpMod.SetTouchHeld(false)
            end
        end)
        settings.autoFishing = false
        settings.autoHeal = false
        settings.noRecoil = false
        pcall(applyNoRecoil, true)
        settings.instantPickup = false
        pcall(applyInstantPickup)
        clearAimLock()
        if aimController and type(aimController.destroy) == "function" then
            pcall(function() aimController:destroy() end)
        end
        pcall(function() setInputBlock(false) end)
        for _, c in ipairs(connections) do
            pcall(function() c:Disconnect() end)
        end
        table.clear(connections)
        pcall(removeUiSections)
        if fovCircle ~= nil then
            pcall(function() fovCircle:Remove() end)
            fovCircle = nil
        end
        if silentFovCircle ~= nil then
            pcall(function() silentFovCircle:Remove() end)
            silentFovCircle = nil
        end
        local players = {}
        for p in pairs(espCache) do table.insert(players, p) end
        for _, p in ipairs(players) do destroyEntry(p) end
        table.clear(espCache)
        table.clear(weaponIconCache)
        weaponIconConfig = nil
        disconnectLootFolder()
        clearLootCache()
        lootFolder = nil
        if bossDraw then
            for _, d in pairs(bossDraw) do
                if d then pcall(function() d:Remove() end) end
            end
            bossDraw = nil
        end
        if bossAlertText then
            pcall(function() bossAlertText:Remove() end)
            bossAlertText = nil
        end

        if visualBackend and type(visualBackend.destroy) == "function" then
            pcall(function() visualBackend.destroy() end)
        end
        bossWasPresent = false
        if _G.__WZP_ApplyNoRecoil == applyNoRecoil then
            _G.__WZP_ApplyNoRecoil = nil
        end
        if environment.__RAVEN_WARZPVP == moduleHandle then
            environment.__RAVEN_WARZPVP = nil
        end
    end

    local function getStatus()
        local lines, visible, ready, entries = 0, 0, 0, 0
        for _, e in pairs(espCache) do
            entries += 1
            if e.boneReady then ready += 1 end
            for _, line in pairs(e.bones or {}) do
                lines += 1
                local ok, shown = pcall(function() return line.Visible end)
                if ok and shown then visible += 1 end
            end
        end
        local currentBallistics = getCurrentBallistics()
        local aimStatus = {}
        if aimController and type(aimController.status) == "function" then
            local okStatus, result = pcall(function() return aimController:status() end)
            if okStatus and type(result) == "table" then aimStatus = result end
        end
        return {
            version = environment.RAVEN_WARZPVP_VER,
            running = running,
            platform = platform.id,
            visualBackend = visualBackend.name,
            aimbot = settings.aimbot,
            silentAim = settings.silentAim,
            silentAimHitChance = settings.silentAimHitChance,
            silentAimPosition = settings.silentAimBone,
            infiniteStamina = settings.infiniteStamina,
            lootAura = settings.lootAura,
            autoFishing = settings.autoFishing,
            aimInputMode = aimStatus.mode,
            aimBackend = aimStatus.backend,
            aimKey = aimStatus.key,
            aimPosition = settings.aimPosition,
            prediction = {
                enabled = settings.aimPrediction,
                weaponId = currentBallistics and currentBallistics.weaponId or predictionState.weaponId,
                rawSpeed = currentBallistics and currentBallistics.rawSpeed or predictionState.rawSpeed,
                projectileSpeed = currentBallistics and currentBallistics.speed or predictionState.projectileSpeed,
                mass = currentBallistics and currentBallistics.mass or predictionState.mass,
                immediate = currentBallistics and currentBallistics.immediate or predictionState.immediate,
                travelTime = predictionState.travelTime,
            },
            aimHeld = aimStatus.held == true,
            target = aimLockPlayer and aimLockPlayer.Name or nil,
            skeleton = {entries = entries, lines = lines, visible = visible, ready = ready},
            performance = {
                espLastMs = espPerf.lastMs,
                espAvgMs = espPerf.avgMs,
                espPeakMs = espPerf.peakMs,
                espBuckets = espPerf.bucketCount,
                espProcessed = espPerf.processed,
            },
            loot = (function()
                local n = 0
                for _ in pairs(lootCache) do n = n + 1 end
                return n
            end)(),
            boss = bossWasPresent,
            menuOpen = menuOpen,
            inputBlocked = inputBlockBound,
        }
    end

    moduleHandle = { Destroy = destroy, GetStatus = getStatus }
    environment.__RAVEN_WARZPVP = moduleHandle
    if type(ctx) == "table" and type(ctx.registerCleanup) == "function" then
        ctx.registerCleanup(destroy)
    end

    -- Test hook (only when loaded with ctx.__test); does not affect hub usage
    if type(ctx) == "table" and ctx.__test == true then
        environment.__RAVEN_WARZPVP._test = {
            settings = settings,
            currentBallistics = getCurrentBallistics,
            solveBallisticTime = solveBallisticTime,
            applyAimPrediction = applyAimPrediction,
            targetLinearVelocity = targetLinearVelocity,
            espPlayers = function()
                local n = 0
                for _ in pairs(espCache) do n = n + 1 end
                return n
            end,
            aimTarget = function()
                local point = getAimTarget()
                return point and aimLockPlayer and aimLockPlayer.Name or nil
            end,
            isPartyMember = isPartyMember,
            weaponIconSource = getWeaponIconSource,
            renderedWeaponId = getRenderedWeaponId,
            fovVisible = function() return fovCircle and fovCircle.Visible or false end,
            platform = function() return platform.id end,
            visualBackend = function() return visualBackend.name end,
            aimStatus = function()
                if aimController and type(aimController.status) == "function" then
                    local ok, status = pcall(function() return aimController:status() end)
                    if ok then return status end
                end
                return nil
            end,
            aimPosition = function() return settings.aimPosition end,
            setAimPosition = function(mode)
                if BONE_GROUPS[mode] then
                    settings.aimPosition = mode
                    aimLockPlayer, aimLockCharacter = nil, nil
                    return true
                end
                return false
            end,
            skeletonStats = function()
                local entries, lines, visible, ready = 0, 0, 0, 0
                for _, e in pairs(espCache) do
                    entries += 1
                    if e.boneReady then ready += 1 end
                    for _, line in pairs(e.bones or {}) do
                        lines += 1
                        local ok, isVisible = pcall(function() return line.Visible end)
                        if ok and isVisible then visible += 1 end
                    end
                end
                return {entries = entries, lines = lines, visible = visible, ready = ready}
            end,
            espNames = function()
                local names = {}
                for plr in pairs(espCache) do
                    table.insert(names, plr.Name)
                end
                return names
            end,
            drawZ = function()
                local ez = nil
                for _, e in pairs(espCache) do
                    if e.box then ez = e.box.ZIndex break end
                end
                return {
                    esp = ez,
                    fov = (fovCircle and fovCircle.ZIndex or nil),
                }
            end,
            menuOpen = function() return menuOpen end,
            blockBound = function() return inputBlockBound end,
            parseLootName = parseLootName,
            lootCategoryAllowed = lootCategoryAllowed,
            updateLootEsp = updateLootEsp,
            updateBossEsp = updateBossEsp,
            getBossModel = getBossModel,
            setLootCategory = function(c) settings.lootCategory = c end,
            lootCount = function()
                local n = 0
                for _ in pairs(lootCache) do n = n + 1 end
                return n
            end,
            bossPresent = function() return bossWasPresent end,
        }
    end

    return environment.__RAVEN_WARZPVP
end
