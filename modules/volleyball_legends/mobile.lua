-- N3Z Volleyball Legends MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "volleyball_legends/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "volleyball_legends/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
