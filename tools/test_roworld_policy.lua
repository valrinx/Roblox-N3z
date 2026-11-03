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

checkBuild("large nation builds a missile launcher", {
    troops = 500000, maxTroops = 1000000, gold = 5000000, incoming = 0,
    tiles = 30000, enableBuild = true,
    buildCounts = { city = 8, factory = 8, port = 6, sam = 2, silo = 0 },
    buildSites = { silo = { tile = 105, cost = 1000000 } },
}, "silo")

checkBuild("affordable SAM does not wait for double its cost", {
    troops = 500000, maxTroops = 1000000, gold = 4000000, incoming = 0,
    tiles = 30000, enableBuild = true,
    buildCounts = { city = 8, factory = 8, port = 6, sam = 2, silo = 1 },
    buildSites = { sam = { tile = 104, cost = 3000000 } },
}, "sam")

local upgrade = policy.choose({
    troops = 900000, maxTroops = 1000000, gold = 5000000, incoming = 0,
    tiles = 30000, enableBuild = true,
    buildCounts = { city = 8, factory = 8, port = 6, sam = 6, silo = 2 },
    upgradeSites = { city = { tile = 201, cost = 1000000, level = 2 } },
})
assert(upgrade.type == "build" and upgrade.kind == "city" and upgrade.upgrade == true
    and upgrade.tile == 201, "city capacity pressure must upgrade an existing city")

local launcherUpgrade = policy.choose({
    troops = 500000, maxTroops = 1000000, gold = 5000000, incoming = 0,
    tiles = 30000, enableBuild = true,
    buildCounts = { city = 8, factory = 8, port = 6, sam = 6, silo = 2 },
    upgradeSites = { silo = { tile = 205, cost = 1000000, level = 2 } },
})
assert(launcherUpgrade.type == "build" and launcherUpgrade.kind == "silo"
    and launcherUpgrade.upgrade == true, "existing launcher must be upgraded")

checkBuild("core protection takes priority over optional missile strike", {
    troops = 500000, maxTroops = 1000000, gold = 5000000, incoming = 0,
    tiles = 30000, enableBuild = true, enableNuke = true,
    buildCounts = { city = 8, factory = 8, port = 6, sam = 2, silo = 1 },
    buildSites = { sam = { tile = 104, cost = 3000000 } },
    nukeTargets = {{ owner = 19, tile = 4444, share = 0.42,
        kind = "atom", cost = 750000 }},
}, "sam")

check("large nation attacks instead of endlessly building defenses", {
    troops = 10000000, maxTroops = 12000000, gold = 30000000, income = 100000,
    incoming = 0, tiles = 120000, enableBuild = true, enableDefense = true, enableExpand = true,
    defenseCount = 3, defenseSite = { tile = 40, cost = 250000 },
    buildCounts = { city = 20, factory = 8, port = 12, sam = 6 },
    buildSites = { sam = { tile = 44, cost = 1500000 } },
    candidates = {{ tile = 55, owner = 25, troops = 1000000, kind = "attack" }},
}, "attack")

check("victory threshold stops issuing new orders", {
    ownShare = 0.80, troops = 10000000, maxTroops = 12000000,
    gold = 30000000, enableBuild = true, enableExpand = true,
    buildCounts = { city = 0 }, buildSites = { city = { tile = 12, cost = 1000000 } },
    candidates = {{ tile = 55, owner = 25, troops = 1000000, kind = "attack" }},
}, "wait")

check("leading nation preserves gold instead of nuking a minor rival", {
    ownShare = 0.40, troops = 10000000, maxTroops = 12000000,
    gold = 30000000, enableExpand = true, enableNuke = true,
    nukeTargets = {{ owner = 19, tile = 4444, share = 0.10,
        kind = "mirv", cost = 25000000 }},
    candidates = {{ tile = 55, owner = 25, troops = 1000000, kind = "attack" }},
}, "attack")

local alternateLanding = policy.choose({
    ownShare = 0.42, troops = 20000000, maxTroops = 24000000,
    gold = 1000000, enableExpand = true,
    candidates = {
        { tile = 101, owner = 1, troops = 100000, tiles = 50000,
            kind = "boat", blocked = true },
        { tile = 202, owner = 2, troops = 200000, tiles = 25000,
            kind = "boat" },
    },
})
assert(alternateLanding.type == "boat" and alternateLanding.owner == 2,
    "failed landing must not be selected again during its cooldown")

local highValueTarget = policy.choose({
    ownShare = 0.42, troops = 20000000, maxTroops = 24000000,
    gold = 1000000, enableExpand = true,
    candidates = {
        { tile = 101, owner = 1, troops = 100000, tiles = 1000, kind = "boat" },
        { tile = 202, owner = 2, troops = 200000, tiles = 50000, kind = "boat" },
    },
})
assert(highValueTarget.type == "boat" and highValueTarget.owner == 2,
    "global expansion must prefer more territory per enemy troop")

