-- ============================================================
-- N3Z Shovel It! platform router
-- Ported from Roblox--Library v1.0.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "shovel_it: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "shovel_it: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/shovel_it/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/shovel_it/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "shovel_it: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "shovel_it: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "shovel_it: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
