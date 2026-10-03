-- N3Z Volleyball Legends PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "volleyball_legends/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "volleyball_legends/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
