-- N3Z Train Your Fish to Race PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "train_your_fish/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "train_your_fish/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
