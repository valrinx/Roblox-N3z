-- N3Z +1 Drain Water Per Click PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "drain_water/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "drain_water/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
