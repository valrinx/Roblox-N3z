return function(sources)
    local results = {}
    local function test(name, fn)
        local ok, err = pcall(fn)
        results[#results+1] = {name = name, passed = ok, error = not ok and tostring(err) or nil}
    end
    local function expect(value, wanted, message)
        assert(value == wanted, message .. ': expected ' .. tostring(wanted) .. ', got ' .. tostring(value))
    end
    local function signal()
        local entries = {}
        return {Connect = function(_, fn)
            local e = {fn = fn, live = true}; entries[#entries+1] = e
            return {Disconnect = function() e.live = false end}
        end, Fire = function(_, ...)
            for _,e in ipairs(entries) do if e.live then e.fn(...) end end
        end}
    end
    local function backend()
        local writes, removes, objects = 0, 0, {}
        local function new()
            local state = {Visible = false, TextBounds = Vector2.new(40, 14)}
            local obj = setmetatable({}, {__index = function(_, key)
                if key == 'Remove' then return function() removes += 1 end end
                return state[key]
            end, __newindex = function(_, key, value) writes += 1; state[key] = value end})
            objects[#objects+1] = state
            return obj
        end
        return {new = new, newImage = new}, function() return writes end,
            function() return removes end, objects
    end
    test('unchanged visual properties reach the backend only once', function()
        local b, writes = backend(); local api = assert(loadstring(sources.visual))()({visualBackend = b})
        local d = api.draw('Text')
        for _=1,100 do d.Visible = false; d.Text = 'Player 100m'; d.Position = Vector2.new(20, 30) end
        expect(writes(), 3, 'redundant backend writes')
        d.Text = 'Player 101m'; expect(writes(), 4, 'changed text did not reach backend')
        expect(d.Text, 'Player 101m', 'cached property read')
    end)
    test('computed text bounds stay live through the visual cache', function()
        local b, _, _, states = backend(); local api = assert(loadstring(sources.visual))()({visualBackend = b})
        local d = api.draw('Text'); expect(d.TextBounds.X, 40, 'initial text bounds')
        states[1].TextBounds = Vector2.new(70, 14); expect(d.TextBounds.X, 70, 'stale text bounds')
    end)
    test('images share dirty property updates and removal is idempotent', function()
        local b, writes, removes = backend(); local api = assert(loadstring(sources.visual))()({visualBackend = b})
        local d = api.image(); d.Image = 'asset'; d.Image = 'asset'; expect(writes(), 1, 'image writes')
        d:Remove(); d:Remove(); expect(removes(), 1, 'duplicate removal')
        d.Visible = true; expect(writes(), 1, 'removed visual updated')
    end)
    test('failed visual creation stays nil', function()
        local api = assert(loadstring(sources.visual))()({visualBackend = {new = function() return nil end}})
        expect(api.draw('Text'), nil, 'failed Drawing'); expect(api.image(), nil, 'unsupported image')
    end)
    local function withNative(fn)
        local states, writes = {}, 0
        local factory = {new = function(class)
            local state = {ClassName = class, TextBounds = Vector2.new(40,14)}; states[#states+1] = state
            return setmetatable({}, {__index = function(_,key)
                if key == 'Destroy' then return function() state.Parent = nil end end
                return state[key]
            end, __newindex = function(_,key,value) writes += 1; state[key] = value end})
        end}
        local create = assert(loadstring(sources.native))()({Instance = factory})
        local b = create({resolveParent = function() return {} end})
        local function state(name)
            for _,s in ipairs(states) do if s.Name == name then return s end end
        end
        local ok,err = pcall(fn,{backend = b, state = state, writes = function() return writes end})
        b.destroy(); assert(ok,err)
    end
    test('native text position updates only geometry and skips unchanged values', function()
        withNative(function(f)
            local d = f.backend.new('Text'); d.Text = 'Player'; local before = f.writes()
            d.Position = Vector2.new(20,30); expect(f.writes()-before,1,'native text position writes')
            expect(f.state('NativeText').Position,UDim2.fromOffset(20,30),'native text position')
            d.Position = Vector2.new(20,30); expect(f.writes()-before,1,'duplicate native geometry update')
            expect(f.state('NativeText').Text,'Player','text changed while moving')
        end)
    end)
    test('native line color avoids recomputing geometry', function()
        withNative(function(f)
            local d = f.backend.new('Line'); d.From = Vector2.new(0,0); d.To = Vector2.new(3,4)
            local before = f.writes(); d.Color = Color3.new(1,0,0)
            expect(f.writes()-before,1,'line color property writes')
            expect(f.state('NativeLine').Size,UDim2.fromOffset(5,1),'line length')
            expect(f.state('NativeLine').Position,UDim2.fromOffset(1.5,2),'line midpoint')
            d.Thickness = 3; expect(f.state('NativeLine').Size,UDim2.fromOffset(5,3),'line thickness')
        end)
    end)
    test('native circle square and image still apply their dependent properties', function()
        withNative(function(f)
            local circle = f.backend.new('Circle'); circle.Radius = 12; circle.Position = Vector2.new(50,60)
            expect(f.state('NativeCircle').Size,UDim2.fromOffset(24,24),'circle diameter')
            circle.Filled = true; circle.Transparency = 0.25
            expect(f.state('NativeCircle').BackgroundTransparency,0.75,'circle alpha')
            local square = f.backend.new('Square'); square.Size = Vector2.new(20,40); square.Position = Vector2.new(5,6)
            expect(f.state('NativeSquare').Size,UDim2.fromOffset(20,40),'square size')
            square.Filled = true; square.Transparency = 0.5
            expect(f.state('NativeSquare').BackgroundTransparency,0.5,'square alpha')
            local image = f.backend.new('Image'); image.Image = 'asset'; image.Size = Vector2.new(32,16); image.Transparency = 0.8
            expect(f.state('NativeImage').Image,'asset','image asset')
            expect(f.state('NativeImage').Size,UDim2.fromOffset(32,16),'image dimensions')
            assert(math.abs(f.state('NativeImage').ImageTransparency-0.2)<0.00001,'image alpha')
        end)
    end)
    local function withEsp(fn, count, realBackend)
        local models, players, lives, cache = {}, {}, {}, {}
        local b, writes = backend()
        local nativeParent
        if realBackend == 'native' then
            nativeParent = Instance.new('Folder')
            local create = assert(loadstring(sources.native))()({Instance = Instance})
            b = create({resolveParent = function() return nativeParent end})
        elseif realBackend then b = {new = function(kind) return Drawing.new(kind) end} end
        local camera = {CFrame = CFrame.new(), ViewportSize = Vector2.new(1000, 700),
            WorldToViewportPoint = function(self, p) return Vector3.new(500+p.X*10+(self.offset or 0), 350-p.Y*10, -p.Z), p.X < 40 end}
        local segments = {}
        for i=1,19 do segments[i] = {tostring(i),tostring(i+1)} end
        for i=1,count or 3 do
            local ch = Instance.new('Model'); models[#models+1] = ch
            local root = Instance.new('Part'); root.Name = 'HumanoidRootPart'; root.Position = Vector3.new(i,0,-100); root.Parent = ch
            local hum = Instance.new('Humanoid'); hum.Parent = ch
            local live = Instance.new('Folder'); live.Parent = ch
            for j=1,20 do local bone = Instance.new('Part'); bone.Name = tostring(j); bone.Position = Vector3.new(i,j/10,-100); bone.Parent = live end
            local p = {Name = 'Player'..i, UserId = i, Character = ch, GetAttribute = function() return nil end}
            players[#players+1] = p; lives[p] = live
        end
        local deps = {visualBackend = b, espCache = cache, camera = camera,
            settings = {espEnabled = true, maxDistance = 1000, boxEsp = true, nameEsp = true,
                distanceEsp = true, healthEsp = true, skeletonEsp = true, weaponEsp = false},
            Players = {GetPlayers = function() return players end}, localPlayer = {},
            bodyPart = function(ch,n) return ch:FindFirstChild(n) end, ESP_COLOR = Color3.new(1,1,0),
            LIVEAIM_BONES = segments, LIVEAIM_BONE_COUNT = 19,
            getLiveAim = function(p) return lives[p] end, findLiveBone = function(l,n) return l:FindFirstChild(n) end,
            boneWorldPosition = function(bone) return bone and bone.Parent and bone.Position or nil end,
            getPlayerRelationColor = function() return nil end,
            getRenderedWeaponId = function() return nil end, getWeaponIconSource = function() return nil end,
            Workspace = {GetServerTimeNow = function() return 10 end},
            getHealthColor = function(ratio) return Color3.fromHSV(ratio*0.33,0.9,1) end}
        local api = assert(loadstring(sources.esp))()(deps)
        local ok, err = pcall(fn, {api = api, deps = deps, cache = cache, players = players, lives = lives, writes = writes})
        for p in pairs(cache) do api.destroy(p) end
        if nativeParent then b.destroy(); nativeParent:Destroy() end
        for _,m in ipairs(models) do m:Destroy() end
        assert(ok, err)
    end
    test('a static ESP frame issues no redundant visual writes', function()
        withEsp(function(f)
            f.api.update(f.players); local before = f.writes(); f.api.update(f.players)
            expect(f.writes() - before, 0, 'static ESP writes')
            f.players[1].Character.HumanoidRootPart.Position += Vector3.new(1,0,0)
            f.api.update(f.players); assert(f.writes() > before, 'moving player did not update ESP')
        end)
    end)
    test('skeleton projection storage is reused without stale visible segments', function()
        withEsp(function(f)
            f.api.update(f.players); local p = f.players[1]; local e = f.cache[p]
            local scratch = assert(e.boneProjected, 'projection scratch storage missing')
            f.api.update(f.players); expect(e.boneProjected, scratch, 'projection table was replaced')
            expect(e.bones[1].Visible, true, 'initial segment')
            f.lives[p]:FindFirstChild('1'):Destroy(); f.api.update(f.players)
            expect(e.bones[1].Visible, false, 'stale bone remained visible')
        end)
    end)
    test('hidden ESP stays hidden without repeating backend updates', function()
        withEsp(function(f)
            f.api.update(f.players); f.deps.settings.espEnabled = false; f.api.update(f.players)
            local before = f.writes(); f.api.update(f.players); expect(f.writes(), before, 'hidden frame writes')
            f.deps.settings.espEnabled = true; f.api.update(f.players)
            expect(f.cache[f.players[1]].box.Visible, true, 'ESP did not return after enabling')
        end)
    end)
    test('hiding an entry twice does not revisit its drawing primitives', function()
        local b,writes = backend(); local e = {box = b.new(), name = b.new(), bones = {b.new()}}
        local deps = {visualBackend = b, espCache = {}, LIVEAIM_BONE_COUNT = 0}
        local api = assert(loadstring(sources.esp))()(deps)
        api.hide(e); local before = writes(); api.hide(e)
        expect(writes(),before,'already hidden drawing revisited')
    end)
    test('a failed hide retries the primitive on the next update', function()
        local fail, visible = true, true
        local d = setmetatable({}, {__newindex = function(_,key,value)
            if fail then fail = false; error('drawing temporarily unavailable') end
            if key == 'Visible' then visible = value end
        end})
        local api = assert(loadstring(sources.esp))()({espCache = {}, LIVEAIM_BONE_COUNT = 0})
        local e = {box = d, bones = {}}
        api.hide(e); expect(visible,true,'failed hide outcome')
        api.hide(e); expect(visible,false,'failed hide never retried')
    end)
    test('player roster stays current without allocating a service list for each scan', function()
        local a,b,c = {},{},{}; local list = {a,b}; local reads = 0
        local players = {PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function()
            reads += 1; return table.clone(list)
        end}
        local api = assert(loadstring(sources.cache))()({Players = players})
        for _=1,100 do expect(#api.get(), 2, 'initial roster') end
        expect(reads, 1, 'service roster allocations')
        players.PlayerAdded:Fire(c); expect(#api.get(), 3, 'joining player missing')
        players.PlayerRemoving:Fire(b); expect(#api.get(), 2, 'leaving player remained')
        expect(api.get()[1], a, 'first player changed'); expect(api.get()[2], c, 'dense removal')
        api.destroy(); players.PlayerAdded:Fire(b); expect(#api.get(), 2, 'roster listener survived cleanup')
    end)
    local function withSupport(fn)
        local now, healthReads, attrReads, uses = 10, 0, 0, 0
        local attrs = {CSGO_Stamina = 100, CSGO_SprintLock = false, CSGO_SprintPenalty = 0, WarzServerStamina = 100}
        local signals, connections = {}, {}
        local hum = {Health = 20, MaxHealth = 100}
        local lp = {Character = {FindFirstChildOfClass = function() healthReads += 1; return hum end}}
        function lp:GetAttribute(key) attrReads += 1; return attrs[key] end
        function lp:GetAttributeChangedSignal(key) signals[key] = signals[key] or signal(); return signals[key] end
        function lp:SetAttribute(key,value)
            if attrs[key] ~= value then attrs[key] = value; self:GetAttributeChangedSignal(key):Fire() end
        end
        local settings = {autoHeal = true, healThreshold = 50, healCooldown = 0, infiniteStamina = true}
        local chunk = assert(loadstring(sources.support))
        setfenv(chunk, setmetatable({os = {clock = function() return now end}}, {__index = getfenv()}))
        local api = chunk()({localPlayer = lp, settings = settings, running = true, connections = connections,
            getCombatInput = function() return {RequestUseMed = function() uses += 1 end} end})
        local f = {api = api, lp = lp, attrs = attrs, settings = settings, hum = hum,
            healthReads = function() return healthReads end, attrReads = function() return attrReads end,
            uses = function() return uses end, step = function(dt) now += dt; api.heal(dt); api.stamina(dt) end}
        local ok, err = pcall(fn,f); for _,c in ipairs(connections) do c:Disconnect() end; assert(ok,err)
    end
    test('Auto Heal polls at bounded frequency while retaining its cooldown', function()
        withSupport(function(f)
            for _=1,100 do f.step(0.01) end
            assert(f.healthReads() <= 11, 'health scanned each frame: '..f.healthReads())
            assert(f.uses() >= 1 and f.uses() <= 2, 'heal cooldown was changed')
        end)
    end)
    test('healthy or disabled Auto Heal never requests a med', function()
        withSupport(function(f)
            f.hum.Health = 90; for _=1,30 do f.step(0.01) end; expect(f.uses(),0,'healthy heal')
            f.hum.Health = 20; f.settings.autoHeal = false; for _=1,30 do f.step(0.01) end
            expect(f.uses(),0,'disabled heal')
        end)
    end)
    test('all stamina attributes are corrected immediately by their own events', function()
        withSupport(function(f)
            f.lp:SetAttribute('CSGO_Stamina',20); expect(f.attrs.CSGO_Stamina,100,'stamina event')
            f.lp:SetAttribute('CSGO_SprintLock',true); expect(f.attrs.CSGO_SprintLock,false,'sprint lock event')
            f.lp:SetAttribute('CSGO_SprintPenalty',5); expect(f.attrs.CSGO_SprintPenalty,0,'penalty event')
            f.lp:SetAttribute('WarzServerStamina',20); expect(f.attrs.WarzServerStamina,100,'server stamina event')
        end)
    end)
    test('unchanged stamina does not scan attributes on every render frame', function()
        withSupport(function(f)
            f.settings.autoHeal = false; for _=1,100 do f.step(0.01) end
            assert(f.attrReads() <= 8, 'stamina attributes polled each frame: '..f.attrReads())
        end)
    end)
    test('disabled stamina respects incoming values', function()
        withSupport(function(f)
            f.settings.infiniteStamina = false; f.lp:SetAttribute('CSGO_Stamina',20)
            f.lp:SetAttribute('WarzServerStamina',20); for _=1,10 do f.step(0.1) end
            expect(f.attrs.CSGO_Stamina,20,'disabled stamina'); expect(f.attrs.WarzServerStamina,20,'disabled server stamina')
        end)
    end)
    local benchmark
    withEsp(function(f)
        for _=1,10 do f.api.update(f.players) end
        local before = f.writes(); local started = os.clock()
        for _=1,200 do f.api.update(f.players) end
        benchmark = {players = #f.players, frames = 200, writes = f.writes()-before, elapsedMs = (os.clock()-started)*1000}
    end,30)
    local realBenchmark, nativeBenchmark = {}, {}
    if sources.realBenchmark then
        for _, visualKind in ipairs({'drawing','native'}) do
            for _, moving in ipairs({false,true}) do
                local samples = {}
                for _=1,5 do
                    withEsp(function(f)
                        for _=1,10 do f.api.update(f.players) end
                        local started = os.clock()
                        for frame=1,60 do
                            f.deps.camera.offset = moving and frame % 20 or 0
                            f.api.update(f.players)
                        end
                        samples[#samples+1] = (os.clock()-started)*1000
                    end,30,visualKind == 'native' and 'native' or true)
                end
                table.sort(samples)
                local target = visualKind == 'native' and nativeBenchmark or realBenchmark
                target[#target+1] = {moving = moving, frames = 60, medianMs = samples[3]}
            end
        end
    end
    local passed = 0; for _,r in ipairs(results) do if r.passed then passed += 1 end end
    return {passed = passed, failed = #results-passed, tests = results, benchmark = benchmark, realBenchmark = realBenchmark, nativeBenchmark = nativeBenchmark}
end
