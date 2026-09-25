local function safeUI(label, fn)
    local ok, err = pcall(fn)
    if not ok then
        warn("Marvel Omega [ESP/" .. label .. "]: " .. tostring(err))
    end
end

local Visual = {
    AdvancedESP = {
        settings = {
            enabled = false,
            name = false,
            distance = true,
            healthbar = true,
            box = true,
            boxType = "full",
            bones = true,
            boneColorName = "White",
            tracers = true,
            tracerColorName = "White",
            scale = 1.5,
            healthBarTopColorName = "DarkGreen",
            healthBarMidColorName = "DarkOrange",
            healthBarBottomColorName = "DarkRed",
            stateColorName = "Orange",
            boxOutline = true,
            boxOutlineColorName = "Black",
            boxOutlineThickness = 0.4,
            boxColorName = "White",
            boxFill = true,
            boxFillColorName = "White",
            boxFillTransparency = 0.9,
            healthBarLeftOffset = 10
        },
        colorMap = {
            Red = Color3.fromRGB(255,0,0),
            DarkRed = Color3.fromRGB(100,0,0),
            Green = Color3.fromRGB(0,255,0),
            DarkGreen = Color3.fromRGB(0,80,0),
            Blue = Color3.fromRGB(0,0,255),
            LightBlue = Color3.fromRGB(200,200,255),
            Yellow = Color3.fromRGB(255,255,0),
            Orange = Color3.fromRGB(255,165,0),
            DarkOrange = Color3.fromRGB(140,70,0),
            Purple = Color3.fromRGB(128,0,128),
            White = Color3.fromRGB(255,255,255),
            Black = Color3.fromRGB(0,0,0)
        },
        connections = {},
        espObjects = {}
    },
    Effects = {
        noShadowEnabled = false,
        noFogEnabled = false,
        fullbrightEnabled = false,
        saturationEnabled = false,
        saturationLevel = 5,
        originalFogEnd = nil,
        originalFogStart = nil,
        originalFogColor = nil,
        originalFogDensity = nil,
        timeChangerEnabled = false,
        originalClockTime = nil,
        timeChangerConnection = nil
    }
}

local function GetESPNumber(value, defaultValue, minValue, maxValue)
    local numberValue = tonumber(value)
    if numberValue == nil or numberValue ~= numberValue or numberValue == math.huge or numberValue == -math.huge then
        numberValue = defaultValue
    end
    if minValue ~= nil and numberValue < minValue then
        numberValue = minValue
    end
    if maxValue ~= nil and numberValue > maxValue then
        numberValue = maxValue
    end
    return numberValue
end

local function NormalizeAdvancedESPNumericSettings()
    local settings = Visual.AdvancedESP.settings
    settings.scale = GetESPNumber(settings.scale, 1.5, 0.25, 5)
    settings.boxOutlineThickness = GetESPNumber(settings.boxOutlineThickness, 0.4, 0, 10)
    settings.boxFillTransparency = GetESPNumber(settings.boxFillTransparency, 0.9, 0, 1)
    settings.healthBarLeftOffset = GetESPNumber(settings.healthBarLeftOffset, 10, 0, 100)
end

local ah, at, ae = false, {}, 0
local ultimateEnabled = false
local characterCache = {}
local renderElapsed = 0
local players = game:GetService("Players")

function Visual.ToggleAdvancedESP(v)
    NormalizeAdvancedESPNumericSettings()
    Visual.AdvancedESP.settings.enabled = v == true
    Visual.Refresh()
end

function Visual.ToggleArtifacts(v)
    ah = v == true
    ae = 0.25
    Visual.Refresh()
end

local function RemoveDrawingObject(object)
    if not object then
        return
    end
    pcall(function()
        object.Visible = false
    end)
    pcall(function()
        object:Remove()
    end)
end

function Visual.DestroyAdvancedESP(p)
    local d = Visual.AdvancedESP.espObjects[p]
    if not d then return end
    for k, o in pairs(d) do
        if k == "Bones" then
            for _, v in pairs(o) do RemoveDrawingObject(v) end
        elseif k ~= "Full" then RemoveDrawingObject(o) end
    end
    Visual.AdvancedESP.espObjects[p] = nil
    characterCache[p] = nil
