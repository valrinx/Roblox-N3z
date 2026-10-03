-- N3Z Wood Carving Tycoon PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "wood_carving_tycoon/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "wood_carving_tycoon/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
