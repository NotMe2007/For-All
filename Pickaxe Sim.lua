--[[
    Pet Mine Simulator Script
    Using Rayfield UI Library
    Game ID: 82013336390273
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- Player
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- Paper Framework (Game's main module)
local Paper = require(ReplicatedStorage:WaitForChild("Paper"))
local Network = Paper.Network

-- Tables/Data
local EggsTable = require(ReplicatedStorage.Tables.Eggs)
local WorldsTable = require(ReplicatedStorage.Tables.Worlds)
local UpgradesTable = require(ReplicatedStorage.Tables.Upgrades)
local AchievementsTable = require(ReplicatedStorage.Tables.Achievements)

-- Load Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Variables
local AutoMineEnabled = false
local AutoHatchEnabled = false
local AutoRollEnabled = false
local AutoTrainEnabled = false
local AutoRebirthEnabled = false
local AutoSellEnabled = false
local AutoUpgradeEnabled = false
local AutoCollectChestsEnabled = false
local AutoClaimAchievementsEnabled = false
local AutoBuyPickaxeEnabled = false
local AutoBuyMinerEnabled = false
local AutoEventUpgradeEnabled = false
local SelectedEgg = "Basic Egg"
local HatchAmount = 3
local SelectedUpgrade = "More Damage"
local WalkSpeedValue = 16
local JumpPowerValue = 50

-- Gamepass Stats (loaded after Paper loads)
local HasSixEggHatch = false
local HasTwelveHatch = false
local HasAutoRebirthPass = false
local HasMaxRebirthPass = false
local HasSecretHunter = false
local HasMagicEggs = false
local HasFastHatch = false

-- Connections
local Connections = {}

-- Helper Functions
local function GetCharacter()
    return Player.Character or Player.CharacterAdded:Wait()
end

local function GetHumanoidRootPart()
    local char = GetCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid()
    local char = GetCharacter()
    return char and char:FindFirstChild("Humanoid")
end

local function SafeTeleport(position)
    local hrp = GetHumanoidRootPart()
    if hrp then
        hrp.CFrame = CFrame.new(position)
    end
end

local function GetCurrentWorld()
    local stat = Paper.Stats.Get("CurrentWorld")
    return stat and stat.Value or 1
end

local function GetEggsList()
    local eggs = {}
    for eggName, _ in pairs(EggsTable) do
        table.insert(eggs, eggName)
    end
    table.sort(eggs)
    return eggs
end

local function GetWorldsList()
    local worlds = {}
    for worldId, worldData in pairs(WorldsTable) do
        if worldData.WorldName then
            table.insert(worlds, {
                Name = worldData.WorldName,
                Id = worldId,
                Position = worldData.WorldTP
            })
        end
    end
    return worlds
end

local function GetUpgradesList()
    local upgrades = {}
    for upgradeName, _ in pairs(UpgradesTable) do
        table.insert(upgrades, upgradeName)
    end
    table.sort(upgrades)
    return upgrades
end

local function LoadGamepassStats()
    pcall(function()
        local sixEgg = Paper.Stats.Get("SixEggHatch")
        HasSixEggHatch = sixEgg and sixEgg.Value or false
        
        local twelveHatch = Paper.Stats.Get("TwelveHatchProduct")
        HasTwelveHatch = twelveHatch and twelveHatch.Value or false
        
        local autoRebirth = Paper.Stats.Get("AutoRebirthPass")
        HasAutoRebirthPass = autoRebirth and autoRebirth.Value or false
        
        local maxRebirth = Paper.Stats.Get("MaxRebirthPass")
        HasMaxRebirthPass = maxRebirth and maxRebirth.Value or false
        
        local secretHunter = Paper.Stats.Get("SecretHunter")
        HasSecretHunter = secretHunter and secretHunter.Value or false
        
        local magicEggs = Paper.Stats.Get("MagicEggs")
        HasMagicEggs = magicEggs and magicEggs.Value or false
        
        local fastHatch = Paper.Stats.Get("FastHatch")
        HasFastHatch = fastHatch and fastHatch.Value or false
    end)
end

-- Auto Mine Function
local function DoAutoMine()
    if not AutoMineEnabled then return end
    
    pcall(function()
        Network.FireServer("Mine", "Hit")
    end)
end

-- Auto Hatch Function
local function DoAutoHatch()
    if not AutoHatchEnabled then return end
    
    pcall(function()
        local eggData = EggsTable[SelectedEgg]
        if eggData then
            -- Use correct hatch amount based on gamepasses
            local amount = HatchAmount
            if amount == 6 and not HasSixEggHatch then
                amount = 3
            elseif amount == 12 and not HasTwelveHatch then
                amount = HasSixEggHatch and 6 or 3
            end
            Network.InvokeServer("Hatch Egg", SelectedEgg, amount)
        end
    end)
end

-- Auto Roll Function  
local function DoAutoRoll()
    if not AutoRollEnabled then return end
    
    pcall(function()
        Network.InvokeServer("Roll")
    end)
end

-- Auto Train Function
local function DoAutoTrain()
    if not AutoTrainEnabled then return end
    
    pcall(function()
        -- Find nearest training stone
        local trainingFolder = workspace:FindFirstChild("Training")
        if trainingFolder then
            for _, stone in pairs(trainingFolder:GetChildren()) do
                local proxim = stone:FindFirstChild("Proxim")
                if proxim then
                    local prompt = proxim:FindFirstChildOfClass("ProximityPrompt")
                    if prompt and prompt.Enabled then
                        fireproximityprompt(prompt)
                        task.wait(0.1)
                        break
                    end
                end
            end
        end
        
        -- Auto hit training stone
        Network.FireServer("Train Hit")
    end)
end

-- Auto Rebirth Function
local function DoAutoRebirth()
    if not AutoRebirthEnabled then return end
    
    pcall(function()
        Network.InvokeServer("Rebirth", 1)
    end)
end

-- Auto Sell Function
local function DoAutoSell()
    if not AutoSellEnabled then return end
    
    pcall(function()
        Network.FireServer("Sell Ores")
    end)
end

-- Auto Upgrade Function (20x per cycle)
local function DoAutoUpgrade()
    if not AutoUpgradeEnabled then return end
    
    pcall(function()
        -- Do 20 upgrades per cycle
        for i = 1, 20 do
            Network.InvokeServer("Upgrade", SelectedUpgrade)
            if i % 5 == 0 then
                task.wait(0.05) -- Small delay every 5 upgrades to prevent throttling
            end
        end
    end)
end

-- Buy specific upgrade once
local function BuyUpgrade(upgradeName)
    pcall(function()
        Network.InvokeServer("Upgrade", upgradeName)
    end)
end

-- Buy all upgrades (cycles through all types)
local function BuyAllUpgrades()
    pcall(function()
        local upgradeNames = GetUpgradesList()
        for _, upgradeName in ipairs(upgradeNames) do
            for i = 1, 10 do
                Network.InvokeServer("Upgrade", upgradeName)
            end
            task.wait(0.1)
        end
    end)
end

-- Auto Collect Chests
local function DoAutoCollectChests()
    if not AutoCollectChestsEnabled then return end
    
    pcall(function()
        Network.FireServer("Collect Chest", "Daily")
        Network.FireServer("Collect Chest", "Group")
    end)
end

-- Auto Claim Achievements
local function DoAutoClaimAchievements()
    if not AutoClaimAchievementsEnabled then return end
    
    pcall(function()
        for achievementName, achievementData in pairs(AchievementsTable) do
            -- Try to claim each tier of achievement (up to 15 tiers)
            for i = 1, 15 do
                local success = Network.InvokeServer("Claim Achievement", achievementName, i)
                if not success then
                    break
                end
            end
        end
    end)
end

-- Auto Buy Pickaxe
local function DoAutoBuyPickaxe()
    if not AutoBuyPickaxeEnabled then return end
    
    pcall(function()
        Network.InvokeServer("Buy Pickaxe")
    end)
end

-- Auto Buy Miner
local function DoAutoBuyMiner()
    if not AutoBuyMinerEnabled then return end
    
    pcall(function()
        Network.InvokeServer("Buy Miner")
    end)
end

-- Auto Event/RNG Upgrades
local function DoAutoEventUpgrade()
    if not AutoEventUpgradeEnabled then return end
    
    pcall(function()
        -- Event upgrades list (RNG related)
        local eventUpgrades = {
            "Roll Speed",
            "Golden Chance",
            "Rainbow Chance",
            "Auto Roll",
            "Better Luck",
            "More Clovers"
        }
        for _, upgradeName in ipairs(eventUpgrades) do
            for i = 1, 5 do
                Network.InvokeServer("Event Upgrade", upgradeName)
            end
        end
    end)
end

-- Teleport to Egg
local function TeleportToEgg(eggName)
    pcall(function()
        local eggsFolder = workspace:FindFirstChild("Eggs")
        if eggsFolder then
            for _, egg in pairs(eggsFolder:GetDescendants()) do
                if egg.Name == eggName or (egg:GetAttribute("EggName") == eggName) then
                    local part = egg:IsA("BasePart") and egg or egg:FindFirstChildOfClass("BasePart")
                    if part then
                        SafeTeleport(part.Position + Vector3.new(0, 5, 0))
                        return
                    end
                end
            end
        end
    end)
end

-- Teleport to World (uses proper game mechanism)
local function TeleportToWorld(worldId)
    pcall(function()
        local worldData = WorldsTable[worldId]
        if worldData then
            -- Use the game's proper teleport mechanism so GUIs load correctly
            local success, _, err = Network.InvokeServer("Set Current World", worldId)
            if not success and err then
                Rayfield:Notify({
                    Title = "Teleport Failed",
                    Content = tostring(err),
                    Duration = 3,
                })
            end
        end
    end)
end

-- Force teleport (bypasses checks, for emergency use)
local function ForceTeleport(position)
    local hrp = GetHumanoidRootPart()
    if hrp then
        hrp.CFrame = CFrame.new(position)
    end
end

-- Create Rayfield Window
local Window = Rayfield:CreateWindow({
    Name = "Pet Mine Simulator",
    LoadingTitle = "Pet Mine Simulator Hub",
    LoadingSubtitle = "by Script Hub",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "PetMineSimulator",
        FileName = "Config"
    },
    Discord = {
        Enabled = false,
        Invite = "",
        RememberJoins = true
    },
    KeySystem = false
})

-- Main Tab
local MainTab = Window:CreateTab("Main", 4483362458)

-- Auto Mine Section
local AutoMineSection = MainTab:CreateSection("Mining")

MainTab:CreateToggle({
    Name = "Auto Mine",
    CurrentValue = false,
    Flag = "AutoMine",
    Callback = function(Value)
        AutoMineEnabled = Value
    end,
})

MainTab:CreateToggle({
    Name = "Auto Sell Ores",
    CurrentValue = false,
    Flag = "AutoSell",
    Callback = function(Value)
        AutoSellEnabled = Value
    end,
})

MainTab:CreateButton({
    Name = "Teleport to Mine",
    Callback = function()
        local currentWorld = GetCurrentWorld()
        local worldData = WorldsTable[currentWorld]
        if worldData and worldData.MineCoordinates then
            SafeTeleport(Vector3.new(worldData.MineCoordinates.X, worldData.MineCoordinates.Y + 10, worldData.MineCoordinates.Z))
        end
    end,
})

-- Eggs Section
local EggsSection = MainTab:CreateSection("Eggs")

MainTab:CreateToggle({
    Name = "Auto Hatch",
    CurrentValue = false,
    Flag = "AutoHatch",
    Callback = function(Value)
        AutoHatchEnabled = Value
    end,
})

MainTab:CreateDropdown({
    Name = "Select Egg",
    Options = GetEggsList(),
    CurrentOption = {"Basic Egg"},
    MultipleOptions = false,
    Flag = "SelectedEgg",
    Callback = function(Options)
        SelectedEgg = Options[1]
    end,
})

MainTab:CreateDropdown({
    Name = "Hatch Amount",
    Options = {"1", "3", "6 (Gamepass)", "12 (Gamepass)", "Max"},
    CurrentOption = {"3"},
    MultipleOptions = false,
    Flag = "HatchAmount",
    Callback = function(Options)
        local selected = Options[1]
        if selected == "1" then
            HatchAmount = 1
        elseif selected == "3" then
            HatchAmount = 3
        elseif selected == "6 (Gamepass)" then
            HatchAmount = 6
        elseif selected == "12 (Gamepass)" then
            HatchAmount = 12
        elseif selected == "Max" then
            HatchAmount = "Max"
        end
    end,
})

MainTab:CreateButton({
    Name = "Teleport to Selected Egg",
    Callback = function()
        TeleportToEgg(SelectedEgg)
    end,
})

-- RNG Tab
local RNGTab = Window:CreateTab("RNG", 4483362458)

RNGTab:CreateSection("RNG Rolling")

RNGTab:CreateToggle({
    Name = "Auto Roll",
    CurrentValue = false,
    Flag = "AutoRoll",
    Callback = function(Value)
        AutoRollEnabled = Value
    end,
})

RNGTab:CreateButton({
    Name = "Roll Once",
    Callback = function()
        pcall(function()
            Network.InvokeServer("Roll")
        end)
    end,
})

RNGTab:CreateButton({
    Name = "Teleport to RNG Area",
    Callback = function()
        TeleportToWorld(-1)
    end,
})

RNGTab:CreateSection("RNG/Event Upgrades")

RNGTab:CreateToggle({
    Name = "Auto Buy Event Upgrades",
    CurrentValue = false,
    Flag = "AutoEventUpgrade",
    Callback = function(Value)
        AutoEventUpgradeEnabled = Value
    end,
})

RNGTab:CreateButton({
    Name = "Buy Roll Speed Upgrade",
    Callback = function()
        pcall(function()
            for i = 1, 10 do
                Network.InvokeServer("Event Upgrade", "Roll Speed")
            end
        end)
    end,
})

RNGTab:CreateButton({
    Name = "Buy Golden Chance Upgrade",
    Callback = function()
        pcall(function()
            for i = 1, 10 do
                Network.InvokeServer("Event Upgrade", "Golden Chance")
            end
        end)
    end,
})

RNGTab:CreateButton({
    Name = "Buy Rainbow Chance Upgrade",
    Callback = function()
        pcall(function()
            for i = 1, 10 do
                Network.InvokeServer("Event Upgrade", "Rainbow Chance")
            end
        end)
    end,
})

RNGTab:CreateButton({
    Name = "Buy Auto Roll Upgrade",
    Callback = function()
        pcall(function()
            Network.InvokeServer("Event Upgrade", "Auto Roll")
        end)
    end,
})

-- Training & Rebirth Tab
local TrainingTab = Window:CreateTab("Training", 4483362458)

TrainingTab:CreateSection("Training")

TrainingTab:CreateToggle({
    Name = "Auto Train",
    CurrentValue = false,
    Flag = "AutoTrain",
    Callback = function(Value)
        AutoTrainEnabled = Value
    end,
})

TrainingTab:CreateButton({
    Name = "Start Training",
    Callback = function()
        pcall(function()
            Network.FireServer("Train")
        end)
    end,
})

TrainingTab:CreateButton({
    Name = "Stop Training",
    Callback = function()
        pcall(function()
            Network.FireServer("Stop Training")
        end)
    end,
})

TrainingTab:CreateSection("Rebirth")

TrainingTab:CreateToggle({
    Name = "Auto Rebirth",
    CurrentValue = false,
    Flag = "AutoRebirth",
    Callback = function(Value)
        AutoRebirthEnabled = Value
    end,
})

TrainingTab:CreateButton({
    Name = "Rebirth Once",
    Callback = function()
        pcall(function()
            Network.InvokeServer("Rebirth", 1)
        end)
    end,
})

TrainingTab:CreateButton({
    Name = "Max Rebirth (Gamepass)",
    Callback = function()
        pcall(function()
            if HasMaxRebirthPass then
                Network.InvokeServer("Rebirth", "Max")
            else
                Rayfield:Notify({
                    Title = "Gamepass Required",
                    Content = "You need the Max Rebirth gamepass!",
                    Duration = 3,
                })
            end
        end)
    end,
})

-- Teleports Tab
local TeleportsTab = Window:CreateTab("Teleports", 4483362458)

TeleportsTab:CreateSection("World Teleports")

-- Add world teleport buttons
local worldsList = GetWorldsList()
for _, world in ipairs(worldsList) do
    TeleportsTab:CreateButton({
        Name = "Teleport to " .. world.Name,
        Callback = function()
            TeleportToWorld(world.Id)
        end,
    })
end

TeleportsTab:CreateSection("Quick Teleports")

TeleportsTab:CreateButton({
    Name = "Teleport to Spawn",
    Callback = function()
        TeleportToWorld(1)
    end,
})

TeleportsTab:CreateButton({
    Name = "Teleport to RNG World",
    Callback = function()
        TeleportToWorld(-1)
    end,
})

TeleportsTab:CreateButton({
    Name = "Teleport to Leaderboards",
    Callback = function()
        TeleportToWorld(0)
    end,
})

-- Upgrades Tab
local UpgradesTab = Window:CreateTab("Upgrades", 4483362458)

UpgradesTab:CreateSection("Auto Upgrades")

UpgradesTab:CreateToggle({
    Name = "Auto Buy Upgrades (20x/sec)",
    CurrentValue = false,
    Flag = "AutoUpgrade",
    Callback = function(Value)
        AutoUpgradeEnabled = Value
    end,
})

UpgradesTab:CreateDropdown({
    Name = "Select Upgrade Type",
    Options = GetUpgradesList(),
    CurrentOption = {"More Damage"},
    MultipleOptions = false,
    Flag = "SelectedUpgrade",
    Callback = function(Options)
        SelectedUpgrade = Options[1]
    end,
})

UpgradesTab:CreateButton({
    Name = "Buy Selected Upgrade (20x)",
    Callback = function()
        pcall(function()
            for i = 1, 20 do
                Network.InvokeServer("Upgrade", SelectedUpgrade)
                task.wait(0.05)
            end
        end)
    end,
})

UpgradesTab:CreateButton({
    Name = "Buy All Upgrade Types",
    Callback = function()
        BuyAllUpgrades()
    end,
})

UpgradesTab:CreateSection("Quick Upgrades")

UpgradesTab:CreateButton({
    Name = "Buy More Damage (20x)",
    Callback = function()
        pcall(function()
            for i = 1, 20 do
                Network.InvokeServer("Upgrade", "More Damage")
                task.wait(0.05)
            end
        end)
    end,
})

UpgradesTab:CreateButton({
    Name = "Buy More Coins (20x)",
    Callback = function()
        pcall(function()
            for i = 1, 20 do
                Network.InvokeServer("Upgrade", "More Coins")
                task.wait(0.05)
            end
        end)
    end,
})

UpgradesTab:CreateButton({
    Name = "Buy More Gems (20x)",
    Callback = function()
        pcall(function()
            for i = 1, 20 do
                Network.InvokeServer("Upgrade", "More Gems")
                task.wait(0.05)
            end
        end)
    end,
})

UpgradesTab:CreateButton({
    Name = "Buy More Rebirths (20x)",
    Callback = function()
        pcall(function()
            for i = 1, 20 do
                Network.InvokeServer("Upgrade", "More Rebirths")
                task.wait(0.05)
            end
        end)
    end,
})

UpgradesTab:CreateButton({
    Name = "Buy Egg Luck (20x)",
    Callback = function()
        pcall(function()
            for i = 1, 20 do
                Network.InvokeServer("Upgrade", "Egg Luck")
                task.wait(0.05)
            end
        end)
    end,
})

UpgradesTab:CreateSection("Misc Purchases")

UpgradesTab:CreateButton({
    Name = "Collect Daily Chest",
    Callback = function()
        pcall(function()
            Network.FireServer("Collect Chest", "Daily")
        end)
    end,
})

UpgradesTab:CreateButton({
    Name = "Collect Group Chest",
    Callback = function()
        pcall(function()
            Network.FireServer("Collect Chest", "Group")
        end)
    end,
})

UpgradesTab:CreateSection("Equipment")

UpgradesTab:CreateToggle({
    Name = "Auto Buy Pickaxe",
    CurrentValue = false,
    Flag = "AutoBuyPickaxe",
    Callback = function(Value)
        AutoBuyPickaxeEnabled = Value
    end,
})

UpgradesTab:CreateToggle({
    Name = "Auto Buy Miner",
    CurrentValue = false,
    Flag = "AutoBuyMiner",
    Callback = function(Value)
        AutoBuyMinerEnabled = Value
    end,
})

UpgradesTab:CreateButton({
    Name = "Buy Next Pickaxe",
    Callback = function()
        pcall(function()
            local success, _, err = Network.InvokeServer("Buy Pickaxe")
            if success then
                Rayfield:Notify({
                    Title = "Success",
                    Content = "Pickaxe purchased!",
                    Duration = 3,
                })
            elseif err then
                Rayfield:Notify({
                    Title = "Failed",
                    Content = tostring(err),
                    Duration = 3,
                })
            end
        end)
    end,
})

UpgradesTab:CreateButton({
    Name = "Buy Next Miner",
    Callback = function()
        pcall(function()
            local success, _, err = Network.InvokeServer("Buy Miner")
            if success then
                Rayfield:Notify({
                    Title = "Success",
                    Content = "Miner purchased!",
                    Duration = 3,
                })
            elseif err then
                Rayfield:Notify({
                    Title = "Failed",
                    Content = tostring(err),
                    Duration = 3,
                })
            end
        end)
    end,
})

-- Pets Tab
local PetsTab = Window:CreateTab("Pets", 4483362458)

PetsTab:CreateSection("Pet Management")

PetsTab:CreateButton({
    Name = "Equip Best Pets",
    Callback = function()
        pcall(function()
            Network.FireServer("Equip Best Pets")
        end)
    end,
})

PetsTab:CreateButton({
    Name = "Unequip All Pets",
    Callback = function()
        pcall(function()
            Network.FireServer("Unequip All Pets")
        end)
    end,
})

PetsTab:CreateButton({
    Name = "Delete Worst Pets",
    Callback = function()
        pcall(function()
            Network.FireServer("Delete Worst Pets")
        end)
    end,
})

PetsTab:CreateSection("Golden Machine")

PetsTab:CreateButton({
    Name = "Make Pet Golden",
    Callback = function()
        pcall(function()
            Network.InvokeServer("Golden Machine")
        end)
    end,
})

PetsTab:CreateButton({
    Name = "Make Pet Rainbow",
    Callback = function()
        pcall(function()
            Network.InvokeServer("Rainbow Machine")
        end)
    end,
})

-- Achievements Tab
local AchievementsTab = Window:CreateTab("Achievements", 4483362458)

AchievementsTab:CreateSection("Auto Achievements")

AchievementsTab:CreateToggle({
    Name = "Auto Claim Achievements",
    CurrentValue = false,
    Flag = "AutoClaimAchievements",
    Callback = function(Value)
        AutoClaimAchievementsEnabled = Value
    end,
})

AchievementsTab:CreateButton({
    Name = "Claim All Achievements",
    Callback = function()
        pcall(function()
            local claimedCount = 0
            for achievementName, achievementData in pairs(AchievementsTable) do
                for i = 1, 15 do
                    local success = Network.InvokeServer("Claim Achievement", achievementName, i)
                    if success then
                        claimedCount = claimedCount + 1
                    end
                end
            end
            Rayfield:Notify({
                Title = "Achievements",
                Content = "Claimed " .. claimedCount .. " achievement rewards!",
                Duration = 3,
            })
        end)
    end,
})

AchievementsTab:CreateSection("Individual Achievements")

AchievementsTab:CreateButton({
    Name = "Claim Blocks Mined",
    Callback = function()
        pcall(function()
            for i = 1, 15 do
                Network.InvokeServer("Claim Achievement", "Blocks Mined", i)
            end
        end)
    end,
})

AchievementsTab:CreateButton({
    Name = "Claim Power Achievement",
    Callback = function()
        pcall(function()
            for i = 1, 15 do
                Network.InvokeServer("Claim Achievement", "Power", i)
            end
        end)
    end,
})

AchievementsTab:CreateButton({
    Name = "Claim Rebirths Achievement",
    Callback = function()
        pcall(function()
            for i = 1, 15 do
                Network.InvokeServer("Claim Achievement", "Rebirths", i)
            end
        end)
    end,
})

AchievementsTab:CreateButton({
    Name = "Claim Wins Achievement",
    Callback = function()
        pcall(function()
            for i = 1, 15 do
                Network.InvokeServer("Claim Achievement", "Wins", i)
            end
        end)
    end,
})

AchievementsTab:CreateButton({
    Name = "Claim Pets Hatched",
    Callback = function()
        pcall(function()
            for i = 1, 15 do
                Network.InvokeServer("Claim Achievement", "Pets Hatched", i)
            end
        end)
    end,
})

-- Player Tab
local PlayerTab = Window:CreateTab("Player", 4483362458)

PlayerTab:CreateSection("Speed Hacks")

PlayerTab:CreateSlider({
    Name = "Walk Speed",
    Range = {16, 500},
    Increment = 1,
    Suffix = " Speed",
    CurrentValue = 16,
    Flag = "WalkSpeed",
    Callback = function(Value)
        WalkSpeedValue = Value
        local hum = GetHumanoid()
        if hum then
            hum.WalkSpeed = Value
        end
    end,
})

PlayerTab:CreateSlider({
    Name = "Jump Power",
    Range = {50, 500},
    Increment = 1,
    Suffix = " Power",
    CurrentValue = 50,
    Flag = "JumpPower",
    Callback = function(Value)
        JumpPowerValue = Value
        local hum = GetHumanoid()
        if hum then
            hum.JumpPower = Value
        end
    end,
})

PlayerTab:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = false,
    Flag = "InfiniteJump",
    Callback = function(Value)
        if Connections.InfiniteJump then
            Connections.InfiniteJump:Disconnect()
            Connections.InfiniteJump = nil
        end
        
        if Value then
            Connections.InfiniteJump = game:GetService("UserInputService").JumpRequest:Connect(function()
                local hum = GetHumanoid()
                if hum then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end)
        end
    end,
})

