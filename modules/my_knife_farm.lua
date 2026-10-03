-- ============================================================
-- N3Z My Knife Farm platform router
-- Ported from Roblox--Library v0.4
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "my_knife_farm: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "my_knife_farm: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/my_knife_farm/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/my_knife_farm/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "my_knife_farm: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "my_knife_farm: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "my_knife_farm: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
