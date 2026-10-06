return function(sources)
    local results = {}
    local function near(actual, expected)
        assert(type(actual) == "number" and math.abs(actual - expected) < 0.000001,
            "expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
    local function test(name, fn)
        local ok, err = pcall(fn)
        results[#results + 1] = {name = name, passed = ok, error = not ok and tostring(err) or nil}
    end
    local function fixture(strength)
        local weapon = {Recoil = 12, ViewRecoil = 0.6, Spread = 0.2}
        local shop = {Recoil = 10, ViewRecoil = 0.4, Spread = 0.3}
        local catalog = {Weapons = {rifle = weapon}}
        local cs = {GetCatalog = function() return catalog end}
        local config = {Shop = {rifle = shop}}
        local settings = {noRecoil = true, noRecoilStrength = strength}
        local cached, calls = {CombatSettings = cs, SharedConfig = config}, 0
        local pending = {}
        local chunk = assert(loadstring(sources.patch))
        setfenv(chunk, setmetatable({task = {defer = function(fn) pending[#pending+1] = fn end}}, {__index = getfenv()}))
        local apply, request, stop = chunk()({settings = settings,
            peekLazy = function(key) return cached[key] end,
            getCombatSettings = function() calls += 1; return cached.CombatSettings end,
            getSharedConfig = function() calls += 1; return cached.SharedConfig end})
        return {weapon = weapon, shop = shop, catalog = catalog, settings = settings,
            apply = apply, request = request, stop = stop, cached = cached, calls = function() return calls end,
            flush = function() local jobs = table.clone(pending); table.clear(pending); for _,job in ipairs(jobs) do job() end end}
    end
    for _, row in ipairs({{0, 12, 0.6, 10, 0.4}, {25, 9, 0.45, 7.5, 0.3},
        {50, 6, 0.3, 5, 0.2}, {100, 0, 0, 0, 0}}) do
        test("strength " .. row[1] .. "% scales weapon and shop recoil", function()
            local f = fixture(row[1]); f.apply()
            near(f.weapon.Recoil, row[2]); near(f.weapon.ViewRecoil, row[3])
            near(f.shop.Recoil, row[4]); near(f.shop.ViewRecoil, row[5])
        end)
    end
    test("refresh never compounds the percentage", function()
        local f = fixture(50); for _ = 1, 5 do f.apply() end
        near(f.weapon.Recoil, 6); near(f.weapon.ViewRecoil, 0.3); near(f.shop.Recoil, 5)
    end)
    test("changing strength uses the original recoil", function()
        local f = fixture(100); f.apply(); f.settings.noRecoilStrength = 25; f.apply()
        near(f.weapon.Recoil, 9); near(f.weapon.ViewRecoil, 0.45); near(f.shop.Recoil, 7.5)
    end)
    test("switching off restores originals regardless of strength", function()
        local f = fixture(50); f.apply(); f.settings.noRecoil = false; f.apply()
        near(f.weapon.Recoil, 12); near(f.weapon.ViewRecoil, 0.6)
        near(f.shop.Recoil, 10); near(f.shop.ViewRecoil, 0.4)
    end)
    test("spread remains unchanged", function()
        local f = fixture(50); f.apply(); near(f.weapon.Spread, 0.2); near(f.shop.Spread, 0.3)
    end)
    test("preexisting backups survive reload", function()
        local f = fixture(50)
        f.weapon.Recoil, f.weapon.ViewRecoil = 0, 0
        f.weapon._origRecoil, f.weapon._origViewRecoil = 12, 0.6
        f.apply(); near(f.weapon.Recoil, 6); near(f.weapon.ViewRecoil, 0.3)
    end)
    test("newly added guns receive the selected strength", function()
        local f = fixture(50); f.apply()
        f.catalog.Weapons.sniper = {Recoil = 20, ViewRecoil = 0.8}
        f.apply(); near(f.catalog.Weapons.sniper.Recoil, 10); near(f.catalog.Weapons.sniper.ViewRecoil, 0.4)
    end)
    test("catalog and shop aliases do not scale twice", function()
        local f = fixture(50); f.cached.SharedConfig.Shop.rifle = f.weapon; f.apply()
        near(f.weapon.Recoil, 6); near(f.weapon.ViewRecoil, 0.3)
    end)
    test("cached cleanup restores without loading modules", function()
        local f = fixture(50); f.apply(); local before = f.calls()
        f.settings.noRecoil = false; f.apply(true)
        near(f.weapon.Recoil, 12); near(f.shop.Recoil, 10); assert(f.calls() == before)
    end)
    test("cleanup with no cached modules never invokes lazy getters", function()
        local f = fixture(50); table.clear(f.cached); f.settings.noRecoil = false; f.apply(true)
        assert(f.calls() == 0, "cleanup started lazy loading")
    end)
    test("shared config can apply while catalog is still loading", function()
        local f = fixture(50); f.cached.CombatSettings.GetCatalog = function() return nil end
        f.apply(); near(f.shop.Recoil, 5)
    end)
    test("shared config can apply before CombatSettings is cached", function()
        local f = fixture(50); f.cached.CombatSettings = nil; f.apply()
        near(f.shop.Recoil, 5); near(f.shop.ViewRecoil, 0.2)
    end)
    test("invalid strength falls back to full assistance", function()
        local f = fixture("invalid"); f.apply(); near(f.weapon.Recoil, 0)
    end)
    for _, row in ipairs({{-50, 12}, {150, 0}}) do
        test("out of range strength " .. row[1] .. " is clamped", function()
            local f = fixture(row[1]); f.apply(); near(f.weapon.Recoil, row[2])
        end)
    end
    test("controls expose a 0-100 slider and apply changes after UI construction", function()
        local f = fixture(100); local controls = {}
        local tab = {CreateToggle = function(_, c) controls[c.Flag] = c end,
            CreateSlider = function(_, c) controls[c.Flag] = c end}
        assert(loadstring(sources.controls))()({settings = f.settings, CombatTab = tab,
            applyNoRecoil = f.apply, requestNoRecoilApply = f.request})
        local slider = assert(controls.WZP_NoRecoilStrength, "strength slider missing")
        near(slider.Range[1], 0); near(slider.Range[2], 100); near(slider.Increment, 1); near(slider.CurrentValue, 100)
        slider.Callback(50); near(f.settings.noRecoilStrength, 50)
        near(f.weapon.Recoil, 12); f.flush(); near(f.weapon.Recoil, 6)
        controls.WZP_NoRecoil.Callback(false); f.flush(); near(f.weapon.Recoil, 12)
        slider.Callback(75); f.flush(); near(f.weapon.Recoil, 12)
        controls.WZP_NoRecoil.Callback(true); f.flush(); near(f.weapon.Recoil, 3)
        slider.Callback(150); near(f.settings.noRecoilStrength, 100)
        slider.Callback(-20); near(f.settings.noRecoilStrength, 0)
    end)
    test("queued recoil changes coalesce and use the latest strength", function()
        local f = fixture(100); assert(f.request, "deferred recoil queue missing")
        f.request(); f.settings.noRecoilStrength = 50; f.request()
        f.settings.noRecoilStrength = 25; f.request()
        near(f.weapon.Recoil, 12); f.flush(); near(f.weapon.Recoil, 9)
        assert(f.calls() == 2, "repeated UI changes scanned modules multiple times")
    end)
    test("unload cancels queued recoil work before calling game APIs", function()
        local f = fixture(50); assert(f.request, "deferred recoil queue missing")
        f.request(); f.stop(); f.flush()
        near(f.weapon.Recoil, 12); assert(f.calls() == 0, "unloaded job called game modules")
    end)
    test("unload during catalog resolution prevents stale recoil writes", function()
        local f = fixture(50)
        f.cached.CombatSettings.GetCatalog = function() f.stop(); return f.catalog end
        f.request(); f.flush(); near(f.weapon.Recoil, 12); near(f.shop.Recoil, 10)
    end)
    test("cached cleanup still restores originals after the module stops", function()
        local f = fixture(50); f.apply(); f.settings.noRecoil = false; f.stop(); f.apply(true)
        near(f.weapon.Recoil, 12); near(f.shop.Recoil, 10)
    end)
    local passed = 0
    for _, r in ipairs(results) do if r.passed then passed += 1 end end
    return {passed = passed, failed = #results - passed, tests = results}
end
