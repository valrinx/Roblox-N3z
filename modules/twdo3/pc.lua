-- N3Z The Walking Dead Online 3 PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "twdo3/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "twdo3/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
