-- N3Z My Knife Farm MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "my_knife_farm/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "my_knife_farm/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
