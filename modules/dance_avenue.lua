-- ============================================================
-- N3Z Dance Avenue platform router
-- v1.0.0 - shared core + explicit PC/Mobile adapters
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "DanceAvenue: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "DanceAvenue: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/dance_avenue/core.lua")
    local adapter = ctx.loadModuleFile("modules/dance_avenue/" .. platformName .. ".lua")

    assert(type(core) == "function",
        "DanceAvenue: core.lua did not return an initializer")
    assert(type(adapter) == "table",
        "DanceAvenue: " .. platformName .. ".lua did not return an adapter")
    assert(adapter.id == platformName,
        "DanceAvenue: adapter id mismatch for " .. platformName)

    return core(Window, ctx, adapter)
end
