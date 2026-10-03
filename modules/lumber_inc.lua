-- ============================================================
-- N3Z Lumber INC. platform router
-- Ported from Roblox--Library v1.0.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "lumber_inc: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "lumber_inc: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/lumber_inc/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/lumber_inc/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "lumber_inc: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "lumber_inc: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "lumber_inc: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
