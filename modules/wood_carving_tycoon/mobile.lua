-- N3Z Wood Carving Tycoon MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "wood_carving_tycoon/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "wood_carving_tycoon/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
