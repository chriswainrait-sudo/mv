local function safeCall(label, fn)
    local ok, err = pcall(fn)
    if not ok then
        warn("Marvel Omega [Settings/" .. label .. "]: " .. tostring(err))
    end
end

safeCall("SetLibrary", function() SaveManager:SetLibrary(Fluent) end)
safeCall("SetLibrary", function() InterfaceManager:SetLibrary(Fluent) end)
safeCall("IgnoreThemeSettings", function() SaveManager:IgnoreThemeSettings() end)
safeCall("SetIgnoreIndexes", function() SaveManager:SetIgnoreIndexes({}) end)
safeCall("SetFolder", function() InterfaceManager:SetFolder("Nexus") end)
safeCall("SetFolder", function() SaveManager:SetFolder("Nexus/Marvel Omega") end)
safeCall("BuildInterfaceSection", function()
    InterfaceManager:BuildInterfaceSection(Tabs.Settings)
end)
safeCall("BuildConfigSection", function()
    SaveManager:BuildConfigSection(Tabs.Settings)
end)

safeCall("SelectTab", function()
    Window:SelectTab(1)
end)

safeCall("Notify loaded", function()
    Notify({
        Title = "PRIME",
        Content = "The script has been loaded.",
        Duration = 4.5
    })
end)

-- Performance/safety: do NOT automatically restore runtime feature toggles on injection.
-- Saved configs are still available from the Settings/config section and can be loaded manually.
-- Autoload could silently start RenderStepped/Heartbeat-heavy features such as
-- Advanced ESP, Silent Aim or Flight Speed before the user explicitly enabled them.
-- SaveManager:LoadAutoloadConfig()

local function Shutdown()
    if PrimeRuntime.IsShuttingDown then
        return
    end
    PrimeRuntime.IsShuttingDown = true

    for index = #PrimeRuntime.Cleanups, 1, -1 do
        pcall(PrimeRuntime.Cleanups[index])
    end
    table.clear(PrimeRuntime.Cleanups)

    for _, connection in ipairs(PrimeRuntime.Connections) do
        pcall(function()
            if connection and connection.Connected then
                connection:Disconnect()
            end
        end)
    end
    table.clear(PrimeRuntime.Connections)

    if PRIME_ENV[PRIME_RUNTIME_KEY] == PrimeRuntime then
        PRIME_ENV[PRIME_RUNTIME_KEY] = nil
    end
end

PrimeRuntime.Shutdown = Shutdown

if Fluent then
    local originalDestroy = Fluent.Destroy
    Fluent.Destroy = function(...)
        Shutdown()
        if originalDestroy then
            return originalDestroy(...)
        end
    end
end

safeCall("AncestryChanged", function()
    TrackRuntimeConnection(game:GetService("Players").LocalPlayer.AncestryChanged:Connect(function(_, parent)
        if not parent then
            Shutdown()
        end
    end))
end)
