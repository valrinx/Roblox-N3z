-- N3Z Lumber INC. PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "lumber_inc/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "lumber_inc/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
