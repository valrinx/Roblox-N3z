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

    local function withTargets(callback)
        local models, players, shapes, predictions, sightChecks = {}, {}, {}, {}, {}
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
            Players = { GetPlayers = function() return players end }, localPlayer = {}, camera = camera, settings = settings,
            getWarzHitboxes = function() return { DataShapes = function(character) return shapes[character] end } end,
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
        local installed, sent, sentMethod, transport, targetCalls
        targetCalls = 0
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
            calls = function() return targetCalls end,
            installed = function() return type(installed) == "function" end })
        assert(ok, err)
    end
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
