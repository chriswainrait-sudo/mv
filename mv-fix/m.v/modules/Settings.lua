InterfaceManager:SetLibrary(Fluent)
SaveManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"MenuKeybind"})

local fs = true
for _, f in ipairs({"isfile", "isfolder", "makefolder", "readfile", "writefile", "listfiles"}) do
    if type(getfenv()[f]) ~= "function" then fs = false break end
end

if fs then
    PrimeRuntime.Run("Settings/Interface", function()
        InterfaceManager:SetFolder("Nexus")
        InterfaceManager:BuildInterfaceSection(Tabs.Settings)
    end)
    PrimeRuntime.Run("Settings/Configs", function()
        SaveManager:SetFolder("Nexus/Marvel Omega")
        SaveManager:BuildConfigSection(Tabs.Settings)
    end)
else
    Tabs.Settings:AddSection("Interface")
    local b = Tabs.Settings:AddKeybind("MenuKeybind", {Title = "Minimize Bind", Default = "LeftAlt", NoDisplay = true})
    Fluent.MinimizeKeybind = b
    Tabs.Settings:AddParagraph({Title = "Configs unavailable", Content = "File APIs are unavailable in this environment."})
end

Tabs.Settings:AddSection("Window")
Tabs.Settings:AddButton({Title = "Close", Callback = PrimeRuntime.Shutdown})
Window:SelectTab(1)
local n = #PrimeRuntime.Errors
Notify({Title = "PRIME", Content = n == 0 and "The script has been loaded." or
    ("Loaded with " .. n .. " errors. See the console."), Duration = 5})
