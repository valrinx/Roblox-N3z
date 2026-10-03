-- ============================================================
-- N3Z Infected Lands platform router
-- Ported from Roblox--Library v0.1.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "infected_lands: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "infected_lands: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/infected_lands/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/infected_lands/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "infected_lands: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "infected_lands: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "infected_lands: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
