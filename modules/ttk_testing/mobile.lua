-- N3Z TTK Testing [MAP VOTING] MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "ttk_testing/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "ttk_testing/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
