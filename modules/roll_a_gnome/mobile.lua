-- N3Z Roll A Gnome MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "roll_a_gnome/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "roll_a_gnome/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
