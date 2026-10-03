-- N3Z Guess The Person PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "guess_the_person/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "guess_the_person/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
