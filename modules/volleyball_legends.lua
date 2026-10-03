-- ============================================================
-- N3Z Volleyball Legends platform router
-- Ported from Roblox--Library v1.4.2
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "volleyball_legends: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "volleyball_legends: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/volleyball_legends/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/volleyball_legends/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "volleyball_legends: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "volleyball_legends: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "volleyball_legends: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
