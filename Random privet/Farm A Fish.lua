--[[
    ═══════════════════════════════════════════════════════════════════════════
    🐟 Farm a Fish - Ultimate AutoFarm Script v2.4
    ═══════════════════════════════════════════════════════════════════════════
    
    Features:
    ✓ Auto-Collect Fish from all nets (FIXED - now iterates all baits)
    ✓ Auto-Sell Fish (regular + event fish)
    ✓ SMART SELLING - Keeps event fish (Christmas, Alien, Robot mutations)
    ✓ Auto-Collect Crates & Pickups
    ✓ Fish Value Calculator
    ✓ Event Auto-Feed (Santa, Alien, Robot, Elf)
    ✓ Auto-Buy Bait
    ✓ Auto-Place Bait with placement bypass if possible
    ✓ ANTI-STAFF - Auto server hop when admin joins + saves settings
    ✓ Auto Feed Pets - Feeds fish to your pets automatically
    ✓ Auto Best Pet - Swaps to better pets based on perk scores
    ✓ Auto Open Bait Packs - Opens bait packs from inventory
    ✓ Smart Bait Management - Replaces worse placed baits with better ones
    ✓ Configurable options and intervals
    ✓ Debug mode for detailed logging
    ✓ Anti-AFK - Prevents idle kick by simulating activity
    ✓ Anti-Staff - Auto server hop when admin joins + saves settings
    ✓ Place pets if not already max
    ✓ Auto Buy Eggs - Automatically purchase eggs from the shop
    ✓ Auto Place Eggs - Automatically place eggs 
    ✓ Auto Hatch Eggs - Automatically hatch eggs when ready
    ✓ Auto Buy Gear - Automatically purchase gear from the shop
    ✓ Auto Use Gear - Automatically use gear based on types


    ═══════════════════════════════════════════════════════════════════════════


    Event Fish Protection:
    - Santa: Keeps fish with Christmas mutation
    - Alien UFO: Keeps fish with Alien mutation
    - Elf: Keeps fish caught with Christmas bait
    - Robot Mechanic: Keeps fish caught with Robot bait
    
    Pet System:
    - Auto Feed Pets: Uses non-event fish to level up your pets
    - Auto Best Pet: Ranks pets by perk value and swaps to optimal setup

    ═══════════════════════════════════════════════════════════════════════════
--]]

-- ═══════════════════════════════════════════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════════════════════════════════════════

