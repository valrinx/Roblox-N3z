-- Execute extracted production functions in Roblox without firing any remotes.
return function(sources)
    local results = {}
    local function expect(actual, wanted, message)
        assert(actual == wanted, message .. ": expected " .. tostring(wanted) .. ", got " .. tostring(actual))
    end
    local function near(actual, wanted, message)
        assert(typeof(actual) == "Vector3" and (actual - wanted).Magnitude < 0.00001, message)
    end
    local function test(name, callback)
        local ok, err = pcall(callback)
        table.insert(results, { name = name, passed = ok, error = not ok and tostring(err) or nil })
    end
    local makeSelection = assert(loadstring(sources.selection, "@silent-selection-test"))()
    local makeHook = assert(loadstring(sources.hook, "@silent-hook-test"))()
    local makePrediction = assert(loadstring(sources.prediction, "@silent-prediction-test"))()
    local makeToggle = assert(loadstring(sources.toggle, "@silent-toggle-test"))()
    local makeControls = assert(loadstring(sources.controls, "@silent-controls-test"))()
    local makeBallistics = assert(loadstring(sources.ballistics, "@silent-ballistics-test"))()

    local function withTargets(callback)
        local models, players, shapes, predictions, sightChecks = {}, {}, {}, {}, {}
        local shapeCalls = 0
        local function add(x)
            local model = Instance.new("Model")
            model:SetAttribute("WarzDataHitboxes", true)
            table.insert(models, model)
            for name, position in pairs({ HumanoidRootPart = Vector3.new(x, 0, -100), Head = Vector3.new(x + 5, 2, -100) }) do
                local part = Instance.new("Part")
                part.Name, part.Anchored, part.Position, part.Parent = name, true, position, model
            end
            local folder = Instance.new("Folder")
            folder.Name, folder.Parent = "WarzHitboxes", model
            local head = Instance.new("Folder")
            head.Name, head.Parent = "Bip01_Head", folder
            shapes[model] = {
                { name = "Bip01_Head", kind = Enum.PartType.Ball, size = Vector3.one, cf = CFrame.new(x, 0, -100) },
                { name = "Chest", kind = Enum.PartType.Cylinder, size = Vector3.one, cf = CFrame.new(x, -2, -100) },
                { name = "Bip01_Spine1", kind = Enum.PartType.Ball, size = Vector3.one, cf = CFrame.new(x, -3, -100) },
            }
            local player = { Character = model }
            table.insert(players, player)
            return player
        end
        local camera = { CFrame = CFrame.new(), ViewportSize = Vector2.new(100, 100),
            WorldToViewportPoint = function(_, point)
                return Vector3.new(50 + point.X, 50 - point.Y, -point.Z), math.abs(point.X) <= 50
            end }
        local settings = { silentAimBone = "Head", silentAimFov = 20, aimPrediction = true }
        local deps = {
            Players = { GetPlayers = function() return players end,
                GetPlayerFromCharacter = function() return nil end }, localPlayer = {}, camera = camera, settings = settings,
            getLiveAim = function() return nil end,
            bodyPart = function(character, name) return character:FindFirstChild(name) end,
            getWarzHitboxes = function() return { DataShapes = function(character)
                shapeCalls += 1
                return shapes[character]
            end } end,
            isPartyMember = function(player) return player.party == true end,
            isPlayerVulnerable = function(player) return player.protected ~= true end,
            isAlive = function(character) return character:GetAttribute("Dead") ~= true end,
            canSeeAimPoint = function(character, point, origin)
                table.insert(sightChecks, { character = character, point = point, origin = origin })
                return true
            end,
            applyAimPrediction = function(point, character, origin)
                table.insert(predictions, { point = point, character = character, origin = origin })
                return point + Vector3.new(100, 0, 0)
            end,
        }
        local ok, err = pcall(callback, { add = add, deps = deps, settings = settings,
            shapes = shapes, predictions = predictions, sightChecks = sightChecks,
            shapeCalls = function() return shapeCalls end,
            api = function() return makeSelection(deps) end })
        for _, model in ipairs(models) do model:Destroy() end
        assert(ok, err)
    end

    test("head aim uses the current data hitbox instead of the offset Head part", function()
        withTargets(function(f)
            local p = f.add(0)
            near(f.api().point(p.Character, "Head"), Vector3.new(0, 0, -100), "incorrect head center")
        end)
    end)
    test("chest and spine aim use their current data shapes", function()
        withTargets(function(f)
            local p = f.add(0)
            local api = f.api()
            near(api.point(p.Character, "Chest"), Vector3.new(0, -2, -100), "incorrect chest center")
            near(api.point(p.Character, "Spine"), Vector3.new(0, -3, -100), "incorrect spine center")
        end)
    end)
    test("Auto chooses the real hitbox nearest the FOV center like Aimbot", function()
        withTargets(function(f)
            local p = f.add(0)
            f.shapes[p.Character][1].cf = CFrame.new(15, 0, -100)
            near(f.api().point(p.Character, "Auto"), Vector3.new(0, -2, -100), "Auto did not select the chest nearest center")
        end)
    end)
    test("Auto waits for data hitboxes instead of aiming at offset legacy parts", function()
        withTargets(function(f)
            local p = f.add(0)
            f.deps.getWarzHitboxes = function() return nil end
            expect(f.api().point(p.Character, "Auto"), nil, "unready Auto used legacy geometry")
        end)
    end)
    test("Auto does not redirect to a data hitbox behind the camera", function()
        withTargets(function(f)
            local p = f.add(0)
            for _, shape in ipairs(f.shapes[p.Character]) do shape.cf = CFrame.new(0, 0, 100) end
            expect(f.api().point(p.Character, "Auto"), nil, "Auto selected a hitbox behind camera")
        end)
    end)
    test("shared exact selection keeps fixed body groups while Auto can select any shape", function()
        withTargets(function(f)
            local p = f.add(0)
            f.shapes[p.Character][1].cf = CFrame.new(15,0,-100)
            table.insert(f.shapes[p.Character], {name="Bip01_L_Foot",cf=CFrame.new(0,0,-100)})
            local api=f.api()
            near(api.exact(p.Character,"Head",true),Vector3.new(15,0,-100),"Head selected another group")
            near(api.exact(p.Character,"Body",true),Vector3.new(0,-2,-100),"Body selected another group")
            near(api.exact(p.Character,"Auto",true),Vector3.new(0,0,-100),"Auto omitted the nearest limb")
        end)
    end)
    test("Silent controls expose hit chance and default to Auto", function()
        local controls, settings = {}, {}
        local function capture(_, spec) controls[spec.Flag] = spec end
        makeControls({ settings = settings, CombatTab = { CreateToggle = capture, CreateSlider = capture,
            CreateDropdown = capture }, getWarzHitboxes = function() end, getCurrentBallistics = function() end })
        local chance = assert(controls.WZP_SilentHitChance, "hit chance control missing")
        expect(chance.Range[1], 0, "minimum hit chance")
        expect(chance.Range[2], 100, "maximum hit chance")
        expect(chance.CurrentValue, 100, "initial hit chance")
        chance.Callback(73)
        expect(settings.silentAimHitChance, 73, "chance callback")
        local position = controls.WZP_SilentBone
        expect(position.CurrentOption, "Auto", "default position")
        assert(table.find(position.Options, "Auto"), "Auto option missing")
        position.Callback("Auto")
        expect(settings.silentAimBone, "Auto", "Auto callback")
    end)
    test("ballistics follow rifle, SMG and sniper changes without reusing the previous gun", function()
        local data = {
            HoneyBadger = { Speed = 500, Mass = 1, Immediate = false },
            UZI = { Speed = 500, Mass = 1, Immediate = false },
            AW_CITYSS2FTK = { Speed = 800, Mass = 2.6, Immediate = false },
        }
        local cs = { CurrentWeaponId = "HoneyBadger" }
        cs.BallisticsFor = function() return data[cs.CurrentWeaponId] end
        local get = makeBallistics({ getCombatSettings = function() return cs end,
            getWarzProjectile = function() return { Scale = 2.687, Gravity = Vector3.new(0,-26.360,0),
                StepSeconds = 1/60, Lifetime = 5 } end })
        for _, id in ipairs({"HoneyBadger", "UZI", "AW_CITYSS2FTK", "HoneyBadger"}) do
            cs.CurrentWeaponId = id
            local b = get()
            expect(b.weaponId, id, "weapon cache")
            expect(b.rawSpeed, data[id].Speed, "raw speed")
            assert(math.abs(b.speed - (id == "AW_CITYSS2FTK" and 2149.6 or 1343.5)) < 0.0001, "projectile speed")
            expect(b.mass, id == "AW_CITYSS2FTK" and 2.6 or 1, "projectile mass")
        end
    end)
    test("data-hitbox characters are not redirected to an inaccurate legacy point while loading", function()
        withTargets(function(f)
            local p = f.add(0)
            f.deps.getWarzHitboxes = function() return nil end
            expect(f.api().point(p.Character, "Head"), nil, "unready data hitbox used the legacy Head")
            p.Character:SetAttribute("WarzDataHitboxes", false)
            near(f.api().point(p.Character, "Head"), p.Character.Head.Position, "legacy character lost its fallback")
        end)
    end)
    test("enabling Silent Aim starts loading hitboxes and prediction before the first shot", function()
        local callback, hitboxLoads, ballisticLoads = nil, 0, 0
        local settings = { silentAim = false, aimPrediction = true }
        makeToggle({ settings = settings,
            CombatTab = { CreateToggle = function(_, options) callback = options.Callback end },
            getWarzHitboxes = function() hitboxLoads += 1 end,
            getCurrentBallistics = function() ballisticLoads += 1 end })
        callback(true)
        expect(settings.silentAim, true, "Silent Aim enabled")
        expect(hitboxLoads, 1, "hitbox preload")
        expect(ballisticLoads, 1, "prediction preload")
        callback(false)
        expect(hitboxLoads, 1, "disabled toggle must not load hitboxes")
    end)
    test("target FOV is checked before movement prediction", function()
        withTargets(function(f)
            f.add(0)
            near(f.api().target(), Vector3.new(100, 0, -100), "prediction outside FOV removed an eligible target")
        end)
    end)
    test("visibility checks use the actual hitbox rather than the future aim point", function()
        withTargets(function(f)
            f.add(0)
            f.api().target()
            expect(#f.sightChecks, 1, "visibility checks")
            near(f.sightChecks[1].point, Vector3.new(0, 0, -100), "visibility tested a future point")
        end)
    end)
    test("only the selected target is predicted using the shot's origin", function()
        withTargets(function(f)
            f.add(0); f.add(10)
            local origin = Vector3.new(2, 0, 0)
            f.api().target(nil, origin)
            expect(#f.predictions, 1, "prediction count")
            near(f.predictions[1].origin, origin, "shot origin was ignored")
        end)
    end)
    test("party members, protected players and dead targets are excluded", function()
        withTargets(function(f)
            f.add(0).party = true
            f.add(1).protected = true
            f.add(2).Character:SetAttribute("Dead", true)
            expect(f.api().target(), nil, "ineligible target selected")
        end)
    end)
    test("players wholly outside Silent FOV do not trigger expensive hitbox generation", function()
        withTargets(function(f)
            f.add(200)
            expect(f.api().target(), nil, "outside target selected")
            expect(f.shapeCalls(), 0, "outside character generated hitboxes")
        end)
    end)
    test("broad filtering preserves a limb inside FOV when the root is outside", function()
        withTargets(function(f)
            local p = f.add(30)
            f.shapes[p.Character][1].cf = CFrame.new(19,0,-100)
            near(f.api().target(), Vector3.new(119,0,-100), "edge hitbox was rejected by root filtering")
        end)
    end)
    test("offscreen roots can still have an eligible hitbox at the viewport edge", function()
        withTargets(function(f)
            local p = f.add(58)
            f.settings.silentAimFov = 50
            f.shapes[p.Character][1].cf = CFrame.new(48,0,-100)
            near(f.api().target(), Vector3.new(148,0,-100), "viewport-edge hitbox was rejected")
        end)
    end)
    test("broad filtering does not reject close targets intersecting the camera plane", function()
        withTargets(function(f)
            local p = f.add(0)
            p.Character.HumanoidRootPart.Position = Vector3.new(0,0,-5)
            f.shapes[p.Character][1].cf = CFrame.new(0,0,-3)
            near(f.api().target(), Vector3.new(100,0,-3), "close hitbox was rejected")
        end)
    end)
    test("candidates unable to beat the current target avoid hitbox generation", function()
        withTargets(function(f)
            f.add(0); f.add(15)
            near(f.api().target(), Vector3.new(100,0,-100), "nearest hitbox changed")
            expect(f.shapeCalls(), 1, "inferior candidate generated hitboxes")
        end)
    end)
    test("legacy custom rigs bypass the WarZ root-envelope assumption", function()
        withTargets(function(f)
            local p=f.add(200)
            p.Character:SetAttribute("WarzDataHitboxes",false)
            f.shapes[p.Character][1].cf=CFrame.new(0,0,-100)
            near(f.api().target(),Vector3.new(100,0,-100),"custom rig hitbox was culled")
        end)
    end)
    test("perspective filtering preserves in-FOV hitboxes across near and distant roots", function()
        withTargets(function(f)
            local p=f.add(0)
            local camera=workspace.CurrentCamera
            f.deps.camera=camera
            f.settings.aimPrediction=false
            local api=f.api()
            local frame=camera.CFrame
            for _,depth in ipairs({15,30,100,300})do
                for _,x in ipairs({-30,-15,-5,0,5,15,30})do
                    local rootPoint=frame.Position+frame.LookVector*depth+frame.RightVector*x
                    p.Character.HumanoidRootPart.Position=rootPoint
                    local shift=x<0 and 8 or -8
                    local point=rootPoint+frame.RightVector*shift
                    f.shapes[p.Character][1].cf=CFrame.new(point)
                    local view,on=camera:WorldToViewportPoint(point)
                    local pixels=(Vector2.new(view.X,view.Y)-camera.ViewportSize/2).Magnitude
                    local result=api.target()
                    if on and view.Z>0 and pixels<=f.settings.silentAimFov then
                        near(result,point,"perspective filtering dropped an eligible hitbox")
                    else
                        expect(result,nil,"outside-FOV hitbox selected")
                    end
                end
            end
        end)
    end)
    test("prediction measures travel from the supplied firing origin", function()
        local relative
        local deps = { settings = { aimPrediction = true }, camera = { CFrame = CFrame.new() }, predictionState = {},
            getCurrentBallistics = function() return { weaponId = "Fixture", rawSpeed = 100, speed = 100,
                mass = 1, gravity = Vector3.zero, stepSeconds = 1 / 60, lifetime = 5, immediate = false } end,
            targetLinearVelocity = function() return Vector3.zero end,
            solveBallisticTime = function(value) relative = value; return 1 end }
        local predict = makePrediction(deps)
        predict(Vector3.new(0, 0, -100), {}, Vector3.new(20, 0, 0))
        near(relative, Vector3.new(-20, 0, -100), "prediction used the render camera origin")
    end)

    local function withHook(callback)
        -- Keep the transport local; real Vector3/CFrame namecalls below still
        -- exercise the executor context that the previous fixture missed.
        local installed, sent, sentMethod, transport, targetCalls, roll, rollCount
        targetCalls = 0
        roll, rollCount = 49, 0
        local remote = { Name = "FireRequest", IsA = function(_, class) return class == "RemoteEvent" end,
            FireServer = function(_, ...)
                sent, sentMethod, transport = table.pack(...), "FireServer", "direct"
            end }
        local folder = { FindFirstChild = function(_, name)
            expect(name, "FireRequest", "fire remote")
            return remote
        end }
        local point = Vector3.new(10, 0, -100)
        local deps
        deps = {
            running = true, settings = { silentAim = true }, camera = { CFrame = CFrame.new() }, game = {},
            ReplicatedStorage = { FindFirstChild = function(_, name)
                expect(name, "Remotes", "remote folder")
                return folder
            end },
            hookmetamethod = function(_, _, fn)
                installed = fn
                return function(_, ...)
                    sent, sentMethod, transport = table.pack(...), deps.getnamecallmethod(), "namecall"
                end
            end,
            getnamecallmethod = function() return "FireServer" end, checkcaller = function() return false end,
            setnamecallmethod = setnamecallmethod,
            Random = { new = function() return { NextNumber = function(_, low, high)
                expect(low, 0, "chance lower bound"); expect(high, 100, "chance upper bound")
                rollCount += 1
                return roll
            end } end },
            getSilentAimTarget = function(_, origin)
                targetCalls = targetCalls + 1
                return point
            end,
            Workspace = { CurrentCamera = { CFrame = CFrame.new() } },
        }
        local ok, err = pcall(callback, { deps = deps, remote = remote,
            install = function() return makeHook(deps) end,
            invoke = function(...) assert(installed, "hook not installed"); installed(remote, ...) end,
            point = function(value) point = value end, sent = function() return sent end,
            method = function() return sentMethod end, transport = function() return transport end,
            roll = function(value) roll = value end, rolls = function() return rollCount end,
            calls = function() return targetCalls end,
            installed = function() return type(installed) == "function" end })
        assert(ok, err)
    end
    test("zero percent leaves shots untouched without selecting a target", function()
        withHook(function(f)
            f.deps.settings.silentAimHitChance = 0
            f.install()
            f.invoke(Vector3.new(0,0,-1),0.25,nil,Vector3.zero,nil,nil,"gun-root",nil)
            near(f.sent()[1], Vector3.new(0,0,-1), "zero chance changed direction")
            expect(f.calls(), 0, "zero chance selected a target")
            expect(f.rolls(), 0, "zero chance consumed randomness")
            expect(f.sent().n, 8, "skipped argument count")
        end)
    end)
    test("one hundred percent redirects every eligible shot without sampling", function()
        withHook(function(f)
            f.deps.settings.silentAimHitChance = 100
            f.roll(100)
            f.install()
            f.invoke(Vector3.new(0,0,-1),0.25,{},Vector3.zero)
            near(f.sent()[1], Vector3.new(10,0,-100).Unit, "full chance failed to redirect")
            expect(f.calls(), 1, "full chance target selection")
            expect(f.rolls(), 0, "full chance consumed randomness")
        end)
    end)
    test("partial hit chance samples once per shot and preserves skipped requests", function()
        withHook(function(f)
            f.deps.settings.silentAimHitChance = 50
            f.install()
            f.roll(49.99)
            f.invoke(Vector3.new(0,0,-1),0.25,{},Vector3.zero)
            near(f.sent()[1], Vector3.new(10,0,-100).Unit, "roll below threshold was skipped")
            f.roll(50)
            f.invoke(Vector3.new(0,0,-1),0.33,nil,Vector3.zero,nil,nil,"gun-root",nil)
            near(f.sent()[1], Vector3.new(0,0,-1), "roll at threshold redirected")
            expect(f.calls(), 1, "skipped shot selected a target")
            expect(f.rolls(), 2, "chance was not sampled once per shot")
            expect(f.sent().n, 8, "skipped shot argument count")
            expect(f.sent()[2], 0.33, "skipped shot spread seed")
        end)
    end)
    for _, outcome in ipairs({ "point", "missing", "error" }) do
        test("shot forwarding restores FireServer after nested namecalls: " .. outcome, function()
            withHook(function(f)
                f.deps.getnamecallmethod = getnamecallmethod
                f.deps.getSilentAimTarget = function()
                    Vector3.one:Dot(Vector3.one)
                    CFrame.new():ToObjectSpace(CFrame.new())
                    if outcome == "error" then error("target disappeared") end
                    return outcome == "point" and Vector3.new(10, 0, -100) or nil
                end
                f.install()
                setnamecallmethod("FireServer")
                f.invoke(Vector3.new(0, 0, -1), 0.25, {}, Vector3.zero)
                expect(f.method(), "FireServer", "nested math method reached the firing remote")
                near(f.sent()[1], outcome == "point" and Vector3.new(10, 0, -100).Unit
                    or Vector3.new(0, 0, -1), "incorrect forwarded direction")
            end)
        end)
    end
    test("executor without a namecall setter forwards through the bound FireServer method", function()
        withHook(function(f)
            f.deps.setnamecallmethod = nil
            f.deps.getnamecallmethod = getnamecallmethod
            f.deps.getSilentAimTarget = function()
                Vector3.one:Dot(Vector3.one)
                return Vector3.new(10, 0, -100)
            end
            f.install()
            setnamecallmethod("FireServer")
            f.invoke(Vector3.new(0, 0, -1), 0.25, nil, Vector3.zero, nil, nil, "gun-root", nil)
            expect(f.method(), "FireServer", "incorrect remote method")
            near(f.sent()[1], Vector3.new(10, 0, -100).Unit, "incorrect shot direction")
            expect(f.transport(), "direct", "unsupported namecall restoration path used")
            expect(f.sent().n, 8, "remote argument count")
            expect(f.sent()[7], "gun-root", "gun root")
        end)
    end)
    test("each shot resolves the latest target without waiting for a render frame", function()
        withHook(function(f)
            f.install()
            f.point(Vector3.new(20, 0, -100))
            f.invoke(Vector3.new(0, 0, -1), 0.5, {}, Vector3.zero)
            near(f.sent()[1], Vector3.new(20, 0, -100).Unit, "stale shot direction")
            expect(f.calls(), 1, "shot-time target selection")
        end)
    end)
    test("redirected shots preserve nil arguments and all untouched values", function()
        withHook(function(f)
            f.install()
            f.invoke(Vector3.new(0, 0, -1), 0.25, nil, Vector3.zero, nil, nil, "gun-root", nil)
            local sent = f.sent()
            near(sent[1], Vector3.new(10, 0, -100).Unit, "shot was not redirected")
            expect(sent.n, 8, "remote argument count")
            expect(sent[2], 0.25, "spread seed")
            expect(sent[3], nil, "nil stance")
            expect(sent[7], "gun-root", "gun root")
        end)
    end)
    test("target selection failures leave the original shot intact", function()
        withHook(function(f)
            f.deps.getSilentAimTarget = function() error("target disappeared") end
            f.install()
            f.invoke(Vector3.new(0, 0, -1), 0.25, {}, Vector3.zero)
            near(f.sent()[1], Vector3.new(0, 0, -1), "failed selection changed shot")
        end)
    end)
    test("zero-length shot direction leaves the original shot intact", function()
        withHook(function(f)
            f.point(Vector3.zero)
            f.install()
            f.invoke(Vector3.new(0, 0, -1), 0.25, {}, Vector3.zero)
            near(f.sent()[1], Vector3.new(0, 0, -1), "invalid zero direction")
        end)
    end)
    test("missing caller inspection does not install a broken hook", function()
        withHook(function(f)
            f.deps.checkcaller = nil
            f.install()
            expect(f.installed(), false, "unsupported hook installed")
        end)
    end)
    local passed = 0
    for _, result in ipairs(results) do if result.passed then passed = passed + 1 end end
    return { passed = passed, failed = #results - passed, tests = results }
end
