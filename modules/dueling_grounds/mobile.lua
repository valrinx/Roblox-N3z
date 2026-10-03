-- N3Z Dueling Grounds MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "dueling_grounds/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "dueling_grounds/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
