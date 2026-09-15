local function safeUI(label, fn)
    local ok, err = pcall(fn)
    if not ok then
        warn("Marvel Omega [Movement/" .. label .. "]: " .. tostring(err))
    end
end

local alwaysSprintEnabled = false
local function toggleAlwaysSprint(value)
    alwaysSprintEnabled = value
    simulateAction("Sprint", value)
end

TrackRuntimeConnection(Player.CharacterAdded:Connect(function()
    task.delay(0.6, function()
        if alwaysSprintEnabled then simulateAction("Sprint", true) end
    end)
end))

local antiFlingEnabled = false
local antiFlingThreshold = 180
local antiFlingConnection
local antiFlingSafeCFrame
local antiFlingLastPosition
local antiFlingCooldown = 0

local function toggleAntiFling(value)
    antiFlingEnabled = value
    if antiFlingConnection then antiFlingConnection:Disconnect() antiFlingConnection = nil end
    antiFlingSafeCFrame, antiFlingLastPosition = nil, nil
    if not value then return end
    antiFlingConnection = game:GetService("RunService").Heartbeat:Connect(function(dt)
        local character = Player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
        if not root or not humanoid or humanoid.Health <= 0 or humanoid.SeatPart or character:GetAttribute("ApplyingFlightForce") then
            antiFlingLastPosition = root and root.Position or nil
            return
        end
        local moved = antiFlingLastPosition and (root.Position - antiFlingLastPosition).Magnitude or 0
        local speed = root.AssemblyLinearVelocity.Magnitude
        if os.clock() >= antiFlingCooldown and antiFlingSafeCFrame and (speed > antiFlingThreshold or moved > math.max(55, antiFlingThreshold * dt * 2.5)) then
            antiFlingCooldown = os.clock() + 0.75
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            character:PivotTo(antiFlingSafeCFrame)
            antiFlingLastPosition = antiFlingSafeCFrame.Position
            return
        end
        if humanoid.FloorMaterial ~= Enum.Material.Air and speed < antiFlingThreshold * 0.45 then
            antiFlingSafeCFrame = root.CFrame
        end
        antiFlingLastPosition = root.Position
    end)
end

local noclipEnabled = false
local noclipConnections = {}
local currentCharacter = nil

local function applyNoclipToPart(part)
    if part:IsA("BasePart") then
        part.CanCollide = false
    end
end

local function removeNoclipFromPart(part)
    if part:IsA("BasePart") then
        part.CanCollide = true
    end
end

