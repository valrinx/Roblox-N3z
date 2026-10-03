-- N3Z Train Your Fish to Race MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "train_your_fish/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "train_your_fish/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