PlayerTab:CreateSection("Misc")

PlayerTab:CreateButton({
    Name = "Reset Character",
    Callback = function()
        local hum = GetHumanoid()
        if hum then
            hum.Health = 0
        end
    end,
})

PlayerTab:CreateButton({
    Name = "Rejoin Server",
    Callback = function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, Player)
    end,
})

-- Settings Tab
local SettingsTab = Window:CreateTab("Settings", 4483362458)

SettingsTab:CreateSection("Game Settings")

SettingsTab:CreateButton({
    Name = "Toggle Auto Mine (In-Game)",
    Callback = function()
        pcall(function()
            Network.FireServer("Toggle Setting", "AutoMine")
        end)
    end,
})

SettingsTab:CreateButton({
    Name = "Toggle Auto Hatch (In-Game)",
    Callback = function()
        pcall(function()
            Network.FireServer("Toggle Setting", "Auto Hatch")
        end)
    end,
})

SettingsTab:CreateButton({
    Name = "Toggle Auto Roll (In-Game)",
    Callback = function()
        pcall(function()
            Network.FireServer("Toggle Setting", "AutoRoll")
        end)
    end,
})

SettingsTab:CreateButton({
    Name = "Toggle Auto Train (In-Game)",
    Callback = function()
        pcall(function()
            Network.FireServer("Toggle Setting", "AutoTrain")
        end)
    end,
})

