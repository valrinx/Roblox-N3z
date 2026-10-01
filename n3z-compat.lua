-- ============================================================
-- N3Z HUB · compat.lua
-- DrawingUI-style Window adapter over the native dock.
-- Lets existing RAVENHUB modules run UNCHANGED:
--   return function(Window, ctx) ... Window:CreateTab("Combat") ...
-- Tab mapping: combat-ish -> COMBAT dock tab, visual/esp-ish -> VISUALS,
-- anything else becomes an extra dock tab (appended after the fixed 4).
-- Usage: local makeWindow = loadstring(compatSrc)(); local Window = makeWindow(dock)
-- ============================================================

return function(dock)
    assert(dock, "n3z-compat: dock required")

    local Window = {
        dock = dock,
        flags = {},
        itemsByFlag = {},
    }
    local unloadFns = {}

    local function mapTabId(name)
        local n = string.lower(tostring(name or ""))
        if n:find("combat", 1, true) or n:find("aim", 1, true) then
            return "combat"
        end
        if n:find("visual", 1, true) or n:find("esp", 1, true) then
            return "visuals"
        end
        return dock:AddTab(tostring(name))
    end

    local function makeTabProxy(tabId)
        local tab = { _dockTab = tabId }

        function tab:CreateToggle(def)
            def = def or {}
            return dock:AddRow(tabId, {
                kind = "toggle",
                name = def.Name or "Toggle",
                value = def.CurrentValue == true,
                onChange = def.Callback,
            })
        end

        function tab:CreateSlider(def)
            def = def or {}
            local range = def.Range or { 0, 100 }
            return dock:AddRow(tabId, {
                kind = "slider",
                name = def.Name or "Slider",
                min = range[1] or 0,
                max = range[2] or 100,
                step = def.Increment or 1,
                suffix = def.Suffix or "",
                value = def.CurrentValue,
                onChange = def.Callback,
            })
        end

        function tab:CreateDropdown(def)
            def = def or {}
            return dock:AddRow(tabId, {
                kind = "dropdown",
                name = def.Name or "Dropdown",
                options = def.Options or {},
                value = def.CurrentOption,
                onChange = def.Callback,
            })
        end

        function tab:CreateButton(def)
            def = def or {}
            local handle = dock:AddRow(tabId, {
                kind = "button",
                name = def.Name or "Button",
                onPress = def.Callback,
            })
            -- DrawingUI button:Set({Name=...}) compat
            local origSetName = handle.SetName
            function handle:Set(t)
                if type(t) == "table" and t.Name ~= nil and origSetName then
                    origSetName(handle, t.Name)
                elseif type(t) == "string" and origSetName then
                    origSetName(handle, t)
                end
            end
            return handle
        end

        function tab:CreateKeybind(def)
            def = def or {}
            local key = def.CurrentKeybind or def.Default or "None"
            if typeof(key) == "EnumItem" then key = key.Name end
            local handle = dock:AddRow(tabId, {
                kind = "keybind",
                name = def.Name or "Keybind",
                key = key,
                callback = def.Callback,
                flag = def.Flag,
            })
            if def.Flag then
                local envFlag = def.Flag
                local origSet = handle.Set
                function handle:Set(newKey)
                    if origSet then origSet(handle, newKey) end
                    if Window.flags then Window.flags[envFlag] = newKey end
                end
                if Window.itemsByFlag then
                    Window.itemsByFlag[def.Flag] = handle
                end
            end
            return handle
        end

        function tab:CreateLabel(text)
            return dock:AddRow(tabId, { kind = "label", text = tostring(text or "") })
        end

        function tab:CreateParagraph(title, text)
            dock:AddRow(tabId, { kind = "label", text = tostring(title or "") .. "\n" .. tostring(text or "") })
            return {}
        end

        function tab:CreateSection(name)
            local sec = { tab = tab }
            dock:AddRow(tabId, { kind = "section", text = tostring(name or "") })
            function sec:CreateToggle(def) return tab:CreateToggle(def) end
            function sec:CreateSlider(def) return tab:CreateSlider(def) end
            function sec:CreateDropdown(def) return tab:CreateDropdown(def) end
            function sec:CreateButton(def) return tab:CreateButton(def) end
            function sec:CreateKeybind(def) return tab:CreateKeybind(def) end
            function sec:CreateLabel(text) return tab:CreateLabel(text) end
            return sec
        end

        -- remove everything the module added to this dock tab (clean reload)
        function tab:Clear()
            dock:ClearRows(tabId)
        end

        return tab
    end

    function Window:CreateTab(name, _icon)
        return makeTabProxy(mapTabId(name))
    end

    function Window:CreatePlaceholderTab(name, _icon, _msg)
        return makeTabProxy(mapTabId(name))
    end

    function Window:OnUnload(fn)
        if type(fn) == "function" then
            table.insert(unloadFns, fn)
        end
    end

    function Window:SortTabs(_order)
        -- dock tabs are fixed-order; no-op for compat
    end

    function Window:Toggle()
        dock:Toggle()
    end

    function Window:Destroy()
        for _, fn in ipairs(unloadFns) do
            pcall(fn)
        end
        dock:Destroy()
    end

    return Window
end