local CONFIG = {
    -- Toggle Features
    AutoCollectFish = true,
    AutoSellFish = true,
    AutoSellEventFish = true,
    AutoCollectCrates = true,
    AutoCollectPickups = true,
    AutoBuyBait = false,
    AutoPlaceBait = false,
    AutoOpenBaitPacks = true, -- Auto open bait packs
    SmartBaitManagement = true, -- Remove worse baits, place better ones
    BypassPlacementCheck = false, -- Try to bypass same-spot restriction
    
    --Pet Features
    AutoFeedPets = false, -- Auto feed fish to pets
    AutoBestPet = false, -- Auto swap to best pets
    MaxFeedWeight = 10, -- Max fish weight (kg) to feed to pets (protects heavy fish)
    
    -- ═══════════════════════════════════════════════════════════════
    -- EGG SYSTEM - Auto buy, place, and hatch eggs
    -- ═══════════════════════════════════════════════════════════════
    AutoBuyEgg = false, -- Auto buy eggs from shop
    AutoPlaceEgg = false, -- Auto place eggs in incubators
    AutoHatchEgg = false, -- Auto hatch eggs when ready
    PreferredEgg = "Starter", -- Which egg to buy (Starter, Novice, Forest, Polar, Tropical, Exotic)
    MaxEggsInInventory = 3, -- Max eggs to hold before stopping
    EggCheckInterval = 5, -- How often to check egg status
    
    -- ═══════════════════════════════════════════════════════════════
    -- GEAR SYSTEM - Auto buy and use gear intelligently
    -- ═══════════════════════════════════════════════════════════════
    AutoBuyGear = false, -- Auto buy gear from shop
    AutoUseGear = false, -- Auto use gear based on type
    GearCheckInterval = 10, -- How often to check gear
    
    -- Gear auto-use settings (which gears to use)
    UseAutoFeeders = true, -- Use feeders next to best bait net
    UseDiamondCookie = true, -- Use on best pet (proximity TP)
    UseYolkBreaker = true, -- Use on Exotic/Tropical eggs ONLY
    UseEggHatcher = true, -- Use on eggs
    UseFoodTrays = true, -- Place food trays
    
    -- Gears to NEVER auto-use
    -- TimeJumper, NetRetractor, ShieldLock are excluded by default
    
    -- Timing (seconds)
    CollectFishInterval = 1,
    SellFishInterval = 5,
    CrateCheckInterval = 0.5,
    PickupCheckInterval = 0.5,
    BuyBaitInterval = 2,
    PlaceBaitInterval = 0.5,
    FeedPetsInterval = 5, -- How often to feed pets
    BestPetInterval = 30, -- How often to check for better pets
    
    -- Bait Settings
    PreferredBait = "Starter", -- Which bait to auto-buy (Starter, Novice, Reef, DeepSea, Koi, etc.)
    MaxBaitInInventory = 10, -- Stop buying when you have this many
    AutoPlaceAllBait = true, -- Place all bait in inventory
    PlacementSpacing = 5, -- Studs between placements (bypass mode)
    
    -- Sell Settings
    SellMinValue = 0, -- Minimum fish value to sell (0 = sell all)
    KeepLikedFish = true, -- Don't sell liked/favorited fish
    
    -- ═══════════════════════════════════════════════════════════════
    -- EVENT FISH PROTECTION - Keep fish with these mutations/baits
    -- These fish can be fed to Santa, Alien, Robot, or Elf NPCs
    -- ═══════════════════════════════════════════════════════════════
    KeepEventFish = true, -- Master toggle for smart selling
    
    -- Mutations to keep (fish with these mutations won't be sold)
    EventMutationsToKeep = {
        "Christmas", -- Santa wants fish with Christmas mutation
        "Alien",     -- Alien UFO wants fish with Alien mutation
    },
    
    -- Event bait types to keep (fish from these baits won't be sold)
    -- Elf wants Christmas bait fish, Robot wants Robot bait fish
    EventBaitTypesToKeep = {
        "Christmas", -- Christmas event bait fish
        "Robot",     -- Robot event bait fish
        "Alien",     -- Alien event bait fish
    },
    
    -- UI Settings
    ShowNotifications = true,
    DebugMode = false,
    
    -- ═══════════════════════════════════════════════════════════════
    -- ANTI-AFK - Prevents AFK kick by walking and server hopping
    -- ═══════════════════════════════════════════════════════════════
    AntiAFK = false, -- Master toggle for anti-AFK protection
    AFKIdleTime = 300, -- 5 minutes in seconds before anti-AFK activates
    AFKWalkDistance = 5, -- Studs to walk away
    AFKServerHopMin = 45 * 60, -- 45 minutes minimum before server hop (in seconds)
    AFKServerHopMax = 85 * 60, -- 1 hour 25 minutes maximum before server hop (in seconds)
    
    -- ═══════════════════════════════════════════════════════════════
    -- ANTI-STAFF - Auto server hop when admin/mod joins
    -- ═══════════════════════════════════════════════════════════════
    AntiStaff = true, -- Master toggle for anti-staff protection
    
    -- Staff detection methods
    DetectByGroupRank = true, -- Check game group for admin ranks
    DetectByCommands = true, -- Check if player has admin commands
    DetectByBadges = true, -- Check for staff badges
    
    -- Game group ID (Tetra Games - Farm a Fish developers)
    GameGroupId = 4843918, -- Tetra Games group
    MinStaffRank = 200, -- Minimum group rank to consider as staff
    
    -- Known staff usernames (add known staff here)
    KnownStaffUsernames = {
        -- Add staff usernames here like:
        -- "StaffUsername1",
    },
    
    -- Known staff UserIDs (more reliable than usernames)
    -- These are confirmed Tetra Games staff/admins
    KnownStaffUserIds = {
        129899851,   -- Staff
        5637838424,  -- Staff
        778981487,   -- Staff
        32153253,    -- Staff
        6746815,     -- Staff
        1933300649,  -- Staff
        112081885,   -- Staff
        562333816,   -- Staff
        379298478,   -- Staff
        443048015,   -- Staff
        180524806,   -- Staff
        145179198,   -- Staff
        2840817775,  -- Staff
        2444896149,  -- Staff
        73944834,    -- Staff
        23991466,    -- Staff
        30180836,    -- Staff
        100705948,   -- Staff
        3242953293,  -- Staff
        120036805,   -- Staff
        1595499446,  -- Staff
        215000681,   -- Staff
        526818140,   -- Staff
        21789509,    -- Staff
        33634819,    -- Staff
    },
    
    -- Admin command detection keywords
    AdminIndicators = {
        "Cmdr", -- Cmdr admin system
        "Admin", 
        "Kick",
        "Ban",
        "ServerAdmin",
    },
}

-- ═══════════════════════════════════════════════════════════════════════════
-- SERVICES & SETUP
-- ═══════════════════════════════════════════════════════════════════════════

-- CLEANUP: Stop all modules from previous execution
local PreviousState = {}
if getgenv().FAF then
    print("[FAF] 🔄 Re-execution detected - Cleaning up previous instance...")
    
    -- Save previous running states to restore later
    PreviousState = {
        AutoCollector = getgenv().FAF.AutoCollector and getgenv().FAF.AutoCollector.Running or false,
        AutoSeller = getgenv().FAF.AutoSeller and getgenv().FAF.AutoSeller.Running or false,
        AutoBuyer = getgenv().FAF.AutoBuyer and getgenv().FAF.AutoBuyer.Running or false,
        AutoPlacer = getgenv().FAF.AutoPlacer and getgenv().FAF.AutoPlacer.Running or false,
        CrateCollector = getgenv().FAF.CrateCollector and getgenv().FAF.CrateCollector.Running or false,
        EventFeeder = getgenv().FAF.EventFeeder and getgenv().FAF.EventFeeder.Running or false,
        AntiStaff = getgenv().FAF.AntiStaff and getgenv().FAF.AntiStaff.Running or false,
        AntiAFK = getgenv().FAF.AntiAFK and getgenv().FAF.AntiAFK.Running or false,
        AutoPetFeeder = getgenv().FAF.AutoPetFeeder and getgenv().FAF.AutoPetFeeder.Running or false,
        AutoBestPet = getgenv().FAF.AutoBestPet and getgenv().FAF.AutoBestPet.Running or false,
        BaitPackOpener = getgenv().FAF.BaitPackOpener and getgenv().FAF.BaitPackOpener.Running or false,
        SmartBaitManager = getgenv().FAF.SmartBaitManager and getgenv().FAF.SmartBaitManager.Running or false,
        AutoEgg = getgenv().FAF.AutoEgg and getgenv().FAF.AutoEgg.Running or false,
        AutoGear = getgenv().FAF.AutoGear and getgenv().FAF.AutoGear.Running or false,
    }
    
    -- Stop all modules from previous instance
    pcall(function() if getgenv().FAF.AutoCollector then getgenv().FAF.AutoCollector.Stop() end end)
    pcall(function() if getgenv().FAF.AutoSeller then getgenv().FAF.AutoSeller.Stop() end end)
    pcall(function() if getgenv().FAF.AutoBuyer then getgenv().FAF.AutoBuyer.Stop() end end)
    pcall(function() if getgenv().FAF.AutoPlacer then getgenv().FAF.AutoPlacer.Stop() end end)
    pcall(function() if getgenv().FAF.CrateCollector then getgenv().FAF.CrateCollector.Stop() end end)
    pcall(function() if getgenv().FAF.EventFeeder then getgenv().FAF.EventFeeder.Stop() end end)
    pcall(function() if getgenv().FAF.AntiStaff then getgenv().FAF.AntiStaff.Stop() end end)
    pcall(function() if getgenv().FAF.AntiAFK then getgenv().FAF.AntiAFK.Stop() end end)
    pcall(function() if getgenv().FAF.AutoPetFeeder then getgenv().FAF.AutoPetFeeder.Stop() end end)
    pcall(function() if getgenv().FAF.AutoBestPet then getgenv().FAF.AutoBestPet.Stop() end end)
    pcall(function() if getgenv().FAF.BaitPackOpener then getgenv().FAF.BaitPackOpener.Stop() end end)
    pcall(function() if getgenv().FAF.SmartBaitManager then getgenv().FAF.SmartBaitManager.Stop() end end)
    pcall(function() if getgenv().FAF.AutoEgg then getgenv().FAF.AutoEgg.Stop() end end)
    pcall(function() if getgenv().FAF.AutoGear then getgenv().FAF.AutoGear.Stop() end end)
    
    print("[FAF] ✓ Previous instance stopped")
    task.wait(0.2) -- Brief delay to let everything stop
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local GroupService = game:GetService("GroupService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Wait for game to load
repeat task.wait() until LocalPlayer.Character

-- ═══════════════════════════════════════════════════════════════════════════
-- REMOTE FINDER
-- ═══════════════════════════════════════════════════════════════════════════

local Remotes = {}

local function FindRemotes()
    local function SearchForRemotes(parent, path)
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
                Remotes[path .. child.Name] = child
                if CONFIG.DebugMode then
                    print("[FAF] Found Remote:", path .. child.Name)
                end
            end
            if #child:GetChildren() > 0 then
                SearchForRemotes(child, path .. child.Name .. "/")
            end
        end
    end
    
    -- Search common remote locations
    local remoteLocations = {
        ReplicatedStorage:FindFirstChild("Remotes"),
        ReplicatedStorage:FindFirstChild("Network"),
        ReplicatedStorage:FindFirstChild("Events"),
        ReplicatedStorage:FindFirstChild("rbxts_include"),
    }
    
    for _, location in ipairs(remoteLocations) do
        if location then
            SearchForRemotes(location, "")
        end
    end
    
    -- Also search ReplicatedStorage root
    SearchForRemotes(ReplicatedStorage, "")
end

-- Alternative: Get remotes from remo package (roblox-ts style)
local RemoRemotes = nil

local function GetRemoRemotes()
    if RemoRemotes then return RemoRemotes end
    
    local success, remotes = pcall(function()
        -- Method 1: Direct require of the remotes module
        local TS = ReplicatedStorage:FindFirstChild("TS")
        if TS then
            local remotesModule = TS:FindFirstChild("remotes")
            if remotesModule then
                local module = require(remotesModule)
                return module.default or module
            end
        end
        
        -- Method 2: Via rbxts_include RuntimeLib import
        local rbxts = ReplicatedStorage:FindFirstChild("rbxts_include")
        if rbxts then
            local runtimeLib = rbxts:FindFirstChild("RuntimeLib")
            if runtimeLib then
                local runtime = require(runtimeLib)
                if runtime and runtime.import then
                    local remotesModule = runtime.import(nil, ReplicatedStorage, "TS", "remotes")
                    return remotesModule.default or remotesModule
                end
            end
        end
        
        return nil
    end)
    
    if success and remotes then
        RemoRemotes = remotes
        if CONFIG.DebugMode then
            print("[FAF] Found remo remotes package")
        end
        return remotes
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- REMOTE ACCESS (Works with roblox-ts remo system)
-- ═══════════════════════════════════════════════════════════════════════════

local RemoteCache = {}

-- Fire remote using remo package (roblox-ts style)
local function FireRemote(namespace, remoteName, ...)
    local args = {...}
    
    -- Method 1: Use remo remotes (preferred)
    local remotes = GetRemoRemotes()
    if remotes then
        local success, result = pcall(function()
            local ns = remotes[namespace]
            if ns then
                local remote = ns[remoteName]
                if remote then
                    -- remo remotes have :fire() for events and :request() for functions
                    if remote.fire then
                        remote:fire(unpack(args))
                        return true
                    elseif remote.request then
                        return remote:request(unpack(args))
                    end
                end
            end
            return nil
        end)
        
        if success and result then
            return result
        end
        
        if CONFIG.DebugMode and not success then
            warn("[FAF] remo fire failed:", result)
        end
    end
    
    -- Method 2: Fallback to direct RemoteEvent search
    local cacheKey = namespace .. "." .. remoteName
    if RemoteCache[cacheKey] then
        local remote = RemoteCache[cacheKey]
        if remote:IsA("RemoteEvent") then
            remote:FireServer(unpack(args))
            return true
        elseif remote:IsA("RemoteFunction") then
            return remote:InvokeServer(unpack(args))
        end
    end
    
    -- Search for RemoteEvent/RemoteFunction
    local function SearchIn(parent)
        for _, child in ipairs(parent:GetDescendants()) do
            if (child:IsA("RemoteEvent") or child:IsA("RemoteFunction")) then
                local name = child.Name:lower()
                if name:find(remoteName:lower()) or name:find(namespace:lower() .. remoteName:lower()) then
                    RemoteCache[cacheKey] = child
                    return child
                end
            end
        end
        return nil
    end
    
    local remote = SearchIn(ReplicatedStorage)
    if remote then
        if remote:IsA("RemoteEvent") then
            remote:FireServer(unpack(args))
            return true
        elseif remote:IsA("RemoteFunction") then
            return remote:InvokeServer(unpack(args))
        end
    end
    
    if CONFIG.DebugMode then
        warn("[FAF] Remote not found:", namespace .. "." .. remoteName)
    end
    
    return false
end

-- Direct fire method for specific remo remotes (more reliable)
local function FireRemoRemote(path, ...)
    local remotes = GetRemoRemotes()
    if not remotes then
        if CONFIG.DebugMode then
            warn("[FAF] Remo remotes not available")
        end
        return false
    end
    
    local args = {...}
    local success, result = pcall(function()
        -- Parse path like "sellFish.sellAllFish"
        local parts = string.split(path, ".")
        local current = remotes
        
        for _, part in ipairs(parts) do
            current = current[part]
            if not current then
                error("Remote path not found: " .. path)
            end
        end
        
        if current.fire then
            current:fire(unpack(args))
            return true
        elseif current.request then
            return current:request(unpack(args))
        end
        
        return false
    end)
    
    if success then
        return result
    else
        if CONFIG.DebugMode then
            warn("[FAF] FireRemoRemote failed:", path, result)
        end
        return false
    end
end

local function GetRemote(namespace, remoteName)
    local cacheKey = namespace .. "." .. remoteName
    if RemoteCache[cacheKey] then
        return RemoteCache[cacheKey]
    end
    
    -- Try to find RemoteEvent/RemoteFunction in ReplicatedStorage
    local function SearchIn(parent)
        for _, child in ipairs(parent:GetDescendants()) do
            if (child:IsA("RemoteEvent") or child:IsA("RemoteFunction")) then
                local name = child.Name:lower()
                if name:find(remoteName:lower()) or name:find(namespace:lower() .. remoteName:lower()) then
                    RemoteCache[cacheKey] = child
                    return child
                end
            end
        end
        return nil
    end
    
    local remote = SearchIn(ReplicatedStorage)
    if remote then
        return remote
    end
    
    -- Fallback: Search by exact path patterns common in roblox-ts
    local possiblePaths = {
        ReplicatedStorage:FindFirstChild("Remotes"),
        ReplicatedStorage:FindFirstChild("Network"),
        ReplicatedStorage:FindFirstChild("rbxts_include"),
    }
    
    for _, path in ipairs(possiblePaths) do
        if path then
            remote = SearchIn(path)
            if remote then return remote end
        end
    end
    
    return nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- FISH VALUE CALCULATOR
-- ═══════════════════════════════════════════════════════════════════════════

local FishValueCalculator = {}

-- Rarity multipliers based on game data
FishValueCalculator.RarityMultipliers = {
    Common = 1,
    Uncommon = 1.5,
    Epic = 2.5,
    Legendary = 5,
    Mythic = 10,
    Ancient = 25,
}

-- Mutation multipliers (estimated from game patterns)
FishValueCalculator.MutationMultipliers = {
    Golden = 3,
    Diamond = 5,
    Void = 8,
    Rainbow = 4,
    Albino = 2,
    Colossal = 2.5,
    Tiny = 0.5,
    Electric = 2,
    Frozen = 2,
    Fiery = 2,
    Spectral = 3,
    Cosmic = 6,
}

-- Base values for baits (from game data)
FishValueCalculator.BaitBaseValues = {
    Starter = 15,
    Novice = 100,
    Reef = 275,
    DeepSea = 600,
    Koi = 1100,
    River = 2000,
    Puffer = 2500,
    Seal = 4000,
    Glo = 1250,
    Ray = 5000,
    Octopus = 7000,
    Axolotl = 2500,
    Jelly = 7500,
    Whale = 20000,
    Shark = 10000,
}

function FishValueCalculator.CalculateSmoothExponentialValue(baseValue, scale, options)
    options = options or {}
    local multiplier = options.multiplier or 0.1
    local cap = options.cap or 2.5
    
    return baseValue * math.pow(1 / scale, math.min(1 + -math.log10(scale) * multiplier, cap))
end

function FishValueCalculator.EstimateFishValue(fishData)
    local baseValue = fishData.baseValue or 100
    local scale = fishData.scale or 1
    local rarity = fishData.rarity or "Common"
    local mutations = fishData.mutations or {}
    
    -- Calculate base value with scale
    local value = FishValueCalculator.CalculateSmoothExponentialValue(baseValue, scale)
    
    -- Apply rarity multiplier
    local rarityMult = FishValueCalculator.RarityMultipliers[rarity] or 1
    value = value * rarityMult
    
    -- Apply mutation multipliers
    for _, mutation in ipairs(mutations) do
        local mutMult = FishValueCalculator.MutationMultipliers[mutation] or 1
        value = value * mutMult
    end
    
    return math.floor(value)
end

function FishValueCalculator.PrintValueTable()
    print("\n═══════════════════════════════════════════════════════════════")
    print("🐟 FISH VALUE CALCULATOR - Estimated Values")
    print("═══════════════════════════════════════════════════════════════\n")
    
    for baitName, baseVal in pairs(FishValueCalculator.BaitBaseValues) do
        print(string.format("%-12s | Base: %8d | Golden: %8d | Diamond: %8d",
            baitName,
            baseVal,
            baseVal * 3,
            baseVal * 5
        ))
    end
    
    print("\n═══════════════════════════════════════════════════════════════\n")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- AUTO COLLECT FISH (FIXED - Now iterates through all placed baits)
-- ═══════════════════════════════════════════════════════════════════════════

local AutoCollector = {}
AutoCollector.Running = false
AutoCollector.CollectedCount = 0

-- Get all placed bait IDs from player data
function AutoCollector.GetPlacedBaitIds()
    local baitIds = {}
    
    local success, result = pcall(function()
        -- Method 1: Try accessing player data via Charm state
        local TS = ReplicatedStorage:FindFirstChild("TS")
        if TS then
            local stateFolder = TS:FindFirstChild("state")
            if stateFolder then
                local playerDataModule = stateFolder:FindFirstChild("player-data")
                if playerDataModule then
                    local module = require(playerDataModule)
                    if module then
                        local getPlayerData = module.getPlayerData or module.getPlayerDataById
                        if getPlayerData then
                            local data = getPlayerData(LocalPlayer) or getPlayerData(tostring(LocalPlayer.UserId))
                            if data then
                                local currentPond = data.currentPond or "Pond1"
                                local pondData = data.ponds and data.ponds[currentPond]
                                if pondData and pondData.baits then
                                    for baitId, _ in pairs(pondData.baits) do
                                        table.insert(baitIds, baitId)
                                    end
                                end
                                -- Also check other ponds
                                if data.ponds then
                                    for pondName, pond in pairs(data.ponds) do
                                        if pond.baits and pondName ~= currentPond then
                                            for baitId, _ in pairs(pond.baits) do
                                                table.insert(baitIds, baitId)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        -- Method 2: Try rbxts_include path
        if #baitIds == 0 then
            local rbxts = ReplicatedStorage:FindFirstChild("rbxts_include")
            if rbxts then
                local runtimeLib = rbxts:FindFirstChild("RuntimeLib")
                if runtimeLib then
                    local runtime = require(runtimeLib)
                    if runtime and runtime.import then
                        local playerDataModule = runtime.import(nil, ReplicatedStorage, "TS", "state", "player-data")
                        if playerDataModule then
                            local getPlayerData = playerDataModule.getPlayerData or playerDataModule.getPlayerDataById
                            if getPlayerData then
                                local data = getPlayerData(LocalPlayer) or getPlayerData(tostring(LocalPlayer.UserId))
                                if data and data.ponds then
                                    for pondName, pond in pairs(data.ponds) do
                                        if pond.baits then
                                            for baitId, _ in pairs(pond.baits) do
                                                table.insert(baitIds, baitId)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        -- Method 3: Search workspace for net models with bait attributes
        if #baitIds == 0 then
            local ponds = Workspace:FindFirstChild("Ponds") or Workspace:FindFirstChild("Map")
            if ponds then
                for _, child in ipairs(ponds:GetDescendants()) do
                    if child:IsA("Model") and (child.Name:lower():find("net") or child.Name:lower():find("bait")) then
                        local baitIdAttr = child:GetAttribute("baitId") or child:GetAttribute("BaitId")
                        if baitIdAttr then
                            table.insert(baitIds, baitIdAttr)
                        end
                    end
                end
            end
        end
        
        return baitIds
    end)
    
    if success then
        return result
    end
    
    return baitIds
end

function AutoCollector.CollectAllFish()
    local baitIds = AutoCollector.GetPlacedBaitIds()
    local totalCollected = 0
    
    if #baitIds > 0 then
        -- Collect from each placed bait
        for _, baitId in ipairs(baitIds) do
            -- Try remo first, then fallback
            local success = FireRemoRemote("bait.collectAllFish", baitId) or FireRemote("bait", "collectAllFish", baitId)
            if success then
                totalCollected = totalCollected + 1
            end
            task.wait(0.1) -- Small delay between collections
        end
        
        if totalCollected > 0 then
            AutoCollector.CollectedCount = AutoCollector.CollectedCount + totalCollected
            if CONFIG.ShowNotifications and AutoCollector.CollectedCount % 10 == 0 then
                print("[FAF] Collected from " .. totalCollected .. " nets (Total: " .. AutoCollector.CollectedCount .. ")")
            end
        end
    else
        -- Fallback: Try collecting without baitId (old behavior)
        -- This might work if the server accepts it
        local success = FireRemoRemote("bait.collectAllFish") or FireRemote("bait", "collectAllFish")
        if success then
            AutoCollector.CollectedCount = AutoCollector.CollectedCount + 1
        end
        
        if CONFIG.DebugMode then
            print("[FAF] No baits found, tried fallback collect")
        end
    end
    
    return totalCollected > 0
end

function AutoCollector.Start()
    if AutoCollector.Running then return end
    AutoCollector.Running = true
    
    print("[FAF] 🐟 Auto Fish Collector STARTED (Fixed - Now collects from all nets)")
    
    task.spawn(function()
        while AutoCollector.Running and CONFIG.AutoCollectFish do
            AutoCollector.CollectAllFish()
            task.wait(CONFIG.CollectFishInterval)
        end
    end)
end

function AutoCollector.Stop()
    AutoCollector.Running = false
    print("[FAF] 🐟 Auto Fish Collector STOPPED")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- AUTO SELL FISH (Smart Selling - Keeps Event Fish)
-- ═══════════════════════════════════════════════════════════════════════════

local AutoSeller = {}
AutoSeller.Running = false
AutoSeller.TotalSold = 0
AutoSeller.TotalEarned = 0
AutoSeller.EventFishKept = 0

-- Get player data from game state (Charm atoms)
function AutoSeller.GetPlayerData()
    local success, playerData = pcall(function()
        -- Try multiple methods to access player data
        
        -- Method 1: Try to access Charm atoms directly
        local TS = ReplicatedStorage:FindFirstChild("TS")
        if TS then
            local stateFolder = TS:FindFirstChild("state")
            if stateFolder then
                local playerDataModule = stateFolder:FindFirstChild("player-data")
                if playerDataModule then
                    local module = require(playerDataModule)
                    if module and module.getPlayerData then
                        return module.getPlayerData(LocalPlayer)
                    end
                end
            end
        end
        
        -- Method 2: Try rbxts_include path
        local rbxts = ReplicatedStorage:FindFirstChild("rbxts_include")
        if rbxts then
            local runtimeLib = rbxts:FindFirstChild("RuntimeLib")
            if runtimeLib then
                local runtime = require(runtimeLib)
                if runtime and runtime.import then
                    local playerDataModule = runtime.import(nil, ReplicatedStorage, "TS", "state", "player-data")
                    if playerDataModule and playerDataModule.getPlayerData then
                        return playerDataModule.getPlayerData(LocalPlayer)
                    end
                end
            end
        end
        
        return nil
    end)
    
    if success and playerData then
        return playerData
    end
    return nil
end

-- Check if fish has an event mutation
function AutoSeller.HasEventMutation(fishData)
    if not fishData or not fishData.mutations then
        return false
    end
    
    for _, mutation in ipairs(fishData.mutations) do
        -- Check against configured mutations to keep
        for _, eventMutation in ipairs(CONFIG.EventMutationsToKeep) do
            if tostring(mutation):lower():find(eventMutation:lower()) then
                return true
            end
        end
    end
    
    return false
end

-- Check if fish is from an event bait type
function AutoSeller.IsFromEventBait(fishData)
    if not fishData or not fishData.fishType then
        return false
    end
    
    -- Get the bait type for this fish (would need game utils)
    -- For now, check if fish name contains event keywords
    local fishType = tostring(fishData.fishType):lower()
    
    for _, eventBait in ipairs(CONFIG.EventBaitTypesToKeep) do
        if fishType:find(eventBait:lower()) then
            return true
        end
    end
    
    return false
end

-- Check if fish should be kept (not sold)
function AutoSeller.ShouldKeepFish(fishData)
    if not fishData then
        return false
    end
    
    -- Keep liked/favorited fish
    if CONFIG.KeepLikedFish and fishData.liked then
        return true
    end
    
    -- Keep event fish if enabled
    if CONFIG.KeepEventFish then
        -- Check for event mutations (Christmas, Alien)
        if AutoSeller.HasEventMutation(fishData) then
            return true
        end
        
        -- Check if from event bait (Robot, Christmas, Alien baits)
        if AutoSeller.IsFromEventBait(fishData) then
            return true
        end
    end
    
    return false
end

-- Smart sell: Sell individual fish, skipping event fish
function AutoSeller.SmartSellFish()
    local playerData = AutoSeller.GetPlayerData()
    
    if not playerData or not playerData.inventory or not playerData.inventory.fishes then
        -- Fallback to bulk sell if we can't read inventory
        if CONFIG.DebugMode then
            warn("[FAF] Could not read player inventory, using bulk sell")
        end
        -- Try both methods
        local success = FireRemoRemote("sellFish.sellAllFish") or FireRemote("sellFish", "sellAllFish")
        return success
    end
    
    local soldCount = 0
    local keptCount = 0
    
    for fishId, fishData in pairs(playerData.inventory.fishes) do
        if AutoSeller.ShouldKeepFish(fishData) then
            keptCount = keptCount + 1
            AutoSeller.EventFishKept = AutoSeller.EventFishKept + 1
            
            if CONFIG.DebugMode then
                local mutations = fishData.mutations and table.concat(fishData.mutations, ", ") or "none"
                print("[FAF] 🛡️ Keeping fish:", fishData.fishType, "| Mutations:", mutations)
            end
        else
            -- Sell this individual fish - try remo first, then fallback
            local success = FireRemoRemote("sellFish.sellFish", fishId) or FireRemote("sellFish", "sellFish", fishId)
            if success then
                soldCount = soldCount + 1
            end
            task.wait(0.05) -- Small delay to avoid rate limiting
        end
    end
    
    AutoSeller.TotalSold = AutoSeller.TotalSold + soldCount
    
    if CONFIG.ShowNotifications and (soldCount > 0 or keptCount > 0) then
        print("[FAF] 💰 Sold:", soldCount, "fish | Kept:", keptCount, "event fish")
    end
    
    return soldCount > 0
end

function AutoSeller.SellAllFish()
    -- Use smart selling if KeepEventFish is enabled
    if CONFIG.KeepEventFish then
        return AutoSeller.SmartSellFish()
    end
    
    -- Otherwise use bulk sell - try remo first, then fallback
    local success = FireRemoRemote("sellFish.sellAllFish") or FireRemote("sellFish", "sellAllFish")
    
    if success then
        AutoSeller.TotalSold = AutoSeller.TotalSold + 1
        if CONFIG.ShowNotifications then
            print("[FAF] 💰 Sold all fish! (Batch #" .. AutoSeller.TotalSold .. ")")
        end
    end
    
    return success
end

function AutoSeller.SellAllEventFish()
    -- Fire sellAllEventFish remote for event currencies - try remo first
    local success = FireRemoRemote("sellFish.sellAllEventFish") or FireRemote("sellFish", "sellAllEventFish")
    
    if success and CONFIG.ShowNotifications then
        print("[FAF] 🎄 Sold all event fish!")
    end
    
    return success
end

function AutoSeller.Start()
    if AutoSeller.Running then return end
    AutoSeller.Running = true
    
    print("[FAF] 💰 Auto Seller STARTED")
    
    task.spawn(function()
        while AutoSeller.Running do
            if CONFIG.AutoSellFish then
                AutoSeller.SellAllFish()
            end
            
            if CONFIG.AutoSellEventFish then
                AutoSeller.SellAllEventFish()
            end
            
            task.wait(CONFIG.SellFishInterval)
        end
    end)
end

function AutoSeller.Stop()
    AutoSeller.Running = false
    print("[FAF] 💰 Auto Seller STOPPED")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- AUTO COLLECT CRATES & PICKUPS (Teleport-based collection)
-- ═══════════════════════════════════════════════════════════════════════════

local CrateCollector = {}
CrateCollector.Running = false
CrateCollector.CratesCollected = 0
CrateCollector.PickupsCollected = 0
CrateCollector.GiftsCollected = 0
CrateCollector.Connections = {}
CrateCollector.LastPosition = nil -- Store position before teleporting
CrateCollector.COLLECTION_RADIUS = 10 -- Game requires being within 10 studs

-- Teleport player to position, wait, then return
function CrateCollector.TeleportTo(position)
    local character = LocalPlayer.Character
    if not character then return false end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    
    -- Save original position
    if not CrateCollector.LastPosition then
        CrateCollector.LastPosition = rootPart.CFrame
    end
    
    -- Teleport to pickup (slightly above to avoid terrain)
    rootPart.CFrame = CFrame.new(position.X, position.Y + 2, position.Z)
    return true
end

function CrateCollector.ReturnToOriginalPosition()
    if CrateCollector.LastPosition then
        local character = LocalPlayer.Character
        if character then
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if rootPart then
                rootPart.CFrame = CrateCollector.LastPosition
            end
        end
        CrateCollector.LastPosition = nil
    end
end

-- Find all pickups in workspace (named Pickup_<id>)
function CrateCollector.FindPickupsInWorkspace()
    local pickups = {}
    
    pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name:match("^Pickup_") then
                local pickupId = obj.Name:match("Pickup_(.+)")
                if pickupId then
                    table.insert(pickups, {
                        id = pickupId,
                        part = obj,
                        position = obj.Position
                    })
                end
            end
        end
    end)
    
    return pickups
end

-- Find all crate drops in workspace
function CrateCollector.FindCratesInWorkspace()
    local crates = {}
    
    pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            -- Crates are usually models with specific tags or names
            if obj:IsA("Model") then
                local name = obj.Name:lower()
                if name:find("crate") or name:find("drop") then
                    local crateId = obj:GetAttribute("CrateId") or obj:GetAttribute("Id") or obj.Name
                    local primaryPart = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    if primaryPart then
                        table.insert(crates, {
                            id = crateId,
                            model = obj,
                            position = primaryPart.Position
                        })
                    end
                end
            end
        end
    end)
    
    return crates
end

-- Find personal gifts (Santa pet drops)
function CrateCollector.FindGiftsInWorkspace()
    local gifts = {}
    
    pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") then
                local name = obj.Name:lower()
                -- Personal gifts from Santa pet
                if name:find("gift") or name:find("present") then
                    local giftId = obj:GetAttribute("GiftId") or obj:GetAttribute("Id")
                    local primaryPart = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    if primaryPart then
                        table.insert(gifts, {
                            id = giftId,
                            model = obj,
                            position = primaryPart.Position
                        })
                    end
                end
            end
        end
    end)
    
    return gifts
end

-- Collect pickup by teleporting to it
function CrateCollector.CollectPickupWithTeleport(pickup)
    if not pickup or not pickup.position then return false end
    
    local character = LocalPlayer.Character
    if not character then return false end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    
    -- Check if already in range
    local distance = (rootPart.Position - pickup.position).Magnitude
    
    if distance > CrateCollector.COLLECTION_RADIUS then
        -- Need to teleport
        CrateCollector.TeleportTo(pickup.position)
        task.wait(0.1) -- Wait for position update
    end
    
    -- Now fire the claim remote
    local remotes = GetRemoRemotes()
    if remotes and remotes.pickup and remotes.pickup.claimPickup then
        pcall(function()
            remotes.pickup.claimPickup:fire(pickup.id)
        end)
        CrateCollector.PickupsCollected = CrateCollector.PickupsCollected + 1
        if CONFIG.DebugMode then
            print("[FAF] ✨ Collected pickup:", pickup.id)
        end
        return true
    end
    
    return false
end

-- Collect crate by teleporting to it  
function CrateCollector.CollectCrateWithTeleport(crate)
    if not crate or not crate.position then return false end
    
    local character = LocalPlayer.Character
    if not character then return false end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    
    -- Check if already in range
    local distance = (rootPart.Position - crate.position).Magnitude
    
    if distance > CrateCollector.COLLECTION_RADIUS then
        -- Need to teleport
        CrateCollector.TeleportTo(crate.position)
        task.wait(0.1)
    end
    
    -- Fire the claim remote
    local remotes = GetRemoRemotes()
    if remotes and remotes.crateDrop and remotes.crateDrop.claimCrateDrop then
        pcall(function()
            remotes.crateDrop.claimCrateDrop:fire(crate.id)
        end)
        CrateCollector.CratesCollected = CrateCollector.CratesCollected + 1
        if CONFIG.ShowNotifications then
            print("[FAF] 📦 Collected crate:", crate.id)
        end
        return true
    end
    
    return false
end

