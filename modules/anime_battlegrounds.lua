-- ============================================================
-- N3Z Anime Battlegrounds platform router
-- Ported from Roblox--Library v1.1.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "anime_battlegrounds: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "anime_battlegrounds: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/anime_battlegrounds/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/anime_battlegrounds/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "anime_battlegrounds: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "anime_battlegrounds: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "anime_battlegrounds: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
