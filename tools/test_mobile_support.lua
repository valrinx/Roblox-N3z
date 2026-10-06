-- Runs real Dock/adapter code in Roblox; viewport and touch inputs are simulated.
return function(sources)
    local results = {}
    local function expect(value, wanted, message)
        assert(value == wanted, message .. ": expected " .. tostring(wanted) .. ", got " .. tostring(value))
    end
    local function test(name, callback)
        local ok, err = pcall(callback)
        table.insert(results, { name = name, passed = ok, error = not ok and tostring(err) or nil })
    end
    local function signal()
        local listeners = {}
        return {
            Connect = function(_, fn)
                local entry = { fn = fn, active = true }
                table.insert(listeners, entry)
                return { Disconnect = function() entry.active = false end }
            end,
            Fire = function(_, ...)
                for _, entry in ipairs(listeners) do if entry.active then entry.fn(...) end end
            end,
        }
    end

    local function withAim(callback)
        local now, clears, menuOpen = 10, 0, false
        local input = { InputBegan = signal(), InputEnded = signal(), WindowFocusReleased = signal() }
        local hitObjects = {}
        local queryCount = 0
        local playerGui = { GetGuiObjectsAtPosition = function()
            queryCount = queryCount + 1
            return hitObjects
        end }
        local camera = { ViewportSize = Vector2.new(1000, 700), CFrame = CFrame.new() }
        local settings = { aimbot = true, aimResponse = 0.5 }
        local connections = {}
        local chunk = assert(loadstring(sources.mobile, "@mobile-aim-test"))
        setfenv(chunk, setmetatable({ os = { clock = function() return now end } }, { __index = getfenv() }))
        local adapter = chunk()
        local controller = adapter.createAimController({
            localPlayer = { FindFirstChildOfClass = function(_, class)
                expect(class, "PlayerGui", "GUI query owner")
                return playerGui
            end },
            settings = settings, UserInputService = input,
            GuiService = { GetGuiObjectsAtPosition = function() error("hit testing belongs to PlayerGui") end },
            CombatTab = { CreateLabel = function() end },
            connect = function(connection) table.insert(connections, connection); return connection end,
            getCamera = function() return camera end,
            isMenuOpen = function() return menuOpen end,
            getAimTarget = function() return Vector3.new(10, 0, -10) end,
            getAimLockCharacter = function() return nil end,
            applyAimPrediction = function(target) return target end,
            clearAimLock = function() clears = clears + 1 end,
        })
        local fixture = {
            controller = controller, input = input, settings = settings,
            touch = function(x, y) return { UserInputType = Enum.UserInputType.Touch,
                KeyCode = Enum.KeyCode.Unknown, Position = Vector3.new(x, y, 0) } end,
            hits = function(objects) hitObjects = objects end,
            advance = function(dt) now = now + dt end,
            camera = function(value) if value == false then camera = nil end; return camera end,
            menu = function(value) menuOpen = value end,
            queries = function() return queryCount end,
            clears = function() return clears end,
        }
        local ok, err = pcall(callback, fixture)
        controller:destroy()
        for _, connection in ipairs(connections) do connection:Disconnect() end
        assert(ok, err)
    end

    local function withButton(name, callback)
        local button = Instance.new("TextButton")
        button.Name, button.Text = name, ""
        local ok, err = pcall(callback, button)
        button:Destroy()
        assert(ok, err)
    end

    test("left fire button activates mobile aim outside the heuristic region", function()
        withButton("FireLeft", function(button)
            withAim(function(f)
                f.hits({ button })
                f.input.InputBegan:Fire(f.touch(100, 200))
                expect(f.controller:status().held, true, "left fire aim")
                expect(f.queries(), 1, "PlayerGui hit testing")
            end)
        end)
    end)
    test("reload button in the right region does not activate mobile aim", function()
        withButton("Reload", function(button)
            withAim(function(f)
                f.hits({ button })
                f.input.InputBegan:Fire(f.touch(700, 400))
                expect(f.controller:status().held, false, "reload aim")
            end)
        end)
    end)
    test("a foreground control blocks a fire button underneath it", function()
        withButton("Reload", function(overlay)
            withButton("Fire", function(fire)
                withAim(function(f)
                    f.hits({ overlay, fire })
                    f.input.InputBegan:Fire(f.touch(700, 400))
                    expect(f.controller:status().held, false, "covered fire button")
                end)
            end)
        end)
    end)
    test("releasing one fire finger preserves the other fire finger", function()
        withButton("Fire", function(button)
            withAim(function(f)
                f.hits({ button })
                local first, second = f.touch(700, 400), f.touch(750, 400)
                f.input.InputBegan:Fire(first)
                f.input.InputBegan:Fire(second)
                f.input.InputEnded:Fire(second)
                f.advance(1)
                expect(f.controller:status().held, true, "remaining fire finger")
                f.input.InputEnded:Fire(first)
                f.advance(1)
                expect(f.controller:status().held, false, "all fingers released")
            end)
        end)
    end)
    test("mobile aim tolerates camera replacement during an active touch", function()
        withButton("Fire", function(button)
            withAim(function(f)
                f.hits({ button })
                f.input.InputBegan:Fire(f.touch(700, 400))
                f.camera(false)
                f.controller:update(1 / 60)
            end)
        end)
    end)
    test("opening the Hub releases active mobile aim", function()
        withAim(function(f)
            f.input.InputBegan:Fire(f.touch(700, 400))
            f.menu(true)
            f.controller:update(1 / 60)
            expect(f.controller:status().held, false, "aim with Hub open")
        end)
    end)
    test("focus loss releases mobile fire touches", function()
        withAim(function(f)
            f.input.InputBegan:Fire(f.touch(700, 400))
            f.input.WindowFocusReleased:Fire()
            f.advance(1)
            expect(f.controller:status().held, false, "aim after focus loss")
        end)
    end)
    test("active mobile aim moves the camera toward the shared target", function()
        withAim(function(f)
            f.input.InputBegan:Fire(f.touch(700, 400))
            local before = f.camera().CFrame
            f.controller:update(1 / 60)
            assert(f.camera().CFrame ~= before, "mobile camera did not move")
        end)
    end)

    local function withDock(layout, width, callback)
        local cameraSignal, workspaceSignal = signal(), signal()
        local camera = { ViewportSize = Vector2.new(width, 700),
            GetPropertyChangedSignal = function() return cameraSignal end }
        local mockWorkspace = { CurrentCamera = camera, GetPropertyChangedSignal = function() return workspaceSignal end }
        local input = { InputBegan = signal(), InputChanged = signal(), InputEnded = signal(), WindowFocusReleased = signal() }
        local realGame = game
        local chunk = assert(loadstring(sources.dock, "@dock-mobile-test"))
        setfenv(chunk, setmetatable({ workspace = mockWorkspace, game = {
            GetService = function(_, name)
                if name == "ContextActionService" then return { UnbindAction = function() end } end
                if name == "UserInputService" then return input end
                return realGame:GetService(name)
            end,
        } }, { __index = getfenv() }))
        local Dock = chunk()
        local dock = Dock.new({ layout = layout, blockInputEnabled = false })
        dock._gui.Name = "N3ZMobileSupportTest"
        local ok, err = pcall(function()
            task.wait(0.08)
            callback(dock, function(newWidth)
                camera.ViewportSize = Vector2.new(newWidth, 700)
                cameraSignal:Fire()
                task.wait(0.08)
            end, input)
        end)
        dock:Destroy()
        assert(ok, err)
    end
    test("mobile avatar uses the same player thumbnail as desktop", function()
        withDock("mobile", 844, function(dock)
            assert(dock._avatar, "mobile avatar missing")
            expect(dock._avatar.Image, "rbxthumb://type=AvatarHeadShot&id="
                .. tostring(game:GetService("Players").LocalPlayer.UserId) .. "&w=150&h=150", "mobile player image")
        end)
    end)
    test("mobile navigation fits a narrow viewport with the avatar pinned", function()
        withDock("mobile", 320, function(dock)
            assert(dock._bar.AbsoluteSize.X <= 304, "mobile bar exceeds viewport")
            assert(dock._avatar, "mobile avatar missing")
            assert(dock._tabsRow:IsA("ScrollingFrame"), "touch navigation cannot scroll")
            assert(dock._tabsRow.AbsolutePosition.X + dock._tabsRow.AbsoluteSize.X
                <= dock._avatar.Parent.AbsolutePosition.X, "tabs overlap avatar")
            assert(dock._tabsRow.ScrollingEnabled, "overflow navigation cannot scroll")
            local avatarX = dock._avatar.AbsolutePosition.X
            dock._tabsRow.CanvasPosition = Vector2.new(9999, 0)
            task.wait(0.08)
            expect(dock._avatar.AbsolutePosition.X, avatarX, "avatar shifted while scrolling")
        end)
    end)
    test("mobile navigation clears stale scrolling when portrait becomes landscape", function()
        withDock("mobile", 320, function(dock, resize)
            assert(dock._tabsRow:IsA("ScrollingFrame"), "mobile scrolling missing")
            dock._tabsRow.CanvasPosition = Vector2.new(50, 0)
            resize(844)
            expect(dock._tabsRow.ScrollingEnabled, false, "landscape overflow")
            expect(dock._tabsRow.CanvasPosition, Vector2.zero, "stale portrait scroll")
        end)
    end)
    test("touch scrolling overflowing tabs does not drag the mobile Hub", function()
        withDock("mobile", 320, function(dock, _, input)
            local row = dock._tabsRow
            assert(row:IsA("ScrollingFrame") and row.ScrollingEnabled, "mobile overflow missing")
            local pos = row.AbsolutePosition + row.AbsoluteSize / 2
            local touch = { UserInputType = Enum.UserInputType.Touch,
                KeyCode = Enum.KeyCode.Unknown, Position = Vector3.new(pos.X, pos.Y, 0) }
            local before = dock._stage.Position
            input.InputBegan:Fire(touch)
            touch.Position = touch.Position - Vector3.new(40, 0, 0)
            input.InputChanged:Fire(touch)
            input.InputEnded:Fire(touch)
            expect(dock._stage.Position, before, "Hub moved during tab scrolling")
        end)
    end)
    test("removing mobile tabs clears overflow and an active removed tab", function()
        withDock("mobile", 320, function(dock)
            assert(dock._tabsRow:IsA("ScrollingFrame"), "mobile scrolling missing")
            dock:AddRow("combat", { kind = "action", name = "Test action", callback = function() end })
            dock:SetActiveTab("combat")
            dock:RemoveTab("combat")
            dock:PruneEmptyTabs({ modules = true, settings = true })
            task.wait(0.08)
            expect(dock._activeTab, nil, "active removed tab")
            expect(dock._panel.Visible, false, "removed tab panel")
            expect(dock._tabsRow.ScrollingEnabled, false, "overflow after pruning")
            expect(dock._tabsRow.CanvasPosition, Vector2.zero, "scroll after pruning")
            assert(dock._tabs.settings and dock._avatar, "utilities lost after pruning")
        end)
    end)
    test("desktop keeps its existing pinned utilities and bar dimensions", function()
        withDock("pc", 844, function(dock)
            expect(dock._bar.Size.X.Offset, 460, "desktop bar width")
            expect(dock._bar.Size.Y.Offset, 52, "desktop bar height")
            expect(dock._avatar.Parent.Parent, dock._utilityZone, "desktop avatar parent")
            expect(dock._tabs.settings.btn.Parent, dock._utilityZone, "desktop settings")
        end)
    end)

    local commonFlags = {
        "WZP_EspEnabled", "WZP_BoxEsp", "WZP_NameEsp", "WZP_HealthEsp",
        "WZP_WeaponEsp", "WZP_SkeletonEsp", "WZP_SelfEsp", "WZP_MaxDistance",
        "WZP_LootEsp", "WZP_LootMaxDistance", "WZP_LootCategory", "WZP_LootAura",
        "WZP_LootAuraRange", "WZP_BossEsp", "WZP_BossAlert", "WZP_Aimbot",
        "WZP_AimPrediction", "WZP_AimPosition", "WZP_AimMaxDist", "WZP_AimFov",
        "WZP_AimSmooth", "WZP_AutoHeal", "WZP_HealThreshold", "WZP_NoRecoil", "WZP_NoRecoilStrength",
        "WZP_InstantPickup", "WZP_SilentAim", "WZP_SilentFov", "WZP_SilentBone", "WZP_SilentHitChance",
        "WZP_InfiniteStamina", "WZP_AutoFishing",
    }
    for _, layout in ipairs({ "pc", "mobile" }) do
        test(layout .. " router initializes every shared WarZ feature control", function()
            withDock(layout, 844, function(dock, _, input)
                local env = {}
                local realGame = game
                local sandbox = setmetatable({
                    getgenv = function() return env end, _G = {}, hookmetamethod = false,
                    require = function(module)
                        -- Keep full-core initialization from patching the live player's weapon tables.
                        if module.Name == "CombatSettings" then
                            return { GetCatalog = function() return { Weapons = {} } end }
                        end
                        if module.Name == "Config" then return { Shop = {} } end
                        return require(module)
                    end,
                    game = { GetService = function(_, name)
                        if name == "RunService" then return { RenderStepped = signal() } end
                        if name == "UserInputService" then return input end
                        if name == "ContextActionService" then return { UnbindAction = function() end } end
                        return realGame:GetService(name)
                    end },
                }, { __index = getfenv() })
                local function compile(source, name)
                    local chunk = assert(loadstring(source, "@" .. name))
                    setfenv(chunk, sandbox)
                    return chunk()
                end
                local Window = compile(sources.compat, "compat-test")(dock)
                local router = compile(sources.router, "router-test")
                local handle
                local ok, err = pcall(function()
                    handle = router(Window, { platform = layout, dock = dock,
                        loadModuleFile = function(path)
                            if path == "modules/warz_pvp/core.lua" then return compile(sources.core, "core-test") end
                            expect(path, "modules/warz_pvp/" .. layout .. ".lua", "selected adapter")
                            return compile(sources[layout], layout .. "-adapter-test")
                        end,
                    })
                    expect(env.RAVEN_WARZPVP_VER, "1.8.6", "shared runtime version")
                    for _, flag in ipairs(commonFlags) do
                        assert(Window.itemsByFlag[flag], layout .. " missing control: " .. flag)
                    end
                    expect(Window.flags.WZP_Aimbot, false, "initial aimbot")
                    expect(Window.flags.WZP_AutoHeal, false, "initial auto heal")
                    expect(Window.flags.WZP_LootAura, false, "initial loot aura")
                    expect(Window.flags.WZP_SilentBone, "Auto", "initial Silent Aim position")
                    expect(Window.flags.WZP_SilentHitChance, 100, "initial Silent Aim chance")
                    expect(Window.flags.WZP_NoRecoil, false, "initial No Recoil toggle")
                    expect(Window.flags.WZP_NoRecoilStrength, 100, "initial No Recoil strength")
                    local status = handle.GetStatus()
                    expect(status.silentAimPosition, "Auto", "Silent Aim runtime position")
                    expect(status.silentAimHitChance, 100, "Silent Aim runtime chance")
                    expect(status.noRecoil, false, "No Recoil runtime toggle")
                    expect(status.noRecoilStrength, 100, "No Recoil runtime strength")
                end)
                if handle then handle.Destroy() end
                assert(ok, err)
            end)
        end)
    end
    local passed = 0
    for _, result in ipairs(results) do if result.passed then passed = passed + 1 end end
    return { passed = passed, failed = #results - passed, tests = results }
end
