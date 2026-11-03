local policy = getgenv().__N3Z_ROWORLD_POLICY
assert(type(policy) == "table", "RoWorld policy is missing")

local function check(name, snapshot, expected)
    local action = policy.choose(snapshot)
    assert(action and action.type == expected, name .. ": expected " .. expected .. ", got " .. tostring(action and action.type))
end

check("under attack blocks expansion", {
    troops = 10000, maxTroops = 20000, gold = 200000, income = 1000,
    incoming = 7000, enableDefense = true,
    candidates = {{ tile = 11, owner = 2, troops = 1000, kind = "attack" }},
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

check("early nation expands neutral land before troop cap", {
    troops = 30000, maxTroops = 100000, gold = 1000, income = 100,
    incoming = 0, candidates = {{ tile = 77, owner = -1, troops = 0, kind = "expand" }},
}, "attack")

check("strong army can commit enough troops to defeat neighbor", {
    troops = 80000, maxTroops = 100000, gold = 1000, income = 100,
    incoming = 0, candidates = {{ tile = 91, owner = 36, troops = 25000, kind = "attack" }},
}, "attack")

local defenseWait = policy.choose({
    troops = 80000, maxTroops = 100000, gold = 75000, income = 1000,
    incoming = 0, enableDefense = true, enableExpand = false,
    defenseSite = { tile = 22, cost = 50000 }, candidates = {},
})
assert(defenseWait.reason == "Saving gold for defense", "defense-only wait must explain the defense budget")

local function checkBuild(name, snapshot, kind)
    local action = policy.choose(snapshot)
    assert(action.type == "build" and action.kind == kind,
        name .. ": expected " .. kind .. ", got " .. tostring(action.kind))
end

checkBuild("troop cap pressure builds city", {
    troops = 90000, maxTroops = 100000, gold = 300000, incoming = 0,
    tiles = 1800, enableBuild = true, buildCounts = { city = 0, factory = 0, port = 0 },
    buildSites = { city = { tile = 101, cost = 125000 }, factory = { tile = 102, cost = 125000 } },
}, "city")

checkBuild("income base builds factory", {
    troops = 50000, maxTroops = 100000, gold = 250000, incoming = 0,
    tiles = 1800, enableBuild = true, buildCounts = { city = 1, factory = 0, port = 0 },
    buildSites = { factory = { tile = 102, cost = 125000 } },
}, "factory")

checkBuild("coastal trade takes priority over inland factory", {
    troops = 50000, maxTroops = 100000, gold = 250000, incoming = 0,
    tiles = 1800, enableBuild = true, buildCounts = { city = 1, factory = 0, port = 0 },
    buildSites = { factory = { tile = 102, cost = 125000 }, port = { tile = 103, cost = 125000 } },
}, "port")

checkBuild("one city does not starve the first port", {
    troops = 90000, maxTroops = 100000, gold = 300000, incoming = 0,
    tiles = 4000, enableBuild = true, buildCounts = { city = 1, factory = 0, port = 0 },
    buildSites = { city = { tile = 101, cost = 125000 }, port = { tile = 103, cost = 125000 } },
}, "port")

checkBuild("coastal trade builds port", {
    troops = 50000, maxTroops = 100000, gold = 300000, incoming = 0,
    tiles = 1800, enableBuild = true, buildCounts = { city = 1, factory = 1, port = 0 },
    buildSites = { port = { tile = 103, cost = 125000 } },
}, "port")

checkBuild("large nation adds SAM protection", {
    troops = 50000, maxTroops = 100000, gold = 5000000, incoming = 0,
    tiles = 6000, enableBuild = true, buildCounts = { city = 6, factory = 5, port = 3, sam = 0 },
    buildSites = { sam = { tile = 104, cost = 1500000 } },
}, "sam")

return "RoWorld policy tests passed"
