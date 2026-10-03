-- N3Z [UPD] Load The Truck! PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "load_the_truck/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "load_the_truck/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
