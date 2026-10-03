-- ============================================================
-- N3Z Desolate Valley platform router
-- Ported from Roblox--Library v1.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "desolate_valley: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "desolate_valley: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/desolate_valley/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/desolate_valley/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "desolate_valley: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "desolate_valley: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "desolate_valley: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
