-- N3Z Anime Battlegrounds PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "anime_battlegrounds/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "anime_battlegrounds/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
