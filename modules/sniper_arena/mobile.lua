-- N3Z Sniper Arena MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "sniper_arena/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "sniper_arena/mobile: shared platform factory missing")

    local adapter = makePlatform("mobile", ctx)

    function adapter.applyAim(camera, goal, alpha)
        if not camera or typeof(goal) ~= "CFrame" then return false end
        camera.CFrame = camera.CFrame:Lerp(goal, math.clamp(tonumber(alpha) or 1, 0, 1))
        return true
    end

    return adapter
end
