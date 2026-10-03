-- ============================================================
-- N3Z Anime Card Farm platform router
-- Ported from Roblox--Library v0.1.1
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "anime_card_farm: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "anime_card_farm: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/anime_card_farm/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/anime_card_farm/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "anime_card_farm: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "anime_card_farm: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "anime_card_farm: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
