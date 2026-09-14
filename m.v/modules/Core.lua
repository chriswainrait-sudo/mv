

-- Runtime singleton: prevents newer copies of this script from stacking
-- background connections/tasks when the script is injected repeatedly.
local PRIME_ENV = (getgenv and getgenv()) or _G
local PRIME_RUNTIME_KEY = "__PRIME_MARVEL_OMEGA_RUNTIME_V2"
local previousRuntime = PRIME_ENV[PRIME_RUNTIME_KEY]
if type(previousRuntime) == "table" and type(previousRuntime.Shutdown) == "function" then
    pcall(previousRuntime.Shutdown)
end

local PrimeRuntime = {
    Shutdown = nil,
    Connections = {},
    IsShuttingDown = false
}
PRIME_ENV[PRIME_RUNTIME_KEY] = PrimeRuntime

local function TrackRuntimeConnection(connection)
    if connection then
        table.insert(PrimeRuntime.Connections, connection)
    end
    return connection
end

local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/conexion19/NexusLib-v.1.1.1-/refs/heads/main/gffff.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/conexion19/Save/refs/heads/main/SAVEGGLIBA.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/conexion19/InterfaceManager-NEW-/refs/heads/main/InterfaceManager.lua"))()

local Player = game:GetService("Players").LocalPlayer
local UserInputService = game:GetService("UserInputService")
local IS_MOBILE = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
local IS_DESKTOP = (UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled)

local windowSize = IS_MOBILE and UDim2.fromOffset(410, 260) or UDim2.fromOffset(620, 370)

local primeTier = type(_G.PRIME_TIER) == "string" and _G.PRIME_TIER:lower() or ""
local userTier = primeTier == "Premium" or "Freemium"

local Window = Fluent:CreateWindow({
    Title = "PRIME",
    SubTitle = "Marvel Omega",
    Search = false,
    TabWidth = 130,
    Size = windowSize,
    Theme = "Slate",
    MinimizeKey = Enum.KeyCode.LeftAlt,
    Tier = userTier
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "user" }),
    Rage = Window:AddTab({ Title = "Rage", Icon = "flame" }),
    Defense = Window:AddTab({ Title = "Defense", Icon = "shield" }),
    Movement = Window:AddTab({ Title = "Movement", Icon = "japanese-yen" }),
    ESP = Window:AddTab({ Title = "ESP", Icon = "eye" }),
    Other = Window:AddTab({ Title = "Other", Icon = "leaf" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings-2" })
}

local Minimizer

if IS_MOBILE then
    Minimizer = Fluent:CreateMinimizer({
        Icon = "rbxassetid://111390226361567",
        Size = UDim2.fromOffset(22, 22),
        Position = UDim2.new(0, 320, 0, 24),
        Corner = 1,
        Transparency = 1,
        Draggable = true,
        Visible = true
    })
else
    Minimizer = nil  
end

local Options = Fluent.Options

local PlayerInputModule
local AbilitiesModule
local NetworkModule
local actionBusy = {}

local function getGameModule(name)
    local modules = game:GetService("ReplicatedStorage"):FindFirstChild("Modules")
    local scriptObject = modules and modules:FindFirstChild(name)
    if not scriptObject or not scriptObject:IsA("ModuleScript") then
        return nil
    end
    local ok, result = pcall(require, scriptObject)
    return ok and result or nil
end

local function simulateAction(action, state)
    PlayerInputModule = PlayerInputModule or getGameModule("PlayerInput")
    if not PlayerInputModule or type(PlayerInputModule.SimulateActionState) ~= "function" then
        return false
    end
    return pcall(PlayerInputModule.SimulateActionState, PlayerInputModule, action, state)
end

local function pulseAction(action, duration)
    if actionBusy[action] then return false end
    actionBusy[action] = true
    if not simulateAction(action, true) then
        actionBusy[action] = nil
        return false
    end
    task.delay(duration or 0.18, function()
        simulateAction(action, false)
        actionBusy[action] = nil
    end)
    return true
end

