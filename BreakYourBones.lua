--[[
    Break Your Bones Hub - by SeneX
    
    Features:
    - Auto Farm: AFK + Spin for max bones (resets every 5 min for materials)
    - Auto Quest: Automatically starts and claims quests
    - Auto Charm Quest: Auto Geko/Fire quests
    - Auto Mastery: Auto upgrade mastery when possible
    - Auto Material: Refines until Electro/Forge (with Forge stacking logic!)
    - Auto Rebirth: Auto rebirth when affordable
    - Auto Bone Upgrades: Keeps all bones at same level (balanced)
    - Auto Pal: Rolls free pals when you have tickets
    - Auto Daily Cookies: Claims daily cookies automatically
    - Auto Forge: Starts and claims forge automatically
    
    UI:
    - Spin Speed Slider (30-120 deg/frame)
    - Target Modifiers Dropdown for material hunting
]]

-- Auto Re-execute on server hop
local SCRIPT_URL = "https://raw.githubusercontent.com/NotMe2007/For-All/refs/heads/main/BreakYourBones.lua"
local ScriptSource = nil
pcall(function()
    ScriptSource = game:HttpGet(SCRIPT_URL)
end)

-- Queue on teleport for server hops
if queue_on_teleport then
    pcall(function()
        queue_on_teleport(ScriptSource or 'loadstring(game:HttpGet("' .. SCRIPT_URL .. '"))()')
    end)
end

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Player
local Player = Players.LocalPlayer

-- Wait for game to fully load (prevents crashes)
if not game:IsLoaded() then
    game.Loaded:Wait()
end
task.wait(2) -- Extra safety delay 

-- Wait for player data to load
repeat task.wait(0.5) until Player:FindFirstChild("Loaded") and Player.Loaded.Value == true
repeat task.wait(0.5) until Player:FindFirstChild("RagdollLoaded") and Player.RagdollLoaded.Value == true

-- Load Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Create Window
local Window = Rayfield:CreateWindow({
    Name = "Break Your Bones Hub",
    LoadingTitle = "Break Your Bones Hub",
    LoadingSubtitle = "by SeneX",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "BreakYourBonesHub",
        FileName = "Config"
    },
    Discord = {
        Enabled = true,
        Invite = "https://discord.gg/ZVHjadv4AG",
        RememberJoins = true
    },
    KeySystem = false
})

-- Variables
local AutoFarmAllEnabled = false
local AutoQuestEnabled = false
local AutoCharmQuestEnabled = false
local AutoMaterialEnabled = false
local AutoRebirthEnabled = false
local AutoBoneUpgradeEnabled = false
local AutoPalEnabled = false
local AutoForgeEnabled = false
local AutoDailyCookiesEnabled = false
local AutoMasteryEnabled = false
local AutoMaterialHuntEnabled = false

-- Spin Variables
local SpinConnection = nil
local SpinSpeed = 30 -- Rotation speed (min 30)

-- Farm Reset Variables (every 5 mins)
local FarmStartTime = 0
local FARM_RESET_INTERVAL = 300 -- 5 minutes in seconds
local FARM_IDLE_TIME = 15 -- 15 seconds idle after reset

-- Auto Daily Cookies
local AutoDailyCookiesEnabled = true

-- Target Modifiers for Auto Material (Forge on by default)
local TargetModifiers = {"Forge"}
local AutoUpgradeRagdoll = true

-- All available modifiers for selection
local AllModifiers = {
    "Forge", "Electro", "Error", "Joker", "Royal", "Magma", 
    "Ghostglass", "Plant", "Titanium", "Glass", "Lucky", 
    "Explosive", "Frog", "Honey", "Shadow", "Chocolate", "Enchanted"
}

-- Modules (safely require)
local Progression = require(ReplicatedStorage.SharedModules.Progression)
local BigNum = require(ReplicatedStorage.SharedModules.BigNum)
local QuestsModule = require(ReplicatedStorage.SharedModules.Quests)

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Helper Functions
local function GetPlayer()
    return Players.LocalPlayer
end

-- Spin Functions (can be improved)
local function StartSpin()
    if SpinConnection then return end
    
    local RunService = game:GetService("RunService")
    SpinConnection = RunService.RenderStepped:Connect(function(dt)
        local character = Player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local hrp = character.HumanoidRootPart
            hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(SpinSpeed * dt * 60), 0)
        end
    end)
end

local function StopSpin()
    if SpinConnection then
        SpinConnection:Disconnect()
        SpinConnection = nil
    end