end

function Visual.HideAdvancedESP(p)
    local d = Visual.AdvancedESP.espObjects[p]
    if not d then return end
    for k, o in pairs(d) do
        if k == "Bones" then
            for _, v in pairs(o) do v.Visible = false end
        elseif k ~= "Full" then o.Visible = false end
    end
end

function Visual.CreateAdvancedESP(p)
    local a = Visual.AdvancedESP
    local d = a.espObjects[p]
    if not d then d = {Bones = {}} a.espObjects[p] = d end
    local function add(k, t, v, dst)
        dst = dst or d
        local o = Drawing.new(t)
        dst[k] = o
        o.Visible = false
        for n, x in pairs(v) do o[n] = x end
        return o
    end
    if not d.Name then
        add("Name", "Text", {Size = 10, Center = true, Outline = true, Color = Color3.new(1, 1, 1)})
    end
    if ultimateEnabled and not d.Ultimate then
        add("Ultimate", "Text", {Size = 13, Center = true, Outline = true, Color = Color3.fromRGB(190, 85, 255)})
    end
    if not a.settings.enabled or d.Full then return d end
    add("BoxFill", "Square", {Thickness = 0, Filled = true})
    add("Distance", "Text", {Size = 10, Center = true, Outline = true, Color = Color3.new(0.8, 0.8, 0.8)})
    add("Tracer", "Line", {Thickness = 1.5})
    add("HealthBg", "Square", {Filled = true, Color = Color3.new(0, 0, 0), Transparency = 1})
    add("HealthBar", "Square", {Filled = true, Transparency = 1})
    add("HealthMask", "Square", {Filled = true, Color = Color3.new(0, 0, 0), Transparency = 0.3})
    add("HealthText", "Text", {Size = 9, Center = true, Outline = true, Color = Color3.new(1, 1, 1)})
    add("Box", "Square", {Thickness = 1.7, Filled = false})
    add("BoxOutline", "Square", {Filled = false})
    for i = 1, 14 do add(i, "Line", {Thickness = 1.5}, d.Bones) end
    for i = 1, 24 do add("HealthStripe" .. i, "Square", {Filled = true, Transparency = 1}) end
    d.Full = true
    return d
end

local function sync()
    local a, t = Visual.AdvancedESP, {}
    for _, p in ipairs(players:GetPlayers()) do
        if p ~= Player and (a.settings.enabled or a.settings.name or ultimateEnabled or ah and at[p]) then
            t[p] = true
            Visual.CreateAdvancedESP(p)
        end
    end
    for p in pairs(a.espObjects) do
        if not t[p] then Visual.DestroyAdvancedESP(p) end
    end
end

function Visual.GetHealthGradientColor(y, h)
    local settings = Visual.AdvancedESP.settings
    local colorMap = Visual.AdvancedESP.colorMap
    
    local t = 1 - (y / math.max(h, 1))
    if t >= 0.5 then
        local s = (t - 0.5) * 2
        local midColor = colorMap[settings.healthBarMidColorName] or colorMap.DarkOrange
        local topColor = colorMap[settings.healthBarTopColorName] or colorMap.DarkGreen
        return midColor:Lerp(topColor, s)
    else
        local s = t * 2
        local bottomColor = colorMap[settings.healthBarBottomColorName] or colorMap.DarkRed
        local midColor = colorMap[settings.healthBarMidColorName] or colorMap.DarkOrange
        return bottomColor:Lerp(midColor, s)
    end
end

function Visual.IsR6(char)
    return char:FindFirstChild("Torso") and not char:FindFirstChild("UpperTorso")
end

