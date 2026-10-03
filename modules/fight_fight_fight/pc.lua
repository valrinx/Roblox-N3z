-- N3Z Fight, Fight, Fight! PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "fight_fight_fight/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "fight_fight_fight/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
