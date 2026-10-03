-- N3Z A Quiet Place: Deadzone PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "aqp_deadzone/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "aqp_deadzone/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
