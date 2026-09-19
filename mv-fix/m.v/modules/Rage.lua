local stormFogRemoverEnabled = false
local stormFogRemoverConnection = nil

local function safelyRemoveStormFog(fogPart)
    if fogPart and fogPart:IsA("Part") and fogPart.Name == "Storm_Fog" then
        task.spawn(function()
            pcall(function()
                fogPart.Transparency = 1
                fogPart.CanCollide = false
                fogPart.Anchored = true

                for _, child in ipairs(fogPart:GetChildren()) do
                    if child:IsA("ParticleEmitter") then
                        child.Enabled = false
                        child.Rate = 0
                    elseif child:IsA("Sound") then
                        child:Stop()
                        child.Playing = false
                    elseif child:IsA("Fire") or child:IsA("Smoke") then
                        child.Enabled = false
                    elseif child:IsA("Decal") then
                        child.Transparency = 1
                    elseif child:IsA("SpecialMesh") or child:IsA("MeshPart") then
                        child.Visible = false
                    elseif child:IsA("SurfaceGui") or child:IsA("BillboardGui") then
                        child.Enabled = false
                    elseif child:IsA("Light") then
                        child.Enabled = false
                    end

                    if child:IsA("BasePart") then
                        child.Transparency = 1
                        child.CanCollide = false
                    end
                end

                fogPart.CFrame = CFrame.new(0, -10000, 0)
            end)
        end)
    end
end

local function startStormFogRemover()
    if stormFogRemoverConnection then
        stormFogRemoverConnection:Disconnect()
        stormFogRemoverConnection = nil
    end

    task.spawn(function()
        local descendants = workspace:GetDescendants()
        local processedCount = 0
        for i, descendant in ipairs(descendants) do
            if not stormFogRemoverEnabled then break end

            if descendant:IsA("Part") and descendant.Name == "Storm_Fog" then
                safelyRemoveStormFog(descendant)
                processedCount = processedCount + 1
            end

            if i % 1000 == 0 then task.wait() end
        end

        if processedCount > 0 then
            print("[Storm_Fog Remover] Processed " .. processedCount .. " objects")
        end
    end)
    stormFogRemoverConnection = workspace.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("Part") and descendant.Name == "Storm_Fog" then
            safelyRemoveStormFog(descendant)
        end
    end)
end

local function stopStormFogRemover()
    if stormFogRemoverConnection then
        stormFogRemoverConnection:Disconnect()
        stormFogRemoverConnection = nil
    end
end

local function toggleStormFogRemover(value)
    stormFogRemoverEnabled = value

    if stormFogRemoverEnabled then
        startStormFogRemover()
    else
        stopStormFogRemover()
    end
end

local flightSpeedEnabled = false
local flightSpeed = 300
local originalFlightSpeed = nil
local originalDampening = nil
local flightSpeedConnections = {}

local function applyFlightSpeed()
    local Player = game:GetService("Players").LocalPlayer
    local Character = Player.Character
    if not Character then
        return
    end

    if flightSpeedEnabled then

        if not originalFlightSpeed then
            originalFlightSpeed = Character:GetAttribute("FlightSpeed") or 1
        end
        if not originalDampening then
            originalDampening = Character:GetAttribute("Dampening") or 1.3
        end

        Character:SetAttribute("FlightSpeed", flightSpeed)
        Character:SetAttribute("Dampening", 1.3)
        Character:SetAttribute("FlightTiltMultiplier", 1)
    else

        if originalFlightSpeed then
            Character:SetAttribute("FlightSpeed", originalFlightSpeed)
        end
        if originalDampening then
            Character:SetAttribute("Dampening", originalDampening)
        end
    end
end

local function clearFlightConnections()
    for _, conn in pairs(flightSpeedConnections) do
        if conn then conn:Disconnect() end
    end
    flightSpeedConnections = {}
end

