-- N3Z Apocalypse Rising 2 PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "ar2/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "ar2/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
