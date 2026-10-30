local function safeCall(label, fn)
    return PrimeRuntime.Run("Settings/" .. label, fn)
end

safeCall("SelectTab", function() Window:SelectTab(1) end)
safeCall("Notify loaded", function()
    Notify({Title = "Liqdation", Content = "Marvel Omega has been loaded.", Duration = 4.5})
end)
safeCall("AncestryChanged", function()
    TrackRuntimeConnection(Player.AncestryChanged:Connect(function(_, parent)
        if not parent then Shutdown() end
    end))
end)
