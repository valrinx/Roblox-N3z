-- N3Z Anime Battlegrounds MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "anime_battlegrounds/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "anime_battlegrounds/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
