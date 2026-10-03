-- N3Z Sniper Arena MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "sniper_arena/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "sniper_arena/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
