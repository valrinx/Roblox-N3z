-- ============================================================
-- N3Z The Walking Dead Online 3 platform router
-- Ported from Roblox--Library v0.8
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "twdo3: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "twdo3: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/twdo3/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/twdo3/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "twdo3: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "twdo3: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "twdo3: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
