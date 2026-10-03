-- N3Z [SEASON 3] Operation One PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "operation_one/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "operation_one/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
