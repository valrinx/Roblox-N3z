-- N3Z Zoo Hatchers! MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "zoo_hatchers/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "zoo_hatchers/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
