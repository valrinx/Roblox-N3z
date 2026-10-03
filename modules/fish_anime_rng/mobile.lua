-- N3Z Fish an Anime RNG MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "fish_anime_rng/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "fish_anime_rng/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
