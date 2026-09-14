local function suicide()
    local player = game:GetService("Players").LocalPlayer
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.Health = 0
            Fluent:Notify({
                Title = "Suicide",
                Content = "You have committed suicide.",
                Duration = 3
            })
        end
    end
end

local function rejoinGame()
    local ts = game:GetService("TeleportService")
    local placeId = game.PlaceId
    local jobId = game.JobId
    
    ts:TeleportToPlaceInstance(placeId, jobId, game:GetService("Players").LocalPlayer)
    Fluent:Notify({
        Title = "Rejoin",
        Content = "Rejoining game...",
        Duration = 3
    })
end

local function serverHop()
    local ts = game:GetService("TeleportService")
    local http = game:GetService("HttpService")
    
    Fluent:Notify({
        Title = "Server Hop",
        Content = "Finding new server...",
        Duration = 3
    })
    
    local servers = {}
    local req = http:GetAsync("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?limit=100")
    local data = http:JSONDecode(req)
    
    for _, server in ipairs(data.data) do
        if server.playing < server.maxPlayers and server.id ~= game.JobId then
            table.insert(servers, server.id)
        end
    end
    
    if #servers > 0 then
        local randomServer = servers[math.random(1, #servers)]
        ts:TeleportToPlaceInstance(game.PlaceId, randomServer)
    else
        Fluent:Notify({
            Title = "Server Hop Error",
            Content = "No available servers found!",
            Duration = 3
        })
    end
end

do
    Tabs.Other:AddSection("Other")
    
    Tabs.Other:AddButton({
        Title = "Suicide",
        Description = "Kill your character",
        Callback = function()
            suicide()
        end
    })
    
    Tabs.Other:AddButton({
        Title = "Rejoin Game",
        Description = "Rejoins the current game server",
        Callback = function()
            rejoinGame()
        end
    })
    
    Tabs.Other:AddButton({
        Title = "Server Hop",
        Description = "Joins a new random server",
        Callback = function()
            serverHop()
        end
    })
end

