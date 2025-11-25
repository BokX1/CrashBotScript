--[[
    TORA APEX ARCHITECTURE (Visual Mode)
    > Managed Thread Pool (Stabilized Burst)
    > Direct C-Call Caching (Speed)
    > Render Enabled (Compatible with Autoclickers)
]]

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")

-- // 1. SYSTEM OPTIMIZATION PREP //
local pcall, error, warn = pcall, error, warn
local task_spawn, task_wait = task.spawn, task.wait
local string_find = string.find
local Instance_new = Instance.new

-- C-Function Caching (Direct Memory Access)
local Invoke = Instance_new("RemoteFunction").InvokeServer
local Fire = Instance_new("RemoteEvent").FireServer

-- // 2. CLEANUP & INIT //
if CoreGui:FindFirstChild("ToraApex") then CoreGui.ToraApex:Destroy() end

-- // 3. ROBUST NETWORK DISCOVERY //
local function GetNetworkerRemotes()
    local packageRoot = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index")
    for _, child in ipairs(packageRoot:GetChildren()) do
        if string_find(child.Name, "leifstout_networker") then
            return child:WaitForChild("networker"):WaitForChild("_remotes")
        end
    end
    return nil
end

local Remotes = GetNetworkerRemotes()
if not Remotes then return warn("CRITICAL FAILURE: Networker Package Missing") end

-- Remote Pointers
local BattleService = Remotes:WaitForChild("BattleService")
local PvpService = Remotes:WaitForChild("PvpService")
local BattleFunc = BattleService:WaitForChild("RemoteFunction")
local BattleEvent = BattleService:WaitForChild("RemoteEvent")
local PvpFunc = PvpService:WaitForChild("RemoteFunction")
local PvpEvent = PvpService:WaitForChild("RemoteEvent")

-- // 4. WORKER POOL LOGIC //
local State = {
    Battle = false,
    PvP = false,
    ActiveThreads = 0,
    MaxThreads = 5, -- Prevents Scheduler Crash
    ClaimDelay = 0.05
}

-- The Request Agent (Managed Thread)
local function SpawnBattleAgent()
    if State.ActiveThreads >= State.MaxThreads then return end -- Throttling
    
    State.ActiveThreads = State.ActiveThreads + 1
    
    task_spawn(function()
        pcall(function()
            -- 1. Fire Request (Yields until server replies)
            Invoke(BattleFunc, "requestBattle")
        end)
        State.ActiveThreads = State.ActiveThreads - 1 -- Release Token
    end)
end

-- The Claim Agent (Aggressive Loop)
local function StartClaimLoop()
    task_spawn(function()
        while State.Battle do
            -- We Spam Claim regardless of request state to catch the MILLISECOND the server accepts
            pcall(function()
                Fire(BattleEvent, "claimResults")
            end)
            task_wait(State.ClaimDelay) 
        end
    end)
end

-- The Master Controller
local function RunBattleOrchestrator()
    StartClaimLoop() -- Start the "Consumer" (Claimer)
    
    task_spawn(function()
        while State.Battle do
            SpawnBattleAgent() -- Start the "Producer" (Requester)
            task_wait() -- 60hz Check
        end
    end)
end

local function RunPvPOrchestrator()
    task_spawn(function()
        while State.PvP do
            pcall(function()
                Invoke(PvpFunc, "attemptMatchmaking")
                Fire(PvpEvent, "claimMatch")
            end)
            task_wait(0.5)
        end
    end)
end

local function SafeTeleport(cframeTarget)
    local char = Players.LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = cframeTarget end
    end
end

-- // 5. ANTI-AFK (Security) //
-- Essential for long farming sessions
local function StartAntiAFK()
    local vu = game:GetService("VirtualUser")
    game:GetService("Players").LocalPlayer.Idled:Connect(function()
        vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task_wait(1)
        vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end)
end
StartAntiAFK()

-- // 6. UI CONSTRUCTION //
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/liebertsx/Tora-Library/main/src/librarynew", true))()
local Window = Library:CreateWindow("Crash Bots APEX")

Window:AddToggle({
    text = "APEX BATTLE (Managed Pool)",
    flag = "toggle_battle",
    state = false,
    callback = function(enabled)
        State.Battle = enabled
        if enabled then RunBattleOrchestrator() end
    end
})

Window:AddSlider({
    text = "Thread Pool Size (Intensity)",
    flag = "slider_threads",
    min = 1,
    max = 20,
    value = 5,
    callback = function(val)
        State.MaxThreads = val
    end
})

Window:AddSlider({
    text = "Claim Latency (0 = Instant)",
    flag = "slider_latency",
    min = 0,
    max = 10,
    value = 1, -- Default 0.1s
    callback = function(val)
        State.ClaimDelay = val / 20 -- Finer control
    end
})

Window:AddToggle({
    text = "Fast PvP",
    flag = "toggle_pvp",
    state = false,
    callback = function(enabled)
        State.PvP = enabled
        if enabled then RunPvPOrchestrator() end
    end
})

Window:AddButton({
    text = "Teleport: Garage",
    flag = "btn_garage",
    callback = function() SafeTeleport(CFrame.new(-238, -66, 83)) end
})

Window:AddButton({
    text = "Teleport: Summon",
    flag = "btn_summon",
    callback = function() SafeTeleport(CFrame.new(-41, -51, 277)) end
})

Window:AddLabel({ text = "System: Apex (Render Enabled)" })
Library:Init()
