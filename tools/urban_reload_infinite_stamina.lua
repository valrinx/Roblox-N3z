local RunService = game:GetService("RunService")

assert(game.PlaceId == 84448037861644, "Urban Reload infinite stamina: wrong place")

local env = (type(getgenv) == "function" and getgenv()) or _G
if type(env.N3Z_UrbanInfiniteStamina) == "table"
    and type(env.N3Z_UrbanInfiniteStamina.Stop) == "function" then
    env.N3Z_UrbanInfiniteStamina.Stop()
end

assert(type(getgc) == "function", "Urban Reload infinite stamina: getgc unavailable")

local clientState
for _, candidate in ipairs(getgc(true)) do
    if type(candidate) == "table"
        and type(rawget(candidate, "Stamina")) == "number"
        and type(rawget(candidate, "StaminaMax")) == "number"
        and type(rawget(candidate, "Exhausted")) == "boolean"
        and type(rawget(candidate, "Sprinting")) == "boolean" then
        clientState = candidate
        break
    end
end
assert(clientState, "Urban Reload infinite stamina: ClientState unavailable")

local state = {
    Enabled = false,
    Refills = 0,
}

local heartbeatConnection
local renderBound = false

local function refill()
    if type(clientState.StaminaMax) ~= "number" or clientState.StaminaMax <= 0 then
        return
    end
    if clientState.Stamina < clientState.StaminaMax or clientState.Exhausted then
        clientState.Stamina = clientState.StaminaMax
        clientState.Exhausted = false
        state.Refills += 1
    end
end

function state.Start()
    if state.Enabled then return end
    state.Enabled = true
    refill()
    heartbeatConnection = RunService.Heartbeat:Connect(refill)
    RunService:BindToRenderStep("N3Z_UrbanInfiniteStamina",
        Enum.RenderPriority.Last.Value + 1, refill)
    renderBound = true
end

function state.Stop()
    if heartbeatConnection then
        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
    end
    if renderBound then
        RunService:UnbindFromRenderStep("N3Z_UrbanInfiniteStamina")
        renderBound = false
    end
    state.Enabled = false
end

function state.Report()
    return {
        enabled = state.Enabled,
        stamina = clientState.Stamina,
        maximum = clientState.StaminaMax,
        exhausted = clientState.Exhausted,
        sprinting = clientState.Sprinting,
        refills = state.Refills,
    }
end

env.N3Z_UrbanInfiniteStamina = state
state.Start()
return state
