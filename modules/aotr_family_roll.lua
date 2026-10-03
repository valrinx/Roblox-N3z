-- ============================================================
-- N3Z Attack on Titan Revolution - Family Roll platform router
-- Ported from Roblox--Library v1.0.1
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "aotr_family_roll: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "aotr_family_roll: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/aotr_family_roll/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/aotr_family_roll/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "aotr_family_roll: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "aotr_family_roll: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "aotr_family_roll: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
