-- N3Z [GALAXY] 8 Ball Duels PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "eight_ball_duels/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "eight_ball_duels/pc: shared platform factory missing")
    return makePlatform("pc", ctx)
end
