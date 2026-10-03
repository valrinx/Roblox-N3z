-- N3Z Steal From The Rich! PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "steal_from_the_rich/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "steal_from_the_rich/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
