-- N3Z Ride A Pet MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "ride_a_pet/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "ride_a_pet/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
