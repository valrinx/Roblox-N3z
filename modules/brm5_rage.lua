-- ============================================================
-- N3Z Blackhawk Rescue Mission 5 platform router
-- Ported from Roblox--Library v3.2
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "brm5_rage: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "brm5_rage: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/brm5_rage/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/brm5_rage/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "brm5_rage: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "brm5_rage: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "brm5_rage: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
