-- N3Z Phantom Forces PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "phantom_forces/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "phantom_forces/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
