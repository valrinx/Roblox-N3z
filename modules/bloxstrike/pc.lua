-- N3Z BloxStrike PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "bloxstrike/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "bloxstrike/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
