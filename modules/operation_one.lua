-- ============================================================
-- N3Z [SEASON 3] Operation One platform router
-- Ported from Roblox--Library v1.2
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "operation_one: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "operation_one: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/operation_one/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/operation_one/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "operation_one: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "operation_one: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "operation_one: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