end

local function SetAFK(enabled)
    local plr = GetPlayer()
    if plr and plr:FindFirstChild("AFK") then
        local currentAFK = plr.AFK.Value
        if currentAFK ~= enabled then
            Remotes.SetAFK:FireServer()
        end
    end
end

local function TeleportToFarmArea()
    pcall(function()
        local character = Player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local target = Workspace:FindFirstChild("RagdollParts")
            if target then
                local collision = target:FindFirstChild("RagdollCollission")
                if collision and collision:IsA("BasePart") then
                    character.HumanoidRootPart.CFrame = collision.CFrame + Vector3.new(0, 5, 0)
                elseif collision then
                    -- Try to find any part inside
                    for _, part in pairs(collision:GetDescendants()) do
                        if part:IsA("BasePart") then
                            character.HumanoidRootPart.CFrame = part.CFrame + Vector3.new(0, 5, 0)
                            break
                        end
                    end
                end
            end
        end
    end)
end

local function GetRagdollPrice()
    local plr = GetPlayer()
    if plr and plr:FindFirstChild("hiddenstats") then
        local ragdollNum = plr.hiddenstats.RagdollNumber.Value
        return Progression.GetRagdollPrice(plr, ragdollNum)
    end
    return math.huge, "None"
end

local function HasTargetModifierOnCurrentRagdoll()
    -- Check if any target modifier is UNLOCKED for CURRENT ragdoll
    local plr = GetPlayer()
    if plr and plr:FindFirstChild("hiddenstats") and plr.hiddenstats:FindFirstChild("CurrentRagdoll") then
        local ragdollName = plr.hiddenstats.CurrentRagdoll.Value
        if plr:FindFirstChild("RagdollInventory") and plr.RagdollInventory:FindFirstChild(ragdollName) then
            local ragdollFolder = plr.RagdollInventory:FindFirstChild(ragdollName)
            for _, target in ipairs(TargetModifiers) do
                if ragdollFolder:FindFirstChild(target) then
                    return true, target
                end
            end
        end
    end
    return false, nil
end

local function GetRagdollWithoutForge()
    -- Find a ragdoll that doesn't have Forge yet (for stacking 0.2x bonus)
    local plr = GetPlayer()
    if plr and plr:FindFirstChild("RagdollInventory") then
        for _, ragdollFolder in pairs(plr.RagdollInventory:GetChildren()) do
            -- Check if this ragdoll has Forge
            if not ragdollFolder:FindFirstChild("Forge") then
                return ragdollFolder.Name
            end
        end
    end
    return nil -- All ragdolls have Forge
end

local function AllRagdollsHaveForge()
    -- Check if ALL owned ragdolls have Forge modifier
    local plr = GetPlayer()
    if plr and plr:FindFirstChild("RagdollInventory") then
        for _, ragdollFolder in pairs(plr.RagdollInventory:GetChildren()) do
            if not ragdollFolder:FindFirstChild("Forge") then
                return false
            end
        end
        return true
    end
    return false
end

local function GetCurrentRagdollName()
    local plr = GetPlayer()
    if plr and plr:FindFirstChild("hiddenstats") and plr.hiddenstats:FindFirstChild("CurrentRagdoll") then
        return plr.hiddenstats.CurrentRagdoll.Value
    end
    return nil
end

local function GetUnlockedModifiersCount()
    -- Get count of unlocked modifiers for current ragdoll
    local plr = GetPlayer()
    if plr and plr:FindFirstChild("hiddenstats") and plr.hiddenstats:FindFirstChild("CurrentRagdoll") then
        local ragdollName = plr.hiddenstats.CurrentRagdoll.Value
        if plr:FindFirstChild("RagdollInventory") and plr.RagdollInventory:FindFirstChild(ragdollName) then
            return #plr.RagdollInventory:FindFirstChild(ragdollName):GetChildren()
        end
    end
    return 0
end

local function GetCash()
    local plr = GetPlayer()
    if plr and plr:FindFirstChild("leaderstats") and plr.leaderstats:FindFirstChild("Cash") then
        return plr.leaderstats.Cash.Value
    end
    return 0
end

local function GetQuestState()
    local plr = GetPlayer()
    if plr and plr:FindFirstChild("Quests") and plr.Quests:FindFirstChild("QuestState") then
        return plr.Quests.QuestState.Value
    end
    return "None"
end

