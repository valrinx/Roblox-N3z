-- ============================================================
-- N3Z Basketball: Zero platform router
-- Ported from Roblox--Library v1.0.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "basketball_zero: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "basketball_zero: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/basketball_zero/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/basketball_zero/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "basketball_zero: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "basketball_zero: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "basketball_zero: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
