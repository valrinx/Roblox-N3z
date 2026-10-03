-- ============================================================
-- N3Z DON'T LOOK BACK platform router
-- Ported from Roblox--Library v1.0
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "dont_look_back: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "dont_look_back: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/dont_look_back/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/dont_look_back/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "dont_look_back: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "dont_look_back: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "dont_look_back: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
