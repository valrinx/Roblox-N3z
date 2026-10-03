-- N3Z Steal Fish Eggs PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "steal_fish_eggs/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "steal_fish_eggs/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
