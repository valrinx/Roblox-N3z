-- N3Z The Walking Dead Online 3 MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "twdo3/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "twdo3/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
