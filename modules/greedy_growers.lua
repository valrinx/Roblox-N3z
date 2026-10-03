-- ============================================================
-- N3Z Greedy Growers platform router
-- Ported from Roblox--Library v4.2.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "greedy_growers: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "greedy_growers: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/greedy_growers/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/greedy_growers/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "greedy_growers: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "greedy_growers: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "greedy_growers: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
