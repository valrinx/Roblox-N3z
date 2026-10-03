-- ============================================================
-- N3Z Beeconomy! platform router
-- Ported from Roblox--Library v1.0.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "beeconomy: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "beeconomy: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/beeconomy/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/beeconomy/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "beeconomy: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "beeconomy: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "beeconomy: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
