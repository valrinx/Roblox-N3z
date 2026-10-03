-- ============================================================
-- N3Z Shiganshina (AoT) platform router
-- Ported from Roblox--Library v7.4
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "shiganshina: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "shiganshina: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/shiganshina/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/shiganshina/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "shiganshina: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "shiganshina: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "shiganshina: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