local function GetGekoQuestState()
    local plr = GetPlayer()
    if plr and plr:FindFirstChild("GekoQuest") and plr.GekoQuest:FindFirstChild("QuestState") then
        return plr.GekoQuest.QuestState.Value
    end
    return "None"
end

local function GetBoneLevel(boneName)
    local plr = GetPlayer()
    if plr and plr:FindFirstChild("IncrementalFolder") and plr.IncrementalFolder:FindFirstChild(boneName) then
        return plr.IncrementalFolder:FindFirstChild(boneName).Value
    end
    return 0
end

local function GetMinBoneLevel()
    local levels = {
        GetBoneLevel("Arm"),
        GetBoneLevel("Leg"),
        GetBoneLevel("Head"),
        GetBoneLevel("Torso")
    }
    return math.min(unpack(levels))
end

local function GetRebirthRequired()
    local plr = GetPlayer()
    if plr then
        return Progression.GetRebirthRequired(plr)
    end
    return 0
end

local function GetRefiningCost()
    local plr = GetPlayer()
    if plr then
        return Progression.GetRefiningCost(plr)
    end
    return math.huge, false
end

local function GetBonePrice(level)
    local plr = GetPlayer()
    if plr then
        return Progression.GetBonePrice(plr, level)
    end
    return math.huge
end

local function HasItem(itemName)
    local plr = GetPlayer()
    if plr and plr:FindFirstChild("ItemFolder") then
        return plr.ItemFolder:FindFirstChild(itemName) ~= nil
    end
    return false
end

local function GetGateNumber()
    local plr = GetPlayer()
    if plr and plr:FindFirstChild("hiddenstats") and plr.hiddenstats:FindFirstChild("GateNumber") then
        return plr.hiddenstats.GateNumber.Value
    end
    return 0
end

local function GetForgeTimer()
    local plr = GetPlayer()
    if plr and plr:FindFirstChild("Forge") then
        return plr.Forge.ForgeTimer.Value, plr.Forge.ForgeDuration.Value
    end
    return 0, 0
end

local function GetServerTime()
    return math.floor(Workspace:GetServerTimeNow())
end

local function GetMasteryXP()
    local plr = GetPlayer()
    if plr and plr:FindFirstChild("Quests") and plr.Quests:FindFirstChild("XP") then
        return plr.Quests.XP.Value
    end
    return 0
end

local function GetMasteryRequired()
    local plr = GetPlayer()
    if plr then
        return QuestsModule.GetMasteryRequired(plr)
    end
    return math.huge
end

local function GetCurrentModifier()
    local plr = GetPlayer()
    if plr and plr:FindFirstChild("hiddenstats") and plr.hiddenstats:FindFirstChild("CurrentRagdoll") then
        local ragdoll = plr.hiddenstats.CurrentRagdoll.Value
        if plr:FindFirstChild("RagdollInventory") and plr.RagdollInventory:FindFirstChild(ragdoll) then
            return plr.RagdollInventory:FindFirstChild(ragdoll).Value
        end
    end
    return "None"
end

local function IsAFKEnabled()
    local plr = GetPlayer()
    if plr and plr:FindFirstChild("AFK") then
        return plr.AFK.Value
    end
    return false
end

-- Main Tab
local MainTab = Window:CreateTab("Main", 4483362458)

-- Auto Farm Section (Top)
local FarmSection = MainTab:CreateSection("Farming")

local AutoFarmToggle
AutoFarmToggle = MainTab:CreateToggle({
    Name = "Auto Farm All",
    CurrentValue = false,
    Flag = "AutoFarmAll",
    Callback = function(Value)
        AutoFarmAllEnabled = Value
        if Value then
            TeleportToFarmArea()
            task.wait(0.5)
            SetAFK(true)
            StartSpin()
            -- Record start time for reset timer
            FarmStartTime = os.clock()
        else
            SetAFK(false)
            StopSpin()
            FarmStartTime = 0
        end
    end,
})

MainTab:CreateSlider({
    Name = "Spin Speed",
    Range = {30, 120},
    Increment = 5,
    Suffix = " deg/frame",
    CurrentValue = 30,
    Flag = "SpinSpeed",
    Callback = function(Value)
        SpinSpeed = Value
    end,
})


local UpgradeSection = MainTab:CreateSection("Upgrades")

MainTab:CreateToggle({
    Name = "Auto Bone Upgrades (Balanced)",
    CurrentValue = false,
    Flag = "AutoBoneUpgrade",
    Callback = function(Value)
        AutoBoneUpgradeEnabled = Value
    end,
})

