-- ============================================================
-- N3Z Pull An Egg platform router
-- Ported from Roblox--Library v1.0.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "pull_an_egg: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "pull_an_egg: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/pull_an_egg/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/pull_an_egg/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "pull_an_egg: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "pull_an_egg: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "pull_an_egg: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
