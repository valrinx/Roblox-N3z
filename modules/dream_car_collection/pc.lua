-- N3Z Dream Car Collection PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "dream_car_collection/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "dream_car_collection/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
