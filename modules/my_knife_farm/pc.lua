-- N3Z My Knife Farm PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "my_knife_farm/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "my_knife_farm/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
