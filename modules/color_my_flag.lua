-- ============================================================
-- N3Z Color My Flag platform router
-- Ported from Roblox--Library v1.0.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "color_my_flag: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "color_my_flag: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/color_my_flag/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/color_my_flag/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "color_my_flag: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "color_my_flag: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "color_my_flag: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
