-- ============================================================
-- N3Z The Wild West platform router
-- Ported from Roblox--Library v0.1.20
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "the_wild_west: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "the_wild_west: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/the_wild_west/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/the_wild_west/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "the_wild_west: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "the_wild_west: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "the_wild_west: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
