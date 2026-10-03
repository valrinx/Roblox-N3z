-- ============================================================
-- N3Z Ouwland platform router
-- Ported from Roblox--Library v2.0.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "ouwland: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "ouwland: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/ouwland/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/ouwland/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "ouwland: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "ouwland: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "ouwland: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
