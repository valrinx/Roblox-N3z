-- N3Z \xF0\x9F\x8D\x82 Game PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "leaf_game/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "leaf_game/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
