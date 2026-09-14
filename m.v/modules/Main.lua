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

local artifactHolderESP = {
    enabled = false,
    connection = nil,
    elapsed = 0,
    entries = {},
    root = nil,
    darkhold = nil,
    darkholdSearchAt = 0
}

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

local function getArtifactHolderRoot()
    if artifactHolderESP.root and artifactHolderESP.root.Parent then
        return artifactHolderESP.root
    end
    local stale = workspace:FindFirstChild("NexusArtifactHolderESP_Runtime")
    if stale then stale:Destroy() end
    local root = Instance.new("Folder")
    root.Name = "NexusArtifactHolderESP_Runtime"
    root.Parent = workspace
    artifactHolderESP.root = root
    return root
end

local function destroyArtifactHolderEntry(player)
    local entry = artifactHolderESP.entries[player]
    if not entry then return end
    if entry.highlight then entry.highlight:Destroy() end
    if entry.billboard then entry.billboard:Destroy() end
    artifactHolderESP.entries[player] = nil
end

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

local function updateArtifactHolderEntry(player, character, names, color, localRoot)
    local entry = artifactHolderESP.entries[player]
    if entry and (entry.character ~= character or not entry.highlight.Parent or not entry.billboard.Parent) then
        destroyArtifactHolderEntry(player)
        entry = nil
    end

    local adornee = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
    if not adornee or not adornee:IsA("BasePart") then return end

    if not entry then
        local root = getArtifactHolderRoot()
        local highlight = Instance.new("Highlight")
        highlight.Name = "NexusArtifactHolderHighlight"
        highlight.Adornee = character
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillTransparency = 0.68
        highlight.OutlineTransparency = 0
        highlight.Parent = root

        local billboard = Instance.new("BillboardGui")
        billboard.Name = "NexusArtifactHolderLabel"
        billboard.Adornee = adornee
        billboard.AlwaysOnTop = true
        billboard.LightInfluence = 0
        billboard.Size = UDim2.fromOffset(240, 42)
        billboard.StudsOffset = Vector3.new(0, 3.2, 0)
        billboard.Parent = root

        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 14
        label.TextStrokeColor3 = Color3.new(0, 0, 0)
        label.TextStrokeTransparency = 0.2
        label.TextWrapped = true
        label.Parent = billboard

        entry = {character = character, highlight = highlight, billboard = billboard, label = label, adornee = adornee}
        artifactHolderESP.entries[player] = entry
    end

    entry.highlight.FillColor = color
    entry.highlight.OutlineColor = color
    entry.label.TextColor3 = color
    local distanceText = ""
    if localRoot then
        distanceText = string.format("  [%d studs]", math.floor((localRoot.Position - entry.adornee.Position).Magnitude + 0.5))
    end
    entry.label.Text = string.format("%s%s\n%s", player.DisplayName, distanceText, table.concat(names, "  •  "))
end

local function scanArtifactHolders()
    local Players = game:GetService("Players")
    local localCharacter = Player.Character
    local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
    local darkholdOwner = getDarkholdOwner()
    local active = {}

    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if character and humanoid and humanoid.Health > 0 then
            local names, color = getCharacterArtifacts(character, darkholdOwner)
            if #names > 0 then
                active[player] = true
                updateArtifactHolderEntry(player, character, names, color, localRoot)
            end
        end
    end

    local stale = {}
    for player in pairs(artifactHolderESP.entries) do
        if not active[player] then stale[#stale + 1] = player end
    end
    for _, player in ipairs(stale) do destroyArtifactHolderEntry(player) end
end

local function toggleArtifactHolderESP(value)
    artifactHolderESP.enabled = value == true
    if artifactHolderESP.enabled then
        scanArtifactHolders()
        if not artifactHolderESP.connection then
            artifactHolderESP.connection = game:GetService("RunService").Heartbeat:Connect(function(deltaTime)
                artifactHolderESP.elapsed += deltaTime
                if artifactHolderESP.elapsed < 0.25 then return end
                artifactHolderESP.elapsed = 0
                scanArtifactHolders()
            end)
        end
        return
    end

    if artifactHolderESP.connection then
        artifactHolderESP.connection:Disconnect()
        artifactHolderESP.connection = nil
    end
    artifactHolderESP.elapsed = 0
    artifactHolderESP.darkhold = nil
    artifactHolderESP.darkholdSearchAt = 0
    local players = {}
    for player in pairs(artifactHolderESP.entries) do players[#players + 1] = player end
    for _, player in ipairs(players) do destroyArtifactHolderEntry(player) end
    if artifactHolderESP.root then
        artifactHolderESP.root:Destroy()
        artifactHolderESP.root = nil
    end
    local stale = workspace:FindFirstChild("NexusArtifactHolderESP_Runtime")
    if stale then stale:Destroy() end
end

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
                    Fluent:Notify({
                        Title = "Teleport",
                        Content = "Teleported to " .. stoneName,
                        Duration = 3
                    })
                else
                    Fluent:Notify({
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
    toggleArtifactHolderESP(false)
end)
