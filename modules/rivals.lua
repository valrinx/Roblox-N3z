-- ============================================================
-- N3Z RIVALS platform router
-- Ported from Roblox--Library v1.4.2
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "rivals: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "rivals: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/rivals/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/rivals/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "rivals: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "rivals: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "rivals: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
