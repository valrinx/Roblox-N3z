-- N3Z Ronopoly Game PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "ronopoly/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "ronopoly/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
