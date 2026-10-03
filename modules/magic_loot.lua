-- ============================================================
-- N3Z Magic Loot platform router
-- Ported from Roblox--Library v2.4
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "magic_loot: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "magic_loot: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/magic_loot/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/magic_loot/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "magic_loot: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "magic_loot: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "magic_loot: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
