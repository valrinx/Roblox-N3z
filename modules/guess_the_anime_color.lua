-- ============================================================
-- N3Z Guess the Anime Color platform router
-- Ported from Roblox--Library v1.0.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "guess_the_anime_color: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "guess_the_anime_color: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/guess_the_anime_color/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/guess_the_anime_color/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "guess_the_anime_color: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "guess_the_anime_color: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "guess_the_anime_color: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
