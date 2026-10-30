local automaticStoneCollectionEnabled = false
local automaticStoneCollectionConnection = nil
local automaticStoneCollectionProcessed = {}
local automaticStoneCollectionLastRun = 0
local automaticStoneCollectionCooldown = 0.5
local stoneMeshPartNames = {
    TimeStine = true,
    PowerStone = true,
    SpaceStone = true
}

local function activateNearbyPrompts(model)
    if not model then return end
    for _, child in pairs(model:GetDescendants()) do
        if child:IsA("ProximityPrompt") then
            if fireproximityprompt then
                fireproximityprompt(child)
            elseif child.Enabled then
                local oldDuration = child.HoldDuration
                child.HoldDuration = 0
                child:InputHoldBegin()
                task.wait()
                child:InputHoldEnd()
                child.HoldDuration = oldDuration
            end
        end
    end
end

local function handleAutomaticStoneCollection(stonePart)
    if not automaticStoneCollectionEnabled or not stonePart or not stonePart:IsA("MeshPart") then
        return
    end

    if automaticStoneCollectionProcessed[stonePart] then
        return
    end

    local now = os.clock()
    if now - automaticStoneCollectionLastRun < automaticStoneCollectionCooldown then
        return
    end

    automaticStoneCollectionLastRun = now
    automaticStoneCollectionProcessed[stonePart] = true

    task.spawn(function()
        task.wait(5)
        
        if not stonePart or not stonePart.Parent or not stonePart:IsDescendantOf(workspace) then
            automaticStoneCollectionProcessed[stonePart] = nil
            return
        end

        if not automaticStoneCollectionEnabled then
            automaticStoneCollectionProcessed[stonePart] = nil
            return
        end

        local player = game:GetService("Players").LocalPlayer
        local character = player.Character
        local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")

        if humanoidRootPart then
            local targetCFrame = stonePart:GetPivot()
            if targetCFrame then
                humanoidRootPart.CFrame = targetCFrame + Vector3.new(0, 3, 0)
            else
                humanoidRootPart.CFrame = CFrame.new(stonePart.Position + Vector3.new(0, 3, 0))
            end

            task.spawn(function()
                task.wait(0.05)
                if automaticStoneCollectionEnabled then
                    activateNearbyPrompts(stonePart)
                end
            end)
        end

        task.delay(1, function()
            automaticStoneCollectionProcessed[stonePart] = nil
        end)
    end)
end

local function setupAutomaticStoneCollection()
    if automaticStoneCollectionConnection then
        automaticStoneCollectionConnection:Disconnect()
        automaticStoneCollectionConnection = nil
    end

    automaticStoneCollectionProcessed = {}

    automaticStoneCollectionConnection = workspace.DescendantAdded:Connect(function(descendant)
        if not automaticStoneCollectionEnabled then return end
        if descendant:IsA("MeshPart") and stoneMeshPartNames[descendant.Name] then
            handleAutomaticStoneCollection(descendant)
        end
    end)

    task.defer(function()
        if not automaticStoneCollectionEnabled then return end
        local descendants = workspace:GetDescendants()
        for _, descendant in ipairs(descendants) do
            if descendant:IsA("MeshPart") and stoneMeshPartNames[descendant.Name] then
                handleAutomaticStoneCollection(descendant)
            end
        end
    end)
end

local function toggleAutomaticStoneCollection(value)
    if value and Options.BossFarmToggle and Options.BossFarmToggle.Value then
        Options.BossFarmToggle:SetValue(false)
    end
    automaticStoneCollectionEnabled = value

    if automaticStoneCollectionEnabled then
        setupAutomaticStoneCollection()
    else
        if automaticStoneCollectionConnection then
            automaticStoneCollectionConnection:Disconnect()
            automaticStoneCollectionConnection = nil
        end
        automaticStoneCollectionProcessed = {}
    end
end

local function teleportToHealingCircle()
    local player = game:GetService("Players").LocalPlayer
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return
    end

    local interactables = workspace:FindFirstChild("Interactables")
    local healingCircle = interactables and interactables:FindFirstChild("Healing Circle")

    if healingCircle and healingCircle.Parent then
        local success, targetCFrame = pcall(function()
            return healingCircle:GetPivot()
        end)

        if success and targetCFrame then
            character.HumanoidRootPart.CFrame = targetCFrame + Vector3.new(0, 3, 0)
        end
    end
end

local autoCollectEnabled = false
local autoCollectConnection = nil
local teleportedModels = {}
local collectionQueue = {}
local isProcessingQueue = false

local function cleanupDeadReferences()
    for model, _ in pairs(teleportedModels) do
        if not model or not model.Parent then
            teleportedModels[model] = nil
        end
    end
end

local cleanupTask = nil
local function startCleanupTask()
    if cleanupTask then return end
    
    cleanupTask = task.spawn(function()
        while autoCollectEnabled do  
            task.wait(30)
            if autoCollectEnabled then
                cleanupDeadReferences()
            end
        end
        cleanupTask = nil
    end)
end

local function stopCleanupTask()
    if cleanupTask then
        task.cancel(cleanupTask)
        cleanupTask = nil  
    end
end

local function teleportToModel(model)
    local player = game:GetService("Players").LocalPlayer
    local character = player.Character
    if character and character:FindFirstChild("HumanoidRootPart") and model and model:IsDescendantOf(workspace) then
        local targetCFrame = model:GetPivot()
        character.HumanoidRootPart.CFrame = targetCFrame
        teleportedModels[model] = true
        return true
    end
    return false
end

local function activateProximityPrompts(model)
    if not model then return end
    for _, child in pairs(model:GetDescendants()) do
        if child:IsA("ProximityPrompt") then
            child.HoldDuration = 0
            if fireproximityprompt then
                fireproximityprompt(child)
            else
                 if child.Enabled then
                    local oldDuration = child.HoldDuration
                    child.HoldDuration = 0
                    child:InputHoldBegin()
                    task.wait()
                    child:InputHoldEnd()
                    child.HoldDuration = oldDuration
                 end
            end
        end
    end
end

local function waitForPromptActivation(model)
    if not model or not model.Parent or not model:IsDescendantOf(workspace) then
        return false
    end

    for _ = 1, 40 do
        if not autoCollectEnabled then
            return false
        end
        if not model or not model.Parent or not model:IsDescendantOf(workspace) then
            return false
        end
        local foundPrompt = false
        for _, child in pairs(model:GetDescendants()) do
            if child:IsA("ProximityPrompt") then
                foundPrompt = true
                break
            end
        end
        if not foundPrompt then
            return true
        end
        task.wait(0.1)
    end
    return false
end

local function processQueue()
    if isProcessingQueue then return end
    isProcessingQueue = true
    
    task.spawn(function()
        while autoCollectEnabled do
            if #collectionQueue > 0 then
                local model = table.remove(collectionQueue, 1)
                
                if model and model.Parent and model.Name == "" then
                    if teleportToModel(model) then
                        task.wait(0.25)
                        activateProximityPrompts(model)
                        waitForPromptActivation(model)
                    end
                end
            else
                task.wait(0.5)
            end
            
             if not autoCollectEnabled then break end
        end
        isProcessingQueue = false
    end)
end

local function addToQueue(model)
    if not teleportedModels[model] then
        teleportedModels[model] = true 
        table.insert(collectionQueue, model)
    end
end

local function setupAutoCollect()
    if autoCollectConnection then
        autoCollectConnection:Disconnect()
        autoCollectConnection = nil
    end
    
    collectionQueue = {}
    
    autoCollectConnection = workspace.DescendantAdded:Connect(function(descendant)
        if not autoCollectEnabled then return end
        
        if descendant:IsA("Model") and descendant.Name == "" then
            addToQueue(descendant)
        end
    end)
    
    task.spawn(function()
        local descendants = workspace:GetDescendants()
        for i, descendant in ipairs(descendants) do
            if not autoCollectEnabled then break end
            
            if descendant:IsA("Model") and descendant.Name == "" then
                addToQueue(descendant)
            end
            
            if i % 500 == 0 then task.wait() end
        end
    end)
    
    processQueue()
