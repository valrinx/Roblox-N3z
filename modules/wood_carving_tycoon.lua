-- ============================================================
-- N3Z Wood Carving Tycoon platform router
-- Ported from Roblox--Library v1.2.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "wood_carving_tycoon: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "wood_carving_tycoon: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/wood_carving_tycoon/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/wood_carving_tycoon/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "wood_carving_tycoon: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "wood_carving_tycoon: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "wood_carving_tycoon: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
