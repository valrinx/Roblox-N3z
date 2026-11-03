local policy = getgenv().__N3Z_ROWORLD_POLICY
assert(type(policy) == "table", "RoWorld policy is missing")

local function check(name, snapshot, expected)
    local action = policy.choose(snapshot)
    assert(action and action.type == expected, name .. ": expected " .. expected .. ", got " .. tostring(action and action.type))
end

check("under attack blocks expansion", {
    troops = 10000, maxTroops = 20000, gold = 200000, income = 1000,
    incoming = 7000, candidates = {{ tile = 11, owner = 2, troops = 1000, kind = "attack" }},
    defenseSite = { tile = 22, cost = 50000 },
}, "build")

check("low reserves block attack", {
    troops = 4000, maxTroops = 20000, gold = 0, income = 1000,
    incoming = 0, candidates = {{ tile = 11, owner = 2, troops = 1000, kind = "attack" }},
}, "wait")

check("favorable frontier expands", {
    troops = 16000, maxTroops = 20000, gold = 0, income = 1000,
    incoming = 0, candidates = {{ tile = 11, owner = 2, troops = 2000, kind = "attack" }},
}, "attack")

check("ally is never attacked", {
    troops = 16000, maxTroops = 20000, gold = 0, income = 1000,
    incoming = 0, candidates = {{ tile = 11, owner = 2, troops = 2000, kind = "attack", ally = true }},
}, "wait")

check("defense mode fortifies exposed frontier", {
    troops = 16000, maxTroops = 20000, gold = 200000, income = 1000,
    incoming = 0, enableDefense = true, enableExpand = false,
    candidates = {{ tile = 11, owner = 2, troops = 1000, kind = "attack" }},
    defenseSite = { tile = 22, cost = 50000 },
}, "build")

check("unclaimed land expands safely", {
    troops = 16000, maxTroops = 20000, gold = 0, income = 1000,
    incoming = 0, candidates = {{ tile = 11, owner = -1, troops = 0, kind = "expand" }},
}, "attack")

return "RoWorld policy tests passed"