SettingsTab:CreateButton({
    Name = "Toggle Auto Rebirth (In-Game)",
    Callback = function()
        pcall(function()
            Network.FireServer("Toggle Setting", "AutoRebirth")
        end)
    end,
})

SettingsTab:CreateSection("Gamepass Info")

SettingsTab:CreateButton({
    Name = "Refresh Gamepass Status",
    Callback = function()
        LoadGamepassStats()
        Rayfield:Notify({
            Title = "Gamepasses Refreshed",
            Content = "Six Hatch: " .. tostring(HasSixEggHatch) .. ", 12 Hatch: " .. tostring(HasTwelveHatch) .. ", Auto Rebirth: " .. tostring(HasAutoRebirthPass),
            Duration = 5,
        })
    end,
})

SettingsTab:CreateSection("UI Settings")

Rayfield:LoadConfiguration()

-- Load gamepass stats on startup
task.spawn(function()
    task.wait(2) -- Wait for game to fully load
    LoadGamepassStats()
end)

-- Main Loop
task.spawn(function()
    while task.wait(0.1) do
        -- Auto Mine
        if AutoMineEnabled then
            DoAutoMine()
        end
        
        -- Auto Sell
        if AutoSellEnabled then
            DoAutoSell()
        end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        -- Auto Hatch (slower interval)
        if AutoHatchEnabled then
            DoAutoHatch()
        end
        
        -- Auto Roll
        if AutoRollEnabled then
            DoAutoRoll()
        end
    end
end)

