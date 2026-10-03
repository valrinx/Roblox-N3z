-- ============================================================
-- N3Z Roll A Gnome platform router
-- Ported from Roblox--Library v1.0.8
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "roll_a_gnome: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "roll_a_gnome: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/roll_a_gnome/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/roll_a_gnome/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "roll_a_gnome: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "roll_a_gnome: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "roll_a_gnome: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
