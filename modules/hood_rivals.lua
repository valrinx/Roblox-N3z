-- ============================================================
-- N3Z HOOD RIVALS platform router
-- Standard AGENT.MD Platform Separation
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "hood_rivals: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "hood_rivals: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/hood_rivals/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/hood_rivals/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "hood_rivals: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "hood_rivals: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "hood_rivals: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