local function setupFlightSpeed()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")

    local Player = Players.LocalPlayer

    clearFlightConnections()

    local charAdded = Player.CharacterAdded:Connect(function(Character)
        task.wait(1)

        local flightAttrConnection = Character:GetAttributeChangedSignal("FlightSpeed"):Connect(function()
            if flightSpeedEnabled then
                local Current = Character:GetAttribute("FlightSpeed") or 0
                if Current ~= flightSpeed then
                    Character:SetAttribute("FlightSpeed", flightSpeed)
                end
            end
        end)
        table.insert(flightSpeedConnections, flightAttrConnection)

        local dampeningAttrConnection = Character:GetAttributeChangedSignal("Dampening"):Connect(function()
            if flightSpeedEnabled then
                local Current = Character:GetAttribute("Dampening") or 0
                if Current ~= 1.3 then
                    Character:SetAttribute("Dampening", 1.3)
                end
            end
        end)
        table.insert(flightSpeedConnections, dampeningAttrConnection)

        local applyingForceConnection = Character:GetAttributeChangedSignal("ApplyingFlightForce"):Connect(function()
            if flightSpeedEnabled then
                local IsFlying = Character:GetAttribute("ApplyingFlightForce")
                if IsFlying then
                    applyFlightSpeed()
                end
            end
        end)
        table.insert(flightSpeedConnections, applyingForceConnection)

        applyFlightSpeed()
    end)
    table.insert(flightSpeedConnections, charAdded)

    local hb = RunService.Heartbeat:Connect(function()
        if Player.Character then
            applyFlightSpeed()
        end
    end)
    table.insert(flightSpeedConnections, hb)

    if Player.Character then
        applyFlightSpeed()
    end
end

local function setFlightSpeed(value)
    flightSpeed = value
    applyFlightSpeed()
end

local function toggleFlightSpeed(value)
    flightSpeedEnabled = value

    if flightSpeedEnabled then
        setupFlightSpeed()
    else
        clearFlightConnections()
        applyFlightSpeed()
    end
end

local silentAimEnabled = false
local silentAimMaxDistance = 500
local silentAimAimPart = "Head"
local silentAimTargetName = "Nearest"
local silentAimIgnoreFriends = false
local silentAimPredictionEnabled = true
local silentAimPredictionTime = 0.08
local silentAimPredictionMaxOffset = 45
local silentAimCachedPing = 0
local silentAimPingUpdatedAt = 0
local silentAimFriendCache = {}
local originalGetAimPosition = nil
local silentAimConnection = nil
local silentAimModule = nil
local silentAimHookTarget = nil
local silentAimWrapper = nil
local silentAimHookMode = nil
local silentAimLastHookAttempt = 0

local function getSilentAimPosition(targetPart)
    local position = targetPart.Position
    if not silentAimPredictionEnabled then
        return position
    end

    local character = targetPart:FindFirstAncestorOfClass("Model")
    local velocityPart = character and (
        character:FindFirstChild("HumanoidRootPart")
        or character.PrimaryPart
    ) or targetPart
    if not velocityPart or not velocityPart:IsA("BasePart") then
        return position
    end

    local velocity = velocityPart.AssemblyLinearVelocity
    if velocity.Magnitude < 1 then
        return position
    end
    if velocity.Magnitude > 200 then
        velocity = velocity.Unit * 200
    end

    local now = os.clock()
    if now - silentAimPingUpdatedAt >= 0.5 then
        silentAimPingUpdatedAt = now
        pcall(function()
            silentAimCachedPing = game:GetService("Players").LocalPlayer:GetNetworkPing()
        end)
    end
    local offset = velocity * math.clamp(silentAimPredictionTime + silentAimCachedPing, 0, 0.5)
    if offset.Magnitude > silentAimPredictionMaxOffset then
        offset = offset.Unit * silentAimPredictionMaxOffset
    end
    return position + offset
end

