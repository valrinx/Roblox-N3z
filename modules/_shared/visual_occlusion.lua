-- ============================================================
-- N3Z shared Drawing occlusion
-- Keeps Drawing-based visuals from rendering through the Hub.
-- Supports the Drawing primitives used by N3Z modules:
-- Text, Square, Line, Circle.
-- ============================================================

return function(baseDrawing, ctx)
    assert(type(baseDrawing) == "table" and type(baseDrawing.new) == "function",
        "visual_occlusion: Drawing provider is required")

    local RunService = game:GetService("RunService")
    local dock = type(ctx) == "table" and ctx.dock or nil
    local entries = {}
    local dead = false
    local cachedRects = nil

    local function getOcclusionRects()
        if dock and type(dock.GetOcclusionRects) == "function" then
            local ok, rects = pcall(function()
                return dock:GetOcclusionRects()
            end)
            if ok and type(rects) == "table" then
                return rects
            end
        end
        return {}
    end

    local function pointInRect(p, rect)
        return typeof(p) == "Vector2"
            and p.X >= rect.x
            and p.X <= rect.x + rect.w
            and p.Y >= rect.y
            and p.Y <= rect.y + rect.h
    end

    local function rectOverlapsRect(x, y, w, h, rect)
        return x < rect.x + rect.w
            and x + w > rect.x
            and y < rect.y + rect.h
            and y + h > rect.y
    end

    local function segmentOverlapsRect(a, b, rect)
        if typeof(a) ~= "Vector2" or typeof(b) ~= "Vector2" then
            return false
        end
        if pointInRect(a, rect) or pointInRect(b, rect) then
            return true
        end

        -- Liang-Barsky segment / axis-aligned rectangle intersection.
        local dx, dy = b.X - a.X, b.Y - a.Y
        local t0, t1 = 0, 1

        local function clip(pv, qv)
            if pv == 0 then return qv >= 0 end
            local r = qv / pv
            if pv < 0 then
                if r > t1 then return false end
                if r > t0 then t0 = r end
            else
                if r < t0 then return false end
                if r < t1 then t1 = r end
            end
            return true
        end

        return clip(-dx, a.X - rect.x)
            and clip(dx, rect.x + rect.w - a.X)
            and clip(-dy, a.Y - rect.y)
            and clip(dy, rect.y + rect.h - a.Y)
            and t0 <= t1
    end

    local function read(obj, key)
        local ok, value = pcall(function() return obj[key] end)
        return ok and value or nil
    end

    local function overlaps(entry, rect)
        local obj = entry.raw
        local kind = entry.kind

        if kind == "Square" then
            local pos = read(obj, "Position")
            local size = read(obj, "Size")
            if typeof(pos) ~= "Vector2" then return false end
            if typeof(size) ~= "Vector2" then
                return pointInRect(pos, rect)
            end
            return rectOverlapsRect(pos.X, pos.Y, size.X, size.Y, rect)
        end

        if kind == "Text" then
            local pos = read(obj, "Position")
            if typeof(pos) ~= "Vector2" then return false end
            local bounds = read(obj, "TextBounds")
            if typeof(bounds) ~= "Vector2" then
                return pointInRect(pos, rect)
            end
            local centered = read(obj, "Center") == true
            local x = pos.X - (centered and bounds.X * 0.5 or 0)
            return rectOverlapsRect(x, pos.Y, bounds.X, bounds.Y, rect)
        end

        if kind == "Line" then
            return segmentOverlapsRect(
                read(obj, "From"),
                read(obj, "To"),
                rect
            )
        end

        if kind == "Circle" then
            local pos = read(obj, "Position")
            local radius = tonumber(read(obj, "Radius")) or 0
            if typeof(pos) ~= "Vector2" then return false end
            return rectOverlapsRect(
                pos.X - radius,
                pos.Y - radius,
                radius * 2,
                radius * 2,
                rect
            )
        end

        -- Unknown Drawing types use their screen Position as a safe fallback.
        local pos = read(obj, "Position")
        return typeof(pos) == "Vector2" and pointInRect(pos, rect) or false
    end

    local function shouldOcclude(entry, rects)
        if rects == nil then
            if cachedRects == nil then cachedRects = getOcclusionRects() end
            rects = cachedRects
        end
        for _, rect in ipairs(rects) do
            if type(rect) == "table"
                and tonumber(rect.x)
                and tonumber(rect.y)
                and tonumber(rect.w)
                and tonumber(rect.h)
                and rect.w > 0
                and rect.h > 0
                and overlaps(entry, rect) then
                return true
            end
        end
        return false
    end

    local function applyVisibility(entry, rects)
        if dead or entry.removed then return end
        local visible = entry.desiredVisible == true
        if visible and shouldOcclude(entry, rects) then
            visible = false
        end
        pcall(function()
            entry.raw.Visible = visible
        end)
        entry.actualVisible = visible
    end

    local function removeEntry(entry)
        if entry.removed then return end
        entry.removed = true
        entries[entry.proxy] = nil
        pcall(function()
            if type(entry.raw.Remove) == "function" then
                entry.raw:Remove()
            elseif type(entry.raw.Destroy) == "function" then
                entry.raw:Destroy()
            end
        end)
    end

    local wrappedDrawing = {}
    for k, v in pairs(baseDrawing) do
        if k ~= "new" then wrappedDrawing[k] = v end
    end

    function wrappedDrawing.new(kind)
        local ok, raw = pcall(baseDrawing.new, kind)
        if not ok or raw == nil then return nil end

        local entry = {
            kind = tostring(kind),
            raw = raw,
            desiredVisible = read(raw, "Visible") == true,
            actualVisible = false,
            removed = false,
        }
        local proxy = {}
        entry.proxy = proxy

        setmetatable(proxy, {
            __index = function(_, key)
                if key == "Visible" then
                    return entry.desiredVisible
                end
                if key == "Occluded" then
                    return entry.desiredVisible and not entry.actualVisible
                end
                if key == "Remove" or key == "Destroy" then
                    return function()
                        removeEntry(entry)
                    end
                end

                local value = read(raw, key)
                if type(value) == "function" then
                    return function(_, ...)
                        return value(raw, ...)
                    end
                end
                return value
            end,
            __newindex = function(_, key, value)
                if entry.removed then return end
                if key == "Visible" then
                    entry.desiredVisible = value == true
                    applyVisibility(entry)
                    return
                end

                local okSet, err = pcall(function()
                    raw[key] = value
                end)
                if not okSet then error(err, 2) end

                if key == "Position"
                    or key == "Size"
                    or key == "Text"
                    or key == "Center"
                    or key == "From"
                    or key == "To"
                    or key == "Radius" then
                    applyVisibility(entry)
                end
            end,
        })

        entries[proxy] = entry
        applyVisibility(entry)
        return proxy
    end

    local connection = RunService.RenderStepped:Connect(function()
        if dead then return end
        cachedRects = getOcclusionRects()
        local rects = cachedRects
        for _, entry in pairs(entries) do
            if entry.desiredVisible then
                applyVisibility(entry, rects)
            elseif entry.actualVisible then
                applyVisibility(entry, rects)
            end
        end
    end)

    function wrappedDrawing.destroy()
        if dead then return end
        dead = true
        if connection then
            pcall(function() connection:Disconnect() end)
            connection = nil
        end

        local pending = {}
        for _, entry in pairs(entries) do
            pending[#pending + 1] = entry
        end
        table.clear(entries)
        for _, entry in ipairs(pending) do
            removeEntry(entry)
        end
    end

    return wrappedDrawing
end
