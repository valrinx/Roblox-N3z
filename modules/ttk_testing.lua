-- ============================================================
-- N3Z TTK Testing [MAP VOTING] platform router
-- Ported from Roblox--Library v1.0.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "ttk_testing: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "ttk_testing: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/ttk_testing/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/ttk_testing/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "ttk_testing: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "ttk_testing: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "ttk_testing: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
