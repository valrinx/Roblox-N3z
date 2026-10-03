-- N3Z Zoo Hatchers! PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "zoo_hatchers/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "zoo_hatchers/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