MainTab:CreateToggle({
    Name = "Auto Rebirth",
    CurrentValue = false,
    Flag = "AutoRebirth",
    Callback = function(Value)
        AutoRebirthEnabled = Value
    end,
})

MainTab:CreateToggle({
    Name = "Auto Material (Hunt Modifiers)",
    CurrentValue = false,
    Flag = "AutoMaterial",
    Callback = function(Value)
        AutoMaterialEnabled = Value
    end,
})

MainTab:CreateDropdown({
    Name = "Target Modifiers",
    Options = AllModifiers,
    CurrentOption = {"Forge"},
    MultipleOptions = true,
    Flag = "TargetModifiers",
    Callback = function(Options)
        TargetModifiers = Options
    end,
})

MainTab:CreateToggle({
    Name = "Auto Upgrade Ragdoll (When Got Modifier)",
    CurrentValue = true,
    Flag = "AutoUpgradeRagdoll",
    Callback = function(Value)
        AutoUpgradeRagdoll = Value
    end,
})

MainTab:CreateParagraph({
    Title = "Material Hunt Priority",
    Content = "FORGE STACKING: Gets Forge on ALL owned ragdolls before buying new ones (0.2x bonus stacks!)\n\nWill auto-equip ragdolls without Forge and refine until they have it. Bone upgrades paused during hunting."
})


local QuestsTab = Window:CreateTab("Quests", 4483362458)

local QuestSection = QuestsTab:CreateSection("Quest System")

QuestsTab:CreateToggle({
    Name = "Auto Quest",
    CurrentValue = false,
    Flag = "AutoQuest",
    Callback = function(Value)
        AutoQuestEnabled = Value
    end,
})

QuestsTab:CreateToggle({
    Name = "Auto Charm Quest (Geko)",
    CurrentValue = false,
    Flag = "AutoCharmQuest",
    Callback = function(Value)
        AutoCharmQuestEnabled = Value
    end,
})

QuestsTab:CreateToggle({
    Name = "Auto Mastery Upgrade",
    CurrentValue = false,
    Flag = "AutoMastery",
    Callback = function(Value)
        AutoMasteryEnabled = Value
    end,
})


local PalsTab = Window:CreateTab("Pals", 4483362458)

local PalSection = PalsTab:CreateSection("Pal System")

PalsTab:CreateToggle({
    Name = "Auto Pal Roll (When Free)",
    CurrentValue = false,
    Flag = "AutoPal",
    Callback = function(Value)
        AutoPalEnabled = Value
    end,
})

PalsTab:CreateToggle({
    Name = "Auto Daily Cookies",
    CurrentValue = true,
    Flag = "AutoDailyCookies",
    Callback = function(Value)
        AutoDailyCookiesEnabled = Value
    end,
})


local MiscTab = Window:CreateTab("Misc", 4483362458)

local ForgeSection = MiscTab:CreateSection("Forge")

MiscTab:CreateToggle({
    Name = "Auto Forge",
    CurrentValue = false,
    Flag = "AutoForge",
    Callback = function(Value)
        AutoForgeEnabled = Value
    end,
})

MiscTab:CreateButton({
    Name = "Start Forge",
    Callback = function()
        pcall(function()
            Remotes.StartForge:FireServer()
        end)
    end,
})

MiscTab:CreateButton({
    Name = "Claim Forge",
    Callback = function()
        pcall(function()
            Remotes.ClaimForge:FireServer()
        end)
    end,
})


local InfoTab = Window:CreateTab("Info", 4483362458)

InfoTab:CreateParagraph({
    Title = "Break Your Bones Hub",
    Content = "Auto Farm: AFK + Spin (resets every 5 min for materials)\nAuto Quests: Normal + Geko + Mastery\nAuto Material: Forge stacking on all ragdolls\nAuto Upgrades: Balanced bones + Rebirth\nAuto Pal: Free rolls + Daily Cookies\nAuto Forge: Start + Claim automatically"
})

InfoTab:CreateParagraph({
    Title = "Features",
    Content = "- Auto re-executes on server hop\n- Farm resets every 5 min (15 sec idle)\n- Spin speed: 30-120 deg/frame"
})

InfoTab:CreateParagraph({
    Title = "Credits",
    Content = "Script made by SeneX Please join our discord https://discord.gg/ZVHjadv4AG \nUI: Rayfield Library"
})

