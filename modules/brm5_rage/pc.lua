-- N3Z Blackhawk Rescue Mission 5 PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "brm5_rage/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "brm5_rage/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
