-- ============================================================
-- N3Z WarZPVP shared core
-- v1.7.0 - shared ESP/loot/boss/target/prediction/ballistics logic
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
    -- Cache the game's own weapon/ballistic helpers once. CurrentWeaponId is
    -- updated by CombatSettings whenever the equipped weapon changes.
    local CombatSettings = nil
    local WarzProjectile = nil
    pcall(function()
        local client = localPlayer.PlayerScripts:FindFirstChild("Client")
        local input = client and client:FindFirstChild("input")
        local module = input and input:FindFirstChild("CombatSettings")
        if module and module:IsA("ModuleScript") then
            CombatSettings = require(module)
        end
    end)
    pcall(function()
        local shared = ReplicatedStorage:FindFirstChild("Shared")
        local module = shared and shared:FindFirstChild("WarzProjectile")
        if module and module:IsA("ModuleScript") then
            WarzProjectile = require(module)
        end
    end)
    local CombatInput = nil
    local function getCombatInput()
        if type(CombatInput) == "table" and type(CombatInput.RequestUseMed) == "function" then
            return CombatInput
        end
        pcall(function()
            local client = localPlayer.PlayerScripts:FindFirstChild("Client")
            local input = client and client:FindFirstChild("input")
            local module = input and input:FindFirstChild("CombatInput")
            if module and module:IsA("ModuleScript") then
                local api = require(module)
                if type(api) == "table" then CombatInput = api end
            end
        end)
        return CombatInput
    end

    local camera = Workspace.CurrentCamera
    local dock = (type(ctx) == "table" and type(ctx.dock) == "table" and ctx.dock)
        or (type(Window) == "table" and type(Window.dock) == "table" and Window.dock)
        or nil

    -- Read-only access to WarZ's own current hit-shape solver.
    -- We only query the currently locked target, never every player per frame.
    local WarzHitboxes = nil
    pcall(function()
        local shared = ReplicatedStorage:FindFirstChild("Shared")
        local warz = shared and shared:FindFirstChild("warz")
        local module = warz and warz:FindFirstChild("WarzHitboxes")
        if module and module:IsA("ModuleScript") then
            local api = require(module)
            if type(api) == "table" and type(api.DataShapes) == "function" then
                WarzHitboxes = api
            end
        end
    end)

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
    environment.RAVEN_WARZPVP_VER = "1.7.0"

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
        autoHeal = false,
        healThreshold = 50,
        healCooldown = 0,
        noRecoil = false,
        instantPickup = false,
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

    local function getPlayerRelationColor(player)
        if not player or player == localPlayer then return nil end
        if sameNonEmptyPlayerAttribute(localPlayer, player, "WarzPartyId") then
            return PARTY_COLOR
        end
        if sameNonEmptyPlayerAttribute(localPlayer, player, "ClanId") then
            return CLAN_COLOR
        end
        return nil
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

    local function closestScreenPoint(points)
        local center = camera.ViewportSize / 2
        local bestPoint, bestName, bestPixels = nil, nil, math.huge
        for _, item in ipairs(points) do
            local point, name = item.point, item.name
            if typeof(point) == "Vector3" then
                local view, on = camera:WorldToViewportPoint(point)
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
        return fallback and fallback.Position or nil, fallback and fallback.Name or nil
    end

    local function shapeAllowed(mode, name)
        if mode == "Auto" then return true end
        local group = SHAPE_GROUPS[mode]
        return group ~= nil and group[name] == true
    end

    local function getExactAimPoint(character, mode)
        mode = BONE_GROUPS[mode] and mode or "Auto"

        -- WarzHitboxes.DataShapes returns the exact current geometry used by
        -- the game. Pick the eligible hit-shape center nearest the crosshair.
        if WarzHitboxes and type(WarzHitboxes.DataShapes) == "function" then
            local ok, shapes = pcall(WarzHitboxes.DataShapes, character, false)
            if ok and type(shapes) == "table" then
                local points = {}
                for _, shape in ipairs(shapes) do
                    if shapeAllowed(mode, shape.name) and typeof(shape.cf) == "CFrame" then
                        table.insert(points, {
                            point = shape.cf.Position,
                            name = shape.name,
                        })
                    end
                end
                local point, name = closestScreenPoint(points)
                if point then return point, name end
            end
        end
        return getBoneAimPoint(character, mode)
    end

    local BODY_PARTS = {
        "Head", "UpperTorso", "LowerTorso", "Torso",
        "LeftUpperArm", "LeftLowerArm", "LeftHand",
        "RightUpperArm", "RightLowerArm", "RightHand",
        "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
        "RightUpperLeg", "RightLowerLeg", "RightFoot",
    }

    local function characterScreenBounds(model)
        local root = bodyPart(model, "HumanoidRootPart") or bodyPart(model, "Torso")
        if not root then return nil end
        local rootView, rootOn = camera:WorldToViewportPoint(root.Position)
        if not rootOn or rootView.Z <= 0 then return nil end

        local minX, minY = math.huge, math.huge
        local maxX, maxY = -math.huge, -math.huge
        local points = 0
        local function add(position)
            local v = camera:WorldToViewportPoint(position)
            if v.Z <= 0 then return end
            points += 1
            minX, minY = math.min(minX, v.X), math.min(minY, v.Y)
            maxX, maxY = math.max(maxX, v.X), math.max(maxY, v.Y)
        end
        local function addPartBounds(part)
            if not part or not part:IsA("BasePart") then return end
            local cf, half = part.CFrame, part.Size * 0.5
            for sx = -1, 1, 2 do
                for sy = -1, 1, 2 do
                    for sz = -1, 1, 2 do
                        add(cf:PointToWorldSpace(Vector3.new(
                            half.X * sx, half.Y * sy, half.Z * sz
                        )))
                    end
                end
            end
        end

        -- Match the rendered WarZ body, not the invisible Character T-pose.
        local _, live = getVisualHead(model)
        if live then
            for _, name in ipairs({ "Head", "Body", "Arms", "Legs" }) do
                local part = live:FindFirstChild(name)
                if part and part:IsA("BasePart") and part.Transparency < 1 then
                    addPartBounds(part)
                end
            end
        end

        -- Fallback while LiveAim has not replicated yet.
        if points == 0 then
            for _, name in ipairs(BODY_PARTS) do
                addPartBounds(bodyPart(model, name))
            end
        end

        if points == 0 then return nil end
        local w, h = maxX - minX, maxY - minY
        local vs = camera.ViewportSize
        if w < 2 or h < 4 or w > vs.X * 2 or h > vs.Y * 2
            or maxX < 0 or minX > vs.X or maxY < 0 or minY > vs.Y then
            return nil
        end
        return {
            x = minX, y = minY, w = w, h = h,
            centerX = (minX + maxX) * 0.5,
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
        e.bones = {}
        e.boneParts = {}
        e.boneCharacter = nil
        e.boneRetryAt = 0
        e.boneReady = false
        espCache[p] = e
        return e
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

    local function resolveSkeletonParts(e, ch, player)
        local now = os.clock()
        local live = getLiveAim(player)
        if e.boneCharacter == ch and e.liveAim == live and e.boneReady then return end
        if e.boneCharacter == ch and e.liveAim == live and now < e.boneRetryAt then return end

        e.boneCharacter = ch
        e.liveAim = live
        e.boneRetryAt = now + 0.5
        table.clear(e.boneParts)
        e.boneReady = live ~= nil
        if not live then return end

        for i, segment in ipairs(LIVEAIM_BONES) do
            local a = findLiveBone(live, segment[1])
            local b = findLiveBone(live, segment[2])
            if a and b then
                e.boneParts[i] = { a, b }
            else
                e.boneParts[i] = false
                e.boneReady = false
            end
        end
    end

    local function hideEntry(e)
        for _, d in pairs({ e.box, e.name, e.hpBack, e.hpFill }) do
            if d then pcall(function() d.Visible = false end) end
        end
        for _, line in pairs(e.bones or {}) do
            if line then pcall(function() line.Visible = false end) end
        end
    end

    local function destroyEntry(p)
        local e = espCache[p]
        if not e then return end
        for _, d in pairs({ e.box, e.name, e.hpBack, e.hpFill }) do
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

    -- Drawing API may render above ScreenGui on some executors. Instead of
    -- hiding all ESP while N3Z is open, clip only drawings that overlap the
    -- visible panel rectangle.
    local function getMenuPanelRect()
        if dock and type(dock.IsPanelOpen) == "function" then
            local okOpen, open = pcall(function() return dock:IsPanelOpen() end)
            if okOpen and open and dock._panel then
                local okRect, pos, size = pcall(function()
                    return dock._panel.AbsolutePosition, dock._panel.AbsoluteSize
                end)
                if okRect and typeof(pos) == "Vector2" and typeof(size) == "Vector2" then
                    return { x = pos.X, y = pos.Y, w = size.X, h = size.Y }
                end
            end
        end

        -- Fallback for older DrawingUI-style windows.
        local ok, visible, pos, size = pcall(function()
            return Window.visible, Window.pos, Window.size
        end)
        if ok and visible == true and typeof(pos) == "Vector2" and typeof(size) == "Vector2" then
            return { x = pos.X, y = pos.Y, w = size.X, h = size.Y }
        end
        return nil
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
        local ok, pos, bounds, centered = pcall(function()
            return d.Position, d.TextBounds, d.Center
        end)
        if not ok or typeof(pos) ~= "Vector2" then return false end
        if typeof(bounds) ~= "Vector2" then
            return pointInMenu(pos, rect)
        end
        local x = pos.X - ((centered == true) and bounds.X * 0.5 or 0)
        local y = pos.Y
        return rectOverlapsMenu(x, y, bounds.X, bounds.Y, rect)
    end

    local function updatePlayerEsp()
        if not settings.espEnabled then
            for _, e in pairs(espCache) do hideEntry(e) end
            return
        end
        local camPos = camera.CFrame.Position
        local menuRect = getMenuPanelRect()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= localPlayer or settings.selfEsp then
                local e = getEntry(p)
                local ch = p.Character
                local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                if hrp and isAlive(ch) then
                    local dist = (hrp.Position - camPos).Magnitude
                    if dist <= settings.maxDistance then
                        local bounds = characterScreenBounds(ch)
                        if bounds then
                            local h, w = bounds.h, bounds.w
                            local x0, y0 = bounds.x, bounds.y
                            local relationColor = getPlayerRelationColor(p)
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
                                if settings.weaponEsp then
                                    local wpn = ch:GetAttribute("HeldWeapon")
                                    if type(wpn) == "string" and wpn ~= "" then
                                        label = label .. " [" .. wpn .. "]"
                                    end
                                end
                                if settings.distanceEsp then
                                    label = label .. " " .. math.floor(dist) .. "m"
                                end
                                e.name.Text = label
                                e.name.Position = Vector2.new(bounds.centerX, y0 - 18)
                                e.name.Color = relationColor or Color3.fromRGB(255, 255, 255)
                                e.name.Visible = not textOverlapsMenu(e.name, menuRect)
                            elseif e.name then
                                e.name.Visible = false
                            end
                            if settings.healthEsp and e.hpBack and e.hpFill then
                                local hum = ch:FindFirstChildOfClass("Humanoid")
                                local ratio = hum and math.clamp(hum.Health / hum.MaxHealth, 0, 1) or 0
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
                            if settings.skeletonEsp then
                                -- Skeleton follows the visible LiveAim rig (animated).
                                -- Retry every 0.5s while LiveAim isn't replicated;
                                -- never draw the invisible Character T-pose.
                                ensureSkeletonDrawings(e)
                                resolveSkeletonParts(e, ch, p)
                                for i = 1, LIVEAIM_BONE_COUNT do
                                    local ln = e.bones[i]
                                    local pair = e.boneParts[i]
                                    if ln then
                                        ln.Color = relationColor or ESP_COLOR
                                        if pair and e.liveAim and e.liveAim.Parent then
                                            local a = boneWorldPosition(pair[1])
                                            local b = boneWorldPosition(pair[2])
                                            if a and b then
                                                local va, ona = camera:WorldToViewportPoint(a)
                                                local vb, onb = camera:WorldToViewportPoint(b)
                                                if ona and onb and va.Z > 0 and vb.Z > 0 then
                                                    local from = Vector2.new(va.X, va.Y)
                                                    local to = Vector2.new(vb.X, vb.Y)
                                                    ln.From = from
                                                    ln.To = to
                                                    ln.Visible = not segmentOverlapsMenu(from, to, menuRect)
                                                else
                                                    ln.Visible = false
                                                end
                                            else
                                                e.boneReady = false
                                                ln.Visible = false
                                            end
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
            elseif espCache[p] then
                hideEntry(espCache[p])
            end
        end
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

    local function updateLootEsp()
        syncLootFolder()

        if not settings.lootEsp then
            for _, entry in pairs(lootCache) do
                hideLootEntry(entry)
            end
            return
        end

        local cam = camera
        if not cam then return end

        local camPos = cam.CFrame.Position
        local maxDistance = settings.lootMaxDistance
        local maxDistanceSq = maxDistance * maxDistance
        local menuRect = getMenuPanelRect()

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
                    local distanceSq = delta:Dot(delta)
                    if distanceSq <= maxDistanceSq then
                        local viewport, onScreen = cam:WorldToViewportPoint(apos)
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
        if type(CombatSettings) ~= "table"
            or type(CombatSettings.BallisticsFor) ~= "function" then
            ballisticCacheWeaponId = nil
            ballisticCache = nil
            return nil
        end

        local weaponId = CombatSettings.CurrentWeaponId
        if type(weaponId) ~= "string" or weaponId == "" then
            ballisticCacheWeaponId = nil
            ballisticCache = nil
            return nil
        end
        if weaponId == ballisticCacheWeaponId and ballisticCache then
            return ballisticCache
        end

        local ok, data = pcall(CombatSettings.BallisticsFor)
        if not ok or type(data) ~= "table" then
            ballisticCacheWeaponId = nil
            ballisticCache = nil
            return nil
        end

        local rawSpeed = tonumber(data.Speed)
        local scale = type(WarzProjectile) == "table" and tonumber(WarzProjectile.Scale) or 2.687
        local mass = tonumber(data.Mass) or 1
        if not rawSpeed or rawSpeed <= 0 or not scale or scale <= 0 then
            ballisticCacheWeaponId = nil
            ballisticCache = nil
            return nil
        end

        local gravity = type(WarzProjectile) == "table" and WarzProjectile.Gravity
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
            stepSeconds = type(WarzProjectile) == "table"
                and tonumber(WarzProjectile.StepSeconds) or (1 / 60),
            lifetime = type(WarzProjectile) == "table"
                and tonumber(WarzProjectile.Lifetime) or 5,
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

    local function applyAimPrediction(point, character)
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

        local origin = camera and camera.CFrame.Position
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
    local function canSeeAimPoint(character, point)
        local origin = camera.CFrame.Position
        local direction = point - origin
        if direction.Magnitude < 0.01 then return false end

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = localPlayer.Character and { localPlayer.Character } or {}
        params.IgnoreWater = true

        local hit = Workspace:Raycast(origin, direction, params)
        if not hit then return true end
        if hit.Instance:IsDescendantOf(character) then return true end

        -- CanQuery is disabled on WarZ character/LiveAim parts, so an obstacle
        -- very near the target point should not incorrectly invalidate the lock.
        return (hit.Position - origin).Magnitude >= direction.Magnitude - 0.15
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

        local view, on = camera:WorldToViewportPoint(point)
        if not on or view.Z <= 0 then return nil, nil end
        local center = camera.ViewportSize / 2
        local pixels = (Vector2.new(view.X, view.Y) - center).Magnitude
        if pixels > maxFov then return nil, nil end
        return point, pixels
    end

    local function scanAimTarget()
        -- Broad phase: cheap animated-bone screen distance for all players.
        -- Narrow phase: exact WarzHitboxes Chest + LOS for only the closest few.
        local candidates = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= localPlayer then
                local character = p.Character
                local point, pixels = validAimPoint(character, settings.aimFov, false)
                if point and pixels then
                    table.insert(candidates, { player = p, pixels = pixels })
                end
            end
        end
        table.sort(candidates, function(a, b)
            return a.pixels < b.pixels
        end)

        for i = 1, math.min(4, #candidates) do
            local p = candidates[i].player
            local character = p.Character
            local point, pixels = validAimPoint(character, settings.aimFov, true)
            if point and pixels and canSeeAimPoint(character, point) then
                return point, p
            end
        end
        return nil, nil
    end

    local function getAimTarget()
        local player = aimLockPlayer
        if player then
            local character = aimLockCharacter
            if character and player.Character == character then
                local point = validAimPoint(character, settings.aimFov * 1.25, true)
                if point and canSeeAimPoint(character, point) then
                    return point
                end
            end
            aimLockPlayer, aimLockCharacter = nil, nil
        end

        local best, bestP = scanAimTarget()
        aimLockPlayer = bestP
        aimLockCharacter = bestP and bestP.Character or nil
        return best
    end

    local fovCircle = safeDrawing("Circle")
    if fovCircle then
        fovCircle.Visible = false
        fovCircle.Thickness = 1
        fovCircle.Filled = false
        fovCircle.Transparency = 1
        fovCircle.Color = Color3.fromRGB(255, 255, 255)
    end

    local function updateFovCircle()
        if not fovCircle then return end
        if settings.aimbot then
            local vs = camera.ViewportSize
            local center = Vector2.new(vs.X / 2, vs.Y / 2)
            local radius = settings.aimFov
            fovCircle.Position = center
            fovCircle.Radius = radius
            local menuRect = getMenuPanelRect()
            fovCircle.Visible = not rectOverlapsMenu(
                center.X - radius, center.Y - radius, radius * 2, radius * 2, menuRect
            )
        else
            fovCircle.Visible = false
        end
    end

    -- [[ Menu-aware input blocking ]]
    -- The UI library never sinks input, so clicks on the open menu also
    -- reached the game. While the menu is open and the cursor is over it,
    -- sink MB1/MB2/Touch at high priority via ContextActionService.
    local inputBlockBound = false
    local menuOpen = false

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
        Name = "Show Weapon",
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
    local cachedSharedConfig = nil
    local recoilTime = 0

    -- No Recoil (Tier 2): modify weapon catalog tables directly
    -- When Recoil <= 0, WarzCamera.ApplyRecoil returns early (no effect). No hooks needed.
    local function applyNoRecoil()
        local cs = CombatSettings
        if type(cs) ~= "table" then
            local ok, loaded = pcall(require, localPlayer.PlayerScripts.Client.input.CombatSettings)
            if ok and type(loaded) == "table" then
                CombatSettings = loaded
                cs = loaded
            end
        end
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
        if not cachedSharedConfig then
            local okCfg, loaded = pcall(require, ReplicatedStorage.Shared.Config)
            if okCfg and type(loaded) == "table" then
                cachedSharedConfig = loaded
            end
        end
        local Config = cachedSharedConfig
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
-- Instant Pickup (Tier 2): patch LootHold.Step to commit instantly
local _origLootHoldStep = nil
local _lootHoldModule = nil

local function getLootHoldModule()
    if type(_lootHoldModule) == "table" then return _lootHoldModule end
    local client = localPlayer.PlayerScripts:FindFirstChild("Client")
    if not client then return nil end
    for _, c in ipairs(client:GetDescendants()) do
        if c.Name == "LootHold" and c:IsA("ModuleScript") then
            local ok, mod = pcall(require, c)
            if ok and type(mod) == "table" then
                _lootHoldModule = mod
                return mod
            end
        end
    end
    return nil
end

local function applyInstantPickup()
    local lhMod = getLootHoldModule()
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
    else
        if _origLootHoldStep then
            lhMod.Step = _origLootHoldStep
            _origLootHoldStep = nil
        end
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

        -- Keep ESP active while the menu is open. Each Drawing primitive
        -- clips itself against the panel rectangle, so visuals outside the menu
        -- remain visible instead of disappearing globally.
        pcall(updatePlayerEsp)
        if lootTime >= 1 / 60 then
            lootTime = math.max(0, lootTime - 1 / 60)
            pcall(updateLootEsp)
        end
        if bossTime >= 1 / 12 then
            bossTime = 0
            pcall(updateBossEsp)
        end
        pcall(updateFovCircle)
        pcall(updateAimbot, dt)

        -- Catalog edits persist; refresh at 2 Hz to catch weapon/config reloads
        -- without scanning every weapon on every render frame.
        if settings.noRecoil then
            recoilTime += dt
            if recoilTime >= 0.5 then
                recoilTime = 0
                pcall(applyNoRecoil)
            end
        else
            recoilTime = 0
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
    end))
    table.insert(connections, Players.PlayerRemoving:Connect(function(p)
        if p == aimLockPlayer then aimLockPlayer, aimLockCharacter = nil, nil end
        destroyEntry(p)
    end))

    local moduleHandle
    local function destroy()
        if not running then return end
        running = false
        settings.aimbot = false
        settings.autoHeal = false
        settings.noRecoil = false
        pcall(applyNoRecoil)
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
        local players = {}
        for p in pairs(espCache) do table.insert(players, p) end
        for _, p in ipairs(players) do destroyEntry(p) end
        table.clear(espCache)
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
        pcall(function()
            local ok, cs = pcall(require, localPlayer.PlayerScripts.Client.input.CombatSettings)
            if ok and cs and type(cs.GetCatalog) == "function" then
                local cat = cs.GetCatalog()
                if cat and cat.Weapons then
                    for _, w in pairs(cat.Weapons) do
                        if type(w) == "table" and w._origRecoil ~= nil then
                            w.Recoil = w._origRecoil
                            w.Spread = w._origSpread
                            w.ViewRecoil = w._origViewRecoil
                        end
                    end
                end
            end
        end)
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
            aimInputMode = aimStatus.mode,
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
