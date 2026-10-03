-- N3Z [UPD] Load The Truck! MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "load_the_truck/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "load_the_truck/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
