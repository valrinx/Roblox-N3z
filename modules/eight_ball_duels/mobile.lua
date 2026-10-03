-- N3Z [GALAXY] 8 Ball Duels MOBILE adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "eight_ball_duels/mobile: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "eight_ball_duels/mobile: shared platform factory missing")
    return makePlatform("mobile", ctx)
end
