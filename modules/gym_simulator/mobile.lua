-- N3Z Gym Star Simulator MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "gym_simulator/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "gym_simulator/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
