-- ============================================================
-- N3Z Steal From The Rich! platform router
-- Ported from Roblox--Library v1.3.1
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "steal_from_the_rich: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "steal_from_the_rich: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/steal_from_the_rich/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/steal_from_the_rich/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "steal_from_the_rich: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "steal_from_the_rich: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "steal_from_the_rich: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
