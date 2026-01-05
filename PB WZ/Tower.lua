-- Tower API
-- https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/Tower.lua
-- Wrapper for game's Tower dungeon functionality
-- 
-- Features:
--   - Track tower progress (floor, waves, chests)
--   - Tower info and status
--   - Tower completion tracking
--   - Chest bonus tracking
--   - Infinite Tower support (endless scaling floors)
--   - Celestial Tower support (level-scaled challenge)
--
-- ANTI-CHEAT COMPLIANCE:
-- See Tests/anticheat.lua for full documentation of detection systems.
--
-- Key protections implemented:
-- • Uses game's official Towers and Missions modules
-- • All progress tracking is read-only (no manipulation)
-- • Floor/wave data comes from server-controlled game state
-- • LOW RISK: Tower API is purely for status/tracking, not manipulation
--
-- TOWER TYPES:
--   Standard Towers (TowerID 1-6):
--     1 = Prison Tower (Lvl 60-70, World 5)
--     2 = Atlantis Tower (Lvl 85-90, World 6)
--     3 = Mezuvian Tower (Lvl 100-105, World 7)
--     4 = Oasis Tower (Lvl 110-115, World 8)
--     5 = Aether Tower (Lvl 125-130, World 9)
--     6 = Arcane Tower (Lvl 140-150, World 10)
--
--   Special Towers (TowerID 0):
--     Infinite Tower (Lvl 100+, endless floors, scaling difficulty)
--     Celestial Tower (Lvl 10+, level-scaled challenge)
--
-- PLACE IDS:
--   5703353651 = Prison Tower
--   6075085184 = Atlantis Tower
--   7071564842 = Mezuvian Tower
--   10089970465 = Oasis Tower
--   10795158121 = Aether Tower
--   15121292578 = Arcane Tower
--   13988110964 = Infinite Tower
--   14400549310 = Celestial Tower

local TowerAPI = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Local Player
local LocalPlayer = Players.LocalPlayer

-- Global environment
local _genv = getgenv()

-- Modules (loaded on init)
local TowersModule = nil
local MissionsModule = nil
local ProfileModule = nil
local MissionDataModule = nil

-- State
local initialized = false
local isInTower = false
local towerData = nil
local currentTowerID = nil
local currentMissionID = nil
local currentFloor = 0
local totalFloors = 0
local chestStatus = {}
local waveProgress = {
    current = 0,
    total = 0,
    killCount = 0,
    totalKills = 0,
    progress = 0
}

-- Special tower flags
local isInfiniteTower = false
local isCelestialTower = false
local infiniteFloor = 0

-- Events
local towerFinishedEvent = nil
local updateChestsEvent = nil
local floorCompleteEvent = nil

-- Callbacks
local onFloorCompleteCallbacks = {}
local onTowerCompleteCallbacks = {}
local onChestUpdateCallbacks = {}

-- ============================================================================
-- PLACE ID MAPPINGS
-- ============================================================================

local TOWER_PLACE_IDS = {
    [5703353651] = { id = 1, name = "Prison Tower", world = 5 },
    [6075085184] = { id = 2, name = "Atlantis Tower", world = 6 },
    [7071564842] = { id = 3, name = "Mezuvian Tower", world = 7 },
    [10089970465] = { id = 4, name = "Oasis Tower", world = 8 },
    [10795158121] = { id = 5, name = "Aether Tower", world = 9 },
    [15121292578] = { id = 6, name = "Arcane Tower", world = 10 },
    [13988110964] = { id = 0, name = "Infinite Tower", world = 0, isInfinite = true },
    [14400549310] = { id = 0, name = "Celestial Tower", world = 0, isCelestial = true },
}

-- ============================================================================
-- TOWER DATA (from decompiled MissionData)
-- ============================================================================