local function getNearestEnemy()
    local Players = game:GetService("Players")
    local CollectionService = game:GetService("CollectionService")

    local LocalPlayer = Players.LocalPlayer
    local NearestEnemy = nil
    local ShortestDistance = silentAimMaxDistance

    local MyCharacter = LocalPlayer.Character
    local MyRoot = MyCharacter and (
        MyCharacter:FindFirstChild("HumanoidRootPart")
        or MyCharacter.PrimaryPart
        or MyCharacter:FindFirstChild("UpperTorso")
        or MyCharacter:FindFirstChild("Torso")
    )
    if not MyRoot or not MyRoot:IsA("BasePart") then
        return nil
    end

    local MyPosition = MyRoot.Position

    if silentAimTargetName and silentAimTargetName ~= "Nearest" then
        local targetPlayer = Players:FindFirstChild(silentAimTargetName)
        local targetCharacter = targetPlayer and targetPlayer.Character
        if targetCharacter then
            if silentAimIgnoreFriends and silentAimFriendCache[targetPlayer] then
                return nil
            end
            local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
            if targetHumanoid and targetHumanoid.Health > 0 then
                local targetPart = targetCharacter:FindFirstChild(silentAimAimPart)
                    or targetCharacter:FindFirstChild("HumanoidRootPart")
                    or targetCharacter.PrimaryPart
                    or targetCharacter:FindFirstChild("UpperTorso")
                    or targetCharacter:FindFirstChild("Torso")
                if targetPart and targetPart:IsA("BasePart")
                    and (targetPart.Position - MyPosition).Magnitude <= silentAimMaxDistance then
                    return targetPart
                end
            end
        end
        return nil
    end

    local Characters = {}
    local SeenCharacters = {}

    local function addCharacter(Character)
        if typeof(Character) == "Instance"
            and Character:IsA("Model")
            and Character ~= MyCharacter
            and not SeenCharacters[Character] then
            SeenCharacters[Character] = true
            Characters[#Characters + 1] = Character
        end
    end

    for _, Character in ipairs(CollectionService:GetTagged("Character")) do
        addCharacter(Character)
    end

    for _, OtherPlayer in ipairs(Players:GetPlayers()) do
        if OtherPlayer ~= LocalPlayer then
            addCharacter(OtherPlayer.Character)
        end
    end

    for _, Character in ipairs(Characters) do
        if silentAimIgnoreFriends then
            local characterPlayer = Players:GetPlayerFromCharacter(Character)
            if characterPlayer and silentAimFriendCache[characterPlayer] then
                continue
            end
        end
        local Humanoid = Character:FindFirstChildOfClass("Humanoid")
        if Humanoid and Humanoid.Health > 0 then
            local TargetPart = Character:FindFirstChild(silentAimAimPart)
                or Character:FindFirstChild("HumanoidRootPart")
                or Character.PrimaryPart
                or Character:FindFirstChild("UpperTorso")
                or Character:FindFirstChild("Torso")
            if TargetPart and TargetPart:IsA("BasePart") then
                local Distance = (TargetPart.Position - MyPosition).Magnitude
                if Distance <= ShortestDistance then
                    ShortestDistance = Distance
                    NearestEnemy = TargetPart
                end
            end
        end
    end

    return NearestEnemy
end

local targetLockEnabled = false
local targetLockMaxDistance = 800
local targetLockPart
local targetModule
local aimAssistEnabled = false
local aimAssistStrength = 0.2
local aimAssistConnection

local function resolveTargetPart(target)
    if typeof(target) ~= "Instance" then return nil end
    local model = target:IsA("Model") and target or target:FindFirstAncestorOfClass("Model")
    if not model then return target:IsA("BasePart") and target or nil end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health <= 0 then return nil end
    return model:FindFirstChild(silentAimAimPart)
        or model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
        or model:FindFirstChild("UpperTorso")
        or model:FindFirstChild("Torso")
end

local function targetIsValid(part)
    local character = Player.Character
    local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
    local targetPart = resolveTargetPart(part)
    return root and targetPart and targetPart:IsDescendantOf(workspace)
        and (targetPart.Position - root.Position).Magnitude <= targetLockMaxDistance
end

local function acquireTargetLock()
    targetModule = targetModule or getGameModule("Target")
    if targetModule and type(targetModule.GetTarget) == "function" then
        local ok, target = pcall(targetModule.GetTarget, targetLockMaxDistance, 5)
        local part = ok and resolveTargetPart(target)
        if targetIsValid(part) then
            targetLockPart = part
            return part
        end
    end
    local fallback = getNearestEnemy()
    targetLockPart = targetIsValid(fallback) and fallback or nil
    return targetLockPart
end

local function getCombatTargetPart()
    if not targetLockEnabled then return getNearestEnemy() end
    if not targetIsValid(targetLockPart) then
        return acquireTargetLock()
    end
    targetLockPart = resolveTargetPart(targetLockPart)
    return targetLockPart
end

local function toggleTargetLock(value)
    targetLockEnabled = value
    targetLockPart = value and acquireTargetLock() or nil
end

local function toggleAimAssist(value)
    aimAssistEnabled = value
    if aimAssistConnection then aimAssistConnection:Disconnect() aimAssistConnection = nil end
    if not value then return end
    aimAssistConnection = game:GetService("RunService").RenderStepped:Connect(function()
        local camera = workspace.CurrentCamera
        local target = camera and getCombatTargetPart()
        if not camera or not target then return end
        local aimPosition = getSilentAimPosition(target)
        local direction = aimPosition - camera.CFrame.Position
        if direction.Magnitude > 0.01 then
            camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(camera.CFrame.Position, aimPosition), aimAssistStrength)
        end
    end)
