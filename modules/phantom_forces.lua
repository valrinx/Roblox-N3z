-- ============================================================
-- N3Z Phantom Forces platform router
-- Ported from Roblox--Library v2.3.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "phantom_forces: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "phantom_forces: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/phantom_forces/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/phantom_forces/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "phantom_forces: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "phantom_forces: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "phantom_forces: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
