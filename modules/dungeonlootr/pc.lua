-- N3Z Dungeon Lootr PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "dungeonlootr/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "dungeonlootr/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
