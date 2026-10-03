-- ============================================================
-- N3Z Dream Car Collection platform router
-- Ported from Roblox--Library v1.0.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "dream_car_collection: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "dream_car_collection: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/dream_car_collection/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/dream_car_collection/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "dream_car_collection: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "dream_car_collection: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "dream_car_collection: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
