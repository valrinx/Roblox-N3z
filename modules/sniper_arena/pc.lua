-- N3Z Sniper Arena PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "sniper_arena/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "sniper_arena/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
