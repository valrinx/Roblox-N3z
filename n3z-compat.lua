-- ============================================================
-- N3Z HUB v2.1.0 · n3z-compat.lua
-- DrawingUI-style Window adapter over the native dock.
-- ============================================================

return function(dock)
    assert(dock, "n3z-compat: dock required")

    local Window = {
        dock = dock,
        flags = {},
        itemsByFlag = {},
    }
    local unloadFns = {}
    local configStore = nil

    function Window:SetConfigStore(store)
        configStore = store
        self.configStore = store
    end

    function Window:GetConfigValue(flag, defaultValue)
        if type(flag) ~= "string" or flag == "" then return defaultValue end
        if configStore and type(configStore.Has) == "function" and configStore:Has(flag) then
            return configStore:Get(flag, defaultValue)
        end
        if configStore and type(configStore.Ensure) == "function" then
            configStore:Ensure(flag, defaultValue)
        end
        return defaultValue
    end

    function Window:SetConfigValue(flag, value)
        if type(flag) ~= "string" or flag == "" then return end
        self.flags[flag] = value
        if configStore and type(configStore.Set) == "function" then
            configStore:Set(flag, value)
        end
    end

    local function resolveValue(flag, kind, declared)
        local value = declared
        if configStore and type(flag) == "string" and flag ~= "" and configStore:Has(flag) then
            value = configStore:Get(flag, declared)
        elseif kind == "toggle" then
            -- First run: gameplay toggles always start OFF. A module's legacy
            -- CurrentValue=true must never silently enable a feature.
            value = false
        end

        if type(flag) == "string" and flag ~= "" then
            Window.flags[flag] = value
            if configStore and type(configStore.Ensure) == "function" then
                configStore:Ensure(flag, value)
            end
        end
        return value
    end

    local function userCallback(flag, callback)
        return function(value)
            if type(flag) == "string" and flag ~= "" then
                Window:SetConfigValue(flag, value)
            end
            if type(callback) == "function" then
                pcall(callback, value)
            end
        end
    end

    local function applyInitial(flag, callback, value)
        if type(flag) == "string" and flag ~= "" then
            Window.flags[flag] = value
        end
        if type(callback) == "function" then
            pcall(callback, value)
        end
    end

    local function rememberHandle(flag, handle)
        if type(flag) == "string" and flag ~= "" then
            Window.itemsByFlag[flag] = handle
        end
        return handle
    end

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
            local value = resolveValue(def.Flag, "toggle", def.CurrentValue == true)
            local handle = dock:AddRow(tabId, {
                kind = "toggle",
                name = def.Name or "Toggle",
                value = value == true,
                onChange = userCallback(def.Flag, def.Callback),
            })
            applyInitial(def.Flag, def.Callback, value == true)
            return rememberHandle(def.Flag, handle)
        end

        function tab:CreateSlider(def)
            def = def or {}
            local range = def.Range or { 0, 100 }
            local value = resolveValue(def.Flag, "slider", def.CurrentValue)
            local handle = dock:AddRow(tabId, {
                kind = "slider",
                name = def.Name or "Slider",
                min = range[1] or 0,
                max = range[2] or 100,
                step = def.Increment or 1,
                suffix = def.Suffix or "",
                value = value,
                onChange = userCallback(def.Flag, def.Callback),
            })
            applyInitial(def.Flag, def.Callback, value)
            return rememberHandle(def.Flag, handle)
        end

        function tab:CreateDropdown(def)
            def = def or {}
            local value = resolveValue(def.Flag, "dropdown", def.CurrentOption)
            local handle = dock:AddRow(tabId, {
                kind = "dropdown",
                name = def.Name or "Dropdown",
                options = def.Options or {},
                value = value,
                onChange = userCallback(def.Flag, def.Callback),
            })
            applyInitial(def.Flag, def.Callback, value)
            return rememberHandle(def.Flag, handle)
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
            local declared = def.CurrentKeybind or def.Default or "None"
            if typeof(declared) == "EnumItem" then declared = declared.Name end
            local key = resolveValue(def.Flag, "keybind", declared)
            if typeof(key) == "EnumItem" then key = key.Name end
            local handle = dock:AddRow(tabId, {
                kind = "keybind",
                name = def.Name or "Keybind",
                key = key,
                callback = userCallback(def.Flag, def.Callback),
                flag = def.Flag,
            })
            local origSet = handle.Set
            function handle:Set(newKey)
                if typeof(newKey) == "EnumItem" then newKey = newKey.Name end
                if origSet then origSet(handle, newKey) end
                if def.Flag then Window:SetConfigValue(def.Flag, newKey) end
            end
            applyInitial(def.Flag, def.Callback, key)
            return rememberHandle(def.Flag, handle)
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

    local windowDestroyed = false
    function Window:Destroy()
        if windowDestroyed then return end
        windowDestroyed = true
        local fns = unloadFns
        unloadFns = {}
        for _, fn in ipairs(fns) do
            pcall(fn)
        end
        dock:Destroy()
    end

    return Window
end