end

local function toggleAutoCollect(value)
    if value and Options.BossFarmToggle and Options.BossFarmToggle.Value then
        Options.BossFarmToggle:SetValue(false)
    end
    autoCollectEnabled = value
    
    if autoCollectEnabled then
        teleportedModels = {}
        setupAutoCollect()
        startCleanupTask()  
    else
        if autoCollectConnection then
            autoCollectConnection:Disconnect()
            autoCollectConnection = nil
        end
        stopCleanupTask()  
        teleportedModels = {}
        collectionQueue = {}
        isProcessingQueue = false
    end
end

local autoFarmEnabled = false
local autoFarmConnection = nil
local autoFarmCharacterConnection = nil
local autoFarmQueue = {}
local autoFarmProcessed = setmetatable({}, {__mode = "k"})
local autoFarmProcessing = false
local autoFarmAttachment = nil
local autoFarmPosition = nil
local autoFarmOrientation = nil

local function releaseAutoFarmHold()
    if autoFarmPosition then
        autoFarmPosition:Destroy()
        autoFarmPosition = nil
    end
    if autoFarmOrientation then
        autoFarmOrientation:Destroy()
        autoFarmOrientation = nil
    end
    if autoFarmAttachment then
        autoFarmAttachment:Destroy()
        autoFarmAttachment = nil
    end
end

local function holdAutoFarmAtOrigin()
    if not autoFarmEnabled or #autoFarmQueue > 0 then
        return
    end

    if autoFarmPosition and autoFarmPosition.Parent
        and autoFarmOrientation and autoFarmOrientation.Parent
        and autoFarmAttachment and autoFarmAttachment.Parent then
        return
    end

    local character = Player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then
        return
    end

    releaseAutoFarmHold()
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    root.CFrame = CFrame.new(0, 0, 0)

    autoFarmAttachment = Instance.new("Attachment")
    autoFarmAttachment.Name = "NexusAutoFarmAttachment"
    autoFarmAttachment.Parent = root

    autoFarmPosition = Instance.new("AlignPosition")
    autoFarmPosition.Name = "NexusAutoFarmPosition"
    autoFarmPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
    autoFarmPosition.Attachment0 = autoFarmAttachment
    autoFarmPosition.Position = Vector3.zero
    autoFarmPosition.ApplyAtCenterOfMass = true
    autoFarmPosition.RigidityEnabled = true
    autoFarmPosition.MaxForce = math.huge
    autoFarmPosition.MaxVelocity = math.huge
    autoFarmPosition.Responsiveness = 200
    autoFarmPosition.Parent = root

    autoFarmOrientation = Instance.new("AlignOrientation")
    autoFarmOrientation.Name = "NexusAutoFarmOrientation"
    autoFarmOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
    autoFarmOrientation.Attachment0 = autoFarmAttachment
    autoFarmOrientation.CFrame = CFrame.new()
    autoFarmOrientation.RigidityEnabled = true
    autoFarmOrientation.MaxTorque = math.huge
    autoFarmOrientation.MaxAngularVelocity = math.huge
    autoFarmOrientation.Responsiveness = 200
    autoFarmOrientation.Parent = root
end

local function processAutoFarmQueue()
    if autoFarmProcessing then
        return
    end

    autoFarmProcessing = true
    task.spawn(function()
        while autoFarmEnabled do
            local model = table.remove(autoFarmQueue, 1)
            if model then
                releaseAutoFarmHold()

                if model.Parent and model:IsDescendantOf(workspace) and model.Name == "" then
                    local character = Player.Character
                    local root = character and character:FindFirstChild("HumanoidRootPart")
                    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

                    if root and humanoid and humanoid.Health > 0 then
                        local success, targetCFrame = pcall(function()
                            return model:GetPivot()
                        end)

                        if success and targetCFrame then
                            root.AssemblyLinearVelocity = Vector3.zero
                            root.AssemblyAngularVelocity = Vector3.zero
                            root.CFrame = targetCFrame
                            task.wait(0.15)

                            if autoFarmEnabled and model.Parent then
                                activateProximityPrompts(model)
                            end
                        end
                    end
                end

                task.wait(0.1)
            else
                holdAutoFarmAtOrigin()
                task.wait(0.25)
            end
        end

        autoFarmProcessing = false
    end)
end

local function queueAutoFarmModel(model)
    if not autoFarmEnabled or not model or not model:IsA("Model") or model.Name ~= "" then
        return
    end
    if autoFarmProcessed[model] then
        return
    end

    autoFarmProcessed[model] = true
    releaseAutoFarmHold()
    table.insert(autoFarmQueue, model)
    processAutoFarmQueue()
end

local function setupAutoFarm()
    if autoFarmConnection then
        autoFarmConnection:Disconnect()
    end
    if autoFarmCharacterConnection then
        autoFarmCharacterConnection:Disconnect()
    end

    autoFarmQueue = {}
    autoFarmProcessed = setmetatable({}, {__mode = "k"})

    autoFarmConnection = workspace.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("Model") and descendant.Name == "" then
            queueAutoFarmModel(descendant)
        end
    end)

    autoFarmCharacterConnection = Player.CharacterAdded:Connect(function()
        releaseAutoFarmHold()
        task.delay(0.5, function()
            if autoFarmEnabled and #autoFarmQueue == 0 then
                holdAutoFarmAtOrigin()
            end
        end)
    end)

    task.spawn(function()
        local descendants = workspace:GetDescendants()
        for index, descendant in ipairs(descendants) do
            if not autoFarmEnabled then
                return
            end
            if descendant:IsA("Model") and descendant.Name == "" then
                queueAutoFarmModel(descendant)
            end
            if index % 500 == 0 then
                task.wait()
            end
        end

        processAutoFarmQueue()
    end)
end

local function toggleAutoFarm(value)
    if value and Options.BossFarmToggle and Options.BossFarmToggle.Value then
        Options.BossFarmToggle:SetValue(false)
    end
    autoFarmEnabled = value

    if value then
        setupAutoFarm()
    else
        if autoFarmConnection then
            autoFarmConnection:Disconnect()
            autoFarmConnection = nil
        end
        if autoFarmCharacterConnection then
            autoFarmCharacterConnection:Disconnect()
            autoFarmCharacterConnection = nil
        end

        releaseAutoFarmHold()
        autoFarmQueue = {}
        autoFarmProcessed = setmetatable({}, {__mode = "k"})
    end
end

local objectESP = {
    stonesEnabled = false,
    boxesEnabled = false,
    entries = {},
    roots = {},
    descendantConnection = nil,
    updateConnection = nil,
    elapsed = 0
}

local stoneESPColors = {
    TimeStone = Color3.fromRGB(50, 230, 80),
    PowerStone = Color3.fromRGB(170, 65, 255),
    SpaceStone = Color3.fromRGB(65, 205, 255)
}

local function getObjectESPRoot(kind)
    local root = objectESP.roots[kind]
    if root and root.Parent then
        return root
    end

    local rootName = kind == "stone" and "NexusStoneESP_Runtime" or "NexusBoxESP_Runtime"
    local staleRoot = workspace:FindFirstChild(rootName)
    if staleRoot then
        staleRoot:Destroy()
    end

    root = Instance.new("Folder")
    root.Name = rootName
    root.Parent = workspace
    objectESP.roots[kind] = root
    return root
end

