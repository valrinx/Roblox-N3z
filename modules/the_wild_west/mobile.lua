-- N3Z The Wild West MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "the_wild_west/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "the_wild_west/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
