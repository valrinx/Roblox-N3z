-- N3Z Cold War [MOUNTED MGs] PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "cold_war/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "cold_war/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
