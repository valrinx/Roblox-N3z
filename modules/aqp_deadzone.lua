-- ============================================================
-- N3Z A Quiet Place: Deadzone platform router
-- Ported from Roblox--Library v1.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "aqp_deadzone: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "aqp_deadzone: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/aqp_deadzone/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/aqp_deadzone/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "aqp_deadzone: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "aqp_deadzone: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "aqp_deadzone: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
