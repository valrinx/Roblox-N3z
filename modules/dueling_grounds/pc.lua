-- N3Z Dueling Grounds PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "dueling_grounds/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "dueling_grounds/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
