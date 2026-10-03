-- ============================================================
-- N3Z KILLSTREAK! platform router
-- Ported from Roblox--Library v1.4
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "killstreak: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "killstreak: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/killstreak/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/killstreak/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "killstreak: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "killstreak: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "killstreak: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
