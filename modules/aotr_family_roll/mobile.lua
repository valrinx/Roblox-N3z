-- N3Z Attack on Titan Revolution - Family Roll MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "aotr_family_roll/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "aotr_family_roll/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
