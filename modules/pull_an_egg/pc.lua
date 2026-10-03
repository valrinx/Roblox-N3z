-- N3Z Pull An Egg PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "pull_an_egg/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "pull_an_egg/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
