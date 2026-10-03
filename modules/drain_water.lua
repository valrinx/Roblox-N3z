-- ============================================================
-- N3Z +1 Drain Water Per Click platform router
-- Ported from Roblox--Library v1.0.1
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "drain_water: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "drain_water: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/drain_water/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/drain_water/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "drain_water: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "drain_water: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "drain_water: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
