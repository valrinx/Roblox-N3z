-- ============================================================
-- N3Z Steal Fish Eggs platform router
-- Ported from Roblox--Library v1.9.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "steal_fish_eggs: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "steal_fish_eggs: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/steal_fish_eggs/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/steal_fish_eggs/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "steal_fish_eggs: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "steal_fish_eggs: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "steal_fish_eggs: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
