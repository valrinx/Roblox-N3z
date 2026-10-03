-- N3Z Build and Crush MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "build_and_crush/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "build_and_crush/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
