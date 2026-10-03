-- ============================================================
-- N3Z Dueling Grounds platform router
-- Ported from Roblox--Library v2.0.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "dueling_grounds: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "dueling_grounds: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/dueling_grounds/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/dueling_grounds/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "dueling_grounds: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "dueling_grounds: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "dueling_grounds: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
