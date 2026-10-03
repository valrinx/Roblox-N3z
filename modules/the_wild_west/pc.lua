-- N3Z The Wild West PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "the_wild_west/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "the_wild_west/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
