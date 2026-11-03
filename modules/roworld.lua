local Policy = {}

function Policy.choose(snapshot)
    local troops = math.max(0, tonumber(snapshot.troops) or 0)
    local cap = math.max(1, tonumber(snapshot.maxTroops) or 1)
    local incoming = math.max(0, tonumber(snapshot.incoming) or 0)
    local gold = math.max(0, tonumber(snapshot.gold) or 0)
    local site = snapshot.defenseSite

    if incoming >= troops * 0.2 then
        if snapshot.enableDefense and site and site.tile and site.cost and gold >= site.cost * 1.25 then
            return { type = "build", kind = "defense", tile = site.tile, reason = "Incoming attack; fortify border" }
        end
        return { type = "wait", reason = "Incoming attack; preserve troops" }
    end

    if snapshot.enableDefense and site and site.tile and site.cost
        and gold >= site.cost * 2
        and (tonumber(snapshot.defenseCount) or 0) < math.max(2, math.ceil((tonumber(snapshot.tiles) or 0) / 1000)) then
        return { type = "build", kind = "defense", tile = site.tile, reason = "Fortify exposed frontier" }
    end

    if snapshot.enableBuild then
        local sites = snapshot.buildSites or {}
        local counts = snapshot.buildCounts or {}
        local tiles = tonumber(snapshot.tiles) or 0
        local function affordable(kind, reserve)
            local candidate = sites[kind]
            return candidate and candidate.tile and candidate.cost
                and gold >= candidate.cost * reserve and candidate
        end
        local city = affordable("city", 1.25)
        if city and (counts.city or 0) == 0 then
            return { type = "build", kind = "city", tile = city.tile, reason = "Increase troop capacity" }
        end
        local port = affordable("port", 1.5)
        if port and (counts.port or 0) < math.max(1, math.floor(tiles / 1800)) then
            return { type = "build", kind = "port", tile = port.tile, reason = "Open coastal trade" }
        end
        local factory = affordable("factory", 1.5)
        if factory and (counts.factory or 0) < math.max(1, math.floor(tiles / 1200)) then
            return { type = "build", kind = "factory", tile = factory.tile, reason = "Grow gold income" }
        end
        if city and troops >= cap * 0.75
            and (counts.city or 0) < math.max(1, math.floor(tiles / 1500)) then
            return { type = "build", kind = "city", tile = city.tile, reason = "Expand troop capacity" }
        end
        local sam = affordable("sam", 2)
        if sam and tiles >= 5000 and (counts.sam or 0) < math.ceil(tiles / 5000) then
            return { type = "build", kind = "sam", tile = sam.tile, reason = "Protect core territory from missiles" }
        end
    end

    if troops < cap * 0.25 then
        return { type = "wait", reason = "Recover troop reserve" }
    end

    local best, bestScore
    for _, candidate in ipairs(snapshot.candidates or {}) do
        if candidate.tile and not candidate.ally
            and (candidate.kind == "attack" or candidate.kind == "expand") then
            local enemy = math.max(0, tonumber(candidate.troops) or 0)
            local neutral = candidate.kind == "expand"
            local committed = neutral and troops * 0.25
                or math.min(troops * 0.7, math.max(troops * 0.25, enemy * 1.8))
            local reserve = troops - committed
            local safe = neutral and reserve >= cap * 0.15
                or not neutral and reserve >= cap * 0.25 and committed >= enemy * 1.8
            if safe then
                local score = enemy + (candidate.owner == -1 and -1000000 or 0)
                if not bestScore or score < bestScore then
                    best = { type = "attack", tile = candidate.tile, owner = candidate.owner,
                        ratio = committed / troops, reason = "Favorable frontier with protected reserve" }
                    bestScore = score
                end
            end
        end
    end
    if best then return best end
    if snapshot.enableDefense and not snapshot.enableExpand then
        return { type = "wait", reason = site and "Saving gold for defense" or "No valid defense site" }
    end
    return { type = "wait", reason = "No safe expansion target" }
end

local environment = (type(getgenv) == "function" and getgenv()) or _G
environment.__N3Z_ROWORLD_POLICY = Policy

