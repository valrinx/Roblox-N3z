-- N3Z Fishing Chef MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "fishing_chef/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "fishing_chef/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