end

local function getAimModule()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Modules = ReplicatedStorage:FindFirstChild("Modules")
    local AimScript = Modules and Modules:FindFirstChild("Aim")
        or ReplicatedStorage:FindFirstChild("Aim", true)
    if not AimScript or not AimScript:IsA("ModuleScript") then
        return nil
    end

    local Success, Aim = pcall(require, AimScript)
    if Success and type(Aim) == "table" and type(Aim.GetAimPosition) == "function" then
        return Aim
    end
    return nil
end

local function restoreSilentAimHook()
    if silentAimHookMode == "function"
        and type(hookfunction) == "function"
        and type(silentAimHookTarget) == "function"
        and type(originalGetAimPosition) == "function" then
        pcall(hookfunction, silentAimHookTarget, originalGetAimPosition)
    elseif silentAimHookMode == "table"
        and silentAimModule
        and silentAimModule.GetAimPosition == silentAimWrapper
        and type(originalGetAimPosition) == "function" then
        pcall(function()
            silentAimModule.GetAimPosition = originalGetAimPosition
        end)
    end

    silentAimModule = nil
    silentAimHookTarget = nil
    silentAimWrapper = nil
    silentAimHookMode = nil
    originalGetAimPosition = nil
end

local function installSilentAimHook()
    if silentAimHookMode then return true end

    local Aim = getAimModule()
    if not Aim then return false end

    local TargetFunction = Aim.GetAimPosition
    if type(TargetFunction) ~= "function" then return false end

    local OriginalFunction = nil
    local Wrapper = function(...)
        if silentAimEnabled then
            local NearestEnemy = getCombatTargetPart()
            if NearestEnemy then
                return getSilentAimPosition(NearestEnemy)
            end
        end

        if OriginalFunction then
            return OriginalFunction(...)
        end
    end

    if type(hookfunction) == "function" then
        local Success, Original = pcall(hookfunction, TargetFunction, Wrapper)
        if Success and type(Original) == "function" then
            OriginalFunction = Original
            originalGetAimPosition = Original
            silentAimModule = Aim
            silentAimHookTarget = TargetFunction
            silentAimWrapper = Wrapper
            silentAimHookMode = "function"
            return true
        end
    end

    OriginalFunction = TargetFunction
    local Success = pcall(function()
        Aim.GetAimPosition = Wrapper
    end)
    if not Success or Aim.GetAimPosition ~= Wrapper then
        return false
    end

    originalGetAimPosition = TargetFunction
    silentAimModule = Aim
    silentAimHookTarget = TargetFunction
    silentAimWrapper = Wrapper
    silentAimHookMode = "table"
    return true