-- Main Loops
task.spawn(function()
    while task.wait(0.5) do
        -- Auto Quest
        if AutoQuestEnabled then
            pcall(function()
                local state = GetQuestState()
                if state == "Completed" then
                    Remotes.ClaimQuest:FireServer("Normal")
                    task.wait(0.5)
                elseif state == "None" then
                    Remotes.StartQuest:FireServer("Normal")
                    task.wait(0.5)
                elseif state == "Failed" then
                    Remotes.RestartQuest:FireServer()
                    task.wait(0.5)
                end
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        -- Auto Charm Quest (Geko)
        if AutoCharmQuestEnabled then
            pcall(function()
                local state = GetGekoQuestState()
                if state == "Completed" then
                    Remotes.ClaimQuest:FireServer("Geko")
                    task.wait(0.5)
                elseif state == "None" then
                    Remotes.StartQuest:FireServer("Geko")
                    task.wait(0.5)
                end
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(1) do
        -- Auto Mastery Upgrade
        if AutoMasteryEnabled then
            pcall(function()
                local xp = GetMasteryXP()
                local required = GetMasteryRequired()
                if xp >= required then
                    Remotes.MasteryLevel:FireServer()
                    task.wait(0.5)
                end
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(0.3) do
        -- Auto Bone Upgrade (Balanced - keeps all bones at same level)
        -- PRIORITY: Skip if Auto Material is active and we don't have target modifier yet
        if AutoBoneUpgradeEnabled then
            pcall(function()
                -- Check priority: if material hunting is on and we don't have target yet, save money
                if AutoMaterialEnabled then
                    local hasTarget, _ = HasTargetModifierOnCurrentRagdoll()
                    if not hasTarget then
                        -- Material hunting takes priority - don't spend on bones
                        return
                    end
                    -- If Forge is target and not all ragdolls have it, don't upgrade bones yet
                    if table.find(TargetModifiers, "Forge") and not AllRagdollsHaveForge() then
                        return
                    end
                end
                
                local bones = {"Arm", "Leg", "Head", "Torso"}
                local levels = {}
                
                for _, bone in ipairs(bones) do
                    levels[bone] = GetBoneLevel(bone)
                end
                
                -- Find the minimum level
                local minLevel = math.huge
                for _, level in pairs(levels) do
                    if level < minLevel then
                        minLevel = level
                    end
                end
                
                -- Upgrade bones that are at minimum level
                for _, bone in ipairs(bones) do
                    if levels[bone] == minLevel then
                        local price = GetBonePrice(levels[bone])
                        if GetCash() >= price then
                            Remotes.PurchaseBoneUpgrade:FireServer(bone)
                            task.wait(0.1)
                            break -- Only upgrade one at a time to keep balanced
                        end
                    end
                end
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(1) do
        -- Auto Rebirth
        if AutoRebirthEnabled then
            pcall(function()
                local required = GetRebirthRequired()
                if required > 0 and GetCash() >= required then
                    Remotes.Rebirth:FireServer()
                    task.wait(3) -- Wait for rebirth animation
                end
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(1) do
        -- Auto Material (Refining) - Hunt for selected modifiers
        -- FORGE STACKING: Get Forge on ALL ragdolls before buying new ones (0.2x stacks!)
        if AutoMaterialEnabled then
            pcall(function()
                local isForgeTarget = table.find(TargetModifiers, "Forge")
                
                -- FORGE STACKING LOGIC: Make sure all ragdolls have Forge before buying new
                if isForgeTarget then
                    -- Check if current ragdoll has Forge
                    local hasForgeOnCurrent, _ = HasTargetModifierOnCurrentRagdoll()
                    
                    if hasForgeOnCurrent then
                        -- Current ragdoll has Forge, check if ALL ragdolls have it
                        local ragdollWithoutForge = GetRagdollWithoutForge()
                        
                        if ragdollWithoutForge then
                            -- Found a ragdoll without Forge, equip it to get Forge
                            local currentRagdoll = GetCurrentRagdollName()
                            if currentRagdoll ~= ragdollWithoutForge then
                                Remotes.EquipRagdoll:FireServer(ragdollWithoutForge)
                                task.wait(1)
                                Rayfield:Notify({
                                    Title = "Switching Ragdoll",
                                    Content = "Equipping " .. ragdollWithoutForge .. " to get Forge (stacking 0.2x)",
                                    Duration = 3,
                                })
                            end
                            return -- Don't buy new ragdoll yet
                        else
                            -- All ragdolls have Forge! Now we can buy next ragdoll
                            if AutoUpgradeRagdoll then
                                local ragdollPrice = GetRagdollPrice()
                                if ragdollPrice and GetCash() >= ragdollPrice then
                                    Remotes.PurchaseNextRagdoll:FireServer()
                                    task.wait(1)
                                    Rayfield:Notify({
                                        Title = "Ragdoll Upgraded!",
                                        Content = "All ragdolls have Forge! Purchased next ragdoll!",
                                        Duration = 5,
                                    })
                                end
                            end
                            return
                        end
                    end
                    -- Current ragdoll doesn't have Forge yet - keep refining
                else
                    -- Non-Forge target - original logic
                    local hasTarget, foundMod = HasTargetModifierOnCurrentRagdoll()
                    if hasTarget then
                        if AutoUpgradeRagdoll then
                            local ragdollPrice = GetRagdollPrice()
                            if ragdollPrice and GetCash() >= ragdollPrice then
                                Remotes.PurchaseNextRagdoll:FireServer()
                                task.wait(1)
                                Rayfield:Notify({
                                    Title = "Ragdoll Upgraded!",
                                    Content = "Got " .. tostring(foundMod) .. "! Purchased next ragdoll!",
                                    Duration = 5,
                                })
                            end
                        end
                        return
                    end
                end
                
                -- Don't have target modifier yet - keep refining
                local cost, _ = GetRefiningCost()
                if HasItem("MaterialTicket") or GetCash() >= cost then
                    Remotes.RefineRagdoll:FireServer()
                    task.wait(2)
                end
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(1) do
        -- Auto Pal (Free Roll - only when you have PalTicket)
        if AutoPalEnabled then
            pcall(function()
                if HasItem("PalTicket") then
                    -- Check if pals are unlocked (gate 6+)
                    if GetGateNumber() >= 6 then
                        Remotes.RollPal:FireServer()
                        task.wait(7) -- Wait for roll animation
                    end
                end
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(2) do
        -- Auto Forge
        if AutoForgeEnabled then
            pcall(function()
                local forgeTimer, forgeDuration = GetForgeTimer()
                local serverTime = GetServerTime()
                
                -- Claim if forge is done
                if forgeDuration ~= 0 and forgeDuration <= serverTime then
                    Remotes.ClaimForge:FireServer()
                    task.wait(1)
                end
                
                -- Start new forge if timer is ready
                if forgeTimer < serverTime then
                    local forgePrice = Progression.GetForgePrice(GetPlayer())
                    if GetCash() >= forgePrice then
                        Remotes.StartForge:FireServer()
                        task.wait(1)
                    end
                end
            end)
        end
    end
end)

-- Auto Farm Reset Loop (every 5 minutes to allow material spinning)
task.spawn(function()
    while task.wait(10) do
        if AutoFarmAllEnabled and FarmStartTime > 0 then
            local elapsed = os.clock() - FarmStartTime
            if elapsed >= FARM_RESET_INTERVAL then
                -- Disable farming
                AutoFarmAllEnabled = false
                SetAFK(false)
                StopSpin()
                
                Rayfield:Notify({
                    Title = "Farm Reset",
                    Content = "Resetting character to allow material collection...",
                    Duration = 3,
                })
                
                -- Reset character
                pcall(function()
                    local character = Player.Character
                    if character and character:FindFirstChild("Humanoid") then
                        character.Humanoid.Health = 0
                    end
                end)
                
                -- Wait for respawn
                task.wait(5)
                
                -- Idle for 15 seconds
                task.wait(FARM_IDLE_TIME)
                
                -- Re-enable farming
                AutoFarmAllEnabled = true
                TeleportToFarmArea()
                task.wait(0.5)
                SetAFK(true)
                StartSpin()
                FarmStartTime = os.clock()
                
                Rayfield:Notify({
                    Title = "Farm Resumed",
                    Content = "Auto farming re-enabled!",
                    Duration = 3,
                })
            end
        end
    end
end)

-- Auto Daily Cookies Loop
task.spawn(function()
    while task.wait(60) do -- Check every minute
        if AutoDailyCookiesEnabled then
            pcall(function()
                Remotes.ClaimDailyCookies:FireServer()
            end)
        end
    end
end)

-- Notify user
Rayfield:Notify({
    Title = "Break Your Bones Hub",
    Content = "Script loaded successfully!",
    Duration = 5,
    Image = 4483362458,
})