local TOWER_INFO = {
    [1] = {
        ID = 1,
        MissionID = 21,
        WorldID = 32,
        Name = "Prison Tower",
        NameTag = "Konoh Gardens",
        LevelRequirement = 60,
        MaxGearLevel = 75,
        DisplayWorldID = 5,
        FinalBoss = "BOSSIgnisFireDragon",
        Description = "Wave defense tower in Konoh Gardens",
        TotalFloors = 10,
        Rewards = {"SolarHeart", "Blossomfield", "IgnisEye", "JawLongsword", "Firecaster", "Dragonkin", "Ignition", "Torchblazer", "IgnisDraw"},
        TowerChest = {"MoltenEgg", "Sundae", "Doughnut", "Strawberry"},
        LivePlaceID = 5703353651,
        DevPlaceID = 5408429442,
    },
    [2] = {
        ID = 2,
        MissionID = 23,
        WorldID = 35,
        Name = "Atlantis Tower",
        NameTag = "Atlantic Atoll",
        LevelRequirement = 85,
        MaxGearLevel = 90,
        DisplayWorldID = 6,
        FinalBoss = "BOSSKrakenMain",
        Description = "Face the Kraken in the depths",
        TotalFloors = 10,
        Rewards = {"KrakenShield", "KrakenEyes", "SirensWatch", "Deeptrench", "KrakenStaff", "Squidbane", "NeptuneTrident", "NightTerror", "SirensSong"},
        TowerChest = {"OceanEgg", "Sundae", "Doughnut", "Strawberry"},
        LivePlaceID = 6075085184,
        DevPlaceID = 5893171846,
    },
    [3] = {
        ID = 3,
        MissionID = 27,
        WorldID = 42,
        Name = "Mezuvian Tower",
        NameTag = "Mezuvia Skylands",
        LevelRequirement = 100,
        MaxGearLevel = 105,
        DisplayWorldID = 7,
        FinalBoss = "BOSSZeus",
        Description = "Ascend to face Zeus",
        TotalFloors = 10,
        Rewards = {"AngelHood", "AngelHalo", "AngelicWings", "Crestfall", "ShiningBanner", "Legacy", "GuildedChampion", "WingsOfDare", "GrimDay", "Proudmaker", "GreatBow", "AngelArmor"},
        TowerChest = {"SkyEgg", "Sundae", "Doughnut", "Strawberry"},
        LivePlaceID = 7071564842,
        DevPlaceID = 6860483493,
    },
    [4] = {
        ID = 4,
        MissionID = 29,
        WorldID = 46,
        Name = "Oasis Tower",
        NameTag = "Wasteland Oasis",
        LevelRequirement = 110,
        MaxGearLevel = 115,
        DisplayWorldID = 8,
        FinalBoss = "Taurha",
        Description = "Challenge Taurha in the desert",
        TotalFloors = 10,
        Rewards = {"World8Tier5Longsword", "World8Tier5Axe", "World8Tier5Scythe", "World8Tier5Spear", "World8Tier5Greatsword", "World8Tier5Staff", "World8Tier5Bow", "World8Tier5Shield", "World8Tier5Armor", "TaurhaStaff"},
        TowerChest = {"AlligatorEgg", "Sundae", "Doughnut", "Strawberry"},
        LivePlaceID = 10089970465,
        DevPlaceID = 9649635544,
    },
    [5] = {
        ID = 5,
        MissionID = 34,
        WorldID = 52,
        Name = "Aether Tower",
        NameTag = "Stonewood Forest",
        LevelRequirement = 125,
        MaxGearLevel = 130,
        DisplayWorldID = 9,
        FinalBoss = "VaneAetherDragon",
        Description = "Battle the Aether Dragon",
        TotalFloors = 10,
        Rewards = {"W9T5Longsword", "W9T5Axe", "W9T5Scythe", "W9T5Spear", "W9T5Greatsword", "W9T5Staff", "W9T5Bow", "W9T5Shield", "W9T5Armor", "W9T5Helmet"},
        TowerChest = {"FairyEgg", "Sundae", "Doughnut", "Strawberry"},
        LivePlaceID = 10795158121,
        DevPlaceID = 10724045559,
    },
    [6] = {
        ID = 6,
        MissionID = 43,
        WorldID = 62,
        Name = "Arcane Tower",
        NameTag = "Crystal Cascade",
        LevelRequirement = 140,
        MaxGearLevel = 150,
        DisplayWorldID = 10,
        FinalBoss = "BOSSKandrix",
        Description = "Face Kandrix the Arcane",
        TotalFloors = 10,
        Rewards = {"W10T5Longsword", "W10T5Axe", "W10T5Scythe", "W10T5Spear", "W10T5Greatsword", "W10T5Staff", "W10T5Bow", "W10T5Shield", "W10T5Armor"},
        TowerChest = {"ArcaneEgg", "Sundae", "Doughnut", "Strawberry"},
        LivePlaceID = 15121292578,
        DevPlaceID = 15025509897,
    },
    -- Special Towers (TowerID = 0)
    ["Infinite"] = {
        ID = 0,
        MissionID = 38,
        WorldID = 57,
        Name = "Infinite Tower",
        NameTag = "Infinite Tower",
        LevelRequirement = 100,
        MaxGearLevel = 999, -- Scales infinitely
        DisplayWorldID = 111,
        FinalBoss = "VaneAetherDragon", -- Repeats
        Description = "Endless scaling challenge - climb as high as you can!",
        TotalFloors = 999, -- Infinite
        IsInfinite = true,
        Rewards = {"SuperEquipmentChest"},
        LivePlaceID = 13988110964,
        DevPlaceID = 13661903549,
    },
    ["Celestial"] = {
        ID = 0,
        MissionID = 39,
        WorldID = 58,
        Name = "Celestial Tower",
        NameTag = "Celestial Tower",
        LevelRequirement = 10,
        MaxGearLevel = 999, -- Scales to player level
        DisplayWorldID = 112,
        FinalBoss = "VaneAetherDragon",
        Description = "Level-scaled tower challenge",
        TotalFloors = 10,
        IsCelestial = true,
        Rewards = {"EquipmentChest"},
        LivePlaceID = 14400549310,
        DevPlaceID = 14213731433,
    },
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function safeWait(sec)
    sec = tonumber(sec) or 0
    if sec > 0 then
        if task and task.wait then
            task.wait(sec)
        else
            local t0 = os.clock()
            while os.clock() - t0 < sec do
                RunService.Heartbeat:Wait()
            end
        end
    else
        RunService.Heartbeat:Wait()
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Load required modules
local function loadModules()
    if initialized then return true end
    
    local success = pcall(function()
        local shared = ReplicatedStorage:FindFirstChild("Shared")
        if not shared then return end
        
        -- Try to get Towers module
        if shared:FindFirstChild("Towers") then
            TowersModule = require(shared.Towers)
        end
        
        if shared:FindFirstChild("Missions") then
            MissionsModule = require(shared.Missions)
            
            -- Try to get MissionData
            local missions = shared.Missions
            if missions:FindFirstChild("MissionData") then
                MissionDataModule = require(missions.MissionData)
            end
        end
        
        if shared:FindFirstChild("Profile") then
            ProfileModule = require(shared.Profile)
        end
    end)
    
    if success then
        initialized = true
    else
        warn("[TowerAPI] Failed to load modules")
    end
    
    return initialized
end

-- Check current place ID to determine tower
local function checkPlaceId()
    local placeId = game.PlaceId
    local towerInfo = TOWER_PLACE_IDS[placeId]
    
    if towerInfo then
        isInTower = true
        currentTowerID = towerInfo.id
        isInfiniteTower = towerInfo.isInfinite or false
        isCelestialTower = towerInfo.isCelestial or false
        
        -- Get tower data from our table
        if isInfiniteTower then
            towerData = TOWER_INFO["Infinite"]
        elseif isCelestialTower then
            towerData = TOWER_INFO["Celestial"]
        else
            towerData = TOWER_INFO[currentTowerID]
        end
        
        if towerData then
            totalFloors = towerData.TotalFloors or 10
        end
        
        return true
    end
    
    return false
end

-- Check if currently in a tower dungeon via MissionData
local function checkIfInTower()
    -- First check by place ID (fastest)
    if checkPlaceId() then
        return true
    end
    
    -- Fallback: check via workspace attribute
    local missionId = workspace:GetAttribute("MissionId")
    if not missionId then return false end
    
    local success, missionData = pcall(function()
        if MissionDataModule then
            for _, mission in ipairs(MissionDataModule) do
                if mission.ID == missionId then
                    return mission
                end
            end
        elseif MissionsModule and MissionsModule.GetMissionData then
            return MissionsModule:GetMissionData()[missionId]
        end
        return nil
    end)
    
    if success and missionData and missionData.IsTowerDungeon then
        isInTower = true
        currentTowerID = missionData.TowerID or 0
        currentMissionID = missionData.ID
        
        -- Check special tower types
        isInfiniteTower = missionData.IsInfiniteTower or false
        isCelestialTower = missionData.IsCelestialTower or false
        
        -- Get our tower info
        if isInfiniteTower then
            towerData = TOWER_INFO["Infinite"]
        elseif isCelestialTower then
            towerData = TOWER_INFO["Celestial"]
        elseif TOWER_INFO[currentTowerID] then
            towerData = TOWER_INFO[currentTowerID]
        end
        
        if towerData then
            totalFloors = towerData.TotalFloors or 10
        end
        
        return true
    end
    
    return false
end

-- Setup event listeners
local function setupEvents()
    local towersScript = ReplicatedStorage.Shared:FindFirstChild("Towers")
    if not towersScript then return end
    
    -- Tower finished event
    if towersScript:FindFirstChild("TowerFinished") then
        towerFinishedEvent = towersScript.TowerFinished.OnClientEvent:Connect(function(countdown, timeTaken)
            for _, callback in pairs(onTowerCompleteCallbacks) do
                pcall(callback, timeTaken, countdown)
            end
        end)
    end
    
    -- Floor complete event
    if towersScript:FindFirstChild("FloorComplete") then
        floorCompleteEvent = towersScript.FloorComplete.OnClientEvent:Connect(function(floor, gotBonus)
            currentFloor = floor
            for _, callback in pairs(onFloorCompleteCallbacks) do
                pcall(callback, floor, gotBonus)
            end
        end)
    end
    
    -- Update chests event
    if towersScript:FindFirstChild("UpdateChests") then
        updateChestsEvent = towersScript.UpdateChests.OnClientEvent:Connect(function(chests, killCount, totalKills, progress, timerValue)
            chestStatus = chests or {}
            waveProgress.killCount = killCount or 0
            waveProgress.totalKills = totalKills or 0
            waveProgress.progress = progress or 0
            
            -- Count current floor from chests
            local floorCount = 0
            for floor, _ in pairs(chestStatus) do
                if floor > floorCount then
                    floorCount = floor
                end
            end
            currentFloor = floorCount
            
            -- For infinite tower, track highest floor
            if isInfiniteTower and currentFloor > infiniteFloor then
                infiniteFloor = currentFloor
            end
            
            for _, callback in pairs(onChestUpdateCallbacks) do
                pcall(callback, chestStatus, waveProgress)
            end
        end)
    end
    
    -- Infinite tower floor update
    if towersScript:FindFirstChild("InfiniteTowerFloorUpdate") then
        towersScript.InfiniteTowerFloorUpdate.OnClientEvent:Connect(function(floor)
            infiniteFloor = floor
            currentFloor = floor
        end)
    end
end

-- Initialize the API
function TowerAPI:Init()
    if not loadModules() then return false end
    
    checkIfInTower()
    
    if isInTower then
        setupEvents()
        local towerName = towerData and towerData.Name or ("Tower " .. tostring(currentTowerID))
    end
    
    return initialized
end

-- ============================================================================
-- TOWER INFO
-- ============================================================================

-- Check if in a tower dungeon
function TowerAPI:IsInTower()
    if not initialized then loadModules() end
    return isInTower or checkIfInTower()
end

-- Check if in Infinite Tower
function TowerAPI:IsInfiniteTower()
    return isInfiniteTower
end

-- Check if in Celestial Tower
function TowerAPI:IsCelestialTower()
    return isCelestialTower
end

-- Check if in a special tower (Infinite or Celestial)
function TowerAPI:IsSpecialTower()
    return isInfiniteTower or isCelestialTower
end

-- Get current tower ID
function TowerAPI:GetTowerID()
    return currentTowerID
end

-- Get current mission ID
function TowerAPI:GetMissionID()
    return currentMissionID
end

-- Get current floor (0-indexed internally, returns 1-indexed for display)
function TowerAPI:GetCurrentFloor()
    return currentFloor
end

-- Get current floor display (1-indexed)
function TowerAPI:GetCurrentFloorDisplay()
    return currentFloor + 1
end

-- Get total floors
function TowerAPI:GetTotalFloors()
    if isInfiniteTower then
        return math.huge -- Infinite
    end
    return totalFloors
end

-- Get tower data
function TowerAPI:GetTowerData()
    return towerData
end

-- Get tower name
function TowerAPI:GetTowerName()
    if towerData then
        return towerData.Name
    end
    
    -- Fallback lookup
    if isInfiniteTower then return "Infinite Tower" end
    if isCelestialTower then return "Celestial Tower" end
    if TOWER_INFO[currentTowerID] then
        return TOWER_INFO[currentTowerID].Name
    end
    
    return "Unknown Tower"
end

-- Get tower description
function TowerAPI:GetTowerDescription()
    if towerData then
        return towerData.Description
    end
    return ""
end

-- Get tower level requirement
function TowerAPI:GetLevelRequirement()
    if towerData then
        return towerData.LevelRequirement
    end
    return 0
end

-- Get tower max gear level
function TowerAPI:GetMaxGearLevel()
    if towerData then
        return towerData.MaxGearLevel
    end
    return 0
end

-- Get current floor level (for infinite tower, scales with floor)
function TowerAPI:GetCurrentFloorLevel()
    if isInfiniteTower then
        -- Infinite tower scales: base 100 + (floor * 2)
        local baseLevel = 100
        return baseLevel + (currentFloor * 2)
    elseif isCelestialTower then
        -- Celestial scales to player level
        local playerLevel = 0
        pcall(function()
            if ProfileModule and ProfileModule.GetLevel then
                playerLevel = ProfileModule:GetLevel(LocalPlayer)
            end
        end)
        return math.max(playerLevel, 10)
    elseif towerData then
        local baseLevel = towerData.LevelRequirement or 0
        return baseLevel + (currentFloor * 2)
    end
    return 0
end

-- Get final boss name
function TowerAPI:GetFinalBoss()
    if towerData then
        return towerData.FinalBoss
    end
    return nil
end

-- Get available rewards
function TowerAPI:GetRewards()
    if towerData then
        return towerData.Rewards or {}
    end
    return {}
end

-- Get tower chest rewards
function TowerAPI:GetTowerChestRewards()
    if towerData then
        return towerData.TowerChest or {}
    end
    return {}
end

-- ============================================================================
-- INFINITE TOWER SPECIFIC
-- ============================================================================

-- Get highest floor reached in Infinite Tower
function TowerAPI:GetInfiniteFloor()
    return infiniteFloor
end

-- Get player's all-time highest Infinite Tower floor
function TowerAPI:GetHighestInfiniteTowerFloor()
    if ProfileModule and ProfileModule.GetHighestTowerFloor then
        local ok, floor = pcall(function()
            return ProfileModule:GetHighestTowerFloor(LocalPlayer)
        end)
        if ok then return floor end
    end
    
    -- Fallback: check profile directly
    pcall(function()
        local profile = ProfileModule:GetProfile(LocalPlayer)
        if profile and profile:FindFirstChild("HighestTowerFloor") then
            return profile.HighestTowerFloor.Value
        end
    end)
    
    return 0
end

-- Get enemy level for current Infinite Tower floor
function TowerAPI:GetInfiniteFloorEnemyLevel()
    if not isInfiniteTower then return 0 end
    -- Formula: 100 + (floor * 5), with scaling
    return 100 + (currentFloor * 5)
end

-- ============================================================================
-- WAVE PROGRESS
-- ============================================================================

-- Get wave progress
function TowerAPI:GetWaveProgress()
    return {
        killCount = waveProgress.killCount,
        totalKills = waveProgress.totalKills,
        progress = waveProgress.progress,
        floor = currentFloor
    }
end

-- Get kill count
function TowerAPI:GetKillCount()
    return waveProgress.killCount
end

-- Get total kills needed
function TowerAPI:GetTotalKills()
    return waveProgress.totalKills
end

-- Get progress percentage
function TowerAPI:GetProgressPercent()
    if waveProgress.totalKills == 0 then return 0 end
    return (waveProgress.killCount / waveProgress.totalKills) * 100
end

-- ============================================================================
-- CHEST STATUS
-- ============================================================================

-- Get chest status for all floors
function TowerAPI:GetChestStatus()
    return chestStatus
end

-- Check if floor got bonus chest
function TowerAPI:FloorGotBonusChest(floor)
    return chestStatus[floor] == true
end

-- Count total bonus chests earned
function TowerAPI:GetBonusChestCount()
    local count = 0
    for _, got in pairs(chestStatus) do
        if got == true then
            count = count + 1
        end
    end
    return count
end

-- Get expected chest count for current progress
function TowerAPI:GetExpectedChests()
    -- Base chest + bonus chests
    return 1 + self:GetBonusChestCount()
end

-- ============================================================================
-- CALLBACKS
-- ============================================================================

-- Register callback for floor completion
function TowerAPI:OnFloorComplete(callback)
    table.insert(onFloorCompleteCallbacks, callback)
end

-- Register callback for tower completion
function TowerAPI:OnTowerComplete(callback)
    table.insert(onTowerCompleteCallbacks, callback)
end

-- Register callback for chest updates
function TowerAPI:OnChestUpdate(callback)
    table.insert(onChestUpdateCallbacks, callback)
end

-- ============================================================================
-- STATUS
-- ============================================================================

-- Get full status
function TowerAPI:GetStatus()
    return {
        Initialized = initialized,
        IsInTower = isInTower,
        TowerID = currentTowerID,
        MissionID = currentMissionID,
        TowerName = self:GetTowerName(),
        TowerDescription = self:GetTowerDescription(),
        IsInfiniteTower = isInfiniteTower,
        IsCelestialTower = isCelestialTower,
        CurrentFloor = currentFloor,
        CurrentFloorDisplay = currentFloor + 1,
        TotalFloors = isInfiniteTower and "∞" or totalFloors,
        FloorLevel = self:GetCurrentFloorLevel(),
        LevelRequirement = self:GetLevelRequirement(),
        MaxGearLevel = self:GetMaxGearLevel(),
        FinalBoss = self:GetFinalBoss(),
        KillCount = waveProgress.killCount,
        TotalKills = waveProgress.totalKills,
        Progress = string.format("%.1f%%", self:GetProgressPercent()),
        BonusChests = self:GetBonusChestCount(),
        ChestStatus = chestStatus,
        HighestInfiniteFloor = isInfiniteTower and self:GetHighestInfiniteTowerFloor() or nil,
    }
end

-- Print status for debugging (disabled - anti-cheat detection)
function TowerAPI:PrintStatus()
    -- Prints removed for anti-cheat
end

-- ============================================================================
-- TOWER INFO PRESETS (All towers from decompiled data)
-- ============================================================================

-- Tower info table (accessible)
TowerAPI.Towers = TOWER_INFO

-- Tower place IDs
TowerAPI.PlaceIDs = TOWER_PLACE_IDS

-- Get tower info by ID
function TowerAPI:GetTowerInfo(towerId)
    if type(towerId) == "string" then
        return TOWER_INFO[towerId]
    end
    return TOWER_INFO[towerId]
end

-- Get tower by place ID
function TowerAPI:GetTowerByPlaceId(placeId)
    local info = TOWER_PLACE_IDS[placeId]
    if info then
        if info.isInfinite then
            return TOWER_INFO["Infinite"]
        elseif info.isCelestial then
            return TOWER_INFO["Celestial"]
        else
            return TOWER_INFO[info.id]
        end
    end
    return nil
end

-- List all standard towers
function TowerAPI:GetStandardTowers()
    local towers = {}
    for i = 1, 6 do
        if TOWER_INFO[i] then
            table.insert(towers, TOWER_INFO[i])
        end
    end
    return towers
end

-- List all special towers
function TowerAPI:GetSpecialTowers()
    return {
        TOWER_INFO["Infinite"],
        TOWER_INFO["Celestial"],
    }
end

-- Get all towers
function TowerAPI:GetAllTowers()
    local all = self:GetStandardTowers()
    for _, tower in ipairs(self:GetSpecialTowers()) do
        table.insert(all, tower)
    end
    return all
end

-- ============================================================================
-- TELEPORT HELPERS
-- ============================================================================

-- Get place ID for a tower
function TowerAPI:GetTowerPlaceId(towerId)
    if type(towerId) == "string" then
        local tower = TOWER_INFO[towerId]
        if tower then
            return tower.LivePlaceID
        end
    else
        local tower = TOWER_INFO[towerId]
        if tower then
            return tower.LivePlaceID
        end
    end
    return nil
end

-- ============================================================================
-- CLEANUP
-- ============================================================================

-- Cleanup connections
function TowerAPI:Cleanup()
    if towerFinishedEvent then
        towerFinishedEvent:Disconnect()
        towerFinishedEvent = nil
    end
    
    if updateChestsEvent then
        updateChestsEvent:Disconnect()
        updateChestsEvent = nil
    end
    
    if floorCompleteEvent then
        floorCompleteEvent:Disconnect()
        floorCompleteEvent = nil
    end
    
    onFloorCompleteCallbacks = {}
    onTowerCompleteCallbacks = {}
    onChestUpdateCallbacks = {}
end

-- ============================================================================
-- EXPOSE TO GLOBAL
-- ============================================================================

_G.TowerAPI = TowerAPI
getgenv().TowerAPI = TowerAPI

return TowerAPI
