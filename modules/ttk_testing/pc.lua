-- N3Z TTK Testing [MAP VOTING] PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "ttk_testing/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "ttk_testing/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
