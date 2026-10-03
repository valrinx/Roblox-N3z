-- N3Z RIVALS MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "rivals/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "rivals/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
