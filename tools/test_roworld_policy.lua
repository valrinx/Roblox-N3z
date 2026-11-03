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

local first, cursor = policy.frontierWindow({ 11, 22, 33, 44, 55 }, 1, 2)
assert(first[1] == 11 and first[2] == 22 and cursor == 3, "first frontier window must advance")
local second
second, cursor = policy.frontierWindow({ 11, 22, 33, 44, 55 }, cursor, 2)
assert(second[1] == 33 and second[2] == 44 and cursor == 5, "second frontier window must advance")
local third
third, cursor = policy.frontierWindow({ 11, 22, 33, 44, 55 }, cursor, 2)
assert(third[1] == 55 and third[2] == 11 and cursor == 2, "frontier window must wrap")

local neighbor = policy.candidateForOwner(25, { troops = 20000 }, 991,
    { ok = true, type = "attack", troops = 1200 }, false)
assert(neighbor and neighbor.tile == 991 and neighbor.owner == 25 and neighbor.troops == 20000,
    "adjacent owner label must be an attack candidate")
assert(policy.candidateForOwner(25, { troops = 20000 }, 991,
    { ok = true, type = "attack" }, true) == nil, "allied owner must be skipped")
local neutral = policy.candidateForOwner(-1, nil, 992, { ok = true, type = "expand" }, false)
assert(neutral and neutral.kind == "expand" and neutral.troops == 0,
    "neutral border must remain an expansion candidate")
local landing = policy.candidateForOwner(29, { troops = 5000000 }, 3000,
    { ok = true, type = "boat", boat_tile = 3333 }, false)
assert(landing and landing.kind == "boat" and landing.tile == 3333,
    "reachable overseas owner must use the boat landing tile")

check("strong navy invades reachable overseas nation", {
    troops = 60000000, maxTroops = 70000000, gold = 1000000, incoming = 0,
    candidates = {{ tile = 3333, owner = 29, troops = 5000000, kind = "boat" }},
}, "boat")
local navalCommitment = policy.choose({
    troops = 20000000, maxTroops = 24000000, gold = 1000000, incoming = 0,
    candidates = {{ tile = 3333, owner = 29, troops = 100000, kind = "boat" }},
})
assert(navalCommitment.type == "boat" and navalCommitment.ratio >= 0.6,
    "overseas invasion needs enough force to secure a landing")

check("runaway rival triggers a legal MIRV strike", {
    troops = 60000000, maxTroops = 70000000, gold = 100000000, incoming = 0,
    enableNuke = true,
    nukeTargets = {{ owner = 19, tile = 4444, share = 0.42, kind = "mirv", cost = 25000000 }},
    candidates = {{ tile = 3333, owner = 29, troops = 5000000, kind = "boat" }},
}, "nuke")

check("leading nation strikes a significant rival before stalling", {
    troops = 26000000, maxTroops = 32000000, gold = 90000000, incoming = 0,
    tiles = 270000, ownShare = 0.39, enableNuke = true,
    nukeTargets = {{ owner = 69, tile = 1892784, share = 0.10,
        kind = "mirv", cost = 25000000 }},
    candidates = {{ tile = 1870784, owner = 69, troops = 1800000, kind = "boat" }},
}, "nuke")

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

check("large nation attacks instead of endlessly building defenses", {
    troops = 10000000, maxTroops = 12000000, gold = 30000000, income = 100000,
    incoming = 0, tiles = 120000, enableBuild = true, enableDefense = true, enableExpand = true,
    defenseCount = 3, defenseSite = { tile = 40, cost = 250000 },
    buildCounts = { city = 20, factory = 8, port = 12, sam = 6 },
    buildSites = { sam = { tile = 44, cost = 1500000 } },
    candidates = {{ tile = 55, owner = 25, troops = 1000000, kind = "attack" }},
}, "attack")

return "RoWorld policy tests passed"
