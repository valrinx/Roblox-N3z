-- ============================================================
-- N3Z Ground War (o) platform router
-- Ported from Roblox--Library v0.1.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "ground_war: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "ground_war: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/ground_war/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/ground_war/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "ground_war: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "ground_war: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "ground_war: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
