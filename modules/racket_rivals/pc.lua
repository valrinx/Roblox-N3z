-- N3Z Racket Rivals PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "racket_rivals/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "racket_rivals/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
