-- ============================================================
-- N3Z Karinderya platform router
-- Ported from Roblox--Library v1.0.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "karinderya: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "karinderya: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/karinderya/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/karinderya/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "karinderya: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "karinderya: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "karinderya: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