task.spawn(function()
    while task.wait(1) do
        -- Auto Train
        if AutoTrainEnabled then
            DoAutoTrain()
        end
        
        -- Auto Rebirth
        if AutoRebirthEnabled then
            DoAutoRebirth()
        end
        
        -- Auto Upgrade
        if AutoUpgradeEnabled then
            DoAutoUpgrade()
        end
        
        -- Auto Buy Pickaxe
        if AutoBuyPickaxeEnabled then
            DoAutoBuyPickaxe()
        end
        
        -- Auto Buy Miner
        if AutoBuyMinerEnabled then
            DoAutoBuyMiner()
        end
        
        -- Auto Event Upgrade
        if AutoEventUpgradeEnabled then
            DoAutoEventUpgrade()
        end
    end
end)

-- Slower loop for achievements (5 seconds)
task.spawn(function()
    while task.wait(5) do
        -- Auto Claim Achievements
        if AutoClaimAchievementsEnabled then
            DoAutoClaimAchievements()
        end
    end
end)

-- Apply walkspeed/jumppower on respawn
Player.CharacterAdded:Connect(function(char)
    Character = char
    local hum = char:WaitForChild("Humanoid")
    task.wait(0.5)
    if WalkSpeedValue > 16 then
        hum.WalkSpeed = WalkSpeedValue
    end
    if JumpPowerValue > 50 then
        hum.JumpPower = JumpPowerValue
    end
end)

-- Notification
Rayfield:Notify({
    Title = "Pet Mine Simulator",
    Content = "Script loaded successfully!",
    Duration = 5,
    Image = 4483362458,
})

print("[Pet Mine Simulator] Script loaded!")
