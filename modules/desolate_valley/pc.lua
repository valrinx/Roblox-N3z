-- N3Z Desolate Valley PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "desolate_valley/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "desolate_valley/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
