-- N3Z Magic Loot PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "magic_loot/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "magic_loot/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
