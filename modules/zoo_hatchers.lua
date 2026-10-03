-- ============================================================
-- N3Z Zoo Hatchers! platform router
-- Ported from Roblox--Library v1.8.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "zoo_hatchers: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "zoo_hatchers: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/zoo_hatchers/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/zoo_hatchers/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "zoo_hatchers: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "zoo_hatchers: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "zoo_hatchers: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
