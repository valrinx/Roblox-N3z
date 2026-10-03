-- N3Z Attack on Titan Revolution - Family Roll PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "aotr_family_roll/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "aotr_family_roll/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
