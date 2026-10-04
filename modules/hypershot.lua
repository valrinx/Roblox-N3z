return function(Window, ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function", "hypershot: ctx required")
    local platformName = ctx.platform == "mobile" and "mobile" or "pc"
    local core = ctx.loadModuleFile("modules/hypershot/core.lua")
    local adapterFactory = ctx.loadModuleFile("modules/hypershot/" .. platformName .. ".lua")
    local adapter = adapterFactory(ctx)
    assert(type(adapter) == "table" and adapter.id == platformName, "hypershot: platform adapter mismatch")
    ctx.platformAdapter = adapter
    if type(ctx.registerCleanup) == "function" and type(adapter.destroy) == "function" then
        ctx.registerCleanup(adapter.destroy)
    end
    return core(Window, ctx)
end