SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("Nexus")
SaveManager:SetFolder("Nexus/Marvel Omega")  
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title = "PRIME",
    Content = "The script has been loaded.",
    Duration = 4.5
})

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

TrackRuntimeConnection(game:GetService("Players").LocalPlayer.AncestryChanged:Connect(function(_, parent)
    if not parent then
        Shutdown()
    end
end))
