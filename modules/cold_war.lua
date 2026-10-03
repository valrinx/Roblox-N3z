-- ============================================================
-- N3Z Cold War [MOUNTED MGs] platform router
-- Ported from Roblox--Library v1.8.4
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "cold_war: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "cold_war: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/cold_war/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/cold_war/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "cold_war: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "cold_war: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "cold_war: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
