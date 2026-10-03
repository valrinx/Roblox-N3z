-- N3Z Dig Into Secrets PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "dig_into_secrets/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "dig_into_secrets/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