end

local function enableSilentAim()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LocalPlayer = Players.LocalPlayer

    installSilentAimHook()

    task.spawn(function()
        while silentAimEnabled do
            if silentAimIgnoreFriends then
                for _, otherPlayer in ipairs(Players:GetPlayers()) do
                    if otherPlayer ~= LocalPlayer then
                        local ok, isFriend = pcall(function()
                            return LocalPlayer:IsFriendsWith(otherPlayer.UserId)
                        end)
                        if ok then
                            silentAimFriendCache[otherPlayer] = isFriend
                        end
                    end
                end
            else
                silentAimFriendCache = {}
            end
            task.wait(5)
        end
    end)

    if silentAimConnection then silentAimConnection:Disconnect() end
    silentAimConnection = RunService.RenderStepped:Connect(function()
        if not silentAimEnabled or not LocalPlayer.Character then
            return
        end

        if not silentAimHookMode and os.clock() - silentAimLastHookAttempt >= 1 then
            silentAimLastHookAttempt = os.clock()
            installSilentAimHook()
        end

        local NearestEnemy = getCombatTargetPart()
        if NearestEnemy then
            local Character = LocalPlayer.Character
            local Camera = workspace.CurrentCamera
            local aimPosition = getSilentAimPosition(NearestEnemy)
            Character:SetAttribute("AimPosition", aimPosition)
            if Camera then
                local Direction = aimPosition - Camera.CFrame.Position
                if Direction.Magnitude > 0.001 then
                    Character:SetAttribute("LookDirection", Direction.Unit)
                end
            end
        end
    end)
end

local function disableSilentAim()
    if silentAimConnection then
        silentAimConnection:Disconnect()
        silentAimConnection = nil
    end
    restoreSilentAimHook()
end

local function toggleSilentAim(value)
    silentAimEnabled = value

    if silentAimEnabled then
        enableSilentAim()
    else
        disableSilentAim()
    end
end

local function setSilentAimDistance(value)
    silentAimMaxDistance = value
end

local function setSilentAimPredictionTime(value)
    silentAimPredictionTime = math.clamp((tonumber(value) or 80) / 1000, 0, 0.5)
end

TrackRuntimeCleanup(function() toggleStormFogRemover(false) end)
TrackRuntimeCleanup(function() toggleFlightSpeed(false) end)
TrackRuntimeCleanup(function() toggleSilentAim(false) end)
TrackRuntimeCleanup(function() toggleTargetLock(false) end)
TrackRuntimeCleanup(function() toggleAimAssist(false) end)

