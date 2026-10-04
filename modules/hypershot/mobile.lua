return function(ctx)
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function", "hypershot/mobile: platform factory missing")
    return makePlatform("mobile", ctx)
end