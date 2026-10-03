-- N3Z Basketball: Zero PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "basketball_zero/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "basketball_zero/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