assert(policy.preferCandidate(
    { owner = 2, kind = "boat", tile = 400 },
    { owner = 2, kind = "attack", tile = 500 }) == true,
    "reachable land frontier must replace a remote boat landing for the same owner")
assert(policy.preferCandidate(
    { owner = 2, kind = "attack", tile = 500 },
    { owner = 2, kind = "boat", tile = 400 }) == false,
    "remote label must not replace an existing land frontier")
assert(policy.preferCandidate(
    { owner = 2, kind = "attack", tile = 500, strategicValue = 0 },
    { owner = 2, kind = "attack", tile = 600, strategicValue = 6 }) == true,
    "reachable factory must replace an ordinary tile of the same owner")

local economicTarget = policy.choose({
    ownShare = 0.5, troops = 20000000, maxTroops = 24000000,
    gold = 0, enableExpand = true,
    candidates = {
        { tile = 101, owner = 1, troops = 100000, tiles = 50000,
            kind = "attack", strategicValue = 0 },
        { tile = 202, owner = 2, troops = 120000, tiles = 50000,
            kind = "attack", strategicValue = 6 },
    },
})
assert(economicTarget.owner == 2 and economicTarget.tile == 202,
    "global campaign should capture a reachable factory over an empty frontier")

local nearbyLanding = policy.choose({
    ownShare = 0.5, troops = 20000000, maxTroops = 24000000,
    gold = 0, enableExpand = true,
    candidates = {
        { tile = 101, owner = 1, troops = 100000, tiles = 50000,
            kind = "boat", portDistance = 900 },
        { tile = 202, owner = 2, troops = 100000, tiles = 50000,
            kind = "boat", portDistance = 100 },
    },
})
assert(nearbyLanding.owner == 2, "naval plan should prefer a nearby reachable landing")

local protectedIndustry = policy.chooseSamSite({
    { tile = 101, cost = 1500000, distanceToEconomy = 20, nearestSam = 25 },
    { tile = 202, cost = 1500000, distanceToEconomy = 60, nearestSam = 200 },
})
assert(protectedIndustry and protectedIndustry.tile == 202,
    "new SAM should cover industry without clustering beside an existing SAM")

assert(policy.campaignResult({ kind = "boat", age = 15,
    initialTiles = 10000, currentTiles = 10000,
    initialTargetTiles = 5000, currentTargetTiles = 5000 }) == "pending",
    "landing needs time to resolve before judging it")
assert(policy.campaignResult({ kind = "boat", age = 50,
    initialTiles = 10000, currentTiles = 10000,
    initialTargetTiles = 5000, currentTargetTiles = 5000 }) == "failed",
    "landing without captured land must trigger a retry cooldown")
assert(policy.campaignResult({ kind = "boat", age = 20,
    initialTiles = 10000, currentTiles = 15000,
    initialTargetTiles = 5000, currentTargetTiles = 0 }) == "captured",
    "a captured landing must release its target lock")

check("global campaign attacks with enough real troops despite a large city cap", {
    ownShare = 0.775, troops = 18000000, maxTroops = 73000000,
    gold = 0, enableExpand = true,
    candidates = {{ tile = 190, owner = 19, troops = 3000000,
        tiles = 83000, kind = "attack" }},
}, "attack")

check("young coastal nation can land against a thinly defended large rival", {
    ownShare = 0.036, troops = 800000, maxTroops = 1000000,
    tiles = 25000, gold = 0, enableExpand = true,
    candidates = {{ tile = 400, owner = 7, troops = 600000,
        tiles = 50000, kind = "boat" }},
}, "boat")

local usefulLanding = policy.choose({
    ownShare = 0.039, troops = 1200000, maxTroops = 1500000,
    tiles = 26500, gold = 0, enableExpand = true,
    candidates = {
        { tile = 101, owner = 375, troops = 25000, tiles = 51,
            kind = "boat", portDistance = 755 },
        { tile = 202, owner = 7, troops = 100000, tiles = 10000,
            kind = "boat", portDistance = 150 },
    },
})
assert(usefulLanding.type == "boat" and usefulLanding.owner == 7,
    "early nation must favor a meaningful landing over a tiny island")

assert(policy.actionCooldown(0.04, "attack")
    < policy.actionCooldown(0.04, "build"),
    "early expansion must issue safe attacks faster than new construction")
assert(policy.actionCooldown(0.04, "boat")
    > policy.actionCooldown(0.04, "attack"),
    "naval landings need more time to resolve than land attacks")
assert(policy.actionCooldown(0.60, "attack")
    > policy.actionCooldown(0.04, "attack"),
    "large armies should have more time between campaigns")

return "RoWorld policy tests passed"
