-- ============================================================
-- N3Z Kronos platform router
-- Ported from Roblox--Library v1.0.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "grand_blue: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "grand_blue: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/grand_blue/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/grand_blue/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "grand_blue: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "grand_blue: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "grand_blue: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
