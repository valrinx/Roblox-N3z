-- N3Z Mine a Mountain PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "mine_a_mountain/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "mine_a_mountain/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
