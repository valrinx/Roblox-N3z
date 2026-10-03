-- N3Z Shovel It! MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "shovel_it/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "shovel_it/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
