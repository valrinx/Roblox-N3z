-- N3Z Racket Rivals MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "racket_rivals/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "racket_rivals/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
