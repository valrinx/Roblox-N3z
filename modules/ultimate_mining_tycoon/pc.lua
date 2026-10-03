-- N3Z Ultimate Mining Tycoon PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "ultimate_mining_tycoon/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "ultimate_mining_tycoon/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
