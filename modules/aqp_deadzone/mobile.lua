-- N3Z A Quiet Place: Deadzone MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "aqp_deadzone/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "aqp_deadzone/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
