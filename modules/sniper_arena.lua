-- ============================================================
-- N3Z Sniper Arena platform router
-- Ported from Roblox--Library v1.3
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "sniper_arena: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "sniper_arena: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/sniper_arena/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/sniper_arena/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "sniper_arena: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "sniper_arena: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "sniper_arena: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
