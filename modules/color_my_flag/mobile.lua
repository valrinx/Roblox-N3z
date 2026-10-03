-- N3Z Color My Flag MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "color_my_flag/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "color_my_flag/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
