-- N3Z Fish an Anime RNG PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "fish_anime_rng/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "fish_anime_rng/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
