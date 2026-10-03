-- N3Z Fishing Chef PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "fishing_chef/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "fishing_chef/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
