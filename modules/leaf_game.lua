-- ============================================================
-- N3Z \xF0\x9F\x8D\x82 Game platform router
-- Ported from Roblox--Library v1.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "leaf_game: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "leaf_game: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/leaf_game/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/leaf_game/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "leaf_game: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "leaf_game: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "leaf_game: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
