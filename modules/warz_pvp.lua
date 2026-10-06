-- ============================================================
-- N3Z WarZPVP platform router
-- v1.8.6 - shared core + explicit PC/Mobile adapters
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "WarZ: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "WarZ: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/warz_pvp/core.lua")
    local adapter = ctx.loadModuleFile("modules/warz_pvp/" .. platformName .. ".lua")

    assert(type(core) == "function",
        "WarZ: core.lua did not return an initializer")
    assert(type(adapter) == "table",
        "WarZ: " .. platformName .. ".lua did not return an adapter")
    assert(adapter.id == platformName,
        "WarZ: adapter id mismatch for " .. platformName)

    return core(Window, ctx, adapter)
end
