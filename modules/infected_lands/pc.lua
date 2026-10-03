-- N3Z Infected Lands PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "infected_lands/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "infected_lands/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
