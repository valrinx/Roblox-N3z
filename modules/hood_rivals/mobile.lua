-- N3Z HOOD RIVALS MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "hood_rivals/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "hood_rivals/mobile: shared platform factory missing")

    local adapter = makePlatform("mobile", ctx)
    adapter.isMobile = true

    -- On mobile, aimbot is active whenever enabled (or camera lock while firing/moving)
    function adapter.isAimActive(activationMode)
        return true
    end

    function adapter.setAimKey(keyName)
        -- No-op on mobile per AGENT.MD separation rules
    end

    return adapter
end
