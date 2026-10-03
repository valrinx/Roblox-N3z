-- N3Z Greedy Growers PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "greedy_growers/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "greedy_growers/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