local function setupNoclipForCharacter(character)
    if not character or not noclipEnabled then return end
    
    currentCharacter = character
    
   
    for _, part in ipairs(character:GetDescendants()) do
        applyNoclipToPart(part)
    end
    
    local descendantAddedConnection = character.DescendantAdded:Connect(function(descendant)
        if noclipEnabled then
            applyNoclipToPart(descendant)
        end
    end)
    
    table.insert(noclipConnections, descendantAddedConnection)
    
    local humanoid = character:FindFirstChildWhichIsA("Humanoid")
    if humanoid then
        local stateChangedConnection = humanoid.StateChanged:Connect(function(_, newState)
            if noclipEnabled then
                for _, part in ipairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
        table.insert(noclipConnections, stateChangedConnection)
    end
end

local function cleanupNoclip()
    for _, connection in ipairs(noclipConnections) do
        if connection.Connected then
            connection:Disconnect()
        end
    end
    noclipConnections = {}
    
    local player = game:GetService("Players").LocalPlayer
    local character = player.Character or currentCharacter
    
    if character then
        for _, part in ipairs(character:GetDescendants()) do
            removeNoclipFromPart(part)
        end
    end
    
    currentCharacter = nil
end

local function toggleNoclip(value)
    noclipEnabled = value
    
    if noclipEnabled then
        cleanupNoclip()  
        
        local player = game:GetService("Players").LocalPlayer
        
        local characterAddedConnection = player.CharacterAdded:Connect(function(character)
            cleanupNoclip() 
            task.wait(0.1)  
            setupNoclipForCharacter(character)
        end)
        
        table.insert(noclipConnections, characterAddedConnection)
        
        if player.Character then
            task.wait(0.1)
            setupNoclipForCharacter(player.Character)
        end
    else
        cleanupNoclip()
    end
end
local jumpPowerEnabled = false
local jumpPowerValue = 50
-- Jump Power
local originalJumpPower = nil
local jumpPowerConnections = {}

local function clearJumpPowerConnections()
    for _, connection in ipairs(jumpPowerConnections) do
        pcall(function()
            if connection and connection.Connected then
                connection:Disconnect()
            end
        end)
    end
    table.clear(jumpPowerConnections)
end

local function applyJumpPower()
    local Player = game:GetService("Players").LocalPlayer
    local Character = Player.Character
    if not Character then
        return
    end
    
    local Humanoid = Character:FindFirstChild("Humanoid")
    if not Humanoid then
        return
    end
    
    if jumpPowerEnabled then
        if not originalJumpPower then
            originalJumpPower = Humanoid.JumpPower
        end
        Humanoid.JumpPower = jumpPowerValue
    else
        if originalJumpPower then
            Humanoid.JumpPower = originalJumpPower
        end
    end
end

local function setupJumpPower()
    local Players = game:GetService("Players")
    local Player = Players.LocalPlayer

    clearJumpPowerConnections()

    local function onCharacterAdded(Character)
        task.wait(0.1)
        if not jumpPowerEnabled or not Character or not Character.Parent then
            return
        end

        applyJumpPower()

        local Humanoid = Character:FindFirstChildOfClass("Humanoid") or Character:WaitForChild("Humanoid", 5)
        if not Humanoid then
            return
        end

        local propertyConnection = Humanoid:GetPropertyChangedSignal("JumpPower"):Connect(function()
            if jumpPowerEnabled and Humanoid.Parent and Humanoid.JumpPower ~= jumpPowerValue then
                Humanoid.JumpPower = jumpPowerValue
            end
        end)
        table.insert(jumpPowerConnections, propertyConnection)
    end

    local characterConnection = Player.CharacterAdded:Connect(function(Character)
        task.spawn(onCharacterAdded, Character)
    end)
    table.insert(jumpPowerConnections, characterConnection)

    if Player.Character then
        task.spawn(onCharacterAdded, Player.Character)
    end
end

local function setJumpPower(value)
    jumpPowerValue = value
    applyJumpPower()
end

local function toggleJumpPower(value)
    jumpPowerEnabled = value == true

    if jumpPowerEnabled then
        setupJumpPower()
    else
        clearJumpPowerConnections()
        applyJumpPower()
    end
end
local walkSpeedEnabled = false
local walkSpeedValue = 50
-- Walk Speed
local originalWalkSpeed = nil
local walkSpeedConnections = {}

local function clearWalkSpeedConnections()
    for _, connection in ipairs(walkSpeedConnections) do
        pcall(function()
            if connection and connection.Connected then
                connection:Disconnect()
            end
        end)
    end
    table.clear(walkSpeedConnections)
end

local function applyWalkSpeed()
    local Player = game:GetService("Players").LocalPlayer
    local Character = Player.Character
    if not Character then
        return
    end
    
    local Humanoid = Character:FindFirstChild("Humanoid")
    if not Humanoid then
        return
    end
    
    if walkSpeedEnabled then
        if not originalWalkSpeed then
            originalWalkSpeed = Humanoid.WalkSpeed
        end
        Humanoid.WalkSpeed = walkSpeedValue
    else
        if originalWalkSpeed then
            Humanoid.WalkSpeed = originalWalkSpeed
        end
    end
end

local function setupWalkSpeed()
    local Players = game:GetService("Players")
    local Player = Players.LocalPlayer

    clearWalkSpeedConnections()

    local function onCharacterAdded(Character)
        task.wait(0.1)
        if not walkSpeedEnabled or not Character or not Character.Parent then
            return
        end

        applyWalkSpeed()

        local Humanoid = Character:FindFirstChildOfClass("Humanoid") or Character:WaitForChild("Humanoid", 5)
        if not Humanoid then
            return
        end

        local propertyConnection = Humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if walkSpeedEnabled and Humanoid.Parent and Humanoid.WalkSpeed ~= walkSpeedValue then
                Humanoid.WalkSpeed = walkSpeedValue
            end
        end)
        table.insert(walkSpeedConnections, propertyConnection)
    end

    local characterConnection = Player.CharacterAdded:Connect(function(Character)
        task.spawn(onCharacterAdded, Character)
    end)
    table.insert(walkSpeedConnections, characterConnection)

    if Player.Character then
        task.spawn(onCharacterAdded, Player.Character)
    end
