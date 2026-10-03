-- N3Z Ride A Pet PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "ride_a_pet/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "ride_a_pet/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
