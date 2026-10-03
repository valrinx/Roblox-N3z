-- N3Z Shovel It! PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "shovel_it/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "shovel_it/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
