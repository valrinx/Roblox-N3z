-- ============================================================
-- N3Z [GALAXY] 8 Ball Duels platform router
-- Ported from Roblox--Library v1.0.4
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "eight_ball_duels: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "eight_ball_duels: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/eight_ball_duels/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/eight_ball_duels/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "eight_ball_duels: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "eight_ball_duels: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "eight_ball_duels: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
