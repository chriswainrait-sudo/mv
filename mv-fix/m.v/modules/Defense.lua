local defenseEnabled = false
local autoCounterEnabled = false
local defenseRange = 65
local defenseReaction = 0.03
local defenseLastUse = 0
local defenseAbilityEnabled = {
    KineticParry = true,
    CosmicBlock = true,
    OpticalBlock = true,
    ChaosShield = true,
    SW_ChaosBubble = true,
    EldritchShield = true,
    BubbleShield = true,
    HeatShield = true,
    HexCounter = true,
    Phasing = true
}

local projectileWords = {"projectile", "missile", "arrow", "bolt", "meteor", "fireball", "orb", "beam", "blast", "rocket", "grenade", "rock", "hazard", "damagezone", "hitbox", "aoe"}
local hazardWords = {"hazard", "damagezone", "hitbox", "aoe"}

local function getWorldPart(instance)
    if not instance then return nil end
    if instance:IsA("BasePart") then return instance end
    if instance:IsA("Model") then
        return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local function isLikelyProjectile(instance)
    if not instance or not (instance:IsA("Model") or instance:IsA("BasePart")) then return false end
    local name = string.lower(instance.Name)
    local named = false
    for _, word in ipairs(projectileWords) do
        if string.find(name, word, 1, true) then named = true break end
    end
    local tagged = instance:HasTag("Projectile") or instance:HasTag("ClientOwned")
    local attributed = instance:GetAttribute("Projectile") ~= nil or instance:GetAttribute("SourceID") ~= nil
    local part = getWorldPart(instance)
    local hazard = false
    local lowerName = string.lower(instance.Name)
    for _, word in ipairs(hazardWords) do
        if string.find(lowerName, word, 1, true) then hazard = true break end
    end
    return part ~= nil and (tagged or attributed or named)
        and (hazard or not part.Anchored or part.AssemblyLinearVelocity.Magnitude > 2)
end

PrimeRuntime.getWorldPart = getWorldPart
PrimeRuntime.isLikelyProjectile = isLikelyProjectile

local dangerCandidates = setmetatable({}, {__mode = "k"})
local function registerDangerCandidate(object)
    if isLikelyProjectile(object) then dangerCandidates[object] = true end
end
for _, object in ipairs(workspace:GetDescendants()) do registerDangerCandidate(object) end
TrackRuntimeConnection(workspace.DescendantAdded:Connect(function(object)
    task.defer(registerDangerCandidate, object)
end))

