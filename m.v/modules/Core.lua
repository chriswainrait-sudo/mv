local g = getgenv and getgenv() or _G
local k = "__PRIME_MARVEL_OMEGA_RUNTIME_V2"
local p = g[k]
if type(p) == "table" and type(p.Shutdown) == "function" then pcall(p.Shutdown) end

local PrimeRuntime = {Connections = {}, Cleanups = {}, Tasks = setmetatable({}, {__mode = "k"}), Errors = {}, IsShuttingDown = false}
g[k] = PrimeRuntime

function PrimeRuntime.Run(n, f)
    local ok, e = xpcall(f, function(e) return debug.traceback(tostring(e), 2) end)
    if not ok then
        local s = n .. ": " .. tostring(e)
        table.insert(PrimeRuntime.Errors, s)
        warn("mv/" .. s)
    end
    return ok
end

local function TrackRuntimeConnection(c)
    if c then table.insert(PrimeRuntime.Connections, c) end
    return c
end

local function TrackRuntimeCleanup(f)
    table.insert(PrimeRuntime.Cleanups, f)
    return f
end

local ts = task
local task = table.clone(ts)
for _, n in ipairs({"spawn", "defer", "delay"}) do
    task[n] = function(...)
        if PrimeRuntime.IsShuttingDown then return end
        local t = ts[n](...)
        PrimeRuntime.Tasks[t] = true
        return t
    end
end

local Fluent, SaveManager, InterfaceManager
function PrimeRuntime.Shutdown()
    if PrimeRuntime.IsShuttingDown then return end
    PrimeRuntime.IsShuttingDown = true
    for t in pairs(PrimeRuntime.Tasks) do
        if t ~= coroutine.running() and coroutine.status(t) ~= "dead" then pcall(ts.cancel, t) end
    end
    table.clear(PrimeRuntime.Tasks)
    for i = #PrimeRuntime.Cleanups, 1, -1 do pcall(PrimeRuntime.Cleanups[i]) end
    table.clear(PrimeRuntime.Cleanups)
    for _, c in ipairs(PrimeRuntime.Connections) do pcall(function() c:Disconnect() end) end
    table.clear(PrimeRuntime.Connections)
    if Fluent then
        if PrimeRuntime.DestroyUI then pcall(PrimeRuntime.DestroyUI, Fluent) end
        if Fluent.GUI then pcall(function() Fluent.GUI:Destroy() end) end
    end
    if g[k] == PrimeRuntime then g[k] = nil end
end

Fluent, SaveManager, InterfaceManager = assert(loadstring(game:HttpGet("https://raw.githubusercontent.com/chriswainrait-sudo/PrimeLibrary-/refs/heads/main/.lua")))()
PrimeRuntime.DestroyUI = Fluent.Destroy
Fluent.Destroy = PrimeRuntime.Shutdown
TrackRuntimeConnection(Fluent.GUI.Destroying:Connect(PrimeRuntime.Shutdown))
local fs = true
for _, n in ipairs({"isfile", "isfolder", "makefolder", "readfile", "writefile", "listfiles"}) do
    if type(getfenv()[n]) ~= "function" then fs = false break end
end
if fs then
    SaveManager = assert(loadstring(game:HttpGet("https://raw.githubusercontent.com/chriswainrait-sudo/SaveManager/refs/heads/main/.lua")))()
    InterfaceManager = assert(loadstring(game:HttpGet("https://raw.githubusercontent.com/chriswainrait-sudo/InterfaceManager/refs/heads/main/.lua")))()
end
TrackRuntimeCleanup(function() InterfaceManager:DisableCursorUnlock() end)

local function Notify(c)
    local ok, r = pcall(Fluent.Notify, Fluent, c)
    return ok and r or nil
end

local Player = assert(game:GetService("Players").LocalPlayer, "LocalPlayer unavailable")
local u = game:GetService("UserInputService")
local m = u.TouchEnabled and not u.KeyboardEnabled
local t = tostring(g.PRIME_TIER or _G.PRIME_TIER or ""):lower()
local Window = Fluent:CreateWindow({
    Title = "PRIME", SubTitle = "Marvel Omega", Search = false, TabWidth = 130,
    Size = m and UDim2.fromOffset(410, 300) or UDim2.fromOffset(720, 450),
    Theme = "Slate", MinimizeKey = Enum.KeyCode.LeftAlt,
    Tier = t == "premium" and "Premium" or "Freemium"
})
Window.Destroy = PrimeRuntime.Shutdown
TrackRuntimeConnection(Window.Root.Destroying:Connect(PrimeRuntime.Shutdown))
local Tabs = {}
for _, v in ipairs({{"Main", "user"}, {"Rage", "flame"}, {"Defense", "shield"},
    {"Movement", "japanese-yen"}, {"ESP", "eye"}, {"Other", "leaf"}, {"Settings", "settings-2"}}) do
    Tabs[v[1]] = Window:AddTab({Title = v[1], Icon = v[2]})
end
if m then
    Fluent:CreateMinimizer({Icon = "rbxassetid://111390226361567", Size = UDim2.fromOffset(28, 28),
        Position = UDim2.new(0, 320, 0, 24), Corner = 1, Transparency = 1, Draggable = true, Visible = true})
end

local Options = Fluent.Options
local PlayerInputModule, AbilitiesModule
local a = {}
local function getGameModule(n)
    local f = game:GetService("ReplicatedStorage"):FindFirstChild("Modules")
    local s = f and f:FindFirstChild(n)
    if not s or not s:IsA("ModuleScript") then return end
    local ok, r = pcall(require, s)
    return ok and r or nil
end

local function simulateAction(n, v)
    PlayerInputModule = PlayerInputModule or getGameModule("PlayerInput")
    if not PlayerInputModule or type(PlayerInputModule.SimulateActionState) ~= "function" then return false end
    return pcall(PlayerInputModule.SimulateActionState, PlayerInputModule, n, v)
end

local function pulseAction(n, d)
    if a[n] or PrimeRuntime.IsShuttingDown then return false end
    a[n] = true
    if not simulateAction(n, true) then a[n] = nil return false end
    task.delay(d or 0.18, function() simulateAction(n, false) a[n] = nil end)
    return true
end
TrackRuntimeCleanup(function()
    for n in pairs(a) do simulateAction(n, false) end
end)
TrackRuntimeConnection(Player.AncestryChanged:Connect(function(_, p)
    if not p then PrimeRuntime.Shutdown() end
end))
