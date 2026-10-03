-- ============================================================
-- N3Z The Sea platform router
-- Ported from Roblox--Library v1.2.5
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "the_sea: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "the_sea: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/the_sea/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/the_sea/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "the_sea: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "the_sea: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "the_sea: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
