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

local aimSettings = PrimeRuntime.SilentAimSettings
local stoneCache = setmetatable({}, {__mode = "k"})
local activeAbilitySlots, abilityFilterConnections = {}, {}
local targetedAimEnabled = false
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
local silentAimGeneration = 0
local function ignoredCharacter(character)
    local owner = game:GetService("Players"):GetPlayerFromCharacter(character)
    return owner and (aimSettings.Ignored[owner.Name] == true
        or silentAimIgnoreFriends and silentAimFriendCache and silentAimFriendCache[owner]) or false
end
local function clearAbilityFilters()
    for _, connection in ipairs(abilityFilterConnections) do pcall(connection.Disconnect, connection) end
    table.clear(abilityFilterConnections)
    table.clear(activeAbilitySlots)
end
local function bindAbilityFilters()
    if #abilityFilterConnections > 0 then return end
    local dependencies = game:GetService("ReplicatedStorage"):FindFirstChild("Dependencies")
    local module = dependencies and dependencies:FindFirstChild("Event")
    if not module then return end
    local ok, bus = PrimeRuntime.Protect(require, module)
    if not ok or type(bus) ~= "table" or type(bus.Connect) ~= "function" then return end
    for index = 1, 5 do
        local slot = "Ability" .. index
        for _, active in ipairs({true, false}) do
            local suffix = active and "Activated" or "Deactivated"
            local success, connection = pcall(bus.Connect, bus, slot .. suffix, function()
                activeAbilitySlots[slot] = active or nil
            end)
            if success and connection then abilityFilterConnections[#abilityFilterConnections + 1] = connection end
        end
    end
end
local function abilityFromValues(values)
    if type(values) ~= "table" then return nil end
    for _, value in pairs(values) do
        if type(value) == "table" and rawget(value, "Character") == Player.Character then
            local slot = rawget(value, "AbilityNumber")
            if type(slot) == "number" then slot = "Ability" .. slot end
            if type(slot) == "string" and slot:match("^Ability[1-5]$") then return slot end
        end
    end
end
local function ignoreCurrentAbility()
    if not next(aimSettings.IgnoredAbilities) then return false end
    if debug and type(debug.info) == "function" then
        for level = 2, 9 do
            if type(debug.getstack) == "function" then
                local ok, values = pcall(debug.getstack, level)
                local slot = ok and abilityFromValues(values)
                if slot then return aimSettings.IgnoredAbilities[slot] == true end
            end
            if type(debug.getupvalues) == "function" then
                local ok, callback = pcall(debug.info, level, "f")
                if ok and type(callback) == "function" then
                    local read, values = pcall(debug.getupvalues, callback)
                    local slot = read and abilityFromValues(values)
                    if slot then return aimSettings.IgnoredAbilities[slot] == true end
                end
            end
        end
    end
    for slot in pairs(activeAbilitySlots) do
        if aimSettings.IgnoredAbilities[slot] then return true end
    end
    return false
end
local function hasStone(character)
    local now, cached = os.clock(), stoneCache[character]
    if cached and now - cached.Time < 0.30 then return cached.Value end
    local found = false
    if type(PrimeRuntime.CharacterHasStone) == "function" then found = PrimeRuntime.CharacterHasStone(character) end
    stoneCache[character] = {Time = now, Value = found == true}
    return found == true
end

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

local function targetedEligible(model, range)
    if typeof(model) ~= "Instance" or not model:IsA("Model") then return false end
    local character = Player.Character
    if not character or model == character or not model:IsDescendantOf(workspace) then return false end
    local invisible = model:GetAttribute("Invisible")
    if model:HasTag("Invisible") or model:HasTag("AimIgnore") or model:HasTag("LocalDriverAimIgnore")
        or invisible == true or type(invisible) == "number" and invisible > 0 then return false end
    return model:HasTag("Damageable") and (model:GetPivot().Position - character:GetPivot().Position).Magnitude <= range
end

local function getNearestEnemy(maxRange, targeted)
    local players = game:GetService("Players")
    local character = Player.Character
    local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
    if not root or not root:IsA("BasePart") then return nil end
    local seen, candidates = {}, {}
    local function add(model)
        if typeof(model) ~= "Instance" or not model:IsA("Model") or model == character or seen[model] then return end
        seen[model] = true
        if targeted and not targetedEligible(model, maxRange) then return end
        local owner = players:GetPlayerFromCharacter(model)
        if owner and aimSettings.Ignored[owner.Name] then return end
        if owner and silentAimIgnoreFriends and silentAimFriendCache[owner] then return end
        if silentAimTargetName ~= "Nearest" and (not owner or owner.Name ~= silentAimTargetName) then return end
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        local part = model:FindFirstChild(silentAimAimPart) or model:FindFirstChild("HumanoidRootPart")
            or model.PrimaryPart or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
        if not humanoid or humanoid.Health <= 0 or not part or not part:IsA("BasePart") then return end
        local distance = (part.Position - root.Position).Magnitude
        if distance > math.min(silentAimMaxDistance, maxRange or silentAimMaxDistance) then return end
        candidates[#candidates + 1] = {Part = part, Character = model, Owner = owner, Distance = distance,
            Health = humanoid.Health, Preferred = owner and aimSettings.Preferred[owner.Name] and 0 or 1}
    end
    for _, model in ipairs(game:GetService("CollectionService"):GetTagged(targeted and "Damageable" or "Character")) do add(model) end
    for _, other in ipairs(players:GetPlayers()) do if other ~= Player then add(other.Character) end end
    local mode = aimSettings.Priority
    if mode == "Stone Holders" or mode == "Stones + Low Health" or mode == "Low Health + Stones" then
        for _, candidate in ipairs(candidates) do candidate.Stone = candidate.Owner and hasStone(candidate.Character) and 0 or 1 end
    end
    table.sort(candidates, function(a, b)
        if a.Preferred ~= b.Preferred then return a.Preferred < b.Preferred end
        if mode == "Low Health + Stones" or mode == "Lowest Health" then
            if a.Health ~= b.Health then return a.Health < b.Health end
        end
        if a.Stone and a.Stone ~= b.Stone then return a.Stone < b.Stone end
        if mode == "Stones + Low Health" and a.Health ~= b.Health then return a.Health < b.Health end
        if a.Distance ~= b.Distance then return a.Distance < b.Distance end
        return (a.Owner and a.Owner.Name or a.Character.Name) < (b.Owner and b.Owner.Name or b.Character.Name)
    end)
    return candidates[1] and candidates[1].Part or nil
end

local targetLockEnabled = false
local targetLockMaxDistance = 800
local targetLockPart
PrimeRuntime.ResetCombatTarget = function() targetLockPart = nil end
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
    return root and targetPart and not ignoredCharacter(targetPart:FindFirstAncestorOfClass("Model")) and targetPart:IsDescendantOf(workspace)
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
    if PrimeRuntime.GetBossFarmTarget then
        local _, root = PrimeRuntime.GetBossFarmTarget()
        if root then return root end
        if PrimeRuntime.BossFarm and PrimeRuntime.BossFarm.Enabled then return nil end
    end
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

    local Success, Aim = PrimeRuntime.Protect(require, AimScript)
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
    if PrimeRuntime.BossFarm and PrimeRuntime.BossFarm.Enabled then return true end
    if silentAimHookMode then return true end

    local Aim = getAimModule()
    if not Aim then return false end

    local TargetFunction = Aim.GetAimPosition
    if type(TargetFunction) ~= "function" then return false end

    local OriginalFunction = nil
    local Wrapper = function(...)
        if silentAimEnabled and not ignoreCurrentAbility() then
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

local targetedHooks = {}
local targetedBusy = false
local targetedConnection
local targetedGeneration = 0
local targetedRange, targetedExtraRange = 100, 0
local function restoreTargetedHooks()
    for _, hook in ipairs(targetedHooks) do
        if hook.Registry[hook.Name] == hook.Wrapper then hook.Registry[hook.Name] = hook.Original end
    end
    table.clear(targetedHooks)
end
local function installTargetedHooks()
    if not targetedAimEnabled or PrimeRuntime.IsShuttingDown
        or PrimeRuntime.BossFarm and PrimeRuntime.BossFarm.Enabled then return end
    targetModule = targetModule or getGameModule("Target")
    local system = shared and shared.System
    local registries = {targetModule, system and system.StoredFunctions}
    for _, registry in pairs(registries) do
        if type(registry) == "table" then
            for _, name in ipairs({"GetTarget", "SetTargetingRange", "AddTargetDistance"}) do
                local exists = false
                for _, hook in ipairs(targetedHooks) do
                    if hook.Registry == registry and hook.Name == name then exists = true break end
                end
                local original = registry[name]
                if not exists and type(original) == "function" then
                    local wrapper
                    if name == "GetTarget" then
                        wrapper = function(range, ...)
                            if not targetedAimEnabled or targetedBusy or PrimeRuntime.IsShuttingDown
                                or PrimeRuntime.BossFarm and PrimeRuntime.BossFarm.Enabled then
                                return original(range, ...)
                            end
                            if ignoreCurrentAbility() then return original(range, ...) end
                            range = type(range) == "number" and range or targetedRange + targetedExtraRange
                            if range ~= range or range <= 0 then return nil end
                            range = math.min(range, silentAimMaxDistance)
                            targetedBusy = true
                            local ok, part = PrimeRuntime.Protect(getCombatTargetPart)
                            targetedBusy = false
                            if not ok then return original(range, ...) end
                            local model = part and part:FindFirstAncestorOfClass("Model")
                            if model and targetedEligible(model, range) and not ignoredCharacter(model) then return model end
                            part = getNearestEnemy(range, true)
                            return part and part:FindFirstAncestorOfClass("Model") or nil
                        end
                    elseif name == "SetTargetingRange" then
                        wrapper = function(range, ...)
                            if type(range) == "number" then targetedRange = range
                            elseif not range then targetedExtraRange = 0 end
                            return original(range, ...)
                        end
                    else
                        wrapper = function(distance, ...)
                            if type(distance) == "number" then targetedExtraRange = targetedExtraRange + distance end
                            return original(distance, ...)
                        end
                    end
                    registry[name] = wrapper
                    targetedHooks[#targetedHooks + 1] = {Registry = registry, Name = name, Original = original, Wrapper = wrapper}
                end
            end
        end
    end
end
local function toggleTargetedAim(enabled)
    targetedGeneration = targetedGeneration + 1
    local generation = targetedGeneration
    targetedAimEnabled = enabled == true
    if targetedConnection then targetedConnection:Disconnect() targetedConnection = nil end
    if not targetedAimEnabled then
        restoreTargetedHooks()
        if not silentAimEnabled then clearAbilityFilters() end
        return
    end
    bindAbilityFilters()
    installTargetedHooks()
    local elapsed = 0
    targetedConnection = game:GetService("RunService").Heartbeat:Connect(function(delta)
        elapsed = elapsed + delta
        if elapsed < 1 then return end
        elapsed = 0
        installTargetedHooks()
    end)
    task.spawn(function()
        while targetedAimEnabled and generation == targetedGeneration and not PrimeRuntime.IsShuttingDown do
            if silentAimIgnoreFriends and not silentAimEnabled then
                for _, other in ipairs(game:GetService("Players"):GetPlayers()) do
                    if other ~= Player then
                        local ok, friend = pcall(Player.IsFriendsWith, Player, other.UserId)
                        if ok then silentAimFriendCache[other] = friend end
                    end
                end
            end
            task.wait(5)
        end
    end)
end

PrimeRuntime.SetBossFarmAim = function(enabled)
    if enabled then
        restoreTargetedHooks()
        restoreSilentAimHook()
    elseif silentAimEnabled and not PrimeRuntime.IsShuttingDown then
        installSilentAimHook()
    end
    if not enabled then installTargetedHooks() end
end

local function enableSilentAim()
    silentAimGeneration = silentAimGeneration + 1
    local generation = silentAimGeneration
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LocalPlayer = Players.LocalPlayer

    bindAbilityFilters()
    installSilentAimHook()

    task.spawn(function()
        while silentAimEnabled and generation == silentAimGeneration do
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

        if ignoreCurrentAbility() then
            if type(originalGetAimPosition) == "function" then
                local ok, position = PrimeRuntime.Protect(originalGetAimPosition)
                local camera = workspace.CurrentCamera
                if ok and typeof(position) == "Vector3" then
                    LocalPlayer.Character:SetAttribute("AimPosition", position)
                    local direction = camera and position - camera.CFrame.Position
                    if direction and direction.Magnitude > 0.001 then LocalPlayer.Character:SetAttribute("LookDirection", direction.Unit) end
                end
            end
            return
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
    silentAimGeneration = silentAimGeneration + 1
    if not targetedAimEnabled then clearAbilityFilters() end
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
    
    Tabs.Main:AddSection("Silent Aim")
    local SilentAimToggle = Tabs.Main:AddToggle("SilentAimToggle", {
        Title = "Silent Aim", 
        Description = "Enable silent aim",
        Default = false
    })
    
    SilentAimToggle:OnChanged(function()
        toggleSilentAim(Options.SilentAimToggle.Value)
    end)
    
    local TargetedAimToggle = Tabs.Main:AddToggle("TargetedAbilityAim", {
        Title = "Targeted Ability Aim",
        Description = "Select ability targets using aim priorities and exclusions. Respects ability range; Boss Farm takes priority.",
        Default = false
    })
    TargetedAimToggle:OnChanged(function()
        toggleTargetedAim(Options.TargetedAbilityAim.Value)
    end)

    local SilentAimDistanceSlider = Tabs.Main:AddSlider("SilentAimDistance", {
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

    local SilentAimPredictionToggle = Tabs.Main:AddToggle("SilentAimPrediction", {
        Title = "Target Prediction",
        Description = "Lead moving targets using their velocity and current ping",
        Default = true
    })
    SilentAimPredictionToggle:OnChanged(function()
        silentAimPredictionEnabled = Options.SilentAimPrediction.Value
    end)

    local SilentAimPredictionSlider = Tabs.Main:AddSlider("SilentAimPredictionTime", {
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

    local SilentAimTargetDropdown = Tabs.Main:AddDropdown("SilentAimTarget", {
        Title = "Silent Aim Target",
        Description = "Target a specific player or the nearest enemy",
        Values = getSilentAimTargetValues(),
        Multi = false,
        Default = "Nearest"
    })
    SilentAimTargetDropdown:OnChanged(function(value)
        silentAimTargetName = value
    end)

    local SilentAimIgnoreFriendsToggle = Tabs.Main:AddToggle("SilentAimIgnoreFriends", {
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

TrackRuntimeCleanup(function()
    toggleStormFogRemover(false)
    toggleFlightSpeed(false)
    toggleTargetedAim(false)
    toggleSilentAim(false)
    toggleTargetLock(false)
    toggleAimAssist(false)
end)

TrackRuntimeConnection(Player.CharacterRemoving:Connect(function()
    table.clear(activeAbilitySlots)
    table.clear(stoneCache)
end))
TrackRuntimeCleanup(clearAbilityFilters)