local function destroyObjectESPEntry(target)
    local entry = objectESP.entries[target]
    if not entry then
        return
    end

    if entry.highlight then
        entry.highlight:Destroy()
    end
    if entry.billboard then
        entry.billboard:Destroy()
    end
    objectESP.entries[target] = nil
end

local function getObjectESPAdornee(target)
    if target:IsA("BasePart") then
        return target
    end
    if target:IsA("Model") then
        return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local function createObjectESPEntry(target, kind, color)
    if objectESP.entries[target] or not target:IsDescendantOf(workspace) then
        return
    end

    local adorneePart = getObjectESPAdornee(target)
    if not adorneePart then
        return
    end

    local runtimeRoot = getObjectESPRoot(kind)

    local highlight = Instance.new("Highlight")
    highlight.Name = kind == "stone" and "NexusStoneESP" or "NexusBoxESP"
    highlight.Adornee = target
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = color
    highlight.FillTransparency = 0
    highlight.OutlineColor = color
    highlight.OutlineTransparency = 0
    highlight.Parent = runtimeRoot

    local billboard = Instance.new("BillboardGui")
    billboard.Name = kind == "stone" and "NexusStoneDistance" or "NexusBoxDistance"
    billboard.Adornee = adorneePart
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.Size = UDim2.fromOffset(145, 24)
    billboard.StudsOffset = Vector3.new(0, math.max(2, adorneePart.Size.Y * 0.5 + 1), 0)
    billboard.Parent = runtimeRoot

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.Arial
    label.TextSize = 15
    label.TextScaled = false
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0.35
    label.Text = kind == "box" and "-- studs  📦" or "-- studs"
    label.Parent = billboard

    objectESP.entries[target] = {
        kind = kind,
        highlight = highlight,
        billboard = billboard,
        label = label,
        adornee = adorneePart
    }
end

local function findCollectibleModel(instance)
    local current = instance
    while current and current ~= workspace do
        if current:IsA("Model") and current.Name == "" then
            return current
        end
        current = current.Parent
    end
    return nil
end

local function trackObjectESPInstance(instance)
    if objectESP.stonesEnabled and instance:IsA("MeshPart") then
        local color = stoneESPColors[instance.Name]
        if color then
            createObjectESPEntry(instance, "stone", color)
        end
    end

    if objectESP.boxesEnabled then
        local model = findCollectibleModel(instance)
        if model then
            createObjectESPEntry(model, "box", Color3.fromRGB(60, 255, 100))
        end
    end
end

local function updateObjectESPConnections()
    local enabled = objectESP.stonesEnabled or objectESP.boxesEnabled

    if enabled and not objectESP.descendantConnection then
        objectESP.descendantConnection = workspace.DescendantAdded:Connect(trackObjectESPInstance)
    elseif not enabled and objectESP.descendantConnection then
        objectESP.descendantConnection:Disconnect()
        objectESP.descendantConnection = nil
    end

    if enabled and not objectESP.updateConnection then
        objectESP.updateConnection = game:GetService("RunService").Heartbeat:Connect(function(deltaTime)
            objectESP.elapsed += deltaTime
            if objectESP.elapsed < 0.2 then
                return
            end
            objectESP.elapsed = 0

            local character = Player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")

            for target, entry in pairs(objectESP.entries) do
                local categoryEnabled
                if entry.kind == "stone" then
                    categoryEnabled = objectESP.stonesEnabled
                else
                    categoryEnabled = objectESP.boxesEnabled
                end

                if not categoryEnabled or not target.Parent or not target:IsDescendantOf(workspace) then
                    destroyObjectESPEntry(target)
                elseif root and entry.adornee and entry.adornee.Parent then
                    local distance = (root.Position - entry.adornee.Position).Magnitude
                    entry.label.Text = entry.kind == "box"
                        and string.format("%d studs  📦", math.floor(distance + 0.5))
                        or string.format("%d studs", math.floor(distance + 0.5))
                end
            end
        end)
    elseif not enabled and objectESP.updateConnection then
        objectESP.updateConnection:Disconnect()
        objectESP.updateConnection = nil
        objectESP.elapsed = 0
    end
end

local function scanObjectESP()
    task.spawn(function()
        local descendants = workspace:GetDescendants()
        for index, descendant in ipairs(descendants) do
            if not objectESP.stonesEnabled and not objectESP.boxesEnabled then
                return
            end
            trackObjectESPInstance(descendant)
            if index % 500 == 0 then
                task.wait()
            end
        end
    end)
end

local function clearObjectESPKind(kind)
    local targets = {}
    for target, entry in pairs(objectESP.entries) do
        if entry.kind == kind then
            table.insert(targets, target)
        end
    end
    for _, target in ipairs(targets) do
        destroyObjectESPEntry(target)
    end

    local root = objectESP.roots[kind]
    if root then
        root:Destroy()
        objectESP.roots[kind] = nil
    end

    local rootName = kind == "stone" and "NexusStoneESP_Runtime" or "NexusBoxESP_Runtime"
    local staleRoot = workspace:FindFirstChild(rootName)
    if staleRoot then
        staleRoot:Destroy()
    end
end

local function toggleESPStones(value)
    objectESP.stonesEnabled = value
    if value then
        clearObjectESPKind("stone")
        updateObjectESPConnections()
        scanObjectESP()
    else
        clearObjectESPKind("stone")
        updateObjectESPConnections()
    end
end

local function toggleESPBoxes(value)
    objectESP.boxesEnabled = value
    if value then
        clearObjectESPKind("box")
        updateObjectESPConnections()
        scanObjectESP()
    else
        clearObjectESPKind("box")
        updateObjectESPConnections()
    end
end

local artifactHolderESP = {darkhold = nil, darkholdSearchAt = 0}

local artifactDefinitions = {
    {name = "SPACE STONE", color = Color3.fromRGB(65, 155, 255), abilities = {MeteorRain = true}},
    {name = "POWER STONE", color = Color3.fromRGB(165, 70, 255), abilities = {PowerBeam = true}},
    {name = "TIME STONE", color = Color3.fromRGB(65, 235, 105), abilities = {TimeStoneRewind = true}},
    {name = "DARKHOLD", color = Color3.fromRGB(225, 55, 180), abilities = {
        OpenDarkhold = true,
        Darkhold_ControlRibbon = true,
        Darkhold_GrantRightOfPower = true,
        Darkhold_RightOfPower = true,
        Darkhold_AstralProject = true,
        Darkhold_SpawnRibbon = true
    }}
}

local function getDarkholdOwner()
    local cached = artifactHolderESP.darkhold
    if cached and cached.Parent then
        local owner = cached:FindFirstChild("Owner")
        return owner and owner:IsA("ObjectValue") and owner.Value or nil
    end

    local CollectionService = game:GetService("CollectionService")
    for _, interactable in ipairs(CollectionService:GetTagged("Interactable")) do
        if interactable:GetAttribute("Type") == "Darkhold" or interactable.Name == "Darkhold" then
            artifactHolderESP.darkhold = interactable
            local owner = interactable:FindFirstChild("Owner")
            if owner and owner:IsA("ObjectValue") and owner.Value then
                return owner.Value
            end
        end
    end

    if os.clock() < artifactHolderESP.darkholdSearchAt then return nil end
    artifactHolderESP.darkholdSearchAt = os.clock() + 2
    for _, descendant in ipairs(workspace:GetDescendants()) do
        if descendant:IsA("ObjectValue") and descendant.Name == "Owner" then
            local interactable = descendant.Parent
            if interactable and (interactable:GetAttribute("Type") == "Darkhold" or interactable.Name == "Darkhold") then
                artifactHolderESP.darkhold = interactable
                return descendant.Value
            end
        end
    end
    return nil
end

