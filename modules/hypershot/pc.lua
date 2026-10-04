return function(ctx)
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function", "hypershot/pc: platform factory missing")
    return makePlatform("pc", ctx)
end