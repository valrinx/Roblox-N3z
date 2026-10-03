-- N3Z Cold War [MOUNTED MGs] MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "cold_war/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "cold_war/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
