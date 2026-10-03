-- N3Z Ultimate Mining Tycoon MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "ultimate_mining_tycoon/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "ultimate_mining_tycoon/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
