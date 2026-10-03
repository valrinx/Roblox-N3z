-- ============================================================
-- N3Z Build and Crush platform router
-- Ported from Roblox--Library v0.3.1
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "build_and_crush: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "build_and_crush: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/build_and_crush/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/build_and_crush/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "build_and_crush: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "build_and_crush: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "build_and_crush: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
