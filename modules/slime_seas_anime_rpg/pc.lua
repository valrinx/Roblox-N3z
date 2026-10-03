-- N3Z Slime Seas ???????????????? Anime RPG PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "slime_seas_anime_rpg/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "slime_seas_anime_rpg/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
