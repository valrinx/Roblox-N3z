-- ============================================================
-- N3Z Racket Rivals platform router
-- Ported from Roblox--Library v1.0.2
-- ============================================================

return function(Window, ctx)
    assert(type(ctx) == "table", "racket_rivals: ctx is required")
    assert(type(ctx.loadModuleFile) == "function",
        "racket_rivals: ctx.loadModuleFile is required")

    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/racket_rivals/core.lua")
    local adapterFactory = ctx.loadModuleFile(
        "modules/racket_rivals/" .. platformName .. ".lua"
    )

    assert(type(core) == "function",
        "racket_rivals: core.lua did not return an initializer")
    assert(type(adapterFactory) == "function",
        "racket_rivals: platform adapter did not return a factory")

    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName,
        "racket_rivals: platform adapter mismatch")

    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function"
        and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end

    return core(Window, ctx)
end
