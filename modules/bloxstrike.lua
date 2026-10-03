-- ============================================================
-- N3Z BloxStrike platform router
-- Ported from Roblox--Library v1.1.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "bloxstrike: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "bloxstrike: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/bloxstrike/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/bloxstrike/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "bloxstrike: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "bloxstrike: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "bloxstrike: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