-- Claim personal gift (Santa pet drops) - may not need proximity
function CrateCollector.ClaimPersonalGift(giftId)
    if not giftId then return false end
    
    local remotes = GetRemoRemotes()
    if remotes and remotes.christmas and remotes.christmas.claimPersonalGift then
        pcall(function()
            remotes.christmas.claimPersonalGift:fire(giftId)
        end)
        CrateCollector.GiftsCollected = CrateCollector.GiftsCollected + 1
        if CONFIG.ShowNotifications then
            print("[FAF] 🎁 Claimed personal gift:", giftId)
        end
        return true
    end
    
    return false
end

-- Main collection routine
function CrateCollector.CollectAll()
    local character = LocalPlayer.Character
    if not character then return end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    -- Save original position
    CrateCollector.LastPosition = rootPart.CFrame
    
    local totalCollected = 0
    
    -- Collect pickups
    if CONFIG.AutoCollectPickups then
        local pickups = CrateCollector.FindPickupsInWorkspace()
        if CONFIG.DebugMode and #pickups > 0 then
            print("[FAF] Found " .. #pickups .. " pickups in workspace")
        end
        
        for _, pickup in ipairs(pickups) do
            if CrateCollector.CollectPickupWithTeleport(pickup) then
                totalCollected = totalCollected + 1
                task.wait(0.15) -- Small delay between collections
            end
        end
    end
    
    -- Collect crates
    if CONFIG.AutoCollectCrates then
        local crates = CrateCollector.FindCratesInWorkspace()
        if CONFIG.DebugMode and #crates > 0 then
            print("[FAF] Found " .. #crates .. " crates in workspace")
        end
        
        for _, crate in ipairs(crates) do
            if CrateCollector.CollectCrateWithTeleport(crate) then
                totalCollected = totalCollected + 1
                task.wait(0.15)
            end
        end
    end
    
    -- Collect gifts (Santa pet drops)
    local gifts = CrateCollector.FindGiftsInWorkspace()
    for _, gift in ipairs(gifts) do
        if gift.id then
            CrateCollector.ClaimPersonalGift(gift.id)
            totalCollected = totalCollected + 1
            task.wait(0.1)
        end
    end
    
    -- Return to original position
    if totalCollected > 0 then
        task.wait(0.2)
        CrateCollector.ReturnToOriginalPosition()
        
        if CONFIG.ShowNotifications then
            print("[FAF] ✨ Collected " .. totalCollected .. " items total!")
        end
    end
end

-- Setup hooks to listen for new spawns
function CrateCollector.SetupPickupHooks()
    local remotes = GetRemoRemotes()
    if not remotes then
        if CONFIG.DebugMode then
            warn("[FAF] Could not get remo remotes for pickup hooks")
        end
        return false
    end
    
    -- Listen for pickup spawns and immediately collect
    pcall(function()
        if remotes.pickup and remotes.pickup.spawnPickup and remotes.pickup.spawnPickup.connect then
            local conn = remotes.pickup.spawnPickup:connect(function(pickupId, reward, position, spawnedAt, velocity)
                if CrateCollector.Running and CONFIG.AutoCollectPickups then
                    if CONFIG.DebugMode then
                        print("[FAF] 🎁 New pickup spawned:", pickupId, "at", position)
                    end
                    -- Wait a moment for pickup to settle then collect
                    task.delay(0.5, function()
                        if CrateCollector.Running then
                            CrateCollector.CollectPickupWithTeleport({
                                id = pickupId,
                                position = position
                            })
                            CrateCollector.ReturnToOriginalPosition()
                        end
                    end)
                end
            end)
            table.insert(CrateCollector.Connections, conn)
            if CONFIG.DebugMode then
                print("[FAF] 📦 Hooked into pickup spawn remote")
            end
        end
    end)
    
    -- Listen for crate spawns
    pcall(function()
        if remotes.crateDrop and remotes.crateDrop.spawnCrateDrop and remotes.crateDrop.spawnCrateDrop.connect then
            local conn = remotes.crateDrop.spawnCrateDrop:connect(function(crateId, position, ...)
                if CrateCollector.Running and CONFIG.AutoCollectCrates then
                    if CONFIG.DebugMode then
                        print("[FAF] 📦 New crate spawned:", crateId)
                    end
                    task.delay(0.5, function()
                        if CrateCollector.Running then
                            -- Try to find the crate in workspace
                            local crates = CrateCollector.FindCratesInWorkspace()
                            for _, crate in ipairs(crates) do
                                CrateCollector.CollectCrateWithTeleport(crate)
                                task.wait(0.1)
                            end
                            CrateCollector.ReturnToOriginalPosition()
                        end
                    end)
                end
            end)
            table.insert(CrateCollector.Connections, conn)
            if CONFIG.DebugMode then
                print("[FAF] 📦 Hooked into crate spawn remote")
            end
        end
    end)
    
    -- Listen for personal gift spawns (Santa pet)
    pcall(function()
        if remotes.christmas and remotes.christmas.spawnPersonalGift and remotes.christmas.spawnPersonalGift.connect then
            local conn = remotes.christmas.spawnPersonalGift:connect(function(giftId, ...)
                if CrateCollector.Running then
                    if CONFIG.DebugMode then
                        print("[FAF] 🎅 Personal gift spawned:", giftId)
                    end
                    task.delay(2, function() -- Wait for gift to drop
                        if CrateCollector.Running then
                            CrateCollector.ClaimPersonalGift(giftId)
                        end
                    end)
                end
            end)
            table.insert(CrateCollector.Connections, conn)
        end
    end)
    
    return true
end

function CrateCollector.Start()
    if CrateCollector.Running then return end
    CrateCollector.Running = true
    
    print("[FAF] 📦 Crate & Pickup Collector STARTED (Teleport Mode)")
    
    -- Setup hooks for new spawns
    CrateCollector.SetupPickupHooks()
    
    -- Main collection loop
    task.spawn(function()
        while CrateCollector.Running do
            CrateCollector.CollectAll()
            task.wait(CONFIG.CrateCheckInterval or 3)
        end
    end)
end

function CrateCollector.Stop()
    CrateCollector.Running = false
    
    -- Return to original position if stuck
    CrateCollector.ReturnToOriginalPosition()
    
    -- Disconnect hooks
    for _, conn in ipairs(CrateCollector.Connections) do
        pcall(function()
            if conn and conn.Disconnect then
                conn:Disconnect()
            elseif conn and conn.disconnect then
                conn:disconnect()
            end
        end)
    end
    CrateCollector.Connections = {}
    
    print("[FAF] 📦 Crate & Pickup Collector STOPPED")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EVENT AUTO-FEED (Santa, Alien, Robot, Elf)
-- ═══════════════════════════════════════════════════════════════════════════

local EventFeeder = {}
EventFeeder.Running = false

function EventFeeder.FeedAllEvents()
    -- Santa Event
    FireRemote("christmas", "feedSantaAll")
    
    -- Elf Event
    FireRemote("christmas", "feedElfAll")
    
    -- Alien Event
    FireRemote("alien", "feedAlienAll")
    FireRemote("alien", "feedAlienSideAll")
    
    -- Robot Event
    FireRemote("robot", "feedRobotAll")
    FireRemote("robot", "scrapAllFish")
end

function EventFeeder.Start()
    if EventFeeder.Running then return end
    EventFeeder.Running = true
    
    print("[FAF] 🎄 Event Auto-Feeder STARTED")
    
    task.spawn(function()
        while EventFeeder.Running do
            EventFeeder.FeedAllEvents()
            task.wait(3)
        end
    end)
end

function EventFeeder.Stop()
    EventFeeder.Running = false
    print("[FAF] 🎄 Event Auto-Feeder STOPPED")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- AUTO FEED PETS
-- ═══════════════════════════════════════════════════════════════════════════

local AutoPetFeeder = {}
AutoPetFeeder.Running = false
AutoPetFeeder.FedCount = 0

-- Get equipped pets from player data
function AutoPetFeeder.GetEquippedPets()
    local pets = {}
    
    local success, result = pcall(function()
        local TS = ReplicatedStorage:FindFirstChild("TS")
        if TS then
            local stateFolder = TS:FindFirstChild("state")
            if stateFolder then
                local playerDataModule = stateFolder:FindFirstChild("player-data")
                if playerDataModule then
                    local module = require(playerDataModule)
                    if module then
                        local getPlayerData = module.getPlayerData or module.getPlayerDataById
                        if getPlayerData then
                            local data = getPlayerData(LocalPlayer) or getPlayerData(tostring(LocalPlayer.UserId))
                            if data and data.equippedPets then
                                for _, petId in ipairs(data.equippedPets) do
                                    if data.inventory and data.inventory.pets and data.inventory.pets[petId] then
                                        table.insert(pets, {
                                            petId = petId,
                                            petData = data.inventory.pets[petId]
                                        })
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        return pets
    end)
    
    return success and result or pets
end

-- Get fish from inventory to feed pets (filters by weight)
function AutoPetFeeder.GetFishToFeed()
    local fishes = {}
    
    local success, result = pcall(function()
        local TS = ReplicatedStorage:FindFirstChild("TS")
        if TS then
            local stateFolder = TS:FindFirstChild("state")
            if stateFolder then
                local playerDataModule = stateFolder:FindFirstChild("player-data")
                if playerDataModule then
                    local module = require(playerDataModule)
                    if module then
                        local getPlayerData = module.getPlayerData or module.getPlayerDataById
                        if getPlayerData then
                            local data = getPlayerData(LocalPlayer) or getPlayerData(tostring(LocalPlayer.UserId))
                            if data and data.inventory and data.inventory.fishes then
                                for fishId, fishData in pairs(data.inventory.fishes) do
                                    -- Get fish weight (scale = kg)
                                    local weight = fishData.scale or fishData.weight or fishData.kg or 0
                                    
                                    -- Don't feed event fish (keep them)
                                    local isEventFish = CONFIG.KeepEventFish and AutoSeller.HasEventMutation(fishData)
                                    
                                    -- Don't feed fish heavier than MaxFeedWeight
                                    local isTooHeavy = weight > CONFIG.MaxFeedWeight
                                    
                                    if not isEventFish and not isTooHeavy then
                                        table.insert(fishes, {
                                            fishId = fishId,
                                            fishData = fishData,
                                            weight = weight
                                        })
                                    elseif CONFIG.DebugMode and isTooHeavy then
                                        print(string.format("[FAF] 🛡️ Protecting heavy fish: %.2fkg (max: %dkg)", weight, CONFIG.MaxFeedWeight))
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        -- Sort by weight ascending (feed lightest fish first)
        table.sort(fishes, function(a, b)
            return a.weight < b.weight
        end)
        
        return fishes
    end)
    
    return success and result or fishes
end

function AutoPetFeeder.FeedPets()
    local pets = AutoPetFeeder.GetEquippedPets()
    local fishes = AutoPetFeeder.GetFishToFeed()
    
    if #pets == 0 then
        if CONFIG.DebugMode then
            print("[FAF] No equipped pets to feed")
        end
        return false
    end
    
    if #fishes == 0 then
        if CONFIG.DebugMode then
            print("[FAF] No fish available to feed pets")
        end
        return false
    end
    
    local fedCount = 0
    for _, pet in ipairs(pets) do
        if #fishes > fedCount then
            local fish = fishes[fedCount + 1]
            -- Fire feedPet remote with petId and fishId (as toolId)
            local success = FireRemote("pets", "feedPet", pet.petId, fish.fishId)
            if success then
                fedCount = fedCount + 1
                AutoPetFeeder.FedCount = AutoPetFeeder.FedCount + 1
            end
            task.wait(0.2)
        end
    end
    
    if fedCount > 0 and CONFIG.ShowNotifications then
        print("[FAF] 🐾 Fed " .. fedCount .. " pets!")
    end
    
    return fedCount > 0
end

function AutoPetFeeder.Start()
    if AutoPetFeeder.Running then return end
    AutoPetFeeder.Running = true
    
    print("[FAF] 🐾 Auto Pet Feeder STARTED")
    
    task.spawn(function()
        while AutoPetFeeder.Running and CONFIG.AutoFeedPets do
            AutoPetFeeder.FeedPets()
            task.wait(CONFIG.FeedPetsInterval or 5)
        end
    end)
end

function AutoPetFeeder.Stop()
    AutoPetFeeder.Running = false
    print("[FAF] 🐾 Auto Pet Feeder STOPPED")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- AUTO BEST PET (Picks up bad pets, places better pets)
-- ═══════════════════════════════════════════════════════════════════════════

local AutoBestPet = {}
AutoBestPet.Running = false
AutoBestPet.SwapsCount = 0

-- Pet perk priority (higher = better)
AutoBestPet.PerkPriority = {
    -- Top tier perks
    PerkMultiplier = 100,
    DuplicateOnCatch = 95,
    BaitLuck = 90,
    EggLuck = 85,
    BiggerFishChance = 80,
    
    -- Good perks
    StealFish = 75,
    GoldChanceBoost = 70,
    SilverChanceBoost = 65,
    ApplyMutation = 60,
    PeriodicMutateOwnFish = 55,
    PeriodicConsumeAndMutate = 50,
    
    -- Useful perks
    CatchSpeedNearBait = 45,
    CatchSpeedPerFriend = 40,
    NetCapacityIncrease = 35,
    AllPetXPBoost = 30,
    CategoryXPBoost = 28,
    HatchTimeReduction = 25,
    AutoFeederDuration = 22,
    
    -- Utility perks
    CoinOnCatch = 20,
    RefundOnPurchase = 18,
    RefundOnSell = 15,
    RefundItemOnCraft = 12,
    ReduceShopPrices = 10,
    WalkspeedBoost = 8,
    HungerReduction = 5,
    StealProtection = 3,
    
    -- Low priority
    DropRandomBait = 2,
    DropRandomGear = 1,
    CatchFishInRandomNet = 1,
}

-- Calculate pet score based on perks
function AutoBestPet.GetPetScore(petData)
    if not petData then return 0 end
    
    local score = 0
    
    -- Check pet type for base perks (from Pets definition)
    local petType = petData.petType or petData.type
    if petType and AutoBestPet.PetPerks[petType] then
        for _, perk in ipairs(AutoBestPet.PetPerks[petType]) do
            local perkName = perk.type or perk
            local priority = AutoBestPet.PerkPriority[perkName] or 0
            local value = perk.value or 1
            score = score + (priority * value)
        end
    end
    
    -- Also check if pet has additional perks from levels/upgrades
    if petData.perks then
        for _, perk in ipairs(petData.perks) do
            local perkName = perk.type or perk
            local priority = AutoBestPet.PerkPriority[perkName] or 0
            local value = perk.value or 1
            score = score + (priority * value)
        end
    end
    
    -- Bonus for pet level
    if petData.level then
        score = score + (petData.level * 2)
    end
    
    -- Bonus for XP
    if petData.xp then
        score = score + (petData.xp / 1000)
    end
    
    return score
end

-- Define known pet perks
AutoBestPet.PetPerks = {
    Cat = {{type = "WalkspeedBoost", value = 0.05}},
    Dog = {{type = "CoinOnCatch", value = 0.2}},
    Bunny = {{type = "HatchTimeReduction", value = 0.1}},
    Sheep = {{type = "CatchSpeedNearBait", value = 0.2}},
    Racoon = {{type = "RefundOnPurchase", value = 0.05}},
    Owl = {{type = "AllPetXPBoost", value = 0.1}},
    Fox = {{type = "StealFish", value = 1}},
    Bear = {{type = "DuplicateOnCatch", value = 0.05}},
    Hedgehog = {{type = "StealProtection", value = 0.05}},
    Phoenix = {{type = "PerkMultiplier", value = 0.2}},
    Lion = {{type = "BaitLuck", value = 0.1}},
    Tiger = {{type = "BiggerFishChance", value = 0.2}},
    Elephant = {{type = "NetCapacityIncrease", value = 1}},
    Wolf = {{type = "HungerReduction", value = 0.15}},
    Panda = {{type = "CatchSpeedNearBait", value = 0.4}},
    Rhino = {{type = "StealProtection", value = 0.1}},
    Koala = {{type = "AutoFeederDuration", value = 0.1}},
    Monkey = {{type = "RefundOnSell", value = 0.02}},
    Parrot = {{type = "RefundItemOnCraft", value = 0.025}},
    Crab = {{type = "GoldChanceBoost", value = 0.5}},
    Reindeer = {{type = "SilverChanceBoost", value = 0.5}},
    PolarBear = {{type = "ApplyMutation", value = 0.1}},
    Kitsune = {{type = "StealFish", value = 1}},
    CyberDragon = {{type = "PeriodicConsumeAndMutate", value = 1}},
    CyberBull = {{type = "PeriodicMutateOwnFish", value = 1}},
    BobaPegasus = {{type = "ReduceShopPrices", value = 0.1}},
    WildKingReindeer = {{type = "EggLuck", value = 0.2}},
}

-- Get all pets from inventory
function AutoBestPet.GetAllPets()
    local allPets = {}
    local equippedPets = {}
    local inventoryPets = {}
    
    local success = pcall(function()
        local TS = ReplicatedStorage:FindFirstChild("TS")
        if TS then
            local stateFolder = TS:FindFirstChild("state")
            if stateFolder then
                local playerDataModule = stateFolder:FindFirstChild("player-data")
                if playerDataModule then
                    local module = require(playerDataModule)
                    if module then
                        local getPlayerData = module.getPlayerData or module.getPlayerDataById
                        if getPlayerData then
                            local data = getPlayerData(LocalPlayer) or getPlayerData(tostring(LocalPlayer.UserId))
                            if data then
                                -- Get equipped pets
                                if data.equippedPets then
                                    for _, petId in ipairs(data.equippedPets) do
                                        if data.inventory and data.inventory.pets and data.inventory.pets[petId] then
                                            local pet = {
                                                petId = petId,
                                                petData = data.inventory.pets[petId],
                                                equipped = true
                                            }
                                            pet.score = AutoBestPet.GetPetScore(pet.petData)
                                            table.insert(equippedPets, pet)
                                            table.insert(allPets, pet)
                                        end
                                    end
                                end
                                
                                -- Get inventory pets (not equipped)
                                if data.inventory and data.inventory.pets then
                                    for petId, petData in pairs(data.inventory.pets) do
                                        local isEquipped = false
                                        if data.equippedPets then
                                            for _, eqPetId in ipairs(data.equippedPets) do
                                                if eqPetId == petId then
                                                    isEquipped = true
                                                    break
                                                end
                                            end
                                        end
                                        
                                        if not isEquipped then
                                            local pet = {
                                                petId = petId,
                                                petData = petData,
                                                equipped = false
                                            }
                                            pet.score = AutoBestPet.GetPetScore(petData)
                                            table.insert(inventoryPets, pet)
                                            table.insert(allPets, pet)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    
    return allPets, equippedPets, inventoryPets
end

-- Fill empty pet slots first (before swapping)
function AutoBestPet.FillEmptySlots()
    local allPets, equippedPets, inventoryPets = AutoBestPet.GetAllPets()
    local PET_LIMIT = 3
    local currentEquipped = #equippedPets
    local emptySlots = PET_LIMIT - currentEquipped
    
    if CONFIG.DebugMode then
        print("[FAF] Pets - Equipped:", currentEquipped, "In Inventory:", #inventoryPets, "Empty Slots:", emptySlots)
    end
    
    if emptySlots <= 0 or #inventoryPets == 0 then
        return 0
    end
    
    -- Sort inventory pets by score (highest first)
    table.sort(inventoryPets, function(a, b)
        return a.score > b.score
    end)
    
    local placed = 0
    for i, invPet in ipairs(inventoryPets) do
        if placed >= emptySlots then break end
        
        if CONFIG.DebugMode then
            print("[FAF] Placing pet from inventory:", invPet.petId, "type:", invPet.petData.petType)
        end
        
        -- Try remo first
        local success = FireRemoRemote("pets.placePetFromInventory", invPet.petId)
        
        if not success then
            -- Fallback to FireRemote
            success = FireRemote("pets", "placePetFromInventory", invPet.petId)
        end
        
        if success ~= false then
            placed = placed + 1
            AutoBestPet.SwapsCount = AutoBestPet.SwapsCount + 1
            
            if CONFIG.ShowNotifications then
                local petName = invPet.petData.petType or "Pet"
                print("[FAF] 🐾 Placed " .. petName .. " (score: " .. math.floor(invPet.score) .. ") - Slot " .. (currentEquipped + placed) .. "/" .. PET_LIMIT)
            end
        else
            if CONFIG.DebugMode then
                print("[FAF] Failed to place pet:", invPet.petId)
            end
        end
        
        task.wait(0.5) -- Delay between placements
    end
    
    return placed
end

function AutoBestPet.SwapToBetterPets()
    -- FIRST: Fill any empty slots
    local filledSlots = AutoBestPet.FillEmptySlots()
    if filledSlots > 0 then
        task.wait(0.5) -- Wait after filling slots
    end
    
    -- THEN: Swap to better pets if all slots are full
    local allPets, equippedPets, inventoryPets = AutoBestPet.GetAllPets()
    
    if #allPets == 0 then
        if CONFIG.DebugMode then
            print("[FAF] No pets found")
        end
        return false
    end
    
    -- Sort inventory pets by score (highest first)
    table.sort(inventoryPets, function(a, b)
        return a.score > b.score
    end)
    
    -- Sort equipped pets by score (lowest first - these are candidates to replace)
    table.sort(equippedPets, function(a, b)
        return a.score < b.score
    end)
    
    local swapsMade = 0
    local PET_LIMIT = 3
    
    for i, invPet in ipairs(inventoryPets) do
        if swapsMade >= PET_LIMIT then break end
        
        -- Check if there's an equipped pet with lower score
        local lowestEquipped = equippedPets[1]
        if lowestEquipped and invPet.score > lowestEquipped.score + 10 then -- +10 threshold to avoid constant swapping
            -- Pick up the bad pet
            local pickupSuccess = FireRemoRemote("pets.pickUpPet", lowestEquipped.petId)
            if not pickupSuccess then
                pickupSuccess = FireRemote("pets", "pickUpPet", lowestEquipped.petId)
            end
            
            if pickupSuccess ~= false then
                task.wait(0.3)
                -- Place the better pet
                local placeSuccess = FireRemoRemote("pets.placePetFromInventory", invPet.petId)
                if not placeSuccess then
                    placeSuccess = FireRemote("pets", "placePetFromInventory", invPet.petId)
                end
                
                if placeSuccess ~= false then
                    swapsMade = swapsMade + 1
                    AutoBestPet.SwapsCount = AutoBestPet.SwapsCount + 1
                    
                    if CONFIG.ShowNotifications then
                        local oldName = lowestEquipped.petData.petType or "Pet"
                        local newName = invPet.petData.petType or "Pet"
                        print("[FAF] 🔄 Swapped " .. oldName .. " (score: " .. math.floor(lowestEquipped.score) .. ") for " .. newName .. " (score: " .. math.floor(invPet.score) .. ")")
                    end
                    
                    -- Update the sorted list (remove swapped pets)
                    table.remove(equippedPets, 1)
                end
            end
            task.wait(0.5)
        end
    end
    
    return swapsMade > 0 or filledSlots > 0
end

function AutoBestPet.Start()
    if AutoBestPet.Running then return end
    AutoBestPet.Running = true
    
    print("[FAF] 🏆 Auto Best Pet STARTED - Will swap to better pets")
    
    task.spawn(function()
        while AutoBestPet.Running and CONFIG.AutoBestPet do
            AutoBestPet.SwapToBetterPets()
            task.wait(CONFIG.BestPetInterval or 30) -- Check every 30 seconds
        end
    end)
end

function AutoBestPet.Stop()
    AutoBestPet.Running = false
    print("[FAF] 🏆 Auto Best Pet STOPPED")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- AUTO EGG SYSTEM (Buy, Place, Hatch)
-- ═══════════════════════════════════════════════════════════════════════════

local AutoEgg = {}
AutoEgg.Running = false
AutoEgg.EggsBought = 0
AutoEgg.EggsPlaced = 0
AutoEgg.EggsHatched = 0

-- Egg data with prices and tiers
local EggData = {
    Starter = {price = 5000, tier = 1},
    Novice = {price = 200000, tier = 2},
    Forest = {price = 3000000, tier = 3},
    Polar = {price = 15000000, tier = 4},
    Tropical = {price = 70000000, tier = 5},
    Exotic = {price = 800000000, tier = 6},
}

-- Get eggs from inventory
function AutoEgg.GetInventoryEggs()
    local eggs = {}
    
    pcall(function()
        local rbxts = ReplicatedStorage:FindFirstChild("rbxts_include")
        if rbxts then
            local runtimeLib = rbxts:FindFirstChild("RuntimeLib")
            if runtimeLib then
                local runtime = require(runtimeLib)
                if runtime and runtime.import then
                    local playerDataModule = runtime.import(nil, ReplicatedStorage, "TS", "state", "player-data")
                    if playerDataModule then
                        local getPlayerDataById = playerDataModule.getPlayerDataById
                        if getPlayerDataById then
                            local data = getPlayerDataById(tostring(LocalPlayer.UserId))
                            if data and data.inventory and data.inventory.eggs then
                                for eggId, eggData in pairs(data.inventory.eggs) do
                                    table.insert(eggs, {
                                        eggId = eggId,
                                        eggType = eggData.eggType or eggData.type,
                                        tier = EggData[eggData.eggType] and EggData[eggData.eggType].tier or 0
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    
    return eggs
end

-- Get eggs in incubators (placed eggs) and incubator info
function AutoEgg.GetIncubatorEggs()
    local incubatorEggs = {}
    
    pcall(function()
        local rbxts = ReplicatedStorage:FindFirstChild("rbxts_include")
        if rbxts then
            local runtimeLib = rbxts:FindFirstChild("RuntimeLib")
            if runtimeLib then
                local runtime = require(runtimeLib)
                if runtime and runtime.import then
                    local playerDataModule = runtime.import(nil, ReplicatedStorage, "TS", "state", "player-data")
                    if playerDataModule then
                        local getPlayerDataById = playerDataModule.getPlayerDataById
                        if getPlayerDataById then
                            local data = getPlayerDataById(tostring(LocalPlayer.UserId))
                            if data and data.ponds then
                                for pondName, pondData in pairs(data.ponds) do
                                    if pondData.eggs then
                                        for eggId, eggData in pairs(pondData.eggs) do
                                            table.insert(incubatorEggs, {
                                                eggId = eggId,
                                                eggType = eggData.eggType,
                                                hatchTime = eggData.hatchTime or 0,
                                                startTime = eggData.startTime or 0,
                                                pondName = pondName,
                                                isReady = eggData.isReady or false,
                                                incubatorId = eggData.incubatorId or eggData.gearId
                                            })
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    
    return incubatorEggs
end

-- Get available incubators (buildings in pond that can hold eggs)
function AutoEgg.GetAvailableIncubators()
    local incubators = {}
    local eggsInIncubators = {}
    
    -- First get eggs that are already in incubators
    local incubatorEggs = AutoEgg.GetIncubatorEggs()
    for _, egg in ipairs(incubatorEggs) do
        if egg.incubatorId then
            eggsInIncubators[egg.incubatorId] = true
        end
    end
    
    pcall(function()
        local rbxts = ReplicatedStorage:FindFirstChild("rbxts_include")
        if rbxts then
            local runtimeLib = rbxts:FindFirstChild("RuntimeLib")
            if runtimeLib then
                local runtime = require(runtimeLib)
                if runtime and runtime.import then
                    local playerDataModule = runtime.import(nil, ReplicatedStorage, "TS", "state", "player-data")
                    if playerDataModule then
                        local getPlayerDataById = playerDataModule.getPlayerDataById
                        if getPlayerDataById then
                            local data = getPlayerDataById(tostring(LocalPlayer.UserId))
                            if data and data.ponds then
                                for pondName, pondData in pairs(data.ponds) do
                                    -- Check gears/buildings for incubators
                                    if pondData.gears then
                                        for gearId, gearData in pairs(pondData.gears) do
                                            local gearType = gearData.gearType or gearData.type or ""
                                            if gearType:find("Incubator") or gearType:find("EggIncubator") then
                                                if not eggsInIncubators[gearId] then
                                                    table.insert(incubators, {
                                                        gearId = gearId,
                                                        gearType = gearType,
                                                        pondName = pondName
                                                    })
                                                end
                                            end
                                        end
                                    end
                                    -- Also check buildings key
                                    if pondData.buildings then
                                        for buildingId, buildingData in pairs(pondData.buildings) do
                                            local buildingType = buildingData.buildingType or buildingData.type or ""
                                            if buildingType:find("Incubator") or buildingType:find("EggIncubator") then
                                                if not eggsInIncubators[buildingId] then
                                                    table.insert(incubators, {
                                                        gearId = buildingId,
                                                        gearType = buildingType,
                                                        pondName = pondName
                                                    })
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    
    -- Fallback: Search workspace for incubator models
    if #incubators == 0 then
        pcall(function()
            -- Look for incubator models in workspace
            local pondsFolder = Workspace:FindFirstChild("Ponds")
            if pondsFolder then
                for _, pond in ipairs(pondsFolder:GetDescendants()) do
                    if pond.Name:find("Incubator") or pond.Name:find("EggIncubator") then
                        local gearId = pond:GetAttribute("gearId") or pond:GetAttribute("id")
                        if gearId then
                            -- Check if it already has an egg
                            local hasEgg = pond:FindFirstChild("Egg") ~= nil
                            if not hasEgg then
                                table.insert(incubators, {
                                    gearId = gearId,
                                    gearType = pond.Name,
                                    model = pond
                                })
                            end
                        end
                    end
                end
            end
        end)
    end
    
    return incubators
end

-- Buy an egg from shop
function AutoEgg.BuyEgg(eggType)
    eggType = eggType or CONFIG.PreferredEgg or "Starter"
    
    local success = FireRemoRemote("shop.purchaseEgg", eggType)
    if not success then
        success = FireRemote("shop", "purchaseEgg", eggType)
    end
    
    if success ~= false then
        AutoEgg.EggsBought = AutoEgg.EggsBought + 1
        if CONFIG.ShowNotifications then
            print("[FAF] 🥚 Bought " .. eggType .. " egg!")
        end
        return true
    end
    return false
end

-- Place egg in incubator (needs incubator gearId and egg toolId)
function AutoEgg.PlaceEgg(eggId, eggType)
    if not eggId then return false end
    
    -- Find an available incubator
    local incubators = AutoEgg.GetAvailableIncubators()
    if #incubators == 0 then
        if CONFIG.DebugMode then
            print("[FAF] 🥚 No available incubators found for egg placement")
        end
        return false
    end
    
    local incubator = incubators[1]
    if CONFIG.DebugMode then
        print("[FAF] 🥚 Placing egg in incubator: " .. tostring(incubator.gearId))
    end
    
    -- The remote takes (incubatorGearId, eggToolId)
    local success = FireRemoRemote("gear.placeEggInIncubator", incubator.gearId, eggId)
    if not success then
        success = FireRemote("gear", "placeEggInIncubator", incubator.gearId, eggId)
    end
    
    if success ~= false then
        AutoEgg.EggsPlaced = AutoEgg.EggsPlaced + 1
        if CONFIG.ShowNotifications then
            print("[FAF] 🥚 Placed " .. (eggType or "egg") .. " in incubator!")
        end
        return true
    end
    return false
end

-- Hatch a ready egg
function AutoEgg.HatchEgg(eggId)
    if not eggId then return false end
    
    local success = FireRemoRemote("pets.hatchEgg", eggId)
    if not success then
        success = FireRemote("pets", "hatchEgg", eggId)
    end
    
    if success ~= false then
        AutoEgg.EggsHatched = AutoEgg.EggsHatched + 1
        if CONFIG.ShowNotifications then
            print("[FAF] 🐣 Hatched egg!")
        end
        return true
    end
    return false
end

-- Main egg loop
function AutoEgg.Process()
    -- Auto Buy Egg
    if CONFIG.AutoBuyEgg then
        local inventoryEggs = AutoEgg.GetInventoryEggs()
        local incubatorEggs = AutoEgg.GetIncubatorEggs()
        local totalEggs = #inventoryEggs + #incubatorEggs
        
        if totalEggs < (CONFIG.MaxEggsInInventory or 3) then
            AutoEgg.BuyEgg(CONFIG.PreferredEgg)
            task.wait(0.5)
        end
    end
    
    -- Auto Place Egg
    if CONFIG.AutoPlaceEgg then
        local inventoryEggs = AutoEgg.GetInventoryEggs()
        local availableIncubators = AutoEgg.GetAvailableIncubators()
        
        -- Only try to place if we have incubators available
        if #availableIncubators > 0 then
            for _, egg in ipairs(inventoryEggs) do
                if AutoEgg.PlaceEgg(egg.eggId, egg.eggType) then
                    task.wait(0.5)
                    -- Refresh available incubators after placing
                    availableIncubators = AutoEgg.GetAvailableIncubators()
                    if #availableIncubators == 0 then
                        break -- No more incubators available
                    end
                end
            end
        elseif #inventoryEggs > 0 and CONFIG.DebugMode then
            print("[FAF] 🥚 Have " .. #inventoryEggs .. " eggs but no available incubators")
        end
    end
    
    -- Auto Hatch Egg
    if CONFIG.AutoHatchEgg then
        local incubatorEggs = AutoEgg.GetIncubatorEggs()
        for _, egg in ipairs(incubatorEggs) do
            -- Check if egg is ready to hatch
            local now = tick()
            local elapsed = now - (egg.startTime or 0)
            if egg.isReady or elapsed >= (egg.hatchTime or 0) then
                AutoEgg.HatchEgg(egg.eggId)
                task.wait(0.5)
            end
        end
    end
end

function AutoEgg.Start()
    if AutoEgg.Running then return end
    AutoEgg.Running = true
    
    print("[FAF] 🥚 Auto Egg System STARTED")
    
    task.spawn(function()
        while AutoEgg.Running and (CONFIG.AutoBuyEgg or CONFIG.AutoPlaceEgg or CONFIG.AutoHatchEgg) do
            AutoEgg.Process()
            task.wait(CONFIG.EggCheckInterval or 5)
        end
    end)
end

function AutoEgg.Stop()
    AutoEgg.Running = false
    print("[FAF] 🥚 Auto Egg System STOPPED")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- AUTO GEAR SYSTEM (Buy and Use Gear Intelligently)
-- ═══════════════════════════════════════════════════════════════════════════

local AutoGear = {}
AutoGear.Running = false
AutoGear.GearsBought = 0
AutoGear.GearsUsed = 0

-- Gear types and their use behavior
local GearBehavior = {
    -- AUTO FEEDERS - Place next to best bait
    BasicAutoFeeder = {category = "autoFeeder", use = true, buyable = true},
    AdvancedAutoFeeder = {category = "autoFeeder", use = true, buyable = true},
    SupremeAutoFeeder = {category = "autoFeeder", use = true, buyable = true},
    ExtremeAutoFeeder = {category = "autoFeeder", use = true, buyable = true},
    
    -- FOOD TRAYS - Place in pond
    BasicFoodTray = {category = "foodTray", use = true, buyable = true},
    AdvancedFoodTray = {category = "foodTray", use = true, buyable = true},
    
    -- DIAMOND COOKIE - Use on best pet
    DiamondCookie = {category = "petGear", use = true, buyable = false, craftOnly = true},
    
    -- YOLK BREAKER - Use on Exotic/Tropical eggs ONLY
    YolkBreaker = {category = "eggGear", use = true, buyable = false, craftOnly = true, exoticOnly = true},
    
    -- EGG HATCHER - Use on eggs
    EggHatcher = {category = "eggGear", use = true, buyable = true},
    
    -- EGG INCUBATOR - Place in pond
    EggIncubator = {category = "building", use = true, buyable = true},
    
    -- XP COOKIE - Use for pet XP boost
    XpCookie = {category = "petBuff", use = true, buyable = true},
    
    -- EXCLUDED GEARS - Never auto-use
    TimeJumper = {category = "excluded", use = false, buyable = false},
    NetRetractor = {category = "excluded", use = false, buyable = false},
    ShieldLock = {category = "excluded", use = false, buyable = false},
    NetRemover = {category = "excluded", use = false, buyable = false},
    NetMover = {category = "excluded", use = false, buyable = false},
}

-- Get gears from inventory
function AutoGear.GetInventoryGears()
    local gears = {}
    
    pcall(function()
        local rbxts = ReplicatedStorage:FindFirstChild("rbxts_include")
        if rbxts then
            local runtimeLib = rbxts:FindFirstChild("RuntimeLib")
            if runtimeLib then
                local runtime = require(runtimeLib)
                if runtime and runtime.import then
                    local playerDataModule = runtime.import(nil, ReplicatedStorage, "TS", "state", "player-data")
                    if playerDataModule then
                        local getPlayerDataById = playerDataModule.getPlayerDataById
                        if getPlayerDataById then
                            local data = getPlayerDataById(tostring(LocalPlayer.UserId))
                            if data and data.inventory and data.inventory.gears then
                                for gearId, gearData in pairs(data.inventory.gears) do
                                    local gearType = gearData.gearType or gearData.type
                                    local behavior = GearBehavior[gearType] or {}
                                    table.insert(gears, {
                                        gearId = gearId,
                                        gearType = gearType,
                                        uses = gearData.uses or gearData.initialUses or 1,
                                        category = behavior.category or "unknown",
                                        canUse = behavior.use ~= false
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    
    return gears
end

-- Get best bait net position for placing auto feeders
function AutoGear.GetBestBaitPosition()
    local bestPos = nil
    local highestTier = 0
    
    pcall(function()
        local rbxts = ReplicatedStorage:FindFirstChild("rbxts_include")
        if rbxts then
            local runtimeLib = rbxts:FindFirstChild("RuntimeLib")
            if runtimeLib then
                local runtime = require(runtimeLib)
                if runtime and runtime.import then
                    local playerDataModule = runtime.import(nil, ReplicatedStorage, "TS", "state", "player-data")
                    if playerDataModule then
                        local getPlayerDataById = playerDataModule.getPlayerDataById
                        if getPlayerDataById then
                            local data = getPlayerDataById(tostring(LocalPlayer.UserId))
                            if data and data.ponds then
                                for pondName, pondData in pairs(data.ponds) do
                                    if pondData.baits then
                                        for baitId, baitData in pairs(pondData.baits) do
                                            local baitType = baitData.baitType or "Starter"
                                            local tier = GetBaitTier(baitType)
                                            if tier > highestTier and baitData.position then
                                                highestTier = tier
                                                bestPos = baitData.position
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    
    return bestPos, highestTier
end

-- Get best pet for Diamond Cookie
function AutoGear.GetBestPet()
    local bestPet = nil
    local bestScore = 0
    
    pcall(function()
        local rbxts = ReplicatedStorage:FindFirstChild("rbxts_include")
        if rbxts then
            local runtimeLib = rbxts:FindFirstChild("RuntimeLib")
            if runtimeLib then
                local runtime = require(runtimeLib)
                if runtime and runtime.import then
                    local playerDataModule = runtime.import(nil, ReplicatedStorage, "TS", "state", "player-data")
                    if playerDataModule then
                        local getPlayerDataById = playerDataModule.getPlayerDataById
                        if getPlayerDataById then
                            local data = getPlayerDataById(tostring(LocalPlayer.UserId))
                            if data and data.pets and data.pets.equipped then
                                for petId, petData in pairs(data.pets.equipped) do
                                    local score = AutoBestPet.ScorePet and AutoBestPet.ScorePet(petData) or 0
                                    if score > bestScore then
                                        bestScore = score
                                        bestPet = {petId = petId, petData = petData}
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    
    return bestPet
end

-- Get Exotic or Tropical eggs for Yolk Breaker
function AutoGear.GetExoticTropicalEggs()
    local targetEggs = {}
    
    local incubatorEggs = AutoEgg.GetIncubatorEggs()
    for _, egg in ipairs(incubatorEggs) do
        if egg.eggType == "Exotic" or egg.eggType == "Tropical" then
            table.insert(targetEggs, egg)
        end
    end
    
    return targetEggs
end

-- Buy gear from shop
function AutoGear.BuyGear(gearType)
    if not gearType then return false end
    
    local success = FireRemoRemote("shop.purchaseGear", gearType)
    if not success then
        success = FireRemote("shop", "purchaseGear", gearType)
    end
    
    if success ~= false then
        AutoGear.GearsBought = AutoGear.GearsBought + 1
        if CONFIG.ShowNotifications then
            print("[FAF] 🔧 Bought " .. gearType .. "!")
        end
        return true
    end
    return false
end

-- Use auto feeder near best bait
function AutoGear.UseAutoFeeder(gearId, gearType)
    local bestPos, tier = AutoGear.GetBestBaitPosition()
    if not bestPos then
        if CONFIG.DebugMode then
            print("[FAF] No bait nets found to place auto feeder near")
        end
        return false
    end
    
    -- Place the building near the bait
    local success = FireRemoRemote("gear.useFishFeeder", gearId, bestPos)
    if not success then
        success = FireRemote("gear", "useFishFeeder", gearId, bestPos)
    end
    
    if not success then
        -- Try ponds.placeBuilding
        success = FireRemoRemote("ponds.placeBuilding", "autoFeeder", gearId, bestPos, 0)
        if not success then
            success = FireRemote("ponds", "placeBuilding", "autoFeeder", gearId, bestPos, 0)
        end
    end
    
    if success ~= false then
        AutoGear.GearsUsed = AutoGear.GearsUsed + 1
        if CONFIG.ShowNotifications then
            print("[FAF] 🔧 Placed " .. (gearType or "Auto Feeder") .. " near best bait!")
        end
        return true
    end
    return false
end

-- Use Diamond Cookie on best pet
function AutoGear.UseDiamondCookie(gearId)
    local bestPet = AutoGear.GetBestPet()
    if not bestPet then
        if CONFIG.DebugMode then
            print("[FAF] No equipped pets found for Diamond Cookie")
        end
        return false
    end
    
    -- Teleport to pet for proximity check
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        -- Find pet model in workspace
        local petModels = Workspace:FindFirstChild("Pets") or Workspace
        for _, model in ipairs(petModels:GetChildren()) do
            if model.Name:find(bestPet.petData.petType or "") then
                local petPart = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
                if petPart then
                    character.HumanoidRootPart.CFrame = petPart.CFrame * CFrame.new(0, 0, 3)
                    task.wait(0.2)
                    break
                end
            end
        end
    end
    
    -- Use the gear on pet
    local success = FireRemoRemote("pets.usePetGearOnPet", gearId, bestPet.petId)
    if not success then
        success = FireRemote("pets", "usePetGearOnPet", gearId, bestPet.petId)
    end
    
    if success ~= false then
        AutoGear.GearsUsed = AutoGear.GearsUsed + 1
        if CONFIG.ShowNotifications then
            print("[FAF] 💎 Used Diamond Cookie on best pet!")
        end
        return true
    end
    return false
end

-- Use Yolk Breaker on Exotic/Tropical egg only
function AutoGear.UseYolkBreaker(gearId)
    local targetEggs = AutoGear.GetExoticTropicalEggs()
    if #targetEggs == 0 then
        if CONFIG.DebugMode then
            print("[FAF] No Exotic/Tropical eggs found for Yolk Breaker")
        end
        return false
    end
    
    local egg = targetEggs[1]
    local success = FireRemoRemote("pets.useEggHatcher", gearId, egg.eggId)
    if not success then
        success = FireRemote("pets", "useEggHatcher", gearId, egg.eggId)
    end
    
    if success ~= false then
        AutoGear.GearsUsed = AutoGear.GearsUsed + 1
        if CONFIG.ShowNotifications then
            print("[FAF] 🔨 Used Yolk Breaker on " .. egg.eggType .. " egg!")
        end
        return true
    end
    return false
end

-- Use Egg Hatcher on any egg
function AutoGear.UseEggHatcher(gearId)
    local incubatorEggs = AutoEgg.GetIncubatorEggs()
    if #incubatorEggs == 0 then
        if CONFIG.DebugMode then
            print("[FAF] No eggs in incubator for Egg Hatcher")
        end
        return false
    end
    
    local egg = incubatorEggs[1]
    local success = FireRemoRemote("pets.useEggHatcher", gearId, egg.eggId)
    if not success then
        success = FireRemote("pets", "useEggHatcher", gearId, egg.eggId)
    end
    
    if success ~= false then
        AutoGear.GearsUsed = AutoGear.GearsUsed + 1
        if CONFIG.ShowNotifications then
            print("[FAF] ⏰ Used Egg Hatcher on egg!")
        end
        return true
    end
    return false
end

-- Main gear processing
function AutoGear.ProcessGears()
    local gears = AutoGear.GetInventoryGears()
    
    for _, gear in ipairs(gears) do
        local gearType = gear.gearType
        local behavior = GearBehavior[gearType]
        
        if not behavior or not behavior.use then
            -- Skip excluded gears
            if CONFIG.DebugMode and behavior and behavior.category == "excluded" then
                print("[FAF] Skipping excluded gear: " .. gearType)
            end
        elseif behavior.category == "autoFeeder" and CONFIG.UseAutoFeeders then
            AutoGear.UseAutoFeeder(gear.gearId, gearType)
            task.wait(0.5)
        elseif gearType == "DiamondCookie" and CONFIG.UseDiamondCookie then
            AutoGear.UseDiamondCookie(gear.gearId)
            task.wait(0.5)
        elseif gearType == "YolkBreaker" and CONFIG.UseYolkBreaker then
            AutoGear.UseYolkBreaker(gear.gearId)
            task.wait(0.5)
        elseif gearType == "EggHatcher" and CONFIG.UseEggHatcher then
            AutoGear.UseEggHatcher(gear.gearId)
            task.wait(0.5)
        elseif behavior.category == "foodTray" and CONFIG.UseFoodTrays then
            -- Place food tray in pond
            local pos = AutoGear.GetBestBaitPosition()
            if pos then
                FireRemoRemote("ponds.placeBuilding", "foodTray", gear.gearId, pos, 0)
                AutoGear.GearsUsed = AutoGear.GearsUsed + 1
                task.wait(0.5)
            end
        end
    end
end

-- Auto buy gear from shop
function AutoGear.AutoBuyGears()
    if not CONFIG.AutoBuyGear then return end
    
    -- List of buyable gears to auto-purchase
    local buyableGears = {
        "BasicAutoFeeder",
        "AdvancedAutoFeeder",
        "SupremeAutoFeeder",
        "ExtremeAutoFeeder",
        "BasicFoodTray",
        "AdvancedFoodTray",
        "EggHatcher",
    }
    
    -- Check current inventory
    local currentGears = AutoGear.GetInventoryGears()
    local gearCounts = {}
    for _, gear in ipairs(currentGears) do
        gearCounts[gear.gearType] = (gearCounts[gear.gearType] or 0) + 1
    end
    
    -- Buy gears we don't have (limit 1 of each type)
    for _, gearType in ipairs(buyableGears) do
        if not gearCounts[gearType] or gearCounts[gearType] < 1 then
            local behavior = GearBehavior[gearType]
            if behavior and behavior.buyable then
                AutoGear.BuyGear(gearType)
                task.wait(0.5)
            end
        end
    end
end

function AutoGear.Start()
    if AutoGear.Running then return end
    AutoGear.Running = true
    
    print("[FAF] 🔧 Auto Gear System STARTED")
    
    task.spawn(function()
        while AutoGear.Running and (CONFIG.AutoBuyGear or CONFIG.AutoUseGear) do
            if CONFIG.AutoBuyGear then
                AutoGear.AutoBuyGears()
            end
            if CONFIG.AutoUseGear then
                AutoGear.ProcessGears()
            end
            task.wait(CONFIG.GearCheckInterval or 10)
        end
    end)
end

function AutoGear.Stop()
    AutoGear.Running = false
    print("[FAF] 🔧 Auto Gear System STOPPED")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ANTI-STAFF PROTECTION (Server hop when admin joins)
-- ═══════════════════════════════════════════════════════════════════════════

local AntiStaff = {}
AntiStaff.Running = false
AntiStaff.StaffDetected = false
AntiStaff.HopsCount = 0
AntiStaff.GameGroupId = nil

-- Settings key for persistence across server hops
local SETTINGS_KEY = "FAF_AutoFarm_Settings"

-- Save current settings to persist across server hop
function AntiStaff.SaveSettings()
    local settingsToSave = {
        -- Active modules state
        AutoCollectorRunning = AutoCollector.Running,
        AutoSellerRunning = AutoSeller.Running,
        CrateCollectorRunning = CrateCollector.Running,
        EventFeederRunning = EventFeeder.Running,
        AutoBuyerRunning = AutoBuyer and AutoBuyer.Running or false,
        AutoPlacerRunning = AutoPlacer and AutoPlacer.Running or false,
        AntiStaffRunning = AntiStaff.Running,
        AntiAFKRunning = AntiAFK and AntiAFK.Running or false,
        
        -- CONFIG values
        AutoCollectFish = CONFIG.AutoCollectFish,
        AutoSellFish = CONFIG.AutoSellFish,
        AutoBuyBait = CONFIG.AutoBuyBait,
        AutoPlaceBait = CONFIG.AutoPlaceBait,
        KeepEventFish = CONFIG.KeepEventFish,
        AntiStaff = CONFIG.AntiStaff,
        AntiAFK = CONFIG.AntiAFK,
        
        -- Stats
        HopsCount = AntiStaff.HopsCount + 1,
        Timestamp = os.time(),
    }
    
    local encoded = HttpService:JSONEncode(settingsToSave)
    
    -- Use queue_on_teleport to run script after server hop
    if queue_on_teleport then
        local restoreScript = string.format([[
-- FAF Anti-Staff Auto-Restore
task.wait(3) -- Wait for game to load

local savedSettings = %s

-- Wait for FAF to load
repeat task.wait(0.5) until getgenv().FAF

local FAF = getgenv().FAF

-- Restore CONFIG
if savedSettings.KeepEventFish ~= nil then FAF.CONFIG.KeepEventFish = savedSettings.KeepEventFish end
if savedSettings.AntiStaff ~= nil then FAF.CONFIG.AntiStaff = savedSettings.AntiStaff end
if savedSettings.AntiAFK ~= nil then FAF.CONFIG.AntiAFK = savedSettings.AntiAFK end

-- Restore running states
task.wait(1)

if savedSettings.AutoCollectorRunning then FAF.AutoCollector.Start() end
if savedSettings.AutoSellerRunning then FAF.AutoSeller.Start() end
if savedSettings.CrateCollectorRunning then FAF.CrateCollector.Start() end
if savedSettings.EventFeederRunning then FAF.EventFeeder.Start() end
if savedSettings.AutoBuyerRunning and FAF.AutoBuyer then FAF.AutoBuyer.Start() end
if savedSettings.AutoPlacerRunning and FAF.AutoPlacer then FAF.AutoPlacer.Start() end
if savedSettings.AntiStaffRunning and FAF.AntiStaff then FAF.AntiStaff.Start() end
if savedSettings.AntiAFKRunning and FAF.AntiAFK then FAF.AntiAFK.Start() end

-- Update hop count
if FAF.AntiStaff then
    FAF.AntiStaff.HopsCount = savedSettings.HopsCount or 0
end

print("[FAF] ✅ Settings restored after server hop! (Hop #" .. (savedSettings.HopsCount or 1) .. ")")
]], encoded)
        
        queue_on_teleport(restoreScript)
        print("[FAF] 💾 Settings saved for server hop")
        return true
    else
        warn("[FAF] queue_on_teleport not available - settings won't persist")
        return false
    end
end

-- Get game group ID
function AntiStaff.GetGameGroupId()
    if AntiStaff.GameGroupId then
        return AntiStaff.GameGroupId
    end
    
    if CONFIG.GameGroupId and CONFIG.GameGroupId > 0 then
        AntiStaff.GameGroupId = CONFIG.GameGroupId
        return AntiStaff.GameGroupId
    end
    
    -- Try to find group ID from game info
    local success, result = pcall(function()
        local creatorId = game.CreatorId
        local creatorType = game.CreatorType
        
        if creatorType == Enum.CreatorType.Group then
            return creatorId
        end
        return nil
    end)
    
    if success and result then
        AntiStaff.GameGroupId = result
        return result
    end
    
    return nil
end

-- Check if player is in a high rank group position
function AntiStaff.CheckGroupRank(player)
    if not CONFIG.DetectByGroupRank then return false end
    
    local groupId = AntiStaff.GetGameGroupId()
    if not groupId then return false end
    
    local success, rank = pcall(function()
        return player:GetRankInGroup(groupId)
    end)
    
    if success and rank >= CONFIG.MinStaffRank then
        if CONFIG.DebugMode then
            print("[FAF] ⚠️ Staff detected by group rank:", player.Name, "Rank:", rank)
        end
        return true
    end
    
    return false
end

-- Check if player has admin commands/tools
function AntiStaff.CheckAdminCommands(player)
    if not CONFIG.DetectByCommands then return false end
    
    -- Check PlayerGui for admin interfaces
    local success, result = pcall(function()
        local playerGui = player:FindFirstChild("PlayerGui")
        if playerGui then
            for _, indicator in ipairs(CONFIG.AdminIndicators) do
                if playerGui:FindFirstChild(indicator, true) then
                    return true
                end
            end
        end
        
        -- Check for admin command modules in PlayerScripts
        local playerScripts = player:FindFirstChild("PlayerScripts")
        if playerScripts then
            for _, indicator in ipairs(CONFIG.AdminIndicators) do
                if playerScripts:FindFirstChild(indicator, true) then
                    return true
                end
            end
        end
        
        return false
    end)
    
    if success and result then
        if CONFIG.DebugMode then
            print("[FAF] ⚠️ Staff detected by admin commands:", player.Name)
        end
        return true
    end
    
    return false
end

-- Check known staff lists
function AntiStaff.CheckKnownStaff(player)
    -- Check by username
    for _, username in ipairs(CONFIG.KnownStaffUsernames) do
        if player.Name:lower() == username:lower() then
            if CONFIG.DebugMode then
                print("[FAF] ⚠️ Known staff detected by username:", player.Name)
            end
            return true
        end
    end
    
    -- Check by UserId
    for _, userId in ipairs(CONFIG.KnownStaffUserIds) do
        if player.UserId == userId then
            if CONFIG.DebugMode then
                print("[FAF] ⚠️ Known staff detected by UserId:", player.Name, player.UserId)
            end
            return true
        end
    end
    
    return false
end

-- Check if player is staff
function AntiStaff.IsStaff(player)
    if player == LocalPlayer then return false end
    
    -- Check known staff lists first (fastest)
    if AntiStaff.CheckKnownStaff(player) then
        return true
    end
    
    -- Check group rank
    if AntiStaff.CheckGroupRank(player) then
        return true
    end
    
    -- Check admin commands (delayed check)
    task.delay(1, function()
        if AntiStaff.CheckAdminCommands(player) then
            AntiStaff.OnStaffDetected(player)
        end
    end)
    
    return false
end

-- Server hop to a new server
function AntiStaff.ServerHop()
    print("[FAF] 🚀 Server hopping to escape staff...")
    
    -- Save settings before hopping
    AntiStaff.SaveSettings()
    
    local placeId = game.PlaceId
    
    -- Method 1: Get random server from server list
    local success, servers = pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    
    if success and servers and servers.data then
        local currentJobId = game.JobId
        local validServers = {}
        
        for _, server in ipairs(servers.data) do
            if server.id ~= currentJobId and server.playing < server.maxPlayers then
                table.insert(validServers, server)
            end
        end
        
        if #validServers > 0 then
            local targetServer = validServers[math.random(1, #validServers)]
            print("[FAF] 🎯 Teleporting to server:", targetServer.id)
            TeleportService:TeleportToPlaceInstance(placeId, targetServer.id, LocalPlayer)
            return true
        end
    end
    
    -- Method 2: Fallback - teleport to random server
    print("[FAF] 🎯 Using fallback teleport...")
    TeleportService:Teleport(placeId, LocalPlayer)
    return true
end

-- Called when staff is detected
function AntiStaff.OnStaffDetected(player)
    if AntiStaff.StaffDetected then return end -- Prevent multiple triggers
    AntiStaff.StaffDetected = true
    
    print("[FAF] 🚨 STAFF DETECTED:", player.Name, "(ID:", player.UserId, ")")
    
    if CONFIG.ShowNotifications then
        -- Visual warning
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "⚠️ STAFF DETECTED",
                Text = "Server hopping now...",
                Duration = 2
            })
        end)
    end
    
    -- Immediate server hop
    task.spawn(function()
        task.wait(0.5) -- Small delay for notification
        AntiStaff.ServerHop()
    end)
end

-- Scan existing players for staff
function AntiStaff.ScanExistingPlayers()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if AntiStaff.IsStaff(player) then
                AntiStaff.OnStaffDetected(player)
                return
            end
        end
    end
end

function AntiStaff.Start()
    if AntiStaff.Running then return end
    AntiStaff.Running = true
    AntiStaff.StaffDetected = false
    
    print("[FAF] 🛡️ Anti-Staff Protection STARTED")
    
    -- Scan existing players
    AntiStaff.ScanExistingPlayers()
    
    -- Listen for new players joining
    Players.PlayerAdded:Connect(function(player)
        if not AntiStaff.Running then return end
        
        if CONFIG.DebugMode then
            print("[FAF] Player joined:", player.Name)
        end
        
        -- Small delay to let player data load
        task.wait(0.5)
        
        if AntiStaff.IsStaff(player) then
            AntiStaff.OnStaffDetected(player)
        end
    end)
end

function AntiStaff.Stop()
    AntiStaff.Running = false
    print("[FAF] 🛡️ Anti-Staff Protection STOPPED")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ANTI-AFK PROTECTION (Walk around and server hop when AFK)
-- ═══════════════════════════════════════════════════════════════════════════

local AntiAFK = {}
AntiAFK.Running = false
AntiAFK.LastInteraction = tick()
AntiAFK.SessionStart = tick()
AntiAFK.IsMovingAway = false
AntiAFK.OriginalPosition = nil
AntiAFK.Connections = {}
AntiAFK.ServerHopScheduled = false
AntiAFK.ServerHopTime = 0

-- Input types to track for interaction detection
local InputTypesToTrack = {
    Enum.UserInputType.MouseButton1,
    Enum.UserInputType.MouseButton2,
    Enum.UserInputType.Keyboard,
    Enum.UserInputType.Touch,
    Enum.UserInputType.Gamepad1,
}

-- Update last interaction time
function AntiAFK.RecordInteraction()
    AntiAFK.LastInteraction = tick()
    if CONFIG.DebugMode then
        print("[FAF] Anti-AFK: Interaction recorded")
    end
end

-- Get random point at specified distance from current position
function AntiAFK.GetRandomPointAway(distance)
    local character = LocalPlayer.Character
    if not character then return nil end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return nil end
    
    -- Random angle in radians
    local angle = math.random() * math.pi * 2
    local offsetX = math.cos(angle) * distance
    local offsetZ = math.sin(angle) * distance
    
    local targetPos = humanoidRootPart.Position + Vector3.new(offsetX, 0, offsetZ)
    return targetPos
end

-- Walk to position using PathfindingService
function AntiAFK.WalkToPosition(targetPosition, callback)
    local PathfindingService = game:GetService("PathfindingService")
    local character = LocalPlayer.Character
    if not character then 
        if callback then callback(false) end
        return 
    end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not humanoidRootPart then 
        if callback then callback(false) end
        return 
    end
    
    -- Create path
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = false,
    })
    
    local success, errorMessage = pcall(function()
        path:ComputeAsync(humanoidRootPart.Position, targetPosition)
    end)
    
    if not success or path.Status ~= Enum.PathStatus.Success then
        -- Fallback: Simple MoveTo
        if CONFIG.DebugMode then
            print("[FAF] Anti-AFK: Pathfinding failed, using simple movement")
        end
        humanoid:MoveTo(targetPosition)
        humanoid.MoveToFinished:Wait()
        if callback then callback(true) end
        return
    end
    
    -- Follow path waypoints
    local waypoints = path:GetWaypoints()
    
    task.spawn(function()
        for i, waypoint in ipairs(waypoints) do
            if waypoint.Action == Enum.PathWaypointAction.Jump then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
            
            humanoid:MoveTo(waypoint.Position)
            
            -- Wait for movement or timeout
            local reached = false
            local connection
            connection = humanoid.MoveToFinished:Connect(function(didReach)
                reached = didReach
                if connection then connection:Disconnect() end
            end)
            
            local timeout = tick() + 5
            while not reached and tick() < timeout do
                task.wait(0.1)
            end
            
            if not reached then
                if connection then connection:Disconnect() end
            end
        end
        
        if callback then callback(true) end
    end)
end

-- Perform AFK walk (walk away then come back)
function AntiAFK.PerformAFKWalk()
    if AntiAFK.IsMovingAway then return end
    AntiAFK.IsMovingAway = true
    
    local character = LocalPlayer.Character
    if not character then 
        AntiAFK.IsMovingAway = false
        return 
    end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then 
        AntiAFK.IsMovingAway = false
        return 
    end
    
    -- Save original position
    AntiAFK.OriginalPosition = humanoidRootPart.Position
    
    if CONFIG.DebugMode then
        print("[FAF] Anti-AFK: Walking away from position...")
    end
    
    -- Get target position (5 studs away)
    local targetPos = AntiAFK.GetRandomPointAway(CONFIG.AFKWalkDistance)
    if not targetPos then
        AntiAFK.IsMovingAway = false
        return
    end
    
    -- Walk to target
    AntiAFK.WalkToPosition(targetPos, function(success)
        if CONFIG.DebugMode then
            print("[FAF] Anti-AFK: Walked away, waiting before returning...")
        end
        
        -- Wait 2-5 seconds before returning
        task.wait(math.random(2, 5))
        
        -- Walk back to original position
        if AntiAFK.OriginalPosition then
            AntiAFK.WalkToPosition(AntiAFK.OriginalPosition, function(success2)
                if CONFIG.DebugMode then
                    print("[FAF] Anti-AFK: Returned to original position")
                end
                AntiAFK.IsMovingAway = false
                
                -- Reset interaction timer after walking (we just moved so we're "active")
                AntiAFK.LastInteraction = tick()
            end)
        else
            AntiAFK.IsMovingAway = false
        end
    end)
end

-- Server hop due to extended AFK
function AntiAFK.ServerHop()
    print("[FAF] ⏰ Anti-AFK: Server hopping after extended AFK period...")
    
    -- Use AntiStaff's save/hop logic for consistency
    AntiStaff.SaveSettings()
    
    local placeId = game.PlaceId
    
    -- Method 1: Get random server from server list
    local success, servers = pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    
    if success and servers and servers.data then
        local currentJobId = game.JobId
        local validServers = {}
        
        for _, server in ipairs(servers.data) do
            if server.id ~= currentJobId and server.playing < server.maxPlayers then
                table.insert(validServers, server)
            end
        end
        
        if #validServers > 0 then
            local targetServer = validServers[math.random(1, #validServers)]
            print("[FAF] 🎯 Teleporting to server:", targetServer.id)
            TeleportService:TeleportToPlaceInstance(placeId, targetServer.id, LocalPlayer)
            return true
        end
    end
    
    -- Fallback
    print("[FAF] 🎯 Using fallback teleport...")
    TeleportService:Teleport(placeId, LocalPlayer)
    return true
end

-- Calculate random server hop time between min and max
function AntiAFK.CalculateServerHopTime()
    local minTime = CONFIG.AFKServerHopMin
    local maxTime = CONFIG.AFKServerHopMax
    return math.random(minTime, maxTime)
end

-- Main loop for Anti-AFK
function AntiAFK.MainLoop()
    while AntiAFK.Running do
        task.wait(1) -- Check every second
        
        local currentTime = tick()
        local idleTime = currentTime - AntiAFK.LastInteraction
        local sessionTime = currentTime - AntiAFK.SessionStart
        
        -- Check for extended AFK (server hop)
        if not AntiAFK.ServerHopScheduled then
            AntiAFK.ServerHopTime = AntiAFK.CalculateServerHopTime()
            AntiAFK.ServerHopScheduled = true
            if CONFIG.DebugMode then
                print("[FAF] Anti-AFK: Server hop scheduled in", math.floor(AntiAFK.ServerHopTime / 60), "minutes")
            end
        end
        
        if sessionTime >= AntiAFK.ServerHopTime then
            print("[FAF] ⏰ Anti-AFK: Session time exceeded", math.floor(AntiAFK.ServerHopTime / 60), "minutes - hopping server")
            AntiAFK.ServerHop()
            break -- Stop loop since we're leaving
        end
        
        -- Check for idle AFK (walk away)
        if idleTime >= CONFIG.AFKIdleTime and not AntiAFK.IsMovingAway then
            print("[FAF] 🚶 Anti-AFK: No interaction for", math.floor(idleTime), "seconds - walking away")
            AntiAFK.PerformAFKWalk()
        end
        
        -- Debug output every 30 seconds
        if CONFIG.DebugMode and math.floor(currentTime) % 30 == 0 then
            print(string.format("[FAF] Anti-AFK Status: Idle: %.0fs, Session: %.0fs, Hop in: %.0fs", 
                idleTime, sessionTime, AntiAFK.ServerHopTime - sessionTime))
        end
    end
end

-- Connect input listeners for interaction tracking
function AntiAFK.ConnectInputListeners()
    local UserInputService = game:GetService("UserInputService")
    
    -- Track keyboard and mouse input
    local inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        for _, inputType in ipairs(InputTypesToTrack) do
            if input.UserInputType == inputType then
                AntiAFK.RecordInteraction()
                break
            end
        end
    end)
    table.insert(AntiAFK.Connections, inputConnection)
    
    -- Track mouse movement
    local mouseConnection = UserInputService.InputChanged:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            AntiAFK.RecordInteraction()
        end
    end)
    table.insert(AntiAFK.Connections, mouseConnection)
    
    -- Track character movement
    local function connectCharacterMovement()
        local character = LocalPlayer.Character
        if not character then return end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local moveConnection = humanoid.Running:Connect(function(speed)
                if speed > 0.1 then
                    AntiAFK.RecordInteraction()
                end
            end)
            table.insert(AntiAFK.Connections, moveConnection)
            
            local jumpConnection = humanoid.Jumping:Connect(function(isJumping)
                if isJumping then
                    AntiAFK.RecordInteraction()
                end
            end)
            table.insert(AntiAFK.Connections, jumpConnection)
        end
    end
    
    connectCharacterMovement()
    local charConnection = LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        connectCharacterMovement()
    end)
    table.insert(AntiAFK.Connections, charConnection)
end

-- Disconnect all listeners
function AntiAFK.DisconnectInputListeners()
    for _, connection in ipairs(AntiAFK.Connections) do
        if connection and connection.Connected then
            connection:Disconnect()
        end
    end
    AntiAFK.Connections = {}
end

function AntiAFK.Start()
    if AntiAFK.Running then return end
    AntiAFK.Running = true
    AntiAFK.SessionStart = tick()
    AntiAFK.LastInteraction = tick()
    AntiAFK.ServerHopScheduled = false
    
    print("[FAF] ⏰ Anti-AFK Protection STARTED")
    print("[FAF] • Walk after " .. (CONFIG.AFKIdleTime / 60) .. " minutes idle")
    print("[FAF] • Server hop after " .. math.floor(CONFIG.AFKServerHopMin / 60) .. "-" .. math.floor(CONFIG.AFKServerHopMax / 60) .. " minutes")
    
    -- Connect input listeners
    AntiAFK.ConnectInputListeners()
    
    -- Start main loop
    task.spawn(AntiAFK.MainLoop)
end

function AntiAFK.Stop()
    AntiAFK.Running = false
    AntiAFK.DisconnectInputListeners()
    print("[FAF] ⏰ Anti-AFK Protection STOPPED")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- BAIT DATA (From Game Dump)
-- ═══════════════════════════════════════════════════════════════════════════

local BaitData = {
    -- Format: name = {price, cooldown, netSize, source, tier}
    -- Tier is used for smart bait management (higher = better)
    Starter = {price = 50, cooldown = 10, netSize = "10x10", source = "BaitShop", tier = 1},
    Novice = {price = 500, cooldown = 60, netSize = "15x15", source = "BaitShop", tier = 2},
    Reef = {price = 2500, cooldown = 90, netSize = "20x20", source = "BaitShop", tier = 3},
    DeepSea = {price = 5000, cooldown = 150, netSize = "15x15", source = "BaitShop", tier = 4},
    Koi = {price = 20000, cooldown = 240, netSize = "15x15", source = "BaitShop", tier = 5},
    River = {price = 50000, cooldown = 420, netSize = "15x15", source = "BaitShop", tier = 6},
    Puffer = {price = 200000, cooldown = 600, netSize = "20x20", source = "BaitShop", tier = 7},
    Seal = {price = 700000, cooldown = 720, netSize = "20x20", source = "BaitShop", tier = 8},
    Glo = {price = 400000, cooldown = 300, netSize = "10x10", source = "BaitShop", tier = 9},
    Ray = {price = 1200000, cooldown = 900, netSize = "20x20", source = "BaitShop", tier = 10},
    Octopus = {price = 30000000, cooldown = 2100, netSize = "25x25", source = "BaitShop", tier = 11},
    Axolotl = {price = 5000000, cooldown = 600, netSize = "10x10", source = "BaitShop", tier = 12},
    Jelly = {price = 60000000, cooldown = 1800, netSize = "15x15", source = "BaitShop", tier = 13},
    Whale = {price = 250000000, cooldown = 14400, netSize = "35x35", source = "BaitShop", tier = 14},
    Shark = {price = 500000000, cooldown = 7200, netSize = "25x25", source = "BaitShop", tier = 15},
    -- Event baits (high tier)
    Christmas = {price = 0, cooldown = 300, netSize = "15x15", source = "Event", tier = 20},
    Robot = {price = 0, cooldown = 300, netSize = "15x15", source = "Event", tier = 21},
    Alien = {price = 0, cooldown = 300, netSize = "15x15", source = "Event", tier = 22},
}

-- Get bait tier (higher = better)
local function GetBaitTier(baitType)
    if BaitData[baitType] then
        return BaitData[baitType].tier or 0
    end
    -- Try to find by lowercase match
    for name, data in pairs(BaitData) do
        if name:lower() == baitType:lower() then
            return data.tier or 0
        end
    end
    return 0
end

local NetSizes = {
    ["10x10"] = 10,
    ["15x15"] = 15,
    ["20x20"] = 20,
    ["25x25"] = 25,
    ["30x30"] = 30,
    ["35x35"] = 35,
    ["40x40"] = 40,
}

-- ═══════════════════════════════════════════════════════════════════════════
-- AUTO BUY BAIT
-- ═══════════════════════════════════════════════════════════════════════════

local AutoBuyer = {}
AutoBuyer.Running = false
AutoBuyer.BaitBought = 0

function AutoBuyer.GetBaitInInventory()
    -- Try to count bait in player's inventory
    local count = 0
    
    -- Method 1: Check player data atoms
    local success, playerData = pcall(function()
        -- Try to access player state
        local stateModule = ReplicatedStorage:FindFirstChild("TS")
        if stateModule then
            local syncAtoms = stateModule:FindFirstChild("state")
            -- This would need proper state access
        end
        return nil
    end)
    
    -- Method 2: Check equipped tools/inventory GUI
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                local name = tool.Name:lower()
                for baitName, _ in pairs(BaitData) do
                    if name:find(baitName:lower()) then
                        count = count + 1
                    end
                end
            end
        end
    end
    
    return count
end

function AutoBuyer.BuyBait(baitName)
    baitName = baitName or CONFIG.PreferredBait
    
    -- Fire the purchaseBait remote
    local success = FireRemote("shop", "purchaseBait", baitName)
    
    if success then
        AutoBuyer.BaitBought = AutoBuyer.BaitBought + 1
        if CONFIG.ShowNotifications then
            print("[FAF] 🎣 Bought bait: " .. baitName .. " (Total: " .. AutoBuyer.BaitBought .. ")")
        end
    end
    
    return success
end

function AutoBuyer.Start()
    if AutoBuyer.Running then return end
    AutoBuyer.Running = true
    
    print("[FAF] 🛒 Auto Bait Buyer STARTED - Buying: " .. CONFIG.PreferredBait)
    
    task.spawn(function()
        while AutoBuyer.Running and CONFIG.AutoBuyBait do
            local currentCount = AutoBuyer.GetBaitInInventory()
            
            if currentCount < CONFIG.MaxBaitInInventory then
                AutoBuyer.BuyBait(CONFIG.PreferredBait)
            else
                if CONFIG.DebugMode then
                    print("[FAF] Bait inventory full: " .. currentCount .. "/" .. CONFIG.MaxBaitInInventory)
                end
            end
            
            task.wait(CONFIG.BuyBaitInterval)
        end
    end)
end

function AutoBuyer.Stop()
    AutoBuyer.Running = false
    print("[FAF] 🛒 Auto Bait Buyer STOPPED")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- AUTO PLACE BAIT (With Bypass Attempt)
-- ═══════════════════════════════════════════════════════════════════════════

local AutoPlacer = {}
AutoPlacer.Running = false
AutoPlacer.BaitPlaced = 0
AutoPlacer.PlacedPositions = {} -- Track where we've placed to avoid duplicates
AutoPlacer.CurrentGridIndex = 0

-- Get player's pond area
function AutoPlacer.GetPlayerPond()
    -- The game organizes ponds in Workspace.Ponds folder
    -- Each pond is named like "Pond1", "Pond2", etc.
    
    local pondsFolder = Workspace:FindFirstChild("Ponds")
    
    if not pondsFolder then
        -- Try to find Ponds elsewhere in workspace
        for _, child in ipairs(Workspace:GetChildren()) do
            if child.Name:lower():find("pond") and child:IsA("Folder") then
                pondsFolder = child
                break
            end
        end
    end
    
    if CONFIG.DebugMode then
        print("[FAF] Looking for ponds folder:", pondsFolder and pondsFolder.Name or "NOT FOUND")
    end
    
    if pondsFolder then
        -- First: Try to find pond by checking OwnsPond component via ECS
        -- The game uses ECS with OwnsPond component to track ownership
        local playerUserId = tostring(LocalPlayer.UserId)
        
        for _, pond in ipairs(pondsFolder:GetChildren()) do
            -- Check various ownership attributes
            local owner = pond:GetAttribute("Owner") 
                or pond:GetAttribute("OwnerId")
                or pond:GetAttribute("PlayerId")
            
            if owner then
                local ownerStr = tostring(owner)
                if ownerStr == playerUserId or ownerStr == LocalPlayer.Name then
                    if CONFIG.DebugMode then
                        print("[FAF] Found owned pond:", pond.Name)
                    end
                    return pond
                end
            end
            
            -- Also check for Owner value instance
            local ownerInstance = pond:FindFirstChild("Owner")
            if ownerInstance and ownerInstance:IsA("ValueBase") then
                local val = ownerInstance.Value
                if val == LocalPlayer or tostring(val) == playerUserId then
                    if CONFIG.DebugMode then
                        print("[FAF] Found owned pond via Owner value:", pond.Name)
                    end
                    return pond
                end
            end
        end
        
        -- Fallback: Find pond closest to player
        local character = LocalPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local playerPos = character.HumanoidRootPart.Position
            local closestPond = nil
            local closestDist = math.huge
            
            for _, pond in ipairs(pondsFolder:GetChildren()) do
                -- Find any part to measure distance
                local pondPart = pond:FindFirstChildWhichIsA("BasePart", true)
                if pondPart then
                    local dist = (pondPart.Position - playerPos).Magnitude
                    if dist < closestDist and dist < 200 then
                        closestDist = dist
                        closestPond = pond
                    end
                end
            end
            
            if closestPond then
                if CONFIG.DebugMode then
                    print("[FAF] Using closest pond:", closestPond.Name, "distance:", math.floor(closestDist))
                end
                return closestPond
            end
        end
    end
    
    if CONFIG.DebugMode then
        print("[FAF] WARNING: Could not find player's pond")
    end
    
    return nil
end

-- Get water surface in pond
function AutoPlacer.GetWaterSurface()
    local pond = AutoPlacer.GetPlayerPond()
    if not pond then 
        if CONFIG.DebugMode then
            print("[FAF] GetWaterSurface: No pond found")
        end
        return nil 
    end
    
    -- Find water part - search recursively
    local waterNames = {"Water", "WaterSurface", "WaterPart", "Pool", "Surface"}
    
    for _, name in ipairs(waterNames) do
        local water = pond:FindFirstChild(name, true)
        if water and water:IsA("BasePart") then
            if CONFIG.DebugMode then
                print("[FAF] Found water surface:", water:GetFullName())
            end
            return water
        end
    end
    
    -- Search for any BasePart that looks like water (blue, terrain water, etc)
    for _, child in ipairs(pond:GetDescendants()) do
        if child:IsA("BasePart") then
            local name = child.Name:lower()
            if name:find("water") or name:find("pool") or name:find("surface") then
                if CONFIG.DebugMode then
                    print("[FAF] Found water via search:", child:GetFullName())
                end
                return child
            end
        end
    end
    
    -- Last resort: Find largest flat part (likely water)
    local largest = nil
    local largestArea = 0
    
    for _, child in ipairs(pond:GetDescendants()) do
        if child:IsA("BasePart") and child.Size.Y < 2 then -- Flat parts
            local area = child.Size.X * child.Size.Z
            if area > largestArea then
                largestArea = area
                largest = child
            end
        end
    end
    
    if largest then
        if CONFIG.DebugMode then
            print("[FAF] Using largest flat part as water:", largest:GetFullName())
        end
        return largest
    end
    
    if CONFIG.DebugMode then
        print("[FAF] WARNING: Could not find water surface in pond:", pond.Name)
    end
    
    return nil
end

-- Generate grid positions for bait placement
function AutoPlacer.GeneratePlacementPositions(centerPos, count, spacing)
    local positions = {}
    local gridSize = math.ceil(math.sqrt(count))
    local offset = (gridSize - 1) * spacing / 2
    
    for x = 0, gridSize - 1 do
        for z = 0, gridSize - 1 do
            local pos = Vector3.new(
                centerPos.X + (x * spacing) - offset,
                centerPos.Y,
                centerPos.Z + (z * spacing) - offset
            )
            table.insert(positions, pos)
        end
    end
    
    return positions
end

-- Get next available placement position (bypass mode)
function AutoPlacer.GetNextPosition()
    local waterSurface = AutoPlacer.GetWaterSurface()
    if not waterSurface then
        -- Fallback to player position
        local character = LocalPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            return character.HumanoidRootPart.Position + Vector3.new(
                math.random(-30, 30),
                0,
                math.random(-30, 30)
            )
        end
        return nil
    end
    
    local centerPos = waterSurface.Position
    local size = waterSurface.Size
    
    -- Generate position in a spiral/grid pattern
    AutoPlacer.CurrentGridIndex = AutoPlacer.CurrentGridIndex + 1
    local spacing = CONFIG.PlacementSpacing
    
    -- Spiral out from center
    local angle = AutoPlacer.CurrentGridIndex * 0.5
    local radius = spacing * (AutoPlacer.CurrentGridIndex / 10)
    
    local pos = Vector3.new(
        centerPos.X + math.cos(angle) * radius,
        centerPos.Y + 0.5, -- Slightly above water
        centerPos.Z + math.sin(angle) * radius
    )
    
    -- Clamp to pond bounds
    pos = Vector3.new(
        math.clamp(pos.X, centerPos.X - size.X/2 + 5, centerPos.X + size.X/2 - 5),
        pos.Y,
        math.clamp(pos.Z, centerPos.Z - size.Z/2 + 5, centerPos.Z + size.Z/2 - 5)
    )
    
    return pos
end

-- Get bait items from player data inventory (proper method)
function AutoPlacer.GetBaitFromInventory()
    local baits = {}
    
    -- Track what methods were tried for debugging
    local methodsTried = {}
    
    local success = pcall(function()
        -- Method 1: Get from player data via direct import using RuntimeLib
        local rbxts = ReplicatedStorage:FindFirstChild("rbxts_include")
        if rbxts then
            local runtimeLib = rbxts:FindFirstChild("RuntimeLib")
            if runtimeLib then
                local runtime = require(runtimeLib)
                if runtime and runtime.import then
                    table.insert(methodsTried, "RuntimeLib import")
                    
                    -- Import player-data module
                    local playerDataModule = runtime.import(nil, ReplicatedStorage, "TS", "state", "player-data")
                    if playerDataModule then
                        local getPlayerDataById = playerDataModule.getPlayerDataById
                        if getPlayerDataById then
                            -- Game uses string UserId
                            local data = getPlayerDataById(tostring(LocalPlayer.UserId))
                            if data then
                                if CONFIG.DebugMode then
                                    print("[FAF] Got player data, checking inventory...")
                                end
                                
                                -- Check inventory.baits (unplaced baits in inventory)
                                if data.inventory and data.inventory.baits then
                                    for baitId, baitData in pairs(data.inventory.baits) do
                                        -- All baits in inventory.baits are placeable
                                        -- baitData contains: baitType, mutation, amount
                                        table.insert(baits, {
                                            name = baitData.baitType or "Unknown",
                                            toolId = baitId,
                                            toolType = "Bait",
                                            baitData = baitData,
                                            amount = baitData.amount or 1
                                        })
                                        if CONFIG.DebugMode then
                                            print("[FAF] Found bait:", baitId, "type:", baitData.baitType)
                                        end
                                    end
                                end
                            else
                                if CONFIG.DebugMode then
                                    print("[FAF] getPlayerDataById returned nil")
                                end
                            end
                        else
                            if CONFIG.DebugMode then
                                print("[FAF] getPlayerDataById function not found")
                            end
                        end
                    end
                end
            end
        end
        
        -- Method 2: Direct require of TS.state.player-data
        if #baits == 0 then
            local TS = ReplicatedStorage:FindFirstChild("TS")
            if TS then
                local stateFolder = TS:FindFirstChild("state")
                if stateFolder then
                    local playerDataModule = stateFolder:FindFirstChild("player-data")
                    if playerDataModule then
                        table.insert(methodsTried, "Direct TS.state.player-data")
                        local module = require(playerDataModule)
                        if module then
                            local getPlayerDataById = module.getPlayerDataById or module.getPlayerData
                            if getPlayerDataById then
                                local data = getPlayerDataById(tostring(LocalPlayer.UserId))
                                if data and data.inventory and data.inventory.baits then
                                    for baitId, baitData in pairs(data.inventory.baits) do
                                        table.insert(baits, {
                                            name = baitData.baitType or "Unknown",
                                            toolId = baitId,
                                            toolType = "Bait",
                                            baitData = baitData,
                                            amount = baitData.amount or 1
                                        })
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    
    if not success and CONFIG.DebugMode then
        print("[FAF] Error reading player data:", methodsTried)
    end
    
    -- Fallback: Check physical tools in backpack if inventory read fails
    if #baits == 0 then
        table.insert(methodsTried, "Backpack tools fallback")
        
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if backpack then
            for _, tool in ipairs(backpack:GetChildren()) do
                if tool:IsA("Tool") then
                    -- Try to get toolId from various attributes
                    local toolId = tool:GetAttribute("ToolId") 
                        or tool:GetAttribute("Id") 
                        or tool:GetAttribute("toolId")
                        or tool:GetAttribute("id")
                    
                    -- Match against known bait names
                    for baitName, _ in pairs(BaitData) do
                        if tool.Name:lower():find(baitName:lower()) then
                            table.insert(baits, {
                                name = baitName,
                                tool = tool,
                                toolId = toolId or tool.Name, -- Use tool name as last resort
                                toolType = "Bait"
                            })
                            if CONFIG.DebugMode then
                                print("[FAF] Found bait tool in backpack:", tool.Name, "id:", toolId)
                            end
                            break
                        end
                    end
                end
            end
        end
        
        -- Check equipped tools in character
        local character = LocalPlayer.Character
        if character then
            for _, tool in ipairs(character:GetChildren()) do
                if tool:IsA("Tool") then
                    local toolId = tool:GetAttribute("ToolId") 
                        or tool:GetAttribute("Id")
                        or tool:GetAttribute("toolId")
                        or tool:GetAttribute("id")
                    
                    for baitName, _ in pairs(BaitData) do
                        if tool.Name:lower():find(baitName:lower()) then
                            table.insert(baits, {
                                name = baitName,
                                tool = tool,
                                toolId = toolId or tool.Name,
                                toolType = "Bait",
                                equipped = true
                            })
                            if CONFIG.DebugMode then
                                print("[FAF] Found equipped bait:", tool.Name, "id:", toolId)
                            end
                            break
                        end
                    end
                end
            end
        end
    end
    
    if CONFIG.DebugMode then
        print("[FAF] GetBaitFromInventory: Found", #baits, "baits. Methods tried:", table.concat(methodsTried, ", "))
    end
    
    return baits
end

-- Place bait at position
function AutoPlacer.PlaceBait(toolId, position, rotation)
    rotation = rotation or 0
    
    -- PlaceableType for bait is "bait"
    local placeableType = "bait"
    
    if CONFIG.DebugMode then
        print(string.format("[FAF] Attempting to place bait: toolId=%s, pos=(%.1f, %.1f, %.1f), rot=%d",
            tostring(toolId), position.X, position.Y, position.Z, rotation))
    end
    
    -- Try different methods to place
    local success = false
    local errorMsg = ""
    
    -- Method 1: Use remo remote (preferred)
    local ok, result = pcall(function()
        return FireRemoRemote("ponds.placeBuilding", placeableType, toolId, position, rotation)
    end)
    
    if ok and result then
        success = true
    else
        errorMsg = errorMsg .. "Remo failed: " .. tostring(result) .. "; "
    end
    
    -- Method 2: Fallback to FireRemote
    if not success then
        local ok2, result2 = pcall(function()
            return FireRemote("ponds", "placeBuilding", placeableType, toolId, position, rotation)
        end)
        
        if ok2 and result2 then
            success = true
        else
            errorMsg = errorMsg .. "FireRemote failed: " .. tostring(result2)
        end
    end
    
    if success then
        AutoPlacer.BaitPlaced = AutoPlacer.BaitPlaced + 1
        table.insert(AutoPlacer.PlacedPositions, position)
        
        if CONFIG.ShowNotifications then
            print(string.format("[FAF] 🎣 Placed bait at (%.1f, %.1f, %.1f) - Total: %d", 
                position.X, position.Y, position.Z, AutoPlacer.BaitPlaced))
        end
        return true
    else
        if CONFIG.DebugMode then
            print("[FAF] PlaceBait failed:", errorMsg)
        end
    end
    
    return false
end

-- Bypass: Try placing at slightly different positions
function AutoPlacer.PlaceBaitWithBypass(toolId, basePosition)
    -- First try exact position
    if AutoPlacer.PlaceBait(toolId, basePosition, 0) then
        return true
    end
    
    if not CONFIG.BypassPlacementCheck then
        return false
    end
    
    -- Bypass attempt: Try nearby positions
    local offsets = {
        Vector3.new(0.1, 0, 0),
        Vector3.new(-0.1, 0, 0),
        Vector3.new(0, 0, 0.1),
        Vector3.new(0, 0, -0.1),
        Vector3.new(0.5, 0, 0.5),
        Vector3.new(-0.5, 0, 0.5),
        Vector3.new(0.5, 0, -0.5),
        Vector3.new(-0.5, 0, -0.5),
        Vector3.new(1, 0, 0),
        Vector3.new(0, 0, 1),
        Vector3.new(-1, 0, 0),
        Vector3.new(0, 0, -1),
    }
    
    for i, offset in ipairs(offsets) do
        local newPos = basePosition + offset
        
        -- Try different rotations too
        for rotation = 0, 270, 90 do
            if AutoPlacer.PlaceBait(toolId, newPos, rotation) then
                if CONFIG.DebugMode then
                    print("[FAF] Bypass succeeded with offset " .. tostring(offset) .. " rotation " .. rotation)
                end
                return true
            end
        end
        
        task.wait(0.05) -- Small delay between attempts
    end
    
    -- Advanced bypass: Try with random micro-offsets
    for i = 1, 10 do
        local randomOffset = Vector3.new(
            (math.random() - 0.5) * 2,
            0,
            (math.random() - 0.5) * 2
        )
        local newPos = basePosition + randomOffset
        
        if AutoPlacer.PlaceBait(toolId, newPos, math.random(0, 3) * 90) then
            if CONFIG.DebugMode then
                print("[FAF] Random bypass succeeded!")
            end
            return true
        end
        
        task.wait(0.02)
    end
    
    return false
end

-- Equip bait tool
function AutoPlacer.EquipBait(baitInfo)
    if CONFIG.DebugMode then
        print("[FAF] Equipping bait:", baitInfo.name, "toolId:", baitInfo.toolId, "toolType:", baitInfo.toolType)
    end
    
    -- Fire equip remote using remo (preferred)
    -- Game uses: tools.equipTool(toolId, toolType)
    local toolType = baitInfo.toolType or "Bait"
    
    -- Try remo first
    local success = FireRemoRemote("tools.equipTool", baitInfo.toolId, toolType)
    
    -- Fallback to FireRemote
    if not success then
        FireRemote("tools", "equipTool", baitInfo.toolId, toolType)
    end
    
    -- Also try humanoid equip if we have a physical tool
    local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
    if humanoid and baitInfo.tool then
        pcall(function()
            humanoid:EquipTool(baitInfo.tool)
        end)
    end
    
    task.wait(0.2) -- Wait longer for equip to process
end

function AutoPlacer.Start()
    if AutoPlacer.Running then return end
    AutoPlacer.Running = true
    
    print("[FAF] 🎣 Auto Bait Placer STARTED")
    if CONFIG.BypassPlacementCheck then
        print("[FAF] ⚡ Bypass mode ENABLED - Will try multiple positions")
    end
    
    -- Initial diagnostic
    local pond = AutoPlacer.GetPlayerPond()
    local water = AutoPlacer.GetWaterSurface()
    local baits = AutoPlacer.GetBaitFromInventory()
    print("[FAF] 📊 Diagnostic: Pond=" .. (pond and pond.Name or "NONE") .. 
          ", Water=" .. (water and water.Name or "NONE") .. 
          ", Baits found=" .. #baits)
    
    if #baits > 0 then
        for i, b in ipairs(baits) do
            print("[FAF]   Bait #" .. i .. ": " .. b.name .. " (toolId: " .. tostring(b.toolId) .. ")")
        end
    end
    
    task.spawn(function()
        while AutoPlacer.Running and CONFIG.AutoPlaceBait do
            local baits = AutoPlacer.GetBaitFromInventory()
            
            if #baits > 0 then
                for _, baitInfo in ipairs(baits) do
                    if not AutoPlacer.Running then break end
                    
                    -- Get next position
                    local position = AutoPlacer.GetNextPosition()
                    
                    if position then
                        -- Equip the bait first
                        AutoPlacer.EquipBait(baitInfo)
                        
                        -- Try to place with bypass
                        local success = AutoPlacer.PlaceBaitWithBypass(baitInfo.toolId, position)
                        if not success then
                            print("[FAF] ⚠️ Failed to place bait at position:", position)
                        end
                    else
                        print("[FAF] ⚠️ Could not get placement position (no pond/water found)")
                    end
                    
                    task.wait(CONFIG.PlaceBaitInterval)
                end
            else
                -- Always print this on first run so user knows
                print("[FAF] ⚠️ No bait in inventory to place")
            end
            
            task.wait(CONFIG.PlaceBaitInterval * 10) -- Wait longer between full checks
        end
    end)
end

function AutoPlacer.Stop()
    AutoPlacer.Running = false
    print("[FAF] 🎣 Auto Bait Placer STOPPED")
end

-- Reset placement grid (useful if pond changes)
function AutoPlacer.ResetGrid()
    AutoPlacer.CurrentGridIndex = 0
    AutoPlacer.PlacedPositions = {}
    print("[FAF] Grid reset!")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- AUTO OPEN BAIT PACKS
-- ═══════════════════════════════════════════════════════════════════════════

local BaitPackOpener = {}
BaitPackOpener.Running = false
BaitPackOpener.PacksOpened = 0

-- Get bait packs from inventory
function BaitPackOpener.GetBaitPacks()
    local packs = {}
    
    pcall(function()
        local rbxts = ReplicatedStorage:FindFirstChild("rbxts_include")
        if rbxts then
            local runtimeLib = rbxts:FindFirstChild("RuntimeLib")
            if runtimeLib then
                local runtime = require(runtimeLib)
                if runtime and runtime.import then
                    local playerDataModule = runtime.import(nil, ReplicatedStorage, "TS", "state", "player-data")
                    if playerDataModule then
                        local getPlayerDataById = playerDataModule.getPlayerDataById
                        if getPlayerDataById then
                            local data = getPlayerDataById(tostring(LocalPlayer.UserId))
                            if data and data.inventory and data.inventory.baitPacks then
                                for packId, packData in pairs(data.inventory.baitPacks) do
                                    table.insert(packs, {
                                        packId = packId,
                                        packType = packData.packType or packData.baitPackType,
                                        amount = packData.amount or 1,
                                        mutation = packData.mutation
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    
    return packs
end

-- Open a bait pack
function BaitPackOpener.OpenPack(packId)
    if not packId then return false end
    
    -- Use store.openBaitPack remote
    local success = FireRemoRemote("store.openBaitPack", packId)
    
    if not success then
        success = FireRemote("store", "openBaitPack", packId)
    end
    
    if success ~= false then
        BaitPackOpener.PacksOpened = BaitPackOpener.PacksOpened + 1
        if CONFIG.ShowNotifications then
            print("[FAF] 📦 Opened bait pack:", packId)
        end
        return true
    end
    
    return false
end

-- Open all bait packs
function BaitPackOpener.OpenAllPacks()
    local packs = BaitPackOpener.GetBaitPacks()
    local opened = 0
    
    for _, pack in ipairs(packs) do
        -- Open each pack multiple times based on amount
        for i = 1, (pack.amount or 1) do
            if BaitPackOpener.OpenPack(pack.packId) then
                opened = opened + 1
            end
            task.wait(0.3) -- Small delay between opens
        end
    end
    
    if opened > 0 and CONFIG.ShowNotifications then
        print("[FAF] 📦 Opened " .. opened .. " bait packs total!")
    end
    
    return opened
end

function BaitPackOpener.Start()
    if BaitPackOpener.Running then return end
    BaitPackOpener.Running = true
    
    print("[FAF] 📦 Auto Bait Pack Opener STARTED")
    
    task.spawn(function()
        while BaitPackOpener.Running and CONFIG.AutoOpenBaitPacks do
            local packs = BaitPackOpener.GetBaitPacks()
            if #packs > 0 then
                BaitPackOpener.OpenAllPacks()
            end
            task.wait(5) -- Check every 5 seconds
        end
    end)
end

function BaitPackOpener.Stop()
    BaitPackOpener.Running = false
    print("[FAF] 📦 Auto Bait Pack Opener STOPPED")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SMART BAIT MANAGEMENT
-- ═══════════════════════════════════════════════════════════════════════════

local SmartBaitManager = {}
SmartBaitManager.Running = false
SmartBaitManager.BaitsRemoved = 0
SmartBaitManager.BaitsOptimized = 0

-- Get placed baits in pond with their tier info
function SmartBaitManager.GetPlacedBaits()
    local placedBaits = {}
    
    pcall(function()
        local rbxts = ReplicatedStorage:FindFirstChild("rbxts_include")
        if rbxts then
            local runtimeLib = rbxts:FindFirstChild("RuntimeLib")
            if runtimeLib then
                local runtime = require(runtimeLib)
                if runtime and runtime.import then
                    local playerDataModule = runtime.import(nil, ReplicatedStorage, "TS", "state", "player-data")
                    if playerDataModule then
                        local getPlayerDataById = playerDataModule.getPlayerDataById
                        if getPlayerDataById then
                            local data = getPlayerDataById(tostring(LocalPlayer.UserId))
                            if data and data.ponds then
                                for pondName, pondData in pairs(data.ponds) do
                                    if pondData.baits then
                                        for baitId, baitData in pairs(pondData.baits) do
                                            local baitType = baitData.baitType or "Unknown"
                                            table.insert(placedBaits, {
                                                baitId = baitId,
                                                baitType = baitType,
                                                tier = GetBaitTier(baitType),
                                                pondName = pondName,
                                                position = baitData.position,
                                                buildingId = baitData.buildingId or baitId
                                            })
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    
    -- Sort by tier (lowest first - these are candidates for removal)
    table.sort(placedBaits, function(a, b)
        return a.tier < b.tier
    end)
    
    return placedBaits
end

-- Get unplaced baits in inventory
function SmartBaitManager.GetInventoryBaits()
    local baits = {}
    
    pcall(function()
        local rbxts = ReplicatedStorage:FindFirstChild("rbxts_include")
        if rbxts then
            local runtimeLib = rbxts:FindFirstChild("RuntimeLib")
            if runtimeLib then
                local runtime = require(runtimeLib)
                if runtime and runtime.import then
                    local playerDataModule = runtime.import(nil, ReplicatedStorage, "TS", "state", "player-data")
                    if playerDataModule then
                        local getPlayerDataById = playerDataModule.getPlayerDataById
                        if getPlayerDataById then
                            local data = getPlayerDataById(tostring(LocalPlayer.UserId))
                            if data and data.inventory and data.inventory.baits then
                                for baitId, baitData in pairs(data.inventory.baits) do
                                    local baitType = baitData.baitType or "Unknown"
                                    table.insert(baits, {
                                        baitId = baitId,
                                        baitType = baitType,
                                        tier = GetBaitTier(baitType),
                                        amount = baitData.amount or 1,
                                        mutation = baitData.mutation
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    
    -- Sort by tier (highest first - best baits first)
    table.sort(baits, function(a, b)
        return a.tier > b.tier
    end)
    
    return baits
end

-- Delete a placed bait/building
function SmartBaitManager.DeleteBait(buildingId)
    if not buildingId then return false end
    
    -- Use ponds.deleteBuilding remote
    local success = FireRemoRemote("ponds.deleteBuilding", buildingId)
    
    if not success then
        success = FireRemote("ponds", "deleteBuilding", buildingId)
    end
    
    if success ~= false then
        SmartBaitManager.BaitsRemoved = SmartBaitManager.BaitsRemoved + 1
        if CONFIG.ShowNotifications then
            print("[FAF] 🗑️ Removed bait building:", buildingId)
        end
        return true
    end
    
    return false
end

-- Check if we should replace a placed bait with a better one
function SmartBaitManager.OptimizeBaits()
    local placedBaits = SmartBaitManager.GetPlacedBaits()
    local inventoryBaits = SmartBaitManager.GetInventoryBaits()
    
    if #inventoryBaits == 0 then
        if CONFIG.DebugMode then
            print("[FAF] No baits in inventory to optimize with")
        end
        return 0
    end
    
    local optimized = 0
    
    -- Check each inventory bait against placed baits
    for _, invBait in ipairs(inventoryBaits) do
        -- Find the worst placed bait
        local worstPlaced = placedBaits[1]
        
        if worstPlaced and invBait.tier > worstPlaced.tier then
            -- We have a better bait! Remove the worse one
            if CONFIG.ShowNotifications then
                print(string.format("[FAF] 🔄 Replacing %s (tier %d) with %s (tier %d)", 
                    worstPlaced.baitType, worstPlaced.tier,
                    invBait.baitType, invBait.tier))
            end
            
            if SmartBaitManager.DeleteBait(worstPlaced.buildingId) then
                task.wait(0.5) -- Wait for deletion to process
                
                -- Now place the better bait
                -- AutoPlacer will pick it up on next cycle
                optimized = optimized + 1
                table.remove(placedBaits, 1) -- Remove from our tracking
            end
        end
    end
    
    SmartBaitManager.BaitsOptimized = SmartBaitManager.BaitsOptimized + optimized
    return optimized
end

function SmartBaitManager.Start()
    if SmartBaitManager.Running then return end
    SmartBaitManager.Running = true
    
    print("[FAF] 🧠 Smart Bait Manager STARTED - Will optimize bait placement")
    
    task.spawn(function()
        while SmartBaitManager.Running and CONFIG.SmartBaitManagement do
            SmartBaitManager.OptimizeBaits()
            task.wait(10) -- Check every 10 seconds
        end
    end)
end

function SmartBaitManager.Stop()
    SmartBaitManager.Running = false
    print("[FAF] 🧠 Smart Bait Manager STOPPED")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SIMPLE GUI
-- ═══════════════════════════════════════════════════════════════════════════

local function CreateGUI()
    -- Clean up existing GUI
    local existingGui = PlayerGui:FindFirstChild("FAF_AutoFarm")
    if existingGui then existingGui:Destroy() end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "FAF_AutoFarm"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = PlayerGui
    
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 220, 0, 780)
    MainFrame.Position = UDim2.new(0, 10, 0.5, -390)
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 8)
    UICorner.Parent = MainFrame
    
    -- Title
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 35)
    Title.BackgroundColor3 = Color3.fromRGB(40, 120, 200)
    Title.BorderSizePixel = 0
    Title.Text = "ZenX Studio                    V-2.6"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 14
    Title.Font = Enum.Font.GothamBold
    Title.Parent = MainFrame
    
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 8)
    TitleCorner.Parent = Title
    
    -- Button template with initial state support
    local function CreateToggleButton(name, yPos, callback, color, initialState)
        local Button = Instance.new("TextButton")
        Button.Name = name
        Button.Size = UDim2.new(0.9, 0, 0, 28)
        Button.Position = UDim2.new(0.05, 0, 0, yPos)
        Button.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        Button.BorderSizePixel = 0
        Button.Text = "▶ " .. name
        Button.TextColor3 = Color3.fromRGB(200, 200, 200)
        Button.TextSize = 12
        Button.Font = Enum.Font.Gotham
        Button.Parent = MainFrame
        
        local BtnCorner = Instance.new("UICorner")
        BtnCorner.CornerRadius = UDim.new(0, 6)
        BtnCorner.Parent = Button
        
        local activeColor = color or Color3.fromRGB(40, 160, 80)
        local enabled = initialState or false
        
        -- Set initial visual state
        if enabled then
            Button.BackgroundColor3 = activeColor
            Button.Text = "■ " .. name
            -- Fire callback to start the module
            task.defer(function()
                callback(true)
            end)
        end
        
        Button.MouseButton1Click:Connect(function()
            enabled = not enabled
            if enabled then
                Button.BackgroundColor3 = activeColor
                Button.Text = "■ " .. name
            else
                Button.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
                Button.Text = "▶ " .. name
            end
            callback(enabled)
        end)
        
        return Button
    end
    
    -- Section: Fishing
    local section1 = Instance.new("TextLabel")
    section1.Size = UDim2.new(0.9, 0, 0, 18)
    section1.Position = UDim2.new(0.05, 0, 0, 40)
    section1.BackgroundTransparency = 1
    section1.Text = "── FISHING ──"
    section1.TextColor3 = Color3.fromRGB(100, 150, 255)
    section1.TextSize = 10
    section1.Font = Enum.Font.GothamBold
    section1.Parent = MainFrame
    
    -- Create buttons with state restoration
    CreateToggleButton("Auto Collect Fish", 60, function(enabled)
        if enabled then AutoCollector.Start() else AutoCollector.Stop() end
    end, nil, PreviousState.AutoCollector)
    
    CreateToggleButton("Auto Sell Fish", 92, function(enabled)
        if enabled then AutoSeller.Start() else AutoSeller.Stop() end
    end, nil, PreviousState.AutoSeller)
    
    -- Section: Bait
    local section2 = Instance.new("TextLabel")
    section2.Size = UDim2.new(0.9, 0, 0, 18)
    section2.Position = UDim2.new(0.05, 0, 0, 124)
    section2.BackgroundTransparency = 1
    section2.Text = "── BAIT ──"
    section2.TextColor3 = Color3.fromRGB(255, 180, 100)
    section2.TextSize = 10
    section2.Font = Enum.Font.GothamBold
    section2.Parent = MainFrame
    
    CreateToggleButton("Auto Buy Bait", 144, function(enabled)
        CONFIG.AutoBuyBait = enabled
        if enabled then AutoBuyer.Start() else AutoBuyer.Stop() end
    end, Color3.fromRGB(200, 140, 40), PreviousState.AutoBuyer)
    
    CreateToggleButton("Auto Place Bait", 176, function(enabled)
        CONFIG.AutoPlaceBait = enabled
        if enabled then AutoPlacer.Start() else AutoPlacer.Stop() end
    end, Color3.fromRGB(200, 100, 40), PreviousState.AutoPlacer)
    
    CreateToggleButton("Open Bait Packs", 208, function(enabled)
        CONFIG.AutoOpenBaitPacks = enabled
        if enabled then BaitPackOpener.Start() else BaitPackOpener.Stop() end
    end, Color3.fromRGB(180, 120, 60), PreviousState.BaitPackOpener)
    
    CreateToggleButton("Smart Bait Mgmt", 240, function(enabled)
        CONFIG.SmartBaitManagement = enabled
        if enabled then SmartBaitManager.Start() else SmartBaitManager.Stop() end
    end, Color3.fromRGB(160, 100, 80), PreviousState.SmartBaitManager)
    
    -- Section: Collection
    local section3 = Instance.new("TextLabel")
    section3.Size = UDim2.new(0.9, 0, 0, 18)
    section3.Position = UDim2.new(0.05, 0, 0, 272)
    section3.BackgroundTransparency = 1
    section3.Text = "── COLLECTION ──"
    section3.TextColor3 = Color3.fromRGB(100, 255, 150)
    section3.TextSize = 10
    section3.Font = Enum.Font.GothamBold
    section3.Parent = MainFrame
    
    CreateToggleButton("Auto Collect Crates", 292, function(enabled)
        if enabled then CrateCollector.Start() else CrateCollector.Stop() end
    end, Color3.fromRGB(80, 180, 80), PreviousState.CrateCollector)
    
    CreateToggleButton("Event Auto-Feed", 324, function(enabled)
        if enabled then EventFeeder.Start() else EventFeeder.Stop() end
    end, Color3.fromRGB(180, 80, 180), PreviousState.EventFeeder)
    
    -- Section: Protection
    local section4 = Instance.new("TextLabel")
    section4.Size = UDim2.new(0.9, 0, 0, 18)
    section4.Position = UDim2.new(0.05, 0, 0, 356)
    section4.BackgroundTransparency = 1
    section4.Text = "── PROTECTION ──"
    section4.TextColor3 = Color3.fromRGB(255, 80, 80)
    section4.TextSize = 10
    section4.Font = Enum.Font.GothamBold
    section4.Parent = MainFrame
    
    CreateToggleButton("Anti-Staff", 376, function(enabled)
        CONFIG.AntiStaff = enabled
        if enabled then AntiStaff.Start() else AntiStaff.Stop() end
    end, Color3.fromRGB(255, 60, 60), PreviousState.AntiStaff)
    
    CreateToggleButton("Anti-AFK", 408, function(enabled)
        CONFIG.AntiAFK = enabled
        if enabled then AntiAFK.Start() else AntiAFK.Stop() end
    end, Color3.fromRGB(255, 120, 60), PreviousState.AntiAFK)
    
    -- Section: Pets
    local section5 = Instance.new("TextLabel")
    section5.Size = UDim2.new(0.9, 0, 0, 18)
    section5.Position = UDim2.new(0.05, 0, 0, 440)
    section5.BackgroundTransparency = 1
    section5.Text = "── PETS ──"
    section5.TextColor3 = Color3.fromRGB(255, 150, 200)
    section5.TextSize = 10
    section5.Font = Enum.Font.GothamBold
    section5.Parent = MainFrame
    
    CreateToggleButton("Auto Feed Pets", 460, function(enabled)
        CONFIG.AutoFeedPets = enabled
        if enabled then AutoPetFeeder.Start() else AutoPetFeeder.Stop() end
    end, Color3.fromRGB(255, 120, 180), PreviousState.AutoPetFeeder)
    
    CreateToggleButton("Auto Best Pet", 492, function(enabled)
        CONFIG.AutoBestPet = enabled
        if enabled then AutoBestPet.Start() else AutoBestPet.Stop() end
    end, Color3.fromRGB(255, 180, 100), PreviousState.AutoBestPet)
    
    -- Section: Eggs & Gear
    local section6 = Instance.new("TextLabel")
    section6.Size = UDim2.new(0.9, 0, 0, 18)
    section6.Position = UDim2.new(0.05, 0, 0, 524)
    section6.BackgroundTransparency = 1
    section6.Text = "── EGGS & GEAR ──"
    section6.TextColor3 = Color3.fromRGB(180, 100, 255)
    section6.TextSize = 10
    section6.Font = Enum.Font.GothamBold
    section6.Parent = MainFrame
    
    CreateToggleButton("Auto Eggs", 544, function(enabled)
        CONFIG.AutoBuyEgg = enabled
        CONFIG.AutoPlaceEgg = enabled
        CONFIG.AutoHatchEgg = enabled
        if enabled then AutoEgg.Start() else AutoEgg.Stop() end
    end, Color3.fromRGB(180, 80, 255), PreviousState.AutoEgg)
    
    CreateToggleButton("Auto Use Gear", 576, function(enabled)
        CONFIG.AutoUseGear = enabled
        if enabled then AutoGear.Start() else AutoGear.Stop() end
    end, Color3.fromRGB(140, 60, 200), PreviousState.AutoGear)
    
    -- Stats label
    local Stats = Instance.new("TextLabel")
    Stats.Size = UDim2.new(0.9, 0, 0, 160)
    Stats.Position = UDim2.new(0.05, 0, 0, 608)
    Stats.BackgroundTransparency = 1
    Stats.Text = "Loading stats..."
    Stats.TextColor3 = Color3.fromRGB(150, 150, 150)
    Stats.TextSize = 9
    Stats.Font = Enum.Font.Gotham
    Stats.TextWrapped = true
    Stats.TextYAlignment = Enum.TextYAlignment.Top
    Stats.Parent = MainFrame
    
    -- Update stats
    task.spawn(function()
        while ScreenGui.Parent do
            local antiStaffStatus = AntiStaff.Running and "ON 🛡️" or "OFF"
            local antiAFKStatus = AntiAFK.Running and "ON ⏰" or "OFF"
            local afkIdleTime = AntiAFK.Running and math.floor(tick() - AntiAFK.LastInteraction) or 0
            local sessionTime = AntiAFK.Running and math.floor(tick() - AntiAFK.SessionStart) or 0
            
            Stats.Text = string.format(
                "📊 STATS\nFish: %d | Event Kept: %d 🛡️\nBait: %d bought | %d placed | Packs: %d\nCrates: %d | Pickups: %d | Optimized: %d\nPets Fed: %d | Swaps: %d\nEggs: %d hatched | Gear: %d used\nAnti-Staff: %s | Hops: %d\nAnti-AFK: %s | Session: %dm",
                AutoCollector.CollectedCount,
                AutoSeller.EventFishKept,
                AutoBuyer.BaitBought,
                AutoPlacer.BaitPlaced,
                BaitPackOpener.PacksOpened,
                CrateCollector.CratesCollected,
                CrateCollector.PickupsCollected,
                SmartBaitManager.BaitsOptimized,
                AutoPetFeeder.FedCount,
                AutoBestPet.SwapsCount,
                AutoEgg.EggsHatched,
                AutoGear.GearsUsed,
                antiStaffStatus,
                AntiStaff.HopsCount,
                antiAFKStatus,
                math.floor(sessionTime / 60)
            )
            task.wait(1)
        end
    end)
    
    -- Make draggable
    local dragging, dragStart, startPos
    
    Title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end)
    
    Title.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    print("[FAF] GUI Created!")
    return ScreenGui
end

-- ═══════════════════════════════════════════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════════════════════════════════════════

print([[
═══════════════════════════════════════════════════════════════════════════
🐟 Farm a Fish - Ultimate AutoFarm Script v2.4
═══════════════════════════════════════════════════════════════════════════
Loaded successfully! Use the GUI to toggle features.

NEW IN v2.4:
✓ NEW: Auto Open Bait Packs - Opens bait packs from inventory automatically
✓ NEW: Smart Bait Management - Replaces worse placed baits with better ones
✓ IMPROVED: Stats display shows new bait management metrics

NEW IN v2.3:
✓ FIXED: Auto Collect Fish - Now properly iterates through ALL placed nets
✓ NEW: Auto Feed Pets - Automatically feeds fish to your pets
✓ NEW: Auto Best Pet - Swaps bad pets for better ones based on perks

EXISTING FEATURES:
✓ Auto Buy Bait - Automatically purchases bait from shop
✓ Auto Place Bait - Places bait with bypass attempts
✓ SMART SELLING - Keeps event fish with mutations for NPCs!
✓ ANTI-STAFF - Auto server hop when admin/mod joins + restores settings!

Event Fish Protection (KeepEventFish = true):
🎅 Santa - Keeps fish with Christmas mutation
👽 Alien UFO - Keeps fish with Alien mutation  
🧝 Elf - Keeps fish caught with Christmas bait
🤖 Robot - Keeps fish caught with Robot bait

Bait Features:
📦 Auto Open Bait Packs - Opens bait packs automatically
🧠 Smart Bait Management - Compares tier of placed vs inventory baits

Pet Features:
🐾 Auto Feed Pets - Feeds non-event fish to your equipped pets (weight filter!)
🏆 Auto Best Pet - Scores pets by perks, swaps to better ones

Commands:
- FAF.CONFIG.PreferredBait = "Shark" - Change bait type
- FAF.CONFIG.MaxBaitInInventory = 20 - Change max bait
- FAF.CONFIG.BypassPlacementCheck = true/false - Toggle bypass
- FAF.CONFIG.KeepEventFish = false - Disable smart selling (sell ALL)
- FAF.CONFIG.AntiStaff = true/false - Toggle anti-staff protection
- FAF.CONFIG.FeedPetsInterval = 5 - Pet feeding interval
- FAF.CONFIG.MaxFeedWeight = 10 - Max fish weight (kg) to feed pets
- FAF.CONFIG.BestPetInterval = 30 - Best pet check interval
- FAF.BaitPackOpener.OpenAllPacks() - Open all bait packs now
- FAF.SmartBaitManager.OptimizeBaits() - Optimize bait placement now
- FAF.AutoPlacer.ResetGrid() - Reset placement positions
- FAF.FishValueCalculator.PrintValueTable() - Show fish values

Available Baits:
Starter, Novice, Reef, DeepSea, Koi, River, Puffer, Seal,
Glo, Ray, Octopus, Axolotl, Jelly, Whale, Shark

═══════════════════════════════════════════════════════════════════════════
]])

-- Initialize
FindRemotes()
CreateGUI()

-- Make accessible globally
getgenv().FAF = {
    CONFIG = CONFIG,
    AutoCollector = AutoCollector,
    AutoSeller = AutoSeller,
    AutoBuyer = AutoBuyer,
    AutoPlacer = AutoPlacer,
    CrateCollector = CrateCollector,
    EventFeeder = EventFeeder,
    AntiStaff = AntiStaff,
    AntiAFK = AntiAFK,
    FishValueCalculator = FishValueCalculator,
    BaitData = BaitData,
    Remotes = Remotes,
    -- Pet modules
    AutoPetFeeder = AutoPetFeeder,
    AutoBestPet = AutoBestPet,
    -- Bait modules
    BaitPackOpener = BaitPackOpener,
    SmartBaitManager = SmartBaitManager,
    GetBaitTier = GetBaitTier,
    -- Egg & Gear modules
    AutoEgg = AutoEgg,
    AutoGear = AutoGear,
}

return getgenv().FAF

--w a
