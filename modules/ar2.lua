-- ============================================================
-- N3Z Apocalypse Rising 2 platform router
-- Ported from Roblox--Library v1.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "ar2: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "ar2: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/ar2/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/ar2/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "ar2: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "ar2: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "ar2: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
