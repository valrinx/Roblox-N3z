-- ============================================================
-- N3Z Iron Soul: Dungeon platform router
-- Ported from Roblox--Library v1.7.2
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "iron_soul: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "iron_soul: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/iron_soul/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/iron_soul/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "iron_soul: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "iron_soul: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "iron_soul: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
