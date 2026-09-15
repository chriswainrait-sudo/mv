local Visual = {
    AdvancedESP = {
        settings = {
            enabled = false,
            name = true,
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
        espObjects = {},
        playerConnections = {}
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

function Visual.ToggleAdvancedESP(enabled)
    NormalizeAdvancedESPNumericSettings()
    Visual.AdvancedESP.settings.enabled = enabled
    
    if enabled then
        Visual.StartAdvancedESP()
    else
        Visual.StopAdvancedESP()
    end
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

function Visual.DestroyAdvancedESP(plr)
    local d = Visual.AdvancedESP.espObjects[plr]
    if not d then
        return
    end

    local directObjects = {
        d.BoxFill, d.Name, d.Distance, d.Tracer, d.HealthBg,
        d.HealthBar, d.HealthMask, d.HealthText, d.Box, d.BoxOutline
    }
    for _, object in ipairs(directObjects) do
        RemoveDrawingObject(object)
    end

    if d.Bones then
        for _, object in ipairs(d.Bones) do
            RemoveDrawingObject(object)
        end
    end

    for i = 1, 24 do
        RemoveDrawingObject(d["HealthStripe" .. i])
    end

    Visual.AdvancedESP.espObjects[plr] = nil
end

function Visual.HideAdvancedESP(plr)
    local d = Visual.AdvancedESP.espObjects[plr]
    if d then
        local drawingObjects = {
            d.BoxFill, d.Name, d.Distance, d.Tracer, d.HealthBg, 
            d.HealthBar, d.HealthMask, d.HealthText, d.Box, d.BoxOutline
        }
        
        for _, obj in ipairs(drawingObjects) do
            if obj then
                pcall(function() 
                    obj.Visible = false 
                end)
            end
        end
        
        for i = 1, 24 do
            if d["HealthStripe"..i] then
                pcall(function() 
                    d["HealthStripe"..i].Visible = false 
                end)
            end
        end
        
        if d.Bones then
            for _, bone in ipairs(d.Bones) do
                if bone then
                    pcall(function() 
                        bone.Visible = false 
                    end)
                end
            end
        end
    end
end

function Visual.CreateAdvancedESP(plr)
    if Visual.AdvancedESP.espObjects[plr] then
        Visual.HideAdvancedESP(plr)
        return Visual.AdvancedESP.espObjects[plr]
    end
    
    local settings = Visual.AdvancedESP.settings
    NormalizeAdvancedESPNumericSettings()
    local fillTransparency = GetESPNumber(settings.boxFillTransparency, 0.9, 0, 1)
    local outlineThickness = GetESPNumber(settings.boxOutlineThickness, 0.4, 0, 10)
    local colorMap = Visual.AdvancedESP.colorMap
    
    local boneColor = colorMap[settings.boneColorName] or colorMap.White
    local tracerColor = colorMap[settings.tracerColorName] or colorMap.White
    local boxColor = colorMap[settings.boxColorName] or colorMap.White
    local boxOutlineColor = colorMap[settings.boxOutlineColorName] or colorMap.Black
    local boxFillColor = colorMap[settings.boxFillColorName] or colorMap.White
    
    local function create(tp, props)
        local o = Drawing.new(tp)
        for i,v in pairs(props) do o[i]=v end
        return o
    end
    
    local d = {
        Bones = {},
        BoxFill = nil,
        Name = nil,
        Distance = nil,
        Tracer = nil,
        HealthBg = nil,
        HealthBar = nil,
        HealthMask = nil,
        HealthText = nil,
        Box = nil,
        BoxOutline = nil
    }
    
    d.BoxFill = create("Square",{
        Thickness = 0,
        Color = boxFillColor,
        Visible = false,
        Filled = true,
        Transparency = 1 - fillTransparency
    })
    
    d.Name = create("Text",{
        Size = 10,
        Center = true,
        Outline = true,
        Color = Color3.new(1,1,1),
        Visible = false
    })
    
    d.Distance = create("Text",{
        Size = 10,
        Center = true,
        Outline = true,
        Color = Color3.new(0.8,0.8,0.8),
        Visible = false
    })
    
    d.Tracer = create("Line",{
        Thickness = 1.5,
        Color = tracerColor,
        Visible = false
    })
    
    d.HealthBg = Drawing.new("Square")
    d.HealthBg.Visible = false
    d.HealthBg.Filled = true
    d.HealthBg.Color = Color3.new(0,0,0)
    d.HealthBg.Transparency = 1
    
    d.HealthBar = Drawing.new("Square")
    d.HealthBar.Visible = false
    d.HealthBar.Filled = true
    d.HealthBar.Transparency = 1
    
    d.HealthMask = Drawing.new("Square")
    d.HealthMask.Visible = false
    d.HealthMask.Filled = true
    d.HealthMask.Color = Color3.new(0,0,0)
    d.HealthMask.Transparency = 0.3
    
    d.HealthText = create("Text",{
        Size = 9,
        Center = true,
        Outline = true,
        Color = Color3.new(1,1,1),
        Visible = false
    })
    
    d.Box = create("Square", {
        Thickness = 1.7,
        Color = boxColor,
        Visible = false,
        Filled = false
    })
    
    d.BoxOutline = create("Square", {
        Thickness = 1.7 + outlineThickness * 2,
        Color = boxOutlineColor,
        Visible = false,
        Filled = false
    })
    
    for i = 1, 14 do
        d.Bones[i] = create("Line", {
            Thickness = 1.5,
            Color = boneColor,
            Visible = false
        })
    end
    
    for i = 1, 24 do
        d["HealthStripe"..i] = Drawing.new("Square")
        d["HealthStripe"..i].Visible = false
        d["HealthStripe"..i].Filled = true
        d["HealthStripe"..i].Transparency = 1
    end
    
    Visual.AdvancedESP.espObjects[plr] = d
    
    if not Visual.AdvancedESP.playerConnections[plr] then
        Visual.AdvancedESP.playerConnections[plr] = {}
    end
    
    return d
end

function Visual.SetupPlayerAdvancedESP(plr)
    local localPlayer = game:GetService("Players").LocalPlayer
    if plr == localPlayer then return end
    
    Visual.CreateAdvancedESP(plr)
    
    local function handleCharacterChanged()
        Visual.HideAdvancedESP(plr)
    end
    
    local charAddedConnection = plr.CharacterAdded:Connect(handleCharacterChanged)
    
    local charRemovingConnection = plr.CharacterRemoving:Connect(function()
        Visual.HideAdvancedESP(plr)
    end)
    
    local ancestryChangedConnection = plr.AncestryChanged:Connect(function(_, parent)
        if not parent then
            Visual.HideAdvancedESP(plr)
            if Visual.AdvancedESP.playerConnections[plr] then
                for _, conn in pairs(Visual.AdvancedESP.playerConnections[plr]) do
                    pcall(function() conn:Disconnect() end)
                end
                Visual.AdvancedESP.playerConnections[plr] = nil
            end
        end
    end)
    
    Visual.AdvancedESP.playerConnections[plr] = {
        charAdded = charAddedConnection,
        charRemoving = charRemovingConnection,
        ancestryChanged = ancestryChangedConnection
    }
    
    if plr.Character then
        task.spawn(function()
            wait(0.5)
            if not Visual.AdvancedESP.espObjects[plr] then
                Visual.CreateAdvancedESP(plr)
            end
        end)
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

function Visual.UpdateAdvancedESP()
    local settings = Visual.AdvancedESP.settings
    if not settings.enabled then return end

    local scale = GetESPNumber(settings.scale, 1.5, 0.25, 5)
    local fillTransparency = GetESPNumber(settings.boxFillTransparency, 0.9, 0, 1)
    local outlineThickness = GetESPNumber(settings.boxOutlineThickness, 0.4, 0, 10)
    local healthBarLeftOffset = GetESPNumber(settings.healthBarLeftOffset, 10, 0, 100)
    
    local Camera = workspace.CurrentCamera
    if not Camera then return end
    local camPos = Camera.CFrame.Position
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
    
    for plr, d in pairs(Visual.AdvancedESP.espObjects) do
        if not plr or not plr.Parent then
            Visual.HideAdvancedESP(plr)
            continue
        end
        
        local char = plr.Character
        if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Head") and char:FindFirstChildOfClass("Humanoid") then
            local hum = char:FindFirstChildOfClass("Humanoid")
            
            if hum and hum.Health <= 0 then
                Visual.HideAdvancedESP(plr)
                continue
            end
            
            local root = char.HumanoidRootPart
            local head = char.Head

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

            if onScreen then
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
                    d.Name.Text = plr.Name
                    d.Name.Size = 9.5
                    d.Name.Position = Vector2.new(headPos.X, y - 22)
                    d.Name.Visible = settings.name and settings.enabled
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
                        local hpPerc = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                        
                        for i = 1, HEALTH_STRIPES do
                            local stripe = d["HealthStripe"..i]
                            if stripe then
                                local stripeY = barY + barHeight * (i - 1) / HEALTH_STRIPES
                                local stripeH = barHeight / HEALTH_STRIPES
                                local stripeColor = Visual.GetHealthGradientColor(stripeY - barY, barHeight)
                                
                                stripe.Color = stripeColor
                                stripe.Position = Vector2.new(barX, stripeY)
                                stripe.Size = Vector2.new(barWidth, stripeH)
                                stripe.Visible = (i - 1) / HEALTH_STRIPES < hpPerc
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

                if d.Bones then
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

function Visual.StartAdvancedESP()
    if Visual.AdvancedESP.connections.renderStepped then
        Visual.AdvancedESP.connections.renderStepped:Disconnect()
        Visual.AdvancedESP.connections.renderStepped = nil
    end
    
    Visual.AdvancedESP.connections.playerAdded = game:GetService("Players").PlayerAdded:Connect(function(plr)
        if plr ~= game:GetService("Players").LocalPlayer then
            Visual.SetupPlayerAdvancedESP(plr)
        end
    end)
    
    Visual.AdvancedESP.connections.playerRemoving = game:GetService("Players").PlayerRemoving:Connect(function(plr)
        Visual.DestroyAdvancedESP(plr)
        if Visual.AdvancedESP.playerConnections[plr] then
            for _, conn in pairs(Visual.AdvancedESP.playerConnections[plr]) do
                pcall(function() conn:Disconnect() end)
            end
            Visual.AdvancedESP.playerConnections[plr] = nil
        end
    end)
    
    for _, plr in pairs(game:GetService("Players"):GetPlayers()) do
        if plr ~= game:GetService("Players").LocalPlayer then
            Visual.SetupPlayerAdvancedESP(plr)
        end
    end
    
    Visual.AdvancedESP.connections.renderStepped = game:GetService("RunService").RenderStepped:Connect(function()
        local ok, err = xpcall(Visual.UpdateAdvancedESP, function(message) return tostring(message) end)
        if not ok then
            warn("[PRIME ESP] Update error:\n" .. tostring(err))
            Visual.StopAdvancedESP()
            Visual.AdvancedESP.settings.enabled = false
            local option = Options and Options.AdvancedESP
            if option and option.Value then
                pcall(function()
                    option:SetValue(false)
                end)
            end
        end
    end)
end

function Visual.StopAdvancedESP()
    for _, connection in pairs(Visual.AdvancedESP.connections) do
        pcall(function() connection:Disconnect() end)
    end
    Visual.AdvancedESP.connections = {}
    
    local espPlayers = {}
    for plr in pairs(Visual.AdvancedESP.espObjects) do
        table.insert(espPlayers, plr)
    end
    for _, plr in ipairs(espPlayers) do
        Visual.DestroyAdvancedESP(plr)
    end
    
    for plr, connections in pairs(Visual.AdvancedESP.playerConnections) do
        for _, conn in pairs(connections) do
            pcall(function() conn:Disconnect() end)
        end
    end
    Visual.AdvancedESP.playerConnections = {}
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
        -- No idle polling. This connection only runs when the game itself changes ClockTime.
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

local combatESPEnabled = {
    Boss = false,
    NPC = false,
    Shield = false,
    Ultimate = false,
    Projectile = false
}
local combatESPEntries = {Boss = {}, NPC = {}, Shield = {}, Ultimate = {}, Projectile = {}}
local combatESPFolder

local function getCombatESPParent()
    if type(gethui) == "function" then
        local ok, parent = pcall(gethui)
        if ok and parent then return parent end
    end
    return Player:FindFirstChildOfClass("PlayerGui") or game:GetService("CoreGui")
end

local function ensureCombatESPFolder()
    if combatESPFolder and combatESPFolder.Parent then return combatESPFolder end
    combatESPFolder = Instance.new("Folder")
    combatESPFolder.Name = "PrimeCombatESP"
    combatESPFolder.Parent = getCombatESPParent()
    return combatESPFolder
end

local combatESPColors = {
    Boss = Color3.fromRGB(255, 55, 95),
    NPC = Color3.fromRGB(255, 145, 45),
    Shield = Color3.fromRGB(70, 215, 255),
    Ultimate = Color3.fromRGB(190, 85, 255),
    Projectile = Color3.fromRGB(255, 225, 70)
}

local function destroyCombatESPEntry(entry)
    if entry.Highlight then entry.Highlight:Destroy() end
    if entry.Billboard then entry.Billboard:Destroy() end
end

local function createCombatESPEntry(kind, target)
    local adornee = PrimeRuntime.getWorldPart(target)
    if not adornee then return nil end
    local color = combatESPColors[kind]
    local entry = {Target = target, Adornee = adornee}
    if kind ~= "Ultimate" then
        local highlight = Instance.new("Highlight")
        highlight.Name = kind .. "Highlight"
        highlight.Adornee = target
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillColor = color
        highlight.OutlineColor = color
        highlight.FillTransparency = kind == "Projectile" and 0.72 or 0.82
        highlight.OutlineTransparency = 0
        highlight.Parent = ensureCombatESPFolder()
        entry.Highlight = highlight
    end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = kind .. "Info"
    billboard.Adornee = adornee
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.fromOffset(180, 34)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, math.max(2.5, adornee.Size.Y * 0.6 + 1.5), 0)
    billboard.Parent = ensureCombatESPFolder()
    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = color
    label.TextStrokeTransparency = 0.15
    label.TextSize = 14
    label.Parent = billboard
    entry.Billboard = billboard
    entry.Label = label
    return entry
end

local function syncCombatESPKind(kind, targets)
    local entries = combatESPEntries[kind]
    for target, entry in pairs(entries) do
        if not targets[target] or not target.Parent then
            destroyCombatESPEntry(entry)
            entries[target] = nil
        end
    end
    if not combatESPEnabled[kind] then return end
    for target in pairs(targets) do
        if target.Parent and not entries[target] then
            entries[target] = createCombatESPEntry(kind, target)
        end
    end
end

local bossNames = {CorruptedWitch1 = true, CorruptedWitch2 = true, CorruptedWitch3 = true, Elderbeast = true}
local shieldWords = {"shield", "barrier", "bubble", "forcefield", "ward"}

local function containsWord(name, words)
    name = string.lower(name)
    for _, word in ipairs(words) do
        if string.find(name, word, 1, true) then return true end
    end
    return false
end

local function collectCombatESPTargets()
    local targets = {Boss = {}, NPC = {}, Shield = {}, Ultimate = {}, Projectile = {}}
    if combatESPEnabled.Boss then
        for name in pairs(bossNames) do
            local model = workspace:FindFirstChild(name, true)
            if model and (model:IsA("Model") or model:IsA("BasePart")) then targets.Boss[model] = true end
        end
    end
    if combatESPEnabled.NPC then
        for _, model in ipairs(game:GetService("CollectionService"):GetTagged("Character")) do
            if model:IsA("Model") and not game:GetService("Players"):GetPlayerFromCharacter(model)
                and not bossNames[model.Name] and model:FindFirstChildOfClass("Humanoid") then
                targets.NPC[model] = true
            end
        end
    end
    if combatESPEnabled.Ultimate then
        for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
            local character = player.Character
            if player ~= Player and character and character:GetAttribute("MaxUltCharge") then
                targets.Ultimate[character] = true
            end
        end
    end
    if combatESPEnabled.Shield or combatESPEnabled.Projectile then
        for _, object in ipairs(workspace:GetDescendants()) do
            if object:IsA("Model") or object:IsA("BasePart") then
                if combatESPEnabled.Shield then
                    local health = object:GetAttribute("Health")
                    local maxHealth = object:GetAttribute("MaxHealth")
                    if type(health) == "number" and type(maxHealth) == "number" and maxHealth > 0
                        and (containsWord(object.Name, shieldWords) or object:IsA("Model")) then
                        targets.Shield[object] = true
                    end
                end
                if combatESPEnabled.Projectile and PrimeRuntime.isLikelyProjectile(object) then
                    local model = object:IsA("BasePart") and object:FindFirstAncestorOfClass("Model")
                    local target = model and not model:FindFirstChildOfClass("Humanoid") and model or object
                    targets.Projectile[target] = true
                end
            end
        end
    end
    return targets
end

local function updateCombatESPText(kind, entry)
    local target = entry.Target
    local root = Player.Character and (Player.Character:FindFirstChild("HumanoidRootPart") or Player.Character.PrimaryPart)
    local part = PrimeRuntime.getWorldPart(target)
    if not part then return end
    local distance = root and math.floor((part.Position - root.Position).Magnitude + 0.5) or 0
    if kind == "Shield" then
        local health = tonumber(target:GetAttribute("Health")) or 0
        local maxHealth = tonumber(target:GetAttribute("MaxHealth")) or 0
        entry.Label.Text = string.format("%s  %d/%d  [%dm]", target.Name, health, maxHealth, distance)
    elseif kind == "Ultimate" then
        local charge = tonumber(target:GetAttribute("UltCharge")) or 0
        local maximum = tonumber(target:GetAttribute("MaxUltCharge")) or 0
        local percent = maximum > 0 and math.floor(charge / maximum * 100 + 0.5) or 0
        local owner = game:GetService("Players"):GetPlayerFromCharacter(target)
        entry.Label.Text = string.format("%s  ULT %d%%", owner and owner.Name or target.Name, percent)
    else
        local humanoid = target:IsA("Model") and target:FindFirstChildOfClass("Humanoid")
        local health = humanoid and string.format("  %d HP", math.max(0, math.floor(humanoid.Health + 0.5))) or ""
        entry.Label.Text = string.format("%s%s  [%dm]", target.Name, health, distance)
    end
end

local function toggleCombatESP(kind, value)
    combatESPEnabled[kind] = value
    if not value then
        for target, entry in pairs(combatESPEntries[kind]) do
            destroyCombatESPEntry(entry)
            combatESPEntries[kind][target] = nil
        end
    end
end

task.spawn(function()
    while not PrimeRuntime.IsShuttingDown do
        local any = false
        for _, enabled in pairs(combatESPEnabled) do if enabled then any = true break end end
        if any then
            local targets = collectCombatESPTargets()
            for kind, list in pairs(targets) do syncCombatESPKind(kind, list) end
            for kind, entries in pairs(combatESPEntries) do
                for _, entry in pairs(entries) do updateCombatESPText(kind, entry) end
            end
        end
        task.wait(any and 0.5 or 1)
    end
end)

local function cleanupCombatESP()
    for kind in pairs(combatESPEnabled) do toggleCombatESP(kind, false) end
    if combatESPFolder then combatESPFolder:Destroy() combatESPFolder = nil end
end

function Visual.Cleanup()
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
    Tabs.ESP:AddSection("Visual & ESP")

    local ESPStonesToggle = Tabs.ESP:AddToggle("ESPStonesToggle", {
        Title = "Esp Stones",
        Description = "Highlight TimeStone, PowerStone and SpaceStone with distance",
        Default = false
    })
    ESPStonesToggle:OnChanged(function(value)
        PrimeRuntime.toggleESPStones(value)
    end)

    local CollectibleESPBoxToggle = Tabs.ESP:AddToggle("CollectibleESPBoxToggle", {
        Title = "ESP Box",
        Description = "Highlight AutoCollect objects and show distance",
        Default = false
    })
    CollectibleESPBoxToggle:OnChanged(function(value)
        PrimeRuntime.toggleESPBoxes(value)
    end)
    
    local NoShadowToggle = Tabs.ESP:AddToggle("NoShadow", {
        Title = "No Shadow", 
        Description = "Remove shadows in the game", 
        Default = false
    })
    NoShadowToggle:OnChanged(function(v) Visual.ToggleNoShadow(v) end)

    local SaturationToggle = Tabs.ESP:AddToggle("Saturation", {
        Title = "Saturation", 
        Description = "Increase color saturation", 
        Default = false
    })
    SaturationToggle:OnChanged(function(v) 
        Visual.ToggleSaturation(v)
    end)

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

    local ArtifactHolderESPToggle = Tabs.ESP:AddToggle("ArtifactHolderESP", {
        Title = "Artifact Holder ESP",
        Description = "Highlight players carrying Infinity Stones or the Darkhold",
        Default = false
    })
    ArtifactHolderESPToggle:OnChanged(function()
        PrimeRuntime.toggleArtifactHolderESP(Options.ArtifactHolderESP.Value)
    end)

    Tabs.ESP:AddSection("Combat ESP")
    local combatToggles = {
        {"BossESP", "Boss ESP", "CorruptedWitch1-3 and Elderbeast", "Boss"},
        {"NPCESP", "NPC ESP", "All spawned NPC characters", "NPC"},
        {"ShieldHealthESP", "Shield Health ESP", "Shield health and defensive objects", "Shield"},
        {"UltimateChargeESP", "Ultimate Charge ESP", "Ultimate charge above players", "Ultimate"},
        {"ProjectileESP", "Projectile ESP", "Moving projectiles and dangerous objects", "Projectile"}
    }
    for _, item in ipairs(combatToggles) do
        local id, title, description, kind = table.unpack(item)
        local toggle = Tabs.ESP:AddToggle(id, {Title = title, Description = description, Default = false})
        toggle:OnChanged(function() toggleCombatESP(kind, Options[id].Value) end)
    end

    -- Second ESP section. PRIME places the second section in the right column.
    Tabs.ESP:AddSection("Player ESP")

    local AdvancedESPToggle = Tabs.ESP:AddToggle("AdvancedESP", {
        Title = "ESP ALL ON / OFF",
        Description = "Enable or disable all player ESP",
        Default = false
    })
    AdvancedESPToggle:OnChanged(function(v)
        Visual.ToggleAdvancedESP(v)
    end)

    local ESPBoxToggle = Tabs.ESP:AddToggle("ESPBox", {
        Title = "Player Boxes", 
        Description = "Show/hide player boxes", 
        Default = true
    })
    ESPBoxToggle:OnChanged(function(v)
        Visual.AdvancedESP.settings.box = v
    end)

    local ESPNamesToggle = Tabs.ESP:AddToggle("ESPNames", {
        Title = "Player Names", 
        Description = "Show/hide player names", 
        Default = true
    })
    ESPNamesToggle:OnChanged(function(v)
        Visual.AdvancedESP.settings.name = v
    end)

    local ESPHealthBarToggle = Tabs.ESP:AddToggle("ESPHealthBar", {
        Title = "Health Bar", 
        Description = "Show/hide health bar", 
        Default = true
    })
    ESPHealthBarToggle:OnChanged(function(v)
        Visual.AdvancedESP.settings.healthbar = v
    end)

    local ESPDistanceToggle = Tabs.ESP:AddToggle("ESPDistance", {
        Title = "Distance", 
        Description = "Show/hide distance to players", 
        Default = true
    })
    ESPDistanceToggle:OnChanged(function(v)
        Visual.AdvancedESP.settings.distance = v
    end)

    local ESPBoxFillToggle = Tabs.ESP:AddToggle("ESPBoxFill", {
        Title = "Filled Box", 
        Description = "Show/hide filled boxes", 
        Default = true
    })
    ESPBoxFillToggle:OnChanged(function(v)
        Visual.AdvancedESP.settings.boxFill = v
    end)

    local ESPTracersToggle = Tabs.ESP:AddToggle("ESPTracers", {
        Title = "Tracers", 
        Description = "Show/hide tracers to players", 
        Default = true
    })
    ESPTracersToggle:OnChanged(function(v)
        Visual.AdvancedESP.settings.tracers = v
    end)

    local ESPBonesToggle = Tabs.ESP:AddToggle("ESPBones", {
        Title = "Player Bones", 
        Description = "Show/hide player bones", 
        Default = true
    })
    ESPBonesToggle:OnChanged(function(v)
        Visual.AdvancedESP.settings.bones = v
    end)
end

TrackRuntimeCleanup(function()
    Visual.Cleanup()
    cleanupCombatESP()
end)