return function(Window)
    if environment.__N3Z_ROWORLD and type(environment.__N3Z_ROWORLD.Destroy) == "function" then
        environment.__N3Z_ROWORLD.Destroy()
    end

    local running = true
    local settings = { autoDefense = false, autoExpand = false, autoBuild = true,
        scanInterval = 3, actionInterval = 8 }
    local lastActionAt = 0
    local status = "Waiting for a live match"
    local tab = Window:CreateTab("RoWorld", "globe")
    tab:CreateSection("Territory Command")
    local statusLabel = tab:CreateLabel("Status: " .. status)
    tab:CreateToggle({ Name = "Auto Defense", CurrentValue = false, Flag = "RoWorldDefense",
        Callback = function(value) settings.autoDefense = value == true end })
    tab:CreateToggle({ Name = "Auto Build", CurrentValue = true, Flag = "RoWorldBuild",
        Callback = function(value) settings.autoBuild = value == true end })
    tab:CreateToggle({ Name = "Auto Expand", CurrentValue = false, Flag = "RoWorldExpand",
        Callback = function(value) settings.autoExpand = value == true end })
    tab:CreateLabel("Builds cities, factories, ports, and SAMs. Attacks keep a troop reserve.")

    local function setStatus(value)
        if value ~= status then
            status = value
            if statusLabel and type(statusLabel.SetText) == "function" then
                statusLabel:SetText("Status: " .. value)
            end
        end
    end

    local function findContext()
        if type(getgc) ~= "function" then return nil end
        for _, candidate in ipairs(getgc(true)) do
            if type(candidate) == "table"
                and rawget(candidate, "session") and rawget(candidate, "world")
                and rawget(candidate, "state") and rawget(candidate, "ratio")
                and rawget(candidate, "rules") and rawget(candidate, "borders") then
                return candidate
            end
        end
        return nil
    end

    local context
    local function readSnapshot(ctx)
        local state = ctx.state
        local me = state and state:local_info()
        if not me or not me.alive or not me.spawned or state.phase ~= 1 then return nil end
        local incoming = 0
        local threatTile
        for _, attack in pairs(state.attacks or {}) do
            if attack.target == me.id and not attack.retreating then
                incoming += tonumber(attack.troops) or 0
                threatTile = attack.anchor_tile or threatTile
            end
        end

        local candidates = {}
        local defenseSite
        local defenseDistance
        local buildCounts = { city = 0, port = 0, factory = 0, defense = 0, sam = 0 }
        local kindsById = { [0] = "city", [1] = "port", [2] = "factory", [3] = "defense", [4] = "sam" }
        for _, structure in pairs(state.structures or {}) do
            if structure.owner == me.id then
                local kind = kindsById[structure.kind]
                if kind then buildCounts[kind] += 1 end
            end
        end
        local seen = {}
        local width = state.W
        local offsets = { -1, 1, -width, width }
        local frontier = {}
        for tile in pairs(ctx.borders.border or {}) do
            frontier[#frontier + 1] = tile
            if #frontier >= 200 then break end
        end
        if settings.autoDefense then
            table.sort(frontier, function(a, b)
                if threatTile then
                    local function distance(tile)
                        return math.abs(tile % width - threatTile % width)
                            + math.abs(math.floor(tile / width) - math.floor(threatTile / width))
                    end
                    return distance(a) < distance(b)
                end
                local function hostile(tile)
                    local count = 0
                    for _, offset in ipairs(offsets) do
                        local target = tile + offset
                        if target >= 0 and target < state.N then
                            local owner = state:tile_owner(target)
                            if owner > 0 and owner ~= me.id and not state:are_allies(me.id, owner) then
                                count += 1
                            end
                        end
                    end
                    return count
                end
                return hostile(a) > hostile(b)
            end)
        end
        local sitesChecked = 0
        local buildSites = {}
        local buildTries = {}
        local buildKinds = { "city", "factory", "port", "sam" }
        local buildAvailability = {}
        if settings.autoBuild then
            for _, kind in ipairs(buildKinds) do
                local availability = ctx.rules:availability(kind)
                if availability and availability.ok and availability.cost
                    and me.gold >= availability.cost * 1.25 then
                    buildAvailability[kind] = availability
                end
                buildTries[kind] = 0
            end
        end
        for _, borderTile in ipairs(frontier) do
            if settings.autoDefense and sitesChecked < 60 and (threatTile or not defenseSite) then
                for _, tile in ipairs({ borderTile, borderTile - width * 4, borderTile + width * 4 }) do
                    if tile >= 0 and tile < state.N and state:tile_owner(tile) == me.id then
                        sitesChecked += 1
                        local placement = ctx.rules:placement("defense", tile)
                        if placement and placement.ok then
                            local availability = ctx.rules:availability("defense")
                            if availability and availability.ok then
                                local distance = threatTile and (
                                    math.abs(tile % width - threatTile % width)
                                    + math.abs(math.floor(tile / width) - math.floor(threatTile / width))) or 0
                                if not defenseSite or (threatTile and distance < defenseDistance) then
                                    defenseSite = { tile = placement.tile or tile, cost = availability.cost or 50000 }
                                    defenseDistance = distance
                                end
                                if not threatTile then break end
                            end
                        end
                    end
                end
            end
            if settings.autoBuild then
                for _, kind in ipairs(buildKinds) do
                    if buildAvailability[kind] and not buildSites[kind] and buildTries[kind] < 24 then
                        for _, tile in ipairs({ borderTile, borderTile - width * 6, borderTile + width * 6 }) do
                            if buildTries[kind] >= 24 then break end
                            if tile >= 0 and tile < state.N and state:tile_owner(tile) == me.id then
                                buildTries[kind] += 1
                                local placement = ctx.rules:placement(kind, tile)
                                if placement and placement.ok and not placement.upgrade then
                                    buildSites[kind] = { tile = placement.tile or tile,
                                        cost = buildAvailability[kind].cost }
                                    break
                                end
                            end
                        end
                    end
                end
            end
            if settings.autoExpand then
                for _, offset in ipairs(offsets) do
                    local tile = borderTile + offset
                    if tile >= 0 and tile < state.N and not seen[tile] then
                        seen[tile] = true
                        local owner = state:tile_owner(tile)
                        if owner ~= me.id and owner ~= 0 then
                            local primary = ctx.rules:primary(tile)
                            if primary and primary.ok
                                and (primary.type == "attack" or primary.type == "expand") then
                                local target = state:get_owner(owner)
                                candidates[#candidates + 1] = {
                                    tile = tile, owner = owner, kind = primary.type,
                                    troops = target and target.troops or 0,
                                    ally = owner > 0 and state:are_allies(me.id, owner) or false,
                                }
                            end
                        end
                    end
                end
            end
        end
        return { troops = me.troops, maxTroops = me.max_troops, gold = me.gold,
            income = me.income, incoming = incoming, threatTile = threatTile,
            defenseSite = defenseSite, defenseCount = buildCounts.defense, tiles = me.tiles,
            buildCounts = buildCounts, buildSites = buildSites,
            enableDefense = settings.autoDefense, enableBuild = settings.autoBuild,
            enableExpand = settings.autoExpand,
            candidates = candidates }
    end

    local function step()
        if not settings.autoDefense and not settings.autoBuild and not settings.autoExpand then
            setStatus("All modes off")
            return
        end
        if not context or not context.session or context.session.state ~= context.state then
            context = findContext()
        end
        if not context or not context.session or not context.state then
            setStatus("Game context unavailable")
            return
        end
        local snapshot = readSnapshot(context)
        if not snapshot then
            setStatus("Waiting for active nation")
            return
        end
        local action = Policy.choose(snapshot)
        if action.type == "build" and action.kind == "defense" and not settings.autoDefense then
            action = { type = "wait", reason = "Defense mode off" }
        elseif action.type == "build" and action.kind ~= "defense" and not settings.autoBuild then
            action = { type = "wait", reason = "Build mode off" }
        elseif action.type == "attack" and not settings.autoExpand then
            action = { type = "wait", reason = "Expansion mode off" }
        end
        if action.type == "wait" then
            setStatus(action.reason)
            return
        end
        if os.clock() - lastActionAt < settings.actionInterval then
            setStatus("Cooldown: " .. action.reason)
            return
        end
        local intent
        if action.type == "build" then
            local placement = context.rules:placement(action.kind, action.tile)
            local availability = context.rules:availability(action.kind)
            if not placement or not placement.ok or not availability or not availability.ok then
                setStatus("Build site changed; rescanning")
                return
            end
            intent = { type = "build", kind = action.kind, tile = placement.tile or action.tile }
        elseif action.type == "attack" then
            local primary = context.rules:primary(action.tile)
            if not primary or not primary.ok or (primary.type ~= "attack" and primary.type ~= "expand") then
                setStatus("Target changed; rescanning")
                return
            end
            intent = { type = "attack", tile = action.tile, ratio = action.ratio }
        end
        if not intent then return end
        context.session:send_intent(intent)
        lastActionAt = os.clock()
        setStatus(action.type .. " at tile " .. tostring(action.tile))
    end

    task.spawn(function()
        while running do
            local ok, err = pcall(step)
            if not ok then setStatus("Paused: " .. tostring(err)) end
            task.wait(settings.scanInterval)
        end
    end)

    environment.__N3Z_ROWORLD = {
        Destroy = function() running = false end,
        GetStatus = function() return status end,
    }
end
