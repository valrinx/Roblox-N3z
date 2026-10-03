-- N3Z Gym Star Simulator PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "gym_simulator/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "gym_simulator/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