end

local function setWalkSpeed(value)
    walkSpeedValue = value
    applyWalkSpeed()
end

local function toggleWalkSpeed(value)
    walkSpeedEnabled = value == true

    if walkSpeedEnabled then
        setupWalkSpeed()
    else
        clearWalkSpeedConnections()
        applyWalkSpeed()
    end
end

do
    safeUI("Movement section", function()
        Tabs.Movement:AddSection("Movement")
    end)

    safeUI("AlwaysSprint", function()
        local AlwaysSprintToggle = Tabs.Movement:AddToggle("AlwaysSprint", {
            Title = "Always Sprint",
            Description = "Keep the built-in Sprint action active",
            Default = false
        })
        AlwaysSprintToggle:OnChanged(function() toggleAlwaysSprint(Options.AlwaysSprint.Value) end)
    end)

    safeUI("AntiFlingRecovery", function()
        local AntiFlingToggle = Tabs.Movement:AddToggle("AntiFlingRecovery", {
            Title = "Anti Fling Recovery",
            Description = "Return to the last stable grounded position after a fling",
            Default = false
        })
        AntiFlingToggle:OnChanged(function() toggleAntiFling(Options.AntiFlingRecovery.Value) end)
    end)

    safeUI("AntiFlingThreshold", function()
        Tabs.Movement:AddSlider("AntiFlingThreshold", {
            Title = "Fling Threshold",
            Description = "Velocity that triggers recovery",
            Default = 180,
            Min = 80,
            Max = 400,
            Rounding = 0,
            Callback = function(value) antiFlingThreshold = value end
        })
    end)
    
    safeUI("NoclipToggle", function()
        local NoclipToggle = Tabs.Movement:AddToggle("NoclipToggle", {
            Title = "Noclip", 
            Description = "Walk through walls",
            Default = false
        })
        
        NoclipToggle:OnChanged(function()
            toggleNoclip(Options.NoclipToggle.Value)
        end)
    end)
    
    safeUI("JumpPowerToggle", function()
        local JumpPowerToggle = Tabs.Movement:AddToggle("JumpPowerToggle", {
            Title = "Jump Power", 
            Description = "Modify jump height",
            Default = false
        })
        
        JumpPowerToggle:OnChanged(function()
            toggleJumpPower(Options.JumpPowerToggle.Value)
        end)
    end)
    
    safeUI("JumpPowerValue", function()
        local JumpPowerSlider = Tabs.Movement:AddSlider("JumpPowerValue", {
            Title = "Jump Height", 
            Description = "Adjust jump power (0-500)",
            Default = 50,
            Min = 0,
            Max = 500,
            Rounding = 0,
            Callback = function(value)
                setJumpPower(value)
            end
        })
    end)
    
    safeUI("WalkSpeedToggle", function()
        local WalkSpeedToggle = Tabs.Movement:AddToggle("WalkSpeedToggle", {
            Title = "Walk Speed", 
            Description = "Modify movement speed",
            Default = false
        })
        
        WalkSpeedToggle:OnChanged(function()
            toggleWalkSpeed(Options.WalkSpeedToggle.Value)
        end)
    end)
    
    safeUI("WalkSpeedValue", function()
        local WalkSpeedSlider = Tabs.Movement:AddSlider("WalkSpeedValue", {
            Title = "Speed Value", 
            Description = "Adjust walk speed (0-1000)",
            Default = 50,
            Min = 0,
            Max = 1000,
            Rounding = 0,
            Callback = function(value)
                setWalkSpeed(value)
            end
        })
    end)
end

TrackRuntimeCleanup(function()
    toggleAlwaysSprint(false)
    toggleAntiFling(false)
    toggleJumpPower(false)
    toggleWalkSpeed(false)
    toggleNoclip(false)
end)
