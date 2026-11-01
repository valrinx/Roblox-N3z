return function(Window, ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "urban_reload: ctx.loadModuleFile is required")

    local env = (type(getgenv) == "function" and getgenv()) or _G
    local featurePaths = {
        farm = "tools/urban_reload_auto_farm.lua",
        aim = "tools/urban_reload_player_aim_assist.lua",
        stamina = "tools/urban_reload_infinite_stamina.lua",
    }
    local envKeys = {
        farm = "N3Z_UrbanFarm",
        aim = "N3Z_PlayerAimAssist",
        stamina = "N3Z_UrbanInfiniteStamina",
    }
    local features = {}
    local destroyed = false
    local farmToggle
    local aimToggle
    local staminaToggle
    local options = {
        farmRange = 95,
        farmMinHealth = 35,
        aimFov = 180,
        aimDistance = 450,
        aimSmoothness = 18,
        aimTurnSpeed = 120,
        aimCircle = true,
        aimHold = false,
    }

    local function instanceFor(name)
        return features[name] or env[envKeys[name]]
    end

    local function stopFeature(name)
        local instance = instanceFor(name)
        if type(instance) == "table" and type(instance.Stop) == "function" then
            pcall(instance.Stop)
        end
    end

    local function configure(name, instance)
        if name == "farm" then
            instance.MaxDistance = options.farmRange
            instance.MinHealth = options.farmMinHealth
        elseif name == "aim" then
            instance.FovPixels = options.aimFov
            instance.MaxDistance = options.aimDistance
            instance.Smoothness = options.aimSmoothness / 100
            instance.MaxTurnDegreesPerSecond = options.aimTurnSpeed
            instance.FovVisible = options.aimCircle
            instance.RequireRightMouse = options.aimHold
        end
    end

    local function startFeature(name)
        if destroyed then return false end
        local instance = features[name]
        if not instance then
            local ok, result = pcall(ctx.loadModuleFile, featurePaths[name])
            if not ok or type(result) ~= "table" or type(result.Start) ~= "function"
                or type(result.Stop) ~= "function" then
                warn("[N3Z Urban Reload] " .. name .. " failed: " .. tostring(result))
                return false
            end
            instance = result
            features[name] = instance
        end
        configure(name, instance)
        local ok, err = pcall(instance.Start)
        if not ok then
            warn("[N3Z Urban Reload] " .. name .. " failed to start: " .. tostring(err))
        end
        return ok
    end

    local function rollbackToggle(handle)
        task.defer(function()
            if handle and handle:Get() then handle:Set(false) end
        end)
    end

    local combat = Window:CreateTab("Urban Reload Combat")
    local visuals = Window:CreateTab("Urban Reload Visuals")
    local movement = Window:CreateTab("Urban Reload Movement")

    farmToggle = combat:CreateToggle({
        Name = "Auto Farm Zombies + Instant Loot",
        Flag = "UrbanReload_AutoFarm",
        Default = false,
        Callback = function(enabled)
            if enabled then
                stopFeature("aim")
                if aimToggle and aimToggle:Get() then aimToggle:Set(false) end
                if not startFeature("farm") then rollbackToggle(farmToggle) end
            else
                stopFeature("farm")
            end
        end,
    })

    aimToggle = combat:CreateToggle({
        Name = "Player Aim Assist",
        Flag = "UrbanReload_PlayerAim",
        Default = false,
        Callback = function(enabled)
            if enabled then
                stopFeature("farm")
                if farmToggle and farmToggle:Get() then farmToggle:Set(false) end
                if not startFeature("aim") then rollbackToggle(aimToggle) end
            else
                stopFeature("aim")
            end
        end,
    })

    combat:CreateSlider({
        Name = "Farm Range",
        Flag = "UrbanReload_FarmRange",
        Min = 20,
        Max = 150,
        Default = options.farmRange,
        Increment = 5,
        Callback = function(value)
            options.farmRange = value
            local instance = features.farm
            if instance then configure("farm", instance) end
        end,
    })

    combat:CreateSlider({
        Name = "Farm Stop Health",
        Flag = "UrbanReload_FarmMinHealth",
        Min = 10,
        Max = 90,
        Default = options.farmMinHealth,
        Increment = 5,
        Callback = function(value)
            options.farmMinHealth = value
            local instance = features.farm
            if instance then configure("farm", instance) end
        end,
    })

    visuals:CreateDropdown({
        Name = "Aim FOV Circle",
        Flag = "UrbanReload_FovCircle",
        Options = {"On", "Off"},
        Default = "On",
        Callback = function(value)
            options.aimCircle = value == "On"
            local instance = features.aim
            if instance then configure("aim", instance) end
        end,
    })

    visuals:CreateSlider({
        Name = "Aim FOV Radius",
        Flag = "UrbanReload_AimFov",
        Min = 30,
        Max = 450,
        Default = options.aimFov,
        Increment = 5,
        Suffix = " px",
        Callback = function(value)
            options.aimFov = value
            local instance = features.aim
            if instance then configure("aim", instance) end
        end,
    })

    visuals:CreateSlider({
        Name = "Aim Smoothness",
        Flag = "UrbanReload_AimSmoothness",
        Min = 5,
        Max = 100,
        Default = options.aimSmoothness,
        Increment = 1,
        Suffix = "%",
        Callback = function(value)
            options.aimSmoothness = value
            local instance = features.aim
            if instance then configure("aim", instance) end
        end,
    })

    visuals:CreateSlider({
        Name = "Aim Distance",
        Flag = "UrbanReload_AimDistance",
        Min = 50,
        Max = 800,
        Default = options.aimDistance,
        Increment = 25,
        Callback = function(value)
            options.aimDistance = value
            local instance = features.aim
            if instance then configure("aim", instance) end
        end,
    })

    visuals:CreateSlider({
        Name = "Aim Turn Speed",
        Flag = "UrbanReload_AimTurnSpeed",
        Min = 30,
        Max = 360,
        Default = options.aimTurnSpeed,
        Increment = 10,
        Suffix = " deg/s",
        Callback = function(value)
            options.aimTurnSpeed = value
            local instance = features.aim
            if instance then configure("aim", instance) end
        end,
    })

    staminaToggle = movement:CreateToggle({
        Name = "Infinite Stamina",
        Flag = "UrbanReload_InfiniteStamina",
        Default = false,
        Callback = function(enabled)
            if enabled then
                if not startFeature("stamina") then rollbackToggle(staminaToggle) end
            else
                stopFeature("stamina")
            end
        end,
    })

    local function destroy()
        if destroyed then return end
        destroyed = true
        for name in pairs(featurePaths) do stopFeature(name) end
        table.clear(features)
    end

    return {Destroy = destroy}
end
