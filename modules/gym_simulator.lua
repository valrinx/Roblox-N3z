-- ============================================================
-- N3Z Gym Star Simulator platform router
-- Ported from Roblox--Library v1.0.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "gym_simulator: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "gym_simulator: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/gym_simulator/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/gym_simulator/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "gym_simulator: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "gym_simulator: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "gym_simulator: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