do
    Tabs.Rage:AddSection("Rage")

    local StormFogToggle = Tabs.Rage:AddToggle("StormFogToggle", {
        Title = "No Fog (Storm)",
        Description = "Remove storm fog effects",
        Default = false
    })

    StormFogToggle:OnChanged(function()
        toggleStormFogRemover(Options.StormFogToggle.Value)
    end)

    local FlightSpeedToggle = Tabs.Rage:AddToggle("FlightSpeedToggle", {
        Title = "Flight Speed",
        Description = "Modify flight speed",
        Default = false
    })

    FlightSpeedToggle:OnChanged(function()
        toggleFlightSpeed(Options.FlightSpeedToggle.Value)
    end)

    local FlightSpeedSlider = Tabs.Rage:AddSlider("FlightSpeedValue", {
        Title = "Flight Speed",
        Description = "Adjust flight speed (1-300)",
        Default = 300,
        Min = 1,
        Max = 300,
        Rounding = 0,
        Callback = function(value)
            setFlightSpeed(value)
        end
    })

    local SilentAimToggle = Tabs.Rage:AddToggle("SilentAimToggle", {
        Title = "Silent Aim",
        Description = "Enable silent aim",
        Default = false
    })

    SilentAimToggle:OnChanged(function()
        toggleSilentAim(Options.SilentAimToggle.Value)
    end)

    local SilentAimDistanceSlider = Tabs.Rage:AddSlider("SilentAimDistance", {
        Title = "Aim Distance",
        Description = "Adjust silent aim distance (100-1200)",
        Default = 500,
        Min = 100,
        Max = 1200,
        Rounding = 0,
        Callback = function(value)
            setSilentAimDistance(value)
        end
    })

    local SilentAimPredictionToggle = Tabs.Rage:AddToggle("SilentAimPrediction", {
        Title = "Target Prediction",
        Description = "Lead moving targets using their velocity and current ping",
        Default = true
    })
    SilentAimPredictionToggle:OnChanged(function()
        silentAimPredictionEnabled = Options.SilentAimPrediction.Value
    end)

    local SilentAimPredictionSlider = Tabs.Rage:AddSlider("SilentAimPredictionTime", {
        Title = "Prediction Time",
        Description = "Additional lead time in milliseconds",
        Default = 80,
        Min = 0,
        Max = 500,
        Rounding = 0,
        Callback = function(value)
            setSilentAimPredictionTime(value)
        end
    })

    local function getSilentAimTargetValues()
        local values = {"Nearest"}
        for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
            if plr ~= Player then
                table.insert(values, plr.Name)
            end
        end
        return values
    end

    local SilentAimTargetDropdown = Tabs.Rage:AddDropdown("SilentAimTarget", {
        Title = "Silent Aim Target",
        Description = "Target a specific player or the nearest enemy",
        Values = getSilentAimTargetValues(),
        Multi = false,
        Default = "Nearest"
    })
    SilentAimTargetDropdown:OnChanged(function(value)
        silentAimTargetName = value
    end)

    local SilentAimIgnoreFriendsToggle = Tabs.Rage:AddToggle("SilentAimIgnoreFriends", {
        Title = "Ignore Friends",
        Description = "Silent Aim will not target players from your friends list",
        Default = false
    })
    SilentAimIgnoreFriendsToggle:OnChanged(function()
        silentAimIgnoreFriends = Options.SilentAimIgnoreFriends.Value
    end)

    Tabs.Rage:AddSection("Targeting")
    local TargetLockToggle = Tabs.Rage:AddToggle("TargetLock", {
        Title = "Target Lock",
        Description = "Lock the target selected by the game's Target module",
        Default = false
    })
    TargetLockToggle:OnChanged(function()
        toggleTargetLock(Options.TargetLock.Value)
    end)
    Tabs.Rage:AddSlider("TargetLockDistance", {
        Title = "Lock Distance",
        Description = "Maximum target-lock distance",
        Default = 800,
        Min = 100,
        Max = 2000,
        Rounding = 0,
        Callback = function(value) targetLockMaxDistance = value end
    })
    local AimAssistToggle = Tabs.Rage:AddToggle("AimAssist", {
        Title = "Aim Assist",
        Description = "Smoothly guide the camera toward the combat target",
        Default = false
    })
    AimAssistToggle:OnChanged(function()
        toggleAimAssist(Options.AimAssist.Value)
    end)
    Tabs.Rage:AddSlider("AimAssistStrength", {
        Title = "Aim Assist Strength",
        Description = "Camera correction strength",
        Default = 18,
        Min = 1,
        Max = 100,
        Rounding = 0,
        Callback = function(value) aimAssistStrength = math.clamp(value / 100, 0.01, 1) end
    })

    local PlayersService = game:GetService("Players")

    TrackRuntimeConnection(PlayersService.PlayerAdded:Connect(function()
        task.defer(function()
            SilentAimTargetDropdown:SetValues(getSilentAimTargetValues())
        end)
    end))

    TrackRuntimeConnection(PlayersService.PlayerRemoving:Connect(function(leavingPlayer)
        task.defer(function()
            SilentAimTargetDropdown:SetValues(getSilentAimTargetValues())
            if silentAimTargetName ~= "Nearest" and leavingPlayer.Name == silentAimTargetName then
                SilentAimTargetDropdown:SetValue("Nearest")
            end
        end)
    end))

end
