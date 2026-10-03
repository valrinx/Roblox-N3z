-- N3Z Guess the Anime Color PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "guess_the_anime_color/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "guess_the_anime_color/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
