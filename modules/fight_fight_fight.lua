-- ============================================================
-- N3Z Fight, Fight, Fight! platform router
-- Ported from Roblox--Library v1.1.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "fight_fight_fight: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "fight_fight_fight: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/fight_fight_fight/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/fight_fight_fight/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "fight_fight_fight: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "fight_fight_fight: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "fight_fight_fight: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
