-- N3Z BloxStrike MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "bloxstrike/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "bloxstrike/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
