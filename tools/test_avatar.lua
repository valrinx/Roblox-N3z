-- Run with the extracted production chunks on the Roblox client via Raven MCP.
-- Network responses and task scheduling are controlled; ImageLabels are real.
return function(sources)
    local results = {}
    local function test(name, callback)
        local ok, err = pcall(callback)
        table.insert(results, { name = name, passed = ok, error = not ok and tostring(err) or nil })
    end

    local function expect(actual, expected, message)
        assert(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end

    local realGame = game
    local constructor = assert(loadstring(sources.constructor, "@avatar-constructor-test"))
    setfenv(constructor, setmetatable({ game = {
        GetService = function(_, name)
            if name == "Players" then return { LocalPlayer = { UserId = 42 } } end
            return realGame:GetService(name)
        end,
    } }, { __index = getfenv() }))
    local buildAvatar = constructor()
    local methods = assert(loadstring(sources.methods, "@avatar-method-test"))()
    local startAvatar = assert(loadstring(sources.loader, "@avatar-loader-test"))()

    test("desktop avatar starts with the running player's thumbnail", function()
        local parent = Instance.new("Frame")
        local state = {}
        local ok, err = pcall(function()
            buildAvatar(state, parent, { showAvatar = true })
            expect(state._avatar.Image, "rbxthumb://type=AvatarHeadShot&id=42&w=150&h=150", "initial avatar")
        end)
        parent:Destroy()
        assert(ok, err)
    end)

    test("layouts with avatars disabled do not create an avatar", function()
        local parent = Instance.new("Frame")
        local state = {}
        buildAvatar(state, parent, { showAvatar = false })
        local count = #parent:GetChildren()
        parent:Destroy()
        expect(count, 0, "mobile avatar children")
        expect(state._avatar, nil, "mobile avatar")
    end)

    local function withLoader(responses, callback, hasAvatar)
        local image = Instance.new("ImageLabel")
        image.Image = "rbxthumb://type=AvatarHeadShot&id=42&w=150&h=150"
        local dock = setmetatable({ _avatar = hasAvatar ~= false and image or nil, _dead = false }, { __index = methods })
        local scheduled, requestedSizes, calls, waits = {}, {}, 0, 0
        local onWait
        local player = { UserId = 42 }
        local players = {
            GetUserThumbnailAsync = function(_, userId, kind, size)
                calls = calls + 1
                expect(userId, 42, "thumbnail owner")
                expect(kind, Enum.ThumbnailType.HeadShot, "thumbnail type")
                table.insert(requestedSizes, size)
                local response = responses[calls] or responses[#responses]
                if response.destroy then dock._dead = true end
                if response.error then error(response.error) end
                return response.content, response.ready
            end,
        }
        local scheduler = {
            spawn = function(fn) table.insert(scheduled, fn) end,
            wait = function() waits = waits + 1; if onWait then onWait() end end,
        }
        local ok, err = pcall(function()
            startAvatar(players, player, dock, scheduler, Enum)
            callback(dock, image, function() for _, fn in ipairs(scheduled) do fn() end end,
                function() return calls, waits, #scheduled end,
                function(fn) onWait = fn end)
            for _, size in ipairs(requestedSizes) do
                expect(size, Enum.ThumbnailSize.Size150x150, "thumbnail size")
            end
        end)
        image:Destroy()
        assert(ok, err)
    end

    test("ready thumbnail replaces the initial image asynchronously", function()
        withLoader({ { content = "rbxassetid://123", ready = true } }, function(_, image, run, counts)
            local calls = counts()
            expect(calls, 0, "nonblocking startup")
            run()
            expect(image.Image, "rbxassetid://123", "ready image")
            expect(counts(), 1, "successful requests")
        end)
    end)

    test("pending thumbnail is retried until ready", function()
        withLoader({ { content = "rbxassetid://0", ready = false },
            { content = "rbxassetid://456", ready = true } }, function(_, image, run, counts)
            run()
            expect(image.Image, "rbxassetid://456", "retried image")
            local calls, waits = counts()
            expect(calls, 2, "pending requests")
            expect(waits, 1, "retry delay")
        end)
    end)

    test("temporary API failure is retried", function()
        withLoader({ { error = "temporary thumbnail failure" },
            { content = "rbxassetid://789", ready = true } }, function(_, image, run)
            run()
            expect(image.Image, "rbxassetid://789", "recovered image")
        end)
    end)

    test("empty ready response cannot erase the initial image", function()
        withLoader({ { content = "", ready = true },
            { content = "rbxassetid://321", ready = true } }, function(_, image, run)
            run()
            expect(image.Image, "rbxassetid://321", "valid retried image")
        end)
    end)

    test("persistent failure keeps the initial image with bounded retries", function()
        withLoader({ { error = "thumbnail unavailable" } }, function(_, image, run, counts)
            run()
            expect(image.Image, "rbxthumb://type=AvatarHeadShot&id=42&w=150&h=150", "fallback image")
            local calls, waits = counts()
            expect(calls, 5, "retry limit")
            expect(waits, 4, "no wait after final attempt")
        end)
    end)

    test("unload during retry stops further requests", function()
        withLoader({ { content = "rbxassetid://0", ready = false } }, function(dock, _, run, counts, setOnWait)
            setOnWait(function() dock._dead = true end)
            run()
            expect(counts(), 1, "requests after unload")
        end)
    end)

    test("unload during an API request prevents late image writes", function()
        withLoader({ { content = "rbxassetid://999", ready = true, destroy = true } }, function(_, image, run)
            run()
            expect(image.Image, "rbxthumb://type=AvatarHeadShot&id=42&w=150&h=150", "image after unload")
        end)
    end)

    test("layout without an avatar does not schedule thumbnail requests", function()
        withLoader({ { content = "rbxassetid://123", ready = true } }, function(_, _, run, counts)
            run()
            local calls, _, scheduled = counts()
            expect(calls, 0, "requests without avatar")
            expect(scheduled, 0, "tasks without avatar")
        end, false)
    end)

    local passed = 0
    for _, result in ipairs(results) do if result.passed then passed = passed + 1 end end
    return { passed = passed, failed = #results - passed, tests = results }
end
