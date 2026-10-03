-- N3Z Lumber INC. MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "lumber_inc/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "lumber_inc/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