local function hasAttackAnimation(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if not animator then return false end
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local animation = track.Animation
        local name = string.lower((animation and animation.Name) or "")
        if track.IsPlaying and track.WeightCurrent > 0.05
            and not string.find(name, "idle", 1, true)
            and not string.find(name, "walk", 1, true)
            and not string.find(name, "run", 1, true)
            and not string.find(name, "jump", 1, true)
            and not string.find(name, "fall", 1, true)
            and not string.find(name, "fly", 1, true) then
            return true
        end
    end
    return false
end

local function getDirectedThreat()
    local character = Player.Character
    local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
    if not root then return nil end
    for _, other in ipairs(game:GetService("Players"):GetPlayers()) do
        local enemy = other ~= Player and other.Character
        local enemyRoot = enemy and (enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart)
        local humanoid = enemy and enemy:FindFirstChildOfClass("Humanoid")
        if enemyRoot and humanoid and humanoid.Health > 0 then
            local offset = root.Position - enemyRoot.Position
            if offset.Magnitude <= defenseRange and offset.Magnitude > 0.01
                and enemyRoot.CFrame.LookVector:Dot(offset.Unit) > 0.25
                and hasAttackAnimation(enemy) then
                return enemy
            end
        end
    end
    for object in pairs(dangerCandidates) do
        if object.Parent and isLikelyProjectile(object) and not object:IsDescendantOf(character) then
            local part = getWorldPart(object)
            local offset = root.Position - part.Position
            local velocity = part.AssemblyLinearVelocity
            if offset.Magnitude <= defenseRange and velocity.Magnitude > 4
                and offset.Magnitude > 0.01 and velocity.Unit:Dot(offset.Unit) > 0.45 then
                return object
            end
        end
    end
    return nil
end

local function getEquippedDefense()
    local character = Player.Character
    local folder = character and character:FindFirstChild("AbilityFolder")
    local ability = folder and folder:GetAttribute("Ability1")
    return defenseAbilityEnabled[ability] and ability or nil
end

task.spawn(function()
    while not PrimeRuntime.IsShuttingDown do
        if defenseEnabled or autoCounterEnabled then
            local ability = getEquippedDefense()
            local threat = ability and getDirectedThreat()
            local interval = autoCounterEnabled and 0.32 or 0.48
            if threat and os.clock() - defenseLastUse >= interval then
                AbilitiesModule = AbilitiesModule or getGameModule("Abilities")
                local ready = true
                if AbilitiesModule and type(AbilitiesModule.GetCooldownRemaining) == "function" then
                    local ok, remaining = pcall(AbilitiesModule.GetCooldownRemaining, ability)
                    ready = not ok or not remaining or remaining <= 0
                end
                if ready then
                    defenseLastUse = os.clock()
                    if defenseReaction > 0 then task.wait(defenseReaction) end
                    pulseAction("Ability1", autoCounterEnabled and 0.12 or 0.28)
                end
            end
        end
        task.wait(0.04)
    end
end)

TrackRuntimeCleanup(function()
    defenseEnabled = false
    autoCounterEnabled = false
    simulateAction("Ability1", false)
end)

do
    Tabs.Defense:AddSection("Automatic Defense")
    local SmartBlockToggle = Tabs.Defense:AddToggle("SmartAutoBlock", {
        Title = "Smart Auto Block",
        Description = "Block directed attacks and incoming projectiles",
        Default = false
    })
    SmartBlockToggle:OnChanged(function() defenseEnabled = Options.SmartAutoBlock.Value end)

    local AutoCounterToggle = Tabs.Defense:AddToggle("AutoCounter", {
        Title = "Auto Counter",
        Description = "Use the equipped counter with tighter timing",
        Default = false
    })
    AutoCounterToggle:OnChanged(function() autoCounterEnabled = Options.AutoCounter.Value end)

    Tabs.Defense:AddSlider("DefenseRange", {
        Title = "Detection Range",
        Description = "Attack and projectile detection radius",
        Default = 65,
        Min = 15,
        Max = 150,
        Rounding = 0,
        Callback = function(value) defenseRange = value end
    })
    Tabs.Defense:AddSlider("DefenseReaction", {
        Title = "Reaction Delay",
        Description = "Delay before defensive action in milliseconds",
        Default = 30,
        Min = 0,
        Max = 250,
        Rounding = 0,
        Callback = function(value) defenseReaction = value / 1000 end
    })

    Tabs.Defense:AddSection("Character Defenses")
    local defenses = {
        {"JeanParry", "Auto Parry | Jean Grey", "KineticParry"},
        {"MonicaBlock", "Auto Cosmic Block | Monica", "CosmicBlock"},
        {"CyclopsBlock", "Auto Optical Block | Cyclops", "OpticalBlock"},
        {"WandaShield", "Auto Chaos Shield | Wanda", "ChaosShield"},
        {"StrangeShield", "Auto Eldritch Shield | Doctor Strange", "EldritchShield"},
        {"InvisibleShield", "Auto Bubble Shield | Invisible Woman", "BubbleShield"},
        {"TorchShield", "Auto Heat Shield | Human Torch", "HeatShield"},
        {"WiccanCounter", "Auto Hex Counter | Wiccan", "HexCounter"},
        {"VisionPhasing", "Auto Phasing | Vision", "Phasing"}
    }
    for _, defense in ipairs(defenses) do
        local optionId, title, ability = table.unpack(defense)
        local toggle = Tabs.Defense:AddToggle(optionId, {Title = title, Default = true})
        toggle:OnChanged(function()
            defenseAbilityEnabled[ability] = Options[optionId].Value
            if ability == "ChaosShield" then defenseAbilityEnabled.SW_ChaosBubble = Options[optionId].Value end
        end)
    end
end
