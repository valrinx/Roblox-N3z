-- N3Z Shiganshina (AoT) MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "shiganshina/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "shiganshina/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