local function getCharacterArtifacts(character, darkholdOwner)
    local found, names, primaryColor = {}, {}, nil
    local function add(definition)
        if found[definition.name] then return end
        found[definition.name] = true
        names[#names + 1] = definition.name
        primaryColor = primaryColor or definition.color
    end

    local abilityFolder = character:FindFirstChild("AbilityFolder")
    if abilityFolder then
        for _, abilityName in pairs(abilityFolder:GetAttributes()) do
            if type(abilityName) == "string" then
                for _, definition in ipairs(artifactDefinitions) do
                    if definition.abilities[abilityName] then add(definition) end
                end
            end
        end
    end

    for _, descendant in ipairs(character:GetDescendants()) do
        local artifactType = descendant:GetAttribute("Type")
        local artifactAbility = descendant:GetAttribute("Ability")
        if artifactType == "InfinityStone" and type(artifactAbility) == "string" then
            for _, definition in ipairs(artifactDefinitions) do
                if definition.abilities[artifactAbility] then add(definition) end
            end
        elseif artifactType == "TimeStone" then
            add(artifactDefinitions[3])
        end
    end

    if darkholdOwner == character then
        add(artifactDefinitions[4])
    end
    return names, primaryColor
end

function PrimeRuntime.CharacterHasStone(character)
    local folder = character and character:FindFirstChild("AbilityFolder")
    if folder then
        for _, name in pairs(folder:GetAttributes()) do
            if name == "MeteorRain" or name == "PowerBeam" or name == "TimeStoneRewind" then return true end
        end
    end
    if character then
        for _, object in ipairs(character:GetDescendants()) do
            local kind = object:GetAttribute("Type")
            if kind == "InfinityStone" or kind == "TimeStone" then return true end
        end
    end
    return false
end

function PrimeRuntime.GetArtifactHolders()
    local t, o = {}, getDarkholdOwner()
    for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
        local c = p.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if p ~= Player and h and h.Health > 0 then
            local n, k = getCharacterArtifacts(c, o)
            if #n > 0 then t[p] = {char = c, text = table.concat(n, " / "), color = k} end
        end
    end
    return t
end

PrimeRuntime.toggleESPStones = toggleESPStones
PrimeRuntime.toggleESPBoxes = toggleESPBoxes

local function teleportToPosition(position)
    local player = game:GetService("Players").LocalPlayer
    local character = player.Character
    
    if character and character:FindFirstChild("HumanoidRootPart") then
        character.HumanoidRootPart.CFrame = CFrame.new(position)
        return true
    end
    return false
end

do

Tabs.Main:AddSection("Main")

Tabs.Main:AddParagraph({
    Icon = "key",
    Title = string.format("Hello, %s!", game:GetService("Players").LocalPlayer.Name),
    Content = "Thank you for being with us!\nEnjoy using the script!"
})

    local AutomaticStoneCollectionToggle = Tabs.Main:AddToggle("AutomaticStoneCollectionToggle", {
        Title = "Automatic stone collection",
        Description = "Teleport to spawned TimeStine/PowerStone/SpaceStone",
        Default = false
    })
    AutomaticStoneCollectionToggle:OnChanged(function()
        toggleAutomaticStoneCollection(Options.AutomaticStoneCollectionToggle.Value)
    end)
    Options.AutomaticStoneCollectionToggle:SetValue(false)
    
    local TPHealToggle = Tabs.Main:AddToggle("TPHealToggle", {
        Title = "TP Heal",
        Description = "tp heal",
        Default = false
    })
    TPHealToggle:OnChanged(function()
        if Options.TPHealToggle.Value then
            teleportToHealingCircle()
        end
    end)
    
    local AutoCollectToggle = Tabs.Main:AddToggle("AutoCollectToggle", {Title = "Auto Collect", Default = false })
    AutoCollectToggle:OnChanged(function()
        if Options.AutoCollectToggle.Value
            and Options.AutoFarmToggle
            and Options.AutoFarmToggle.Value then
            Options.AutoFarmToggle:SetValue(false)
        end
        toggleAutoCollect(Options.AutoCollectToggle.Value)
    end)
    Options.AutoCollectToggle:SetValue(false)

    local AutoFarmToggle = Tabs.Main:AddToggle("AutoFarmToggle", {
        Title = "AutoFarm",
        Description = "auto collect farm",
        Default = false
    })
    AutoFarmToggle:OnChanged(function()
        if Options.AutoFarmToggle.Value
            and Options.AutoCollectToggle
            and Options.AutoCollectToggle.Value then
            Options.AutoCollectToggle:SetValue(false)
        end
        toggleAutoFarm(Options.AutoFarmToggle.Value)
    end)
    Options.AutoFarmToggle:SetValue(false)
    
    local TeleportDropdown = Tabs.Main:AddDropdown("TeleportDropdown", {
        Title = "Teleport to Stone",
        Values = {"--", "Time Stone", "Power Stone", "DarkHold", "Space Stone"},
        Multi = false,
        Default = "--",
    })
    
    TeleportDropdown:OnChanged(function(value)
        if value ~= "--" then
            local position
            local stoneName = ""
            
            if value == "Time Stone" then
                position = Vector3.new(2374.59, 694.15, 656.16)
                stoneName = "Time Stone"
            elseif value == "Power Stone" then
                position = Vector3.new(-346.44, 699.48, 1900.34)
                stoneName = "Power Stone"
            elseif value == "DarkHold" then
                position = Vector3.new(-2819.78, 1050.55, 650.29)
                stoneName = "DarkHold"
            elseif value == "Space Stone" then
                local spaceStoneChest = workspace:FindFirstChild("SpaceStoneChest", true)
                if spaceStoneChest then
                    if spaceStoneChest:IsA("Model") then
                        position = spaceStoneChest:GetPivot().Position
                    elseif spaceStoneChest:IsA("BasePart") then
                        position = spaceStoneChest.Position
                    end
                end
                stoneName = "Space Stone"
            end
            
            if position then
                local success = teleportToPosition(position)
                if success then
                    Notify({
                        Title = "Teleport",
                        Content = "Teleported to " .. stoneName,
                        Duration = 3
                    })
                else
                    Notify({
                        Title = "Teleport Error",
                        Content = "Failed to teleport to " .. stoneName,
                        Duration = 3
                    })
                end
            end
 
            task.wait(0.1)
            TeleportDropdown:SetValue("--")
        end
    end)
end

TrackRuntimeCleanup(function()
    toggleAutomaticStoneCollection(false)
    toggleAutoCollect(false)
    toggleAutoFarm(false)
    toggleESPStones(false)
    toggleESPBoxes(false)
end)

do
    local Players = game:GetService("Players")
    local CollectionService = game:GetService("CollectionService")
    local RunService = game:GetService("RunService")
    local state = {
        Enabled = false,
        Generation = 0,
        Cursor = 1,
        Elapsed = 0,
        NextCast = 0,
        NextSearch = 0,
        NextRespawn = 0,
        NextStream = 0,
        StreamIndex = 0,
        StreamBusy = false,
        RespawnBusy = false,
        Distance = 8,
        Character = nil,
        CharacterName = nil,
        SkinName = "Default",
        Target = nil,
        Cast = nil,
        Connection = nil,
        Hooks = {},
    }
    local slots = {
        "Ability1", "Ability2", "Ability3", "Ability4", "Ability5", "Ultimate",
        "DarkholdSpell_One", "DarkholdSpell_Two", "DarkholdSpell_Three",
        "Option1", "Option2", "Option3",
    }
    local searchPositions = {
        Vector3.new(-1052, 820, 325),
    }
    local combatAbilities = {}
    for _, name in ipairs({
        "DarkBolt", "DarkBeam", "DarkWraith", "DarkCurse", "DarkChains",
        "BinaryForm", "PhotonBlast", "PhotonBeam", "BinaryThrow",
        "OpticalStrike", "OpticalUnleash", "OpticalBeam", "OpticalBlast",
        "EldritchSlices", "EldritchLasso", "MirrorDimension", "IcyTendrilsOfIkthalon",
        "GiantArrow", "ArrowShot", "GasArrow", "StunArrow",
        "Flamethrow", "Fireball", "Supernova", "MeteorRain", "PowerBeam",
        "BubbleFrisbee", "BubbleBlast", "BubbleMace",
        "RepulsorBlast", "LaserSpin", "MissileLaunch",
        "KineticStrike", "PhoenixStrike", "MentalInstability", "JG_Telekinesis",
        "JG_Telekinesis_Push", "PhoenixPush", "ConsumingFlame",
        "CosmicCombat", "CosmicBolt", "CosmicPunch",
        "SpeedPunch", "SpeedPunche", "SpeedCarry", "SonicBoom", "SpeedCarryThrow", "SpeedAreaPunch",
        "LightningBeam", "IcicleSpear", "Tornado",
        "GodOfThunder", "Thor_LightningBeam", "LightningAura", "HammerThrow", "HammerSlam", "BifrostSlam",
        "MindBeam", "MindBolt", "ChaosBarrage", "ChaosAbsorb", "ChaosDarkHex", "ChaosKinesis",
        "SW_ChaosBeam", "ChaosTelekinesis", "ChaosBolt", "ChaosLift", "ChaosBoulderThrow",
        "ChaosVault_Slam", "ChaosVault_SlamSW", "ChaosBeam", "ChaosReactionSlam",
        "ChaosRockOutburst", "AOUWanda_AreaBlast",
        "HexBeam", "HexHalt", "HexTrap", "TelepathicPull", "HexMark",
    }) do combatAbilities[name] = true end
    local abilities, presets, network, system, aimModule, targetModule

    local function getParts(character)
        if not character or not character.Parent then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local root = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
        if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
            return humanoid, root
        end
    end

    local function available(model)
        if typeof(model) ~= "Instance" or not model:IsA("Model") or model.Name ~= "Elderbeast"
            or not model:IsDescendantOf(workspace) or model == Player.Character
            or Players:GetPlayerFromCharacter(model)
            or not CollectionService:HasTag(model, "EnemyNPC") then return false end
        local humanoid, root = getParts(model)
        if not humanoid then return false end
        return true, root
    end

    local function getTarget()
        if not state.Enabled or not getParts(Player.Character)
            or Player:GetAttribute("SelectingCharacter") then return end
        local valid, root = available(state.Target)
        if valid then return state.Target, root end
    end

    local function rememberCharacter(character)
        if not character then return end
        local name = character:GetAttribute("CharacterName")
        if type(name) == "string" and name ~= "" then
            state.CharacterName = name
            state.SkinName = character:GetAttribute("SkinName") or "Default"
        end
    end

    local function resolveModules()
        abilities = abilities or getGameModule("Abilities")
        network = network or getGameModule("Network")
        aimModule = aimModule or getGameModule("Aim")
        targetModule = targetModule or getGameModule("Target")
        if not system then
            system = type(shared) == "table" and shared.System or nil
            if not system then
                local module = game:GetService("ReplicatedFirst"):FindFirstChild("System")
                if module then
                    local ok, result = pcall(require, module)
                    if ok then system = result end
                end
            end
        end
        if not presets then
            local folder = game:GetService("ReplicatedStorage"):FindFirstChild("Abilities_Client")
            local module = folder and folder:FindFirstChild("Presets")
            if module then
                local ok, result = pcall(require, module)
                if ok then presets = result end
            end
        end
        return type(abilities) == "table" and type(abilities.GetAbilityNumInfo) == "function"
            and type(abilities.GetCooldownRemaining) == "function"
            and type(abilities.ActivateAbility) == "function"
            and type(abilities.DeactivateAbility) == "function"
            and type(system) == "table" and type(system.StoredFunctions) == "table"
            and type(aimModule) == "table" and type(aimModule.GetAimPosition) == "function"
    end

    local function removeHooks()
        for _, hook in ipairs(state.Hooks) do
            if hook.Registry[hook.Name] == hook.Wrapper then
                hook.Registry[hook.Name] = hook.Original
            end
        end
        table.clear(state.Hooks)
        if PrimeRuntime.SetBossFarmAim then PrimeRuntime.SetBossFarmAim(false) end
    end

    local function installHooks()
        if #state.Hooks > 0 then return true end
        local registry = system.StoredFunctions
        for _, name in ipairs({"GetAimPosition", "GetTarget"}) do
            if type(registry[name]) ~= "function" then return false end
        end
        if PrimeRuntime.SetBossFarmAim then PrimeRuntime.SetBossFarmAim(true) end
        local entries = {
            {Registry = registry, Name = "GetAimPosition"},
            {Registry = registry, Name = "GetTarget"},
            {Registry = aimModule, Name = "GetAimPosition"},
        }
        if type(aimModule.GetRawAimPosition) == "function" then
            table.insert(entries, {Registry = aimModule, Name = "GetRawAimPosition"})
        end
        if type(targetModule) == "table" and type(targetModule.GetTarget) == "function" then
            table.insert(entries, {Registry = targetModule, Name = "GetTarget"})
        end
        for _, entry in ipairs(entries) do
            local destination, name = entry.Registry, entry.Name
            local original = destination[name]
            local wrapper = function(...)
                local target, root = getTarget()
                if target then
                    if name ~= "GetTarget" then return root.Position end
                    local range = select(1, ...)
                    local _, ownRoot = getParts(Player.Character)
                    if type(range) ~= "number" or (root.Position - ownRoot.Position).Magnitude <= range then
                        return target
                    end
                    return nil
                end
                if state.Enabled and name == "GetTarget" then return nil end
                return original(...)
            end
            destination[name] = wrapper
            table.insert(state.Hooks, {Registry = destination, Name = name, Original = original, Wrapper = wrapper})
        end
        return true
    end

    local function endCast()
        local cast = state.Cast
        state.Cast = nil
        if cast and not cast.Finished and cast.Character == Player.Character and abilities then
            pcall(abilities.DeactivateAbility, cast.Name)
        end
    end

    local function requestRespawn(now)
        if not state.CharacterName or state.RespawnBusy or now < state.NextRespawn
            or Player:GetAttribute("SelectingCharacter") ~= true then return end
        state.NextRespawn = now + 5
        local invoke = network and network.InvokeServer
        if type(invoke) ~= "function" and type(network) == "table" then
            for key, callback in pairs(network) do
                if type(key) == "string" and key:find("InvokeServer", 1, true)
                    and type(callback) == "function" then invoke = callback break end
            end
        end
        if type(invoke) ~= "function" then return end
        state.RespawnBusy = true
        local generation = state.Generation
        local name, skin = state.CharacterName, state.SkinName
        task.spawn(function()
            if state.Enabled and state.Generation == generation
                and Player:GetAttribute("SelectingCharacter") == true then
                pcall(invoke, "RequestCharacter", name, skin)
            end
            state.RespawnBusy = false
        end)
    end

    local function findBoss(root, now)
        if now < state.NextSearch then return end
        state.NextSearch = now + 0.5
        local nearest, distance
        for _, model in ipairs(CollectionService:GetTagged("EnemyNPC")) do
            local valid, targetRoot = available(model)
            if valid then
                local current = (targetRoot.Position - root.Position).Magnitude
                if not distance or current < distance then nearest, distance = model, current end
            end
        end
        state.Target = nearest
        if nearest then state.NextCast = now + 0.05 return end
        if not workspace.StreamingEnabled or state.StreamBusy or now < state.NextStream then return end
        state.NextStream = now + 5
        state.StreamIndex = state.StreamIndex % #searchPositions + 1
        local position = searchPositions[state.StreamIndex]
        local generation = state.Generation
        state.StreamBusy = true
        task.spawn(function()
            if state.Enabled and state.Generation == generation then
                pcall(Player.RequestStreamAroundAsync, Player, position, 3)
            end
            state.StreamBusy = false
        end)
    end

    local function nextAbility(character, root, targetRoot, now)
        if now < state.NextCast or Player:GetAttribute("CanUseAbilities") ~= true
            or character:GetAttribute("Stuns") then return end
        for _ = 1, #slots do
            local slot = slots[state.Cursor]
            state.Cursor = state.Cursor % #slots + 1
            local ok, name, definition = pcall(abilities.GetAbilityNumInfo, slot)
            local folder = character:FindFirstChild("AbilityFolder")
            if ok and type(name) == "string" and combatAbilities[name] and type(definition) == "table"
                and folder and folder:GetAttribute(slot) == name then
                local preset = presets and presets[definition.AbilityPreset]
                local function field(key)
                    if definition[key] ~= nil then return definition[key] end
                    return preset and preset[key]
                end
                local charge, maximum = character:GetAttribute("UltCharge"), character:GetAttribute("MaxUltCharge")
                local readyUltimate = not field("Ultimate")
                    or type(charge) == "number" and type(maximum) == "number" and charge >= maximum
                local cooldownOK, cooldown = pcall(abilities.GetCooldownRemaining, name)
                local range = tonumber(field("TargetRange")) or 100
                if not field("Passive") and field("AbilityPreset") ~= "Shield"
                    and field("AbilityPreset") ~= "Flight" and field("AbilityPreset") ~= "Sprint"
                    and readyUltimate and cooldownOK
                    and (cooldown == nil or type(cooldown) == "number" and cooldown <= 0)
                    and (not field("TargetRequired") or (targetRoot.Position - root.Position).Magnitude <= range) then
                    local cast = {
                        Name = name,
                        Character = character,
                        StartedAt = now,
                        Finished = false,
                        ReleaseAt = now + math.clamp(tonumber(field("AimDuration"))
                            or tonumber(field("MaxActivationTime")) or 3, 0.4, 8),
                        CanDeactivate = field("CanDeactivate") == true,
                        NextRelease = 0,
                    }
                    state.Cast = cast
                    state.NextCast = now + 0.05
                    local generation = state.Generation
                    task.spawn(function()
                        if state.Enabled and state.Generation == generation
                            and Player.Character == character and getTarget() then
                            local success, result = pcall(abilities.ActivateAbility, name)
                            if not success then
                                cast.Error = tostring(result)
                                state.LastError = cast.Error
                            end
                        end
                        cast.Finished = true
                    end)
                    return
                end
            end
        end
        state.NextCast = now + 0.05
    end

    local function step(now)
        if not state.Enabled or PrimeRuntime.IsShuttingDown then return end
        local character = Player.Character
        rememberCharacter(character)
        if character ~= state.Character then
            endCast()
            state.Character = character
            state.Cursor = 1
            state.NextCast = now + 0.2
        end
        local humanoid, root = getParts(character)
        if not humanoid or Player:GetAttribute("SelectingCharacter") then
            endCast()
            requestRespawn(now)
            return
        end
        if not available(state.Target) then
            endCast()
            state.Target = nil
            findBoss(root, now)
        end
        local target, targetRoot = getTarget()
        if not target then return end
        local desired = targetRoot.Position - targetRoot.CFrame.LookVector * state.Distance
        if (root.Position - desired).Magnitude > 2.5 and not character:GetAttribute("Stuns") then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            root.CFrame = CFrame.lookAt(desired, targetRoot.Position)
        end
        character:SetAttribute("AimPosition", targetRoot.Position)
        local direction = targetRoot.Position - root.Position
        if direction.Magnitude > 0.01 then character:SetAttribute("LookDirection", direction.Unit) end
        local cast = state.Cast
        if cast then
            if cast.Finished then
                state.Cast = nil
            elseif cast.CanDeactivate and now >= cast.ReleaseAt and now >= cast.NextRelease then
                cast.NextRelease = now + 0.5
                pcall(abilities.DeactivateAbility, cast.Name)
            end
            if state.Cast then return end
        end
        nextAbility(character, root, targetRoot, now)
    end

    local function setEnabled(value)
        value = value == true
        if value == state.Enabled then return end
        state.Generation = state.Generation + 1
        if not value then
            state.Enabled = false
            if state.Connection then state.Connection:Disconnect() state.Connection = nil end
            endCast()
            removeHooks()
            state.Target, state.Character = nil, nil
            return
        end
        if not resolveModules() or not installHooks() then
            removeHooks()
            Notify({Title = "Boss Farm", Content = "Game abilities are not ready. Try again after spawning.", Duration = 5})
            local option = Options.BossFarmToggle
            if option and option.Value then option:SetValue(false) end
            return
        end
        for _, name in ipairs({"AutomaticStoneCollectionToggle", "AutoCollectToggle", "AutoFarmToggle"}) do
            local option = Options[name]
            if option and option.Value then option:SetValue(false) end
        end
        state.Enabled = true
        state.Cursor, state.Elapsed = 1, 0
        state.NextCast, state.NextSearch, state.NextRespawn, state.NextStream = 0, 0, os.clock() + 2, 0
        rememberCharacter(Player.Character)
        state.Connection = RunService.Heartbeat:Connect(function(dt)
            state.Elapsed = state.Elapsed + dt
            if state.Elapsed < 0.05 then return end
            state.Elapsed = 0
            local ok, err = pcall(step, os.clock())
            if not ok then
                state.LastError = tostring(err)
                setEnabled(false)
                local option = Options.BossFarmToggle
                if option and option.Value then option:SetValue(false) end
                Notify({Title = "Boss Farm", Content = tostring(err), Duration = 5})
            end
        end)
    end

    PrimeRuntime.GetBossFarmTarget = getTarget
    PrimeRuntime.BossFarm = state
    local toggle = Tabs.Main:AddToggle("BossFarmToggle", {
        Title = "Boss Farm",
        Description = "Farm Elderbeast with built-in Silent Aim and repeat ready attack abilities",
        Default = false,
    })
    toggle:OnChanged(function() setEnabled(Options.BossFarmToggle.Value) end)
    Tabs.Main:AddSlider("BossFarmDistance", {
        Title = "Boss Distance",
        Description = "Distance behind the current boss",
        Default = 8,
        Min = 3,
        Max = 30,
        Rounding = 0,
        Callback = function(value) state.Distance = math.clamp(tonumber(value) or 8, 3, 30) end,
    })
    TrackRuntimeCleanup(function()
        setEnabled(false)
        if PrimeRuntime.GetBossFarmTarget == getTarget then PrimeRuntime.GetBossFarmTarget = nil end
        if PrimeRuntime.BossFarm == state then PrimeRuntime.BossFarm = nil end
    end)
end

do
    local settings = PrimeRuntime.SilentAimSettings
    local players = game:GetService("Players")
    local function changed()
        if PrimeRuntime.ResetCombatTarget then PrimeRuntime.ResetCombatTarget() end
    end
    Tabs.Main:AddSection("Silent Aim Filters")
    Tabs.Main:AddDropdown("SilentAimPriority", {Title = "Target Priority",
        Values = {"Nearest", "Lowest Health", "Stone Holders", "Stones + Low Health", "Low Health + Stones"},
        Default = "Nearest", Callback = function(value) settings.Priority = value; changed() end})
    local function names()
        local values, seen = {}, {}
        for _, player in ipairs(players:GetPlayers()) do if player ~= Player then seen[player.Name] = true end end
        for name in pairs(settings.Preferred) do seen[name] = true end
        for name in pairs(settings.Ignored) do seen[name] = true end
        for name in pairs(seen) do values[#values + 1] = name end
        table.sort(values)
        return values
    end
    local preferred = Tabs.Main:AddDropdown("SilentAimPriorityPlayers", {Title = "Priority Players", Multi = true,
        Values = names(), Default = {}, Callback = function(value) settings.Preferred = value; changed() end})
    local ignored = Tabs.Main:AddDropdown("SilentAimIgnorePlayers", {Title = "Ignore Players", Multi = true,
        Values = names(), Default = {}, Callback = function(value) settings.Ignored = value; changed() end})
    for index = 1, 5 do
        local slot = "Ability" .. index
        Tabs.Main:AddToggle("SilentAimIgnore" .. slot, {Title = "Ignore Ability " .. index, Default = false,
            Callback = function(value) settings.IgnoredAbilities[slot] = value or nil end})
    end
    local function refresh()
        if PrimeRuntime.IsShuttingDown then return end
        local values = names()
        preferred:SetValues(values); ignored:SetValues(values)
    end
    TrackRuntimeConnection(players.PlayerAdded:Connect(refresh))
    TrackRuntimeConnection(players.PlayerRemoving:Connect(function() task.defer(refresh) end))
end
do
    local storage = game:GetService("ReplicatedStorage")
    local players = game:GetService("Players")
    local catalog, heroes, definitions = {}, {}, {}
    local state = {Hero = "JeanGrey", Skin = "Default", Effects = false, Appearance = false, Epoch = 0,
        Objects = {}, Hidden = {}, Removed = {}, EffectCount = 0, AppearanceApplied = false}
    local characterConnections, skinDropdown, status = {}, nil, nil
    local dataFolder = storage:FindFirstChild("CharacterData")
    if dataFolder then
        for _, module in ipairs(dataFolder:GetChildren()) do
            if module:IsA("ModuleScript") then
                local ok, data = PrimeRuntime.Protect(require, module)
                if ok and type(data) == "table" and type(data.Skins) == "table" then
                    catalog[module.Name] = data
                    heroes[#heroes + 1] = module.Name
                end
            end
        end
    end
    table.sort(heroes)
    if not catalog[state.Hero] then state.Hero = heroes[1] end
    local function skinNames(hero)
        local result = {}
        for name in pairs(catalog[hero] and catalog[hero].Skins or {}) do result[#result + 1] = name end
        table.sort(result, function(a, b) if a == b then return false elseif a == "Default" then return true elseif b == "Default" then return false end; return a < b end)
        return result
    end
    local function clear()
        for _, object in ipairs(state.Objects) do pcall(object.Destroy, object) end
        table.clear(state.Objects)
        for object, properties in pairs(state.Hidden) do
            for key, value in pairs(properties) do pcall(function() object[key] = value end) end
        end
        table.clear(state.Hidden)
        for _, record in ipairs(state.Removed) do
            pcall(function() if record.Parent.Parent then record.Object.Parent = record.Parent else record.Object:Destroy() end end)
        end
        table.clear(state.Removed)
        state.EffectCount, state.AppearanceApplied = 0, false
    end
    local function remember(object, key, value)
        local ok, original = pcall(function() return object[key] end)
        if not ok then return end
        local properties = state.Hidden[object]
        if not properties then properties = {}; state.Hidden[object] = properties end
        if properties[key] == nil then properties[key] = original end
        pcall(function() object[key] = value end)
    end
    local function track(object) state.Objects[#state.Objects + 1] = object; return object end
    local function sanitize(object)
        for _, child in ipairs(object:GetDescendants()) do
            if child:IsA("LuaSourceContainer") or child:IsA("Humanoid") or child:IsA("Animator")
                or child:IsA("BodyMover") or child:IsA("Constraint") or child:IsA("JointInstance")
                or child:IsA("ProximityPrompt") or child:IsA("Sound") then child:Destroy() end
        end
    end
    local function findModel(data)
        local modelName = data.CharacterModelName
        if type(modelName) == "string" then
            local candidate = storage:FindFirstChild(modelName, true)
            if candidate and candidate:IsA("Model") then return candidate end
        end
        for _, player in ipairs(players:GetPlayers()) do
            local model = player.Character
            if model and model ~= Player.Character and model:GetAttribute("CharacterName") == state.Hero
                and (model:GetAttribute("SkinName") or "Default") == state.Skin then return model end
        end
        return nil
    end
    local function applyAppearance(character, data)
        if character:GetAttribute("CharacterName") == state.Hero
            and (character:GetAttribute("SkinName") or "Default") == state.Skin then return true end
        local source = findModel(data)
        if not source then return false end
        local container = track(Instance.new("Folder"))
        container.Name, container.Parent = "PRIME_LocalSkin", character
        local bodyCount = 0
        local dressed = source:FindFirstChildOfClass("Shirt") or source:FindFirstChildOfClass("Pants")
        for _, part in ipairs(source:GetChildren()) do
            local target = character:FindFirstChild(part.Name)
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and target and target:IsA("BasePart") then
                local textured = part:IsA("MeshPart") and part.TextureID ~= "" or part:FindFirstChildOfClass("SpecialMesh")
                if dressed and not textured then remember(target, "Color", part.Color); bodyCount = bodyCount + 1
                else
                    local ok, clone = pcall(part.Clone, part)
                    if ok and clone then
                        sanitize(clone)
                        for _, nested in ipairs(clone:GetDescendants()) do
                            if nested:IsA("BasePart") then nested:Destroy() end
                        end
                        clone.Name = "Skin_" .. part.Name
                        clone.Anchored, clone.CanCollide, clone.CanTouch, clone.CanQuery, clone.Massless = false, false, false, false, true
                        clone.CFrame = target.CFrame
                        clone.LocalTransparencyModifier = 0
                        clone.Parent = container
                        local weld = Instance.new("WeldConstraint")
                        weld.Part0, weld.Part1, weld.Parent = target, clone, clone
                        bodyCount = bodyCount + 1
                        remember(target, "LocalTransparencyModifier", 1)
                        for _, child in ipairs(target:GetChildren()) do if child:IsA("Decal") then remember(child, "Transparency", 1) end end
                    end
                end
            end
        end
        if bodyCount == 0 then return false end
        for _, item in ipairs(character:GetChildren()) do
            if item:IsA("Accessory") then
                for _, part in ipairs(item:GetDescendants()) do if part:IsA("BasePart") then remember(part, "LocalTransparencyModifier", 1) end end
            elseif item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
                state.Removed[#state.Removed + 1] = {Object = item, Parent = character}
                item.Parent = nil
            end
        end
        for _, item in ipairs(source:GetChildren()) do
            if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
                local clone = track(item:Clone()); clone.Parent = character
            elseif item:IsA("Accessory") then
                local handle = item:FindFirstChild("Handle")
                local originalWeld = handle and handle:FindFirstChild("AccessoryWeld")
                local target = originalWeld and originalWeld.Part1 and character:FindFirstChild(originalWeld.Part1.Name)
                if target and target:IsA("BasePart") then
                    local clone = track(item:Clone()); sanitize(clone)
                    clone.Parent = container
                    local clonedHandle = clone:FindFirstChild("Handle")
                    if clonedHandle then
                        local sourceFrame = clonedHandle.CFrame
                        local handleFrame = target.CFrame * originalWeld.C0 * originalWeld.C1:Inverse()
                        for _, part in ipairs(clone:GetDescendants()) do
                            if part:IsA("BasePart") then
                                part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.Massless = false, false, false, false, true
                                local relative = sourceFrame:ToObjectSpace(part.CFrame)
                                part.CFrame = handleFrame * relative
                                if part ~= clonedHandle then
                                    local joint = Instance.new("WeldConstraint")
                                    joint.Part0, joint.Part1, joint.Parent = clonedHandle, part, part
                                end
                            end
                        end
                        local weld = Instance.new("Weld")
                        weld.Part0, weld.Part1, weld.C0, weld.C1 = target, clonedHandle, originalWeld.C0, originalWeld.C1
                        weld.Parent = clonedHandle
                    end
                end
            end
        end
        return true
    end
    local function effectRoot()
        local effects = storage:FindFirstChild("Effects")
        local assets = effects and effects:FindFirstChild("Assets")
        return assets and assets:FindFirstChild("Characters")
    end
    local function findEffect(root, name)
        return root and type(name) == "string" and root:FindFirstChild(name, true) or nil
    end
    local function effectSources(data)
        local root, result, seen = effectRoot(), {}, {}
        if not root then return result end
        local function add(name)
            if type(name) ~= "string" or seen[name] then return end
            local variant = state.Skin ~= "Default" and findEffect(root, name .. "_" .. state.Skin)
            local asset = variant or findEffect(root, name)
            if asset and not seen[asset] then seen[name], seen[asset] = true, true; result[#result + 1] = asset end
        end
        if type(data.MenuEffectParams) == "table" then add(data.MenuEffectParams.EffectSetName) end
        local modules = storage:FindFirstChild("Abilities_Client")
        local module = modules and modules:FindFirstChild(state.Hero)
        if not module and modules then
            for _, candidate in ipairs(modules:GetChildren()) do
                if candidate:IsA("ModuleScript") and state.Hero:lower():sub(1, #candidate.Name) == candidate.Name:lower() then module = candidate; break end
            end
        end
        if module and definitions[module] == nil then
            local ok, value = PrimeRuntime.Protect(require, module)
            definitions[module] = ok and type(value) == "table" and value or false
        end
        local abilities = module and definitions[module]
        for _, ability in pairs(data.Abilities or {}) do
            local definition = abilities and abilities[ability]
            local name = type(definition) == "table" and definition.CharacterEffect
            if type(name) == "string" and (name:find("Aura", 1, true) or name:find("Flight", 1, true)) and #result < 3 then add(name) end
        end
        return result
    end
    local function applyEffects(character, data)
        for _, source in ipairs(effectSources(data)) do
            local clone = source:Clone()
            sanitize(clone)
            for _, child in ipairs(clone:GetChildren()) do
                local target = character:FindFirstChild(child.Name, true)
                if child:IsA("Attachment") and target and target:IsA("BasePart") then
                    for _, descendant in ipairs(child:GetDescendants()) do
                        if descendant:IsA("BasePart") then descendant:Destroy() end
                    end
                    child.Parent = target
                    track(child)
                    state.EffectCount = state.EffectCount + 1
                    for _, effect in ipairs(child:GetDescendants()) do
                        if effect:IsA("ParticleEmitter") then
                            local modifiers = data.VfxModifiers
                            if type(modifiers) == "table" then
                                local points = {}
                                for _, point in ipairs(effect.Color.Keypoints) do
                                    local h, saturation, brightness = point.Value:ToHSV()
                                    local color = Color3.fromHSV((h + (modifiers.Hue or 0)) % 1,
                                        math.clamp(saturation + (modifiers.Saturation or 0), 0, 1),
                                        math.clamp(brightness + (modifiers.Brightness or 0), 0, 1))
                                    points[#points + 1] = ColorSequenceKeypoint.new(point.Time, color)
                                end
                                effect.Color = ColorSequence.new(points)
                            end
                            effect.Enabled = true
                            if effect.Rate == 0 then effect:Emit(math.clamp(tonumber(effect:GetAttribute("EmitCount")) or 12, 1, 60)) end
                        elseif effect:IsA("Trail") or effect:IsA("Beam") or effect:IsA("Light") then effect.Enabled = true end
                    end
                end
            end
            clone:Destroy()
        end
    end
    local function refresh()
        clear()
        local character = Player.Character
        local data = catalog[state.Hero] and catalog[state.Hero].Skins[state.Skin]
        if not character or not data or PrimeRuntime.IsShuttingDown then
            if status then status:SetDesc("Spawn a character to preview a local skin.") end
            return
        end
        if state.Appearance then state.AppearanceApplied = applyAppearance(character, data) end
        if state.Effects then applyEffects(character, data) end
        if status then
            local appearance = not state.Appearance and "Off" or state.AppearanceApplied and "Applied" or "Model not loaded"
            status:SetDesc("Appearance: " .. appearance .. " | Effect attachments: " .. state.EffectCount)
        end
    end
    local function safeRefresh()
        local ok, failure = PrimeRuntime.Protect(refresh)
        if not ok then clear(); Notify({Title = "Local Skin Preview", Content = tostring(failure), Duration = 4}) end
    end
    Tabs.Main:AddSection("Local Skin Preview")
    status = Tabs.Main:AddParagraph({Title = "Local appearance and effects", Content = "Exact appearance requires a skin model already loaded by the game."})
    Tabs.Main:AddDropdown("LocalSkinHero", {Title = "Skin Character", Values = heroes, Default = state.Hero, ConfigOrder = 10,
        Callback = function(value)
            state.Hero = value
            local names = skinNames(value)
            state.Skin = names[1]
            if skinDropdown then skinDropdown:SetValues(names); skinDropdown:SetValue(state.Skin) end
            safeRefresh()
        end})
    local names = skinNames(state.Hero)
    state.Skin = names[1]
    skinDropdown = Tabs.Main:AddDropdown("LocalSkinName", {Title = "Skin", Values = names, Default = state.Skin, ConfigOrder = 20,
        Callback = function(value) state.Skin = value; safeRefresh() end})
    Tabs.Main:AddToggle("LocalSkinAppearance", {Title = "Local Skin Appearance", Default = false,
        Callback = function(value) state.Appearance = value; safeRefresh() end})
    Tabs.Main:AddToggle("LocalSkinEffects", {Title = "Local Skin Effects", Default = false,
        Callback = function(value) state.Effects = value; safeRefresh() end})
    Tabs.Main:AddButton({Title = "Refresh Local Skin", Callback = safeRefresh})
    local function bindCharacter(character)
        for _, connection in ipairs(characterConnections) do connection:Disconnect() end
        table.clear(characterConnections)
        state.Epoch = state.Epoch + 1
        local epoch = state.Epoch
        clear()
        if not character then return end
        local pending = false
        local function schedule()
            if pending then return end
            pending = true
            task.delay(0.2, function()
                pending = false
                if epoch == state.Epoch and not PrimeRuntime.IsShuttingDown then safeRefresh() end
            end)
        end
        characterConnections[#characterConnections + 1] = character.ChildAdded:Connect(function(child)
            if child:IsA("BasePart") and (state.Appearance or state.Effects) then schedule() end
        end)
        task.delay(0.6, function()
            if epoch == state.Epoch and not PrimeRuntime.IsShuttingDown then safeRefresh() end
        end)
    end
    TrackRuntimeConnection(Player.CharacterAdded:Connect(bindCharacter))
    TrackRuntimeConnection(Player.CharacterRemoving:Connect(function() bindCharacter(nil) end))
    bindCharacter(Player.Character)
    PrimeRuntime.LocalSkinPreview = {Refresh = safeRefresh, Clear = clear, State = state}
    TrackRuntimeCleanup(function()
        state.Epoch = state.Epoch + 1
        clear()
        for _, connection in ipairs(characterConnections) do connection:Disconnect() end
        table.clear(characterConnections)
        PrimeRuntime.LocalSkinPreview = nil
    end)
end
