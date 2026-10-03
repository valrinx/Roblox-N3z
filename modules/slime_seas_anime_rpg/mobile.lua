-- N3Z Slime Seas ???????????????? Anime RPG MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "slime_seas_anime_rpg/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "slime_seas_anime_rpg/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