function Visual.UpdateAdvancedESP(dt)
    local settings = Visual.AdvancedESP.settings
    if not settings.enabled and not settings.name and not ah and not ultimateEnabled then return end
    ae += dt or 0
    if ae >= 0.25 then
        ae = 0
        at = ah and PrimeRuntime.GetArtifactHolders() or {}
        sync()
    end

    local scale = GetESPNumber(settings.scale, 1.5, 0.25, 5)
    local fillTransparency = GetESPNumber(settings.boxFillTransparency, 0.9, 0, 1)
    local outlineThickness = GetESPNumber(settings.boxOutlineThickness, 0.4, 0, 10)
    local healthBarLeftOffset = GetESPNumber(settings.healthBarLeftOffset, 10, 0, 100)
    
    local Camera = workspace.CurrentCamera
    if not Camera then
        for p in pairs(Visual.AdvancedESP.espObjects) do Visual.HideAdvancedESP(p) end
        return
    end
    local camPos = Camera.CFrame.Position
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
    
    for plr, d in pairs(Visual.AdvancedESP.espObjects) do
        if not plr or not plr.Parent then
            Visual.HideAdvancedESP(plr)
            continue
        end
        
        local char = plr.Character
        local cached = characterCache[plr]
        if not cached or cached.char ~= char then
            cached = {char = char}
            characterCache[plr] = cached
        end
        if char then
            if not cached.root or not cached.root.Parent then cached.root = char:FindFirstChild("HumanoidRootPart") end
            if not cached.head or not cached.head.Parent then cached.head = char:FindFirstChild("Head") end
            if not cached.hum or not cached.hum.Parent then cached.hum = char:FindFirstChildOfClass("Humanoid") end
        end
        local a = ah and at[plr]
        if a and a.char ~= char then a = nil end
        if char and cached.root and cached.head and cached.hum then
            local hum = cached.hum
            
            if hum and hum.Health <= 0 then
                Visual.HideAdvancedESP(plr)
                continue
            end
            
            local root = cached.root
            local head = cached.head

            local function screenPosOrNil(part)
                if part then
                    local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen and pos.Z > 0 then 
                        return Vector2.new(pos.X, pos.Y) 
                    end
                end
                return nil
            end

            local headPos, onScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
            local footPos = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 2.5, 0))

            if onScreen and headPos.Z > 0 and footPos.Z > 0 then
                local rawHeight = footPos.Y - headPos.Y
                local height = rawHeight * scale
                local width = (height / 2) * scale
                local x = headPos.X - width / 2
                local y = headPos.Y - (height - rawHeight) / 2

                if d.BoxFill then
                    d.BoxFill.Position = Vector2.new(x, y)
                    d.BoxFill.Size = Vector2.new(width, height)
                    d.BoxFill.Color = Visual.AdvancedESP.colorMap[settings.boxFillColorName] or Visual.AdvancedESP.colorMap.White
                    d.BoxFill.Filled = true
                    d.BoxFill.Transparency = 1 - fillTransparency
                    d.BoxFill.Visible = settings.boxFill and settings.enabled
                end

                if d.Box then
                    d.Box.Position = Vector2.new(x, y)
                    d.Box.Size = Vector2.new(width, height)
                    d.Box.Color = Visual.AdvancedESP.colorMap[settings.boxColorName] or Visual.AdvancedESP.colorMap.White
                    d.Box.Thickness = 1.7
                    d.Box.Visible = settings.box and settings.enabled
                end
                
                if d.BoxOutline then
                    local thickness = outlineThickness
                    d.BoxOutline.Position = Vector2.new(x - thickness, y - thickness)
                    d.BoxOutline.Size = Vector2.new(width + thickness * 2, height + thickness * 2)
                    d.BoxOutline.Color = Visual.AdvancedESP.colorMap[settings.boxOutlineColorName] or Visual.AdvancedESP.colorMap.Black
                    d.BoxOutline.Thickness = thickness
                    d.BoxOutline.Visible = settings.box and settings.boxOutline and settings.enabled
                end

                if d.Name then
                    d.Name.Text = a and (plr.Name .. "\n" .. a.text) or plr.Name
                    d.Name.Color = a and a.color or Color3.new(1, 1, 1)
                    d.Name.Size = 9.5
                    d.Name.Position = Vector2.new(headPos.X, y - (a and 34 or 22))
                    d.Name.Visible = settings.name or a ~= nil
                end

                if d.Ultimate then
                    local maximum = tonumber(char:GetAttribute("MaxUltCharge"))
                    local charge = tonumber(char:GetAttribute("UltCharge"))
                    local valid = maximum and maximum > 0 and maximum < math.huge and charge and charge == charge
                    d.Ultimate.Visible = ultimateEnabled and valid and true or false
                    if d.Ultimate.Visible then
                        local text = tostring(math.floor(math.clamp(charge / maximum, 0, 1) * 100 + 0.5)) .. "%"
                        if d.Ultimate.Text ~= text then d.Ultimate.Text = text end
                        d.Ultimate.Position = Vector2.new(headPos.X, y - (d.Name.Visible and (a and 51 or 39) or 20))
                    end
                end

                if d.Distance then
                    local dist = math.floor((root.Position - camPos).Magnitude)
                    d.Distance.Text = dist .. "m"
                    d.Distance.Size = 9.5
                    d.Distance.Position = Vector2.new(headPos.X, y + height + 6)
                    d.Distance.Visible = settings.distance and settings.enabled
                end

                if d.HealthBg and d.HealthBar and d.HealthText then
                    local barX = x - healthBarLeftOffset
                    local barY = y
                    local barWidth = 6
                    local barHeight = height
                    
                    d.HealthBg.Position = Vector2.new(barX, barY)
                    d.HealthBg.Size = Vector2.new(barWidth, barHeight)
                    d.HealthBg.Visible = settings.healthbar and settings.enabled
                    
                    if settings.healthbar and settings.enabled then
                        local HEALTH_STRIPES = 24
                        local hpPerc = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                        
                        for i = 1, HEALTH_STRIPES do
                            local stripe = d["HealthStripe"..i]
                            if stripe then
                                local stripeY = barY + barHeight * (i - 1) / HEALTH_STRIPES
                                local stripeH = barHeight / HEALTH_STRIPES
                                local stripeColor = Visual.GetHealthGradientColor(stripeY - barY, barHeight)
                                
                                stripe.Color = stripeColor
                                stripe.Position = Vector2.new(barX, stripeY)
                                stripe.Size = Vector2.new(barWidth, stripeH)
                                stripe.Visible = (HEALTH_STRIPES - i) / HEALTH_STRIPES < hpPerc
                            end
                        end
                        
                        d.HealthText.Text = tostring(math.floor(hum.Health))
                        d.HealthText.Size = 14
                        d.HealthText.Position = Vector2.new(x - healthBarLeftOffset - 14, y + height / 2)
                        d.HealthText.Visible = true
                    else
                        for i = 1, 24 do
                            if d["HealthStripe"..i] then
                                d["HealthStripe"..i].Visible = false
                            end
                        end
                        d.HealthText.Visible = false
                    end
                end

                if d.Bones and settings.enabled and settings.bones then
                    local bonesVisible = settings.bones and settings.enabled
                    local bones
                    
                    if Visual.IsR6(char) then
                        bones = {
                            {char:FindFirstChild("Head"), char:FindFirstChild("Torso")},
                            {char:FindFirstChild("Torso"), char:FindFirstChild("Left Arm")},
                            {char:FindFirstChild("Left Arm"), char:FindFirstChild("Left Leg")},
                            {char:FindFirstChild("Torso"), char:FindFirstChild("Right Arm")},
                            {char:FindFirstChild("Right Arm"), char:FindFirstChild("Right Leg")},
                            {char:FindFirstChild("Torso"), char:FindFirstChild("Left Leg")},
                            {char:FindFirstChild("Torso"), char:FindFirstChild("Right Leg")}
                        }
                    else
                        bones = {
                            {char:FindFirstChild("Head"), char:FindFirstChild("Neck")},
                            {char:FindFirstChild("Neck"), char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")},
                            {char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"), char:FindFirstChild("LeftUpperArm") or char:FindFirstChild("Left Arm")},
                            {char:FindFirstChild("LeftUpperArm") or char:FindFirstChild("Left Arm"), char:FindFirstChild("LeftLowerArm") or char:FindFirstChild("Left Forearm")},
                            {char:FindFirstChild("LeftLowerArm") or char:FindFirstChild("Left Forearm"), char:FindFirstChild("LeftHand") or char:FindFirstChild("Left hand")},
                            {char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"), char:FindFirstChild("RightUpperArm") or char:FindFirstChild("Right Arm")},
                            {char:FindFirstChild("RightUpperArm") or char:FindFirstChild("Right Arm"), char:FindFirstChild("RightLowerArm") or char:FindFirstChild("Right Forearm")},
                            {char:FindFirstChild("RightLowerArm") or char:FindFirstChild("Right Forearm"), char:FindFirstChild("RightHand") or char:FindFirstChild("Right hand")},
                            {char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"), char:FindFirstChild("LeftUpperLeg") or char:FindFirstChild("Left Leg")},
                            {char:FindFirstChild("LeftUpperLeg") or char:FindFirstChild("Left Leg"), char:FindFirstChild("LeftLowerLeg") or char:FindFirstChild("Left Shin")},
                            {char:FindFirstChild("LeftLowerLeg") or char:FindFirstChild("Left Shin"), char:FindFirstChild("LeftFoot") or char:FindFirstChild("Left foot")},
                            {char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"), char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("Right Leg")},
                            {char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("Right Leg"), char:FindFirstChild("RightLowerLeg") or char:FindFirstChild("Right Shin")},
                            {char:FindFirstChild("RightLowerLeg") or char:FindFirstChild("Right Shin"), char:FindFirstChild("RightFoot") or char:FindFirstChild("Right foot")}
                        }
                    end
                    
                    for i = 1, 14 do
                        local line = d.Bones[i]
                        if line and bones[i] and bones[i][1] and bones[i][2] then
                            local p1 = screenPosOrNil(bones[i][1])
                            local p2 = screenPosOrNil(bones[i][2])
                            if p1 and p2 then
                                line.From = p1
                                line.To = p2
                                line.Color = Visual.AdvancedESP.colorMap[settings.boneColorName] or Visual.AdvancedESP.colorMap.White
                                line.Visible = bonesVisible
                            else
                                line.Visible = false
                            end
                        elseif line then
                            line.Visible = false
                        end
                    end
                elseif d.Bones then
                    for _, bone in pairs(d.Bones) do bone.Visible = false end
                end

                if d.Tracer then
                    local rootPos2D = Vector2.new(headPos.X, headPos.Y)
                    d.Tracer.From = screenCenter
                    d.Tracer.To = rootPos2D
                    d.Tracer.Color = Visual.AdvancedESP.colorMap[settings.tracerColorName] or Visual.AdvancedESP.colorMap.White
                    d.Tracer.Visible = settings.tracers and settings.enabled
                end
            else
                Visual.HideAdvancedESP(plr)
            end
        else
            Visual.HideAdvancedESP(plr)
        end
    end
end

function Visual.StopAdvancedESP()
    local a = Visual.AdvancedESP
    for _, c in pairs(a.connections) do pcall(function() c:Disconnect() end) end
    table.clear(a.connections)
    for p in pairs(a.espObjects) do Visual.DestroyAdvancedESP(p) end
    at, ae = {}, 0
    renderElapsed = 0
    table.clear(characterCache)
end

function Visual.Refresh()
    local a = Visual.AdvancedESP
    if PrimeRuntime.IsShuttingDown or not (a.settings.enabled or a.settings.name or ah or ultimateEnabled) then
        Visual.StopAdvancedESP()
        return
    end
    local function step(dt)
        renderElapsed += dt
        local interval = IS_MOBILE and 1 / 30 or 1 / 60
        if dt > 0 and renderElapsed < interval then return end
        local elapsed = renderElapsed
        renderElapsed = 0
        local ok, e = pcall(function()
            assert(Drawing and type(Drawing.new) == "function", "Drawing API unavailable")
            Visual.UpdateAdvancedESP(elapsed)
        end)
        if not ok then
            a.settings.enabled, a.settings.name, ah, ultimateEnabled = false, false, false, false
            Visual.StopAdvancedESP()
            warn("[PRIME ESP] " .. tostring(e))
            for _, n in ipairs({"AdvancedESP", "ESPNames", "ArtifactHolderESP", "UltimateChargeESP"}) do
                local o = Options[n]
                if o and o.Value then pcall(function() o:SetValue(false) end) end
            end
        end
    end
    if not a.connections.renderStepped then
        a.connections.renderStepped = game:GetService("RunService").RenderStepped:Connect(step)
    end
    ae = 0.25
    step(0)
end

function Visual.ToggleNoShadow(enabled)
    Visual.Effects.noShadowEnabled = enabled
    if enabled then
        for _, light in ipairs(game:GetService("Lighting"):GetDescendants()) do 
            if light:IsA("Light") then 
                light.Shadows = false 
            end 
        end
        game:GetService("Lighting").GlobalShadows = false
    else
        for _, light in ipairs(game:GetService("Lighting"):GetDescendants()) do 
            if light:IsA("Light") then 
                light.Shadows = true 
            end 
        end
        game:GetService("Lighting").GlobalShadows = true
    end
end

function Visual.ToggleNoFog(enabled)
    Visual.Effects.noFogEnabled = enabled
    
    if enabled then
        local lighting = game:GetService("Lighting")
        
        if not Visual.Effects.originalFogEnd then
            Visual.Effects.originalFogEnd = lighting.FogEnd
            Visual.Effects.originalFogStart = lighting.FogStart
            Visual.Effects.originalFogColor = lighting.FogColor
            Visual.Effects.originalFogDensity = lighting.FogDensity
        end
        
        lighting.FogEnd = 10000000
        lighting.FogStart = 0
        lighting.FogDensity = 0
    else
        local lighting = game:GetService("Lighting")
        
        if Visual.Effects.originalFogEnd then
            lighting.FogEnd = Visual.Effects.originalFogEnd
            lighting.FogStart = Visual.Effects.originalFogStart
            lighting.FogColor = Visual.Effects.originalFogColor
            lighting.FogDensity = Visual.Effects.originalFogDensity
            
            Visual.Effects.originalFogEnd = nil
            Visual.Effects.originalFogStart = nil
            Visual.Effects.originalFogColor = nil
            Visual.Effects.originalFogDensity = nil
        end
    end
end

function Visual.ToggleSaturation(enabled)
    Visual.Effects.saturationEnabled = enabled
    
    if enabled then
        Visual.UpdateSaturation()
    else
        local lighting = game:GetService("Lighting")
        
        local colorCorrection = lighting:FindFirstChild("SaturationEffect")
        if colorCorrection then
            colorCorrection:Destroy()
        end
    end
end

function Visual.UpdateSaturation()
    if not Visual.Effects.saturationEnabled then return end
    
    local lighting = game:GetService("Lighting")
    
    local colorCorrection = lighting:FindFirstChild("SaturationEffect")
    if not colorCorrection then
        colorCorrection = Instance.new("ColorCorrectionEffect")
        colorCorrection.Name = "SaturationEffect"
        colorCorrection.Parent = lighting
    end
    
    local saturationValue = Visual.Effects.saturationLevel / 5
    colorCorrection.Saturation = saturationValue
end

function Visual.ToggleTimeChanger(enabled)
    local effects = Visual.Effects
    local lighting = game:GetService("Lighting")
    effects.timeChangerEnabled = enabled == true

    if effects.timeChangerConnection then
        effects.timeChangerConnection:Disconnect()
        effects.timeChangerConnection = nil
    end

    if effects.timeChangerEnabled then
        if effects.originalClockTime == nil then
            effects.originalClockTime = lighting.ClockTime
        end

        local function enforceSelectedTime()
            if not effects.timeChangerEnabled then
                return
            end

            local selectedTime = Options.TimeValue and Options.TimeValue.Value or 14
            if math.abs(lighting.ClockTime - selectedTime) > 0.001 then
                lighting.ClockTime = selectedTime
            end
        end

        enforceSelectedTime()

        effects.timeChangerConnection = lighting:GetPropertyChangedSignal("ClockTime"):Connect(enforceSelectedTime)
    else
        if effects.originalClockTime ~= nil then
            lighting.ClockTime = effects.originalClockTime
            effects.originalClockTime = nil
        end
    end
end

function Visual.SetTime(time)
    game:GetService("Lighting").ClockTime = time
end

local function toggleUlt(value)
    ultimateEnabled = value == true
    Visual.Refresh()
end

function Visual.Cleanup()
    ultimateEnabled = false
    ah = false
    Visual.AdvancedESP.settings.enabled = false
    Visual.AdvancedESP.settings.name = false
    Visual.StopAdvancedESP()
    Visual.ToggleNoShadow(false)
    Visual.ToggleNoFog(false)
    Visual.ToggleSaturation(false)
    Visual.ToggleTimeChanger(false)

    for _, connection in pairs(Visual.AdvancedESP.connections) do
        pcall(function() connection:Disconnect() end)
    end
    Visual.AdvancedESP.connections = {}
end

do
    safeUI("Visual section", function()
        Tabs.ESP:AddSection("Visual & ESP")
    end)

    safeUI("ESPStonesToggle", function()
        local ESPStonesToggle = Tabs.ESP:AddToggle("ESPStonesToggle", {
            Title = "Esp Stones",
            Description = "Highlight TimeStone, PowerStone and SpaceStone with distance",
            Default = false
        })
        ESPStonesToggle:OnChanged(function(value)
            PrimeRuntime.toggleESPStones(value)
        end)
    end)

    safeUI("CollectibleESPBoxToggle", function()
        local CollectibleESPBoxToggle = Tabs.ESP:AddToggle("CollectibleESPBoxToggle", {
            Title = "ESP Box",
            Description = "Highlight AutoCollect objects and show distance",
            Default = false
        })
        CollectibleESPBoxToggle:OnChanged(function(value)
            PrimeRuntime.toggleESPBoxes(value)
        end)
    end)
    
    safeUI("NoShadow", function()
        local NoShadowToggle = Tabs.ESP:AddToggle("NoShadow", {
            Title = "No Shadow", 
            Description = "Remove shadows in the game", 
            Default = false
        })
        NoShadowToggle:OnChanged(function(v) Visual.ToggleNoShadow(v) end)
    end)

    safeUI("Saturation", function()
        local SaturationToggle = Tabs.ESP:AddToggle("Saturation", {
            Title = "Saturation", 
            Description = "Increase color saturation", 
            Default = false
        })
        SaturationToggle:OnChanged(function(v) 
            Visual.ToggleSaturation(v)
        end)
    end)

    safeUI("SaturationLevel", function()
        local SaturationSlider = Tabs.ESP:AddSlider("SaturationLevel", {
            Title = "Saturation Level", 
            Description = "Adjust saturation intensity",
            Default = 5,
            Min = 1,
            Max = 10,
            Rounding = 0,
            Callback = function(value)
                Visual.Effects.saturationLevel = value
                if Visual.Effects.saturationEnabled then
                    Visual.UpdateSaturation()
                end
            end
        })
    end)

    safeUI("TimeChanger", function()
        local TimeChangerToggle = Tabs.ESP:AddToggle("TimeChanger", {
            Title = "Time Changer", 
            Description = "Change the time of day", 
            Default = false
        })

        local TimeSlider = Tabs.ESP:AddSlider("TimeValue", {
            Title = "Time of Day", 
            Description = "Change the time of day (24 hours)",
            Default = 14,
            Min = 0,
            Max = 24,
            Rounding = 1,
            Callback = function(value)
                if Options.TimeChanger and Options.TimeChanger.Value then
                    Visual.SetTime(value)
                end
            end
        })

        TimeChangerToggle:OnChanged(function(v)
            Visual.ToggleTimeChanger(v)
        end)
    end)

    safeUI("ArtifactHolderESP", function()
        local ArtifactHolderESPToggle = Tabs.ESP:AddToggle("ArtifactHolderESP", {
            Title = "Artifact Holder ESP",
            Description = "Colored Drawing names for artifact holders",
            Default = false
        })
        ArtifactHolderESPToggle:OnChanged(function()
            Visual.ToggleArtifacts(Options.ArtifactHolderESP.Value)
        end)
    end)

    safeUI("Combat ESP section", function()
        Tabs.ESP:AddSection("Combat ESP")
    end)
    safeUI("UltimateChargeESP", function()
        local t = Tabs.ESP:AddToggle("UltimateChargeESP", {
            Title = "Ultimate Charge ESP", Description = "Drawing ultimate percentage above players", Default = false
        })
        t:OnChanged(toggleUlt)
    end)

    safeUI("Player ESP section", function()
        Tabs.ESP:AddSection("Player ESP")
    end)

    safeUI("AdvancedESP", function()
        local AdvancedESPToggle = Tabs.ESP:AddToggle("AdvancedESP", {
            Title = "Advanced ESP",
            Description = "Boxes, health, distance, bones and tracers",
            Default = false
        })
        AdvancedESPToggle:OnChanged(function(v)
            Visual.ToggleAdvancedESP(v)
        end)
    end)

    safeUI("ESPBox", function()
        local ESPBoxToggle = Tabs.ESP:AddToggle("ESPBox", {
            Title = "Player Boxes", 
            Description = "Show/hide player boxes", 
            Default = true
        })
        ESPBoxToggle:OnChanged(function(v)
            Visual.AdvancedESP.settings.box = v
        end)
    end)

    safeUI("ESPNames", function()
        local ESPNamesToggle = Tabs.ESP:AddToggle("ESPNames", {
            Title = "Player Names", 
            Description = "Drawing names for all players", 
            Default = false
        })
        ESPNamesToggle:OnChanged(function(v)
            Visual.AdvancedESP.settings.name = v
            Visual.Refresh()
        end)
    end)

    safeUI("ESPHealthBar", function()
        local ESPHealthBarToggle = Tabs.ESP:AddToggle("ESPHealthBar", {
            Title = "Health Bar", 
            Description = "Show/hide health bar", 
            Default = true
        })
        ESPHealthBarToggle:OnChanged(function(v)
            Visual.AdvancedESP.settings.healthbar = v
        end)
    end)

    safeUI("ESPDistance", function()
        local ESPDistanceToggle = Tabs.ESP:AddToggle("ESPDistance", {
            Title = "Distance", 
            Description = "Show/hide distance to players", 
            Default = true
        })
        ESPDistanceToggle:OnChanged(function(v)
            Visual.AdvancedESP.settings.distance = v
        end)
    end)

    safeUI("ESPBoxFill", function()
        local ESPBoxFillToggle = Tabs.ESP:AddToggle("ESPBoxFill", {
            Title = "Filled Box", 
            Description = "Show/hide filled boxes", 
            Default = true
        })
        ESPBoxFillToggle:OnChanged(function(v)
            Visual.AdvancedESP.settings.boxFill = v
        end)
    end)

    safeUI("ESPTracers", function()
        local ESPTracersToggle = Tabs.ESP:AddToggle("ESPTracers", {
            Title = "Tracers", 
            Description = "Show/hide tracers to players", 
            Default = true
        })
        ESPTracersToggle:OnChanged(function(v)
            Visual.AdvancedESP.settings.tracers = v
        end)
    end)

    safeUI("ESPBones", function()
        local ESPBonesToggle = Tabs.ESP:AddToggle("ESPBones", {
            Title = "Player Bones", 
            Description = "Show/hide player bones", 
            Default = true
        })
        ESPBonesToggle:OnChanged(function(v)
            Visual.AdvancedESP.settings.bones = v
        end)
    end)
end

TrackRuntimeCleanup(function()
    Visual.Cleanup()
end)
