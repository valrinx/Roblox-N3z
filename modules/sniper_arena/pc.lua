-- N3Z Sniper Arena PC adapter
return function(ctx)
    assert(type(ctx) == "table" and type(ctx.loadModuleFile) == "function",
        "sniper_arena/pc: ctx.loadModuleFile is required")
    local makePlatform = ctx.loadModuleFile("modules/_shared/legacy_platform.lua")
    assert(type(makePlatform) == "function",
        "sniper_arena/pc: shared platform factory missing")

    local adapter = makePlatform("pc", ctx)

    function adapter.applyAim(camera, goal, alpha)
        if not camera or typeof(goal) ~= "CFrame" then return false end
        camera.CFrame = camera.CFrame:Lerp(goal, math.clamp(tonumber(alpha) or 1, 0, 1))
        return true
    end

    function adapter.firePrimary(_, holdSeconds)
        local delaySeconds = math.max(0, tonumber(holdSeconds) or 0.018)
        if type(adapter.mouse1press) == "function"
            and type(adapter.mouse1release) == "function" then
            adapter.mouse1press()
            task.wait(delaySeconds)
            adapter.mouse1release()
            return true
        end
        if type(adapter.mouse1click) == "function" then
            adapter.mouse1click()
            return true
        end
        return false
    end

    return adapter
end
