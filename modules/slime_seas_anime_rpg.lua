-- ============================================================
-- N3Z Slime Seas ???????????????? Anime RPG platform router
-- Ported from Roblox--Library v0.1
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "slime_seas_anime_rpg: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "slime_seas_anime_rpg: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/slime_seas_anime_rpg/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/slime_seas_anime_rpg/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "slime_seas_anime_rpg: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "slime_seas_anime_rpg: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "slime_seas_anime_rpg: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
