-- N3Z Guess The Person MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "guess_the_person/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "guess_the_person/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
