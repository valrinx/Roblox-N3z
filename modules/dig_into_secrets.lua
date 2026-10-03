-- ============================================================
-- N3Z Dig Into Secrets platform router
-- Ported from Roblox--Library v1.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "dig_into_secrets: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "dig_into_secrets: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/dig_into_secrets/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/dig_into_secrets/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "dig_into_secrets: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "dig_into_secrets: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "dig_into_secrets: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
