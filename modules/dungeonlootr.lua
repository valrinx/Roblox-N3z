-- ============================================================
-- N3Z Dungeon Lootr platform router
-- Ported from Roblox--Library v3.6.6
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "dungeonlootr: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "dungeonlootr: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/dungeonlootr/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/dungeonlootr/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "dungeonlootr: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "dungeonlootr: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "dungeonlootr: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
