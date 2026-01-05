-- ============================================================================
-- Auto Sell - Automated Item Selling System
-- ============================================================================
-- https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/autosell.lua
-- Automatically sells items based on rarity configuration using the correct
-- game remote: ReplicatedStorage.Shared.Drops.SellItems:InvokeServer(items)
--
-- FIXED: Now uses correct SellItems remote instead of non-existent DeleteItem
-- ADDED: Anti-detection features with timing variance and batch selling
--
-- API USAGE:
-- • AutoSellAPI.enable()    - Enable auto sell
-- • AutoSellAPI.disable()   - Disable auto sell
-- • AutoSellAPI.toggle()    - Toggle auto sell state
-- • AutoSellAPI.sellNow()   - Immediately sell items matching config
-- • AutoSellAPI.isEnabled() - Check if running
-- • AutoSellAPI.getStatus() - Get full status with module info
--
-- ANTI-DETECTION API:
-- • AutoSellAPI.setAntiDetection({...}) - Configure anti-detection settings
-- • AutoSellAPI.getAntiDetection()      - Get current anti-detection config
--
-- PERK GRADE SYSTEM:
-- • S+ = Perfect roll (max value)
-- • S  = Near-perfect roll
-- • A  = Good roll (80%+)
-- • B  = Decent roll (50%+)
-- • C  = Poor roll (below 50%)
--
-- LEGENDARY PERK FILTER:
-- • sellLegendaryIfNotPerk = true  - Sell Legendary items below perk threshold
-- • legendaryMinPerkGrade = "S"    - Keep items with S or S+ perks, sell rest
--
-- NOTE: Mythic (rarity 6) items are NEVER sold - they should be traded
--
-- ANTI-CHEAT COMPLIANCE:
-- See Tests/anticheat.lua for full documentation of detection systems.
--
-- Key protections implemented:
-- • Uses game's official Drops.SellItems remote (not raw/custom remotes)
-- • Anti-detection timing variance (0.3-0.8s between sells)
-- • Micro-pause chance (8%) to simulate human hesitation
-- • Batch variance prevents predictable sell patterns
-- • LOW RISK: Selling operations are not monitored by combat anti-cheat
-- ============================================================================

-- Services
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')

-- Global environment
local _genv = getgenv()

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

local function safeRequire(mod)
    if not mod then return nil end
    local ok, res = pcall(require, mod)
    return ok and res or nil
end

-- ============================================================================
-- RARITY SYSTEM
-- ============================================================================

-- NOTE: Mythic (rarity 6) is NEVER sold - it should be traded instead
local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

local RARITY_MAP = {
    Common = 1,
    Uncommon = 2,
    Rare = 3,
    Epic = 4,
    Legendary = 5,
    -- Mythic = 6 is intentionally excluded from selling
}

local RARITY_NAMES = {
    [1] = "Common",
    [2] = "Uncommon",
    [3] = "Rare",
    [4] = "Epic",
    [5] = "Legendary",
    [6] = "Mythic",  -- For display only, never sold
}

-- ============================================================================
-- PERK GRADE SYSTEM
-- ============================================================================

-- Perk grades from best to worst (used for Legendary filtering)
local PERK_GRADE_ORDER = { "S+", "S", "A", "B", "C" }

-- Numeric values for comparison (higher = better)
local PERK_GRADE_VALUE = {
    ["S+"] = 5,
    ["S"] = 4,
    ["A"] = 3,
    ["B"] = 2,
    ["C"] = 1,
}

-- Get numeric value for a perk grade (for comparison)
local function getPerkGradeValue(grade)
    return PERK_GRADE_VALUE[grade] or 0
end

-- ============================================================================
-- DEFAULT CONFIGURATION
-- ============================================================================

local DEFAULT_CONFIG = {
    enabled = false,
    sellThreshold = "Rare",       -- Sell items BELOW this rarity (max is Legendary, Mythic never sold)
    keepBestCount = 1,            -- Keep X best items of each type
    scanInterval = 15,            -- Seconds between inventory scans (replaces sellOnPickup)
    sellDelay = 0.5,              -- Delay between sells (anti-detection)
    sellInterval = 30,            -- Seconds between auto-sell cycles
    excludeEquipped = true,       -- Never sell equipped items
    excludeFavorites = true,      -- Never sell favorited items
    excludePets = true,           -- Never sell pets
    confirmLegendaryPlus = true,  -- Confirm before selling Legendary+ (with perk filter)
    MaxLevelToSell = 0,           -- Only sell items at or below this level (0 = disabled)
    MinLevelToKeep = 0,           -- Keep items at or above this level (0 = disabled)
    -- Legendary Perk Filtering
    sellLegendaryIfNotPerk = false, -- Enable selling Legendary items with bad perks
    legendaryMinPerkGrade = "S",    -- Minimum perk grade to KEEP (S+, S, A, B, C)
}

-- ============================================================================
-- AUTO SELL MODULE
-- ============================================================================

local AutoSellAPI = {}

-- State
local isRunning = false
local loopConnection = nil

-- Cached modules (lazy loaded)
local ItemsModule = nil
local InventoryModule = nil
local ProfileModule = nil
local GearModule = nil
local GearPerksModule = nil
local DropsModule = nil
local SellItemsRemote = nil  -- The correct remote: ReplicatedStorage.Shared.Drops.SellItems

-- ============================================================================
-- ANTI-DETECTION CONFIGURATION
-- ============================================================================

local AntiDetection = {
    minSellDelay = 0.3,           -- Minimum delay between sells
    maxSellDelay = 0.8,           -- Maximum delay between sells (randomized)
    sellBatchVariance = 0.15,     -- Variance in batch timing
    jitterEnabled = true,         -- Enable timing jitter
    microPauseChance = 0.08,      -- Chance of micro-pause between actions
    microPauseMin = 0.1,          -- Minimum micro-pause duration
    microPauseMax = 0.4,          -- Maximum micro-pause duration
}

-- ============================================================================
-- CONFIGURATION HELPERS
-- ============================================================================

local function getConfig(key)
    -- First try to get from genv (set by settings API)
    local genvKey = "AutoSell_" .. key
    if _genv[genvKey] ~= nil then
        return _genv[genvKey]
    end
    -- Fall back to default
    return DEFAULT_CONFIG[key]
end

local function setConfig(key, value)
    _genv["AutoSell_" .. key] = value
end

local function getRarityIndex(rarity)
    return RARITY_MAP[rarity] or 1
end

local function getRarityName(index)
    return RARITY_NAMES[index] or "Common"
end

-- ============================================================================
-- MODULE LOADING
-- ============================================================================

local function loadModules()
    pcall(function()
        local shared = ReplicatedStorage:FindFirstChild('Shared')
        if not shared then return end
        
        -- Load Items module (ReplicatedStorage.Shared.Items)
        if not ItemsModule then
            local items = shared:FindFirstChild('Items')
            if items then
                ItemsModule = safeRequire(items)
            end
        end
        
        -- Load Inventory module (ReplicatedStorage.Shared.Inventory)
        if not InventoryModule then
            local inventory = shared:FindFirstChild('Inventory')
            if inventory then
                InventoryModule = safeRequire(inventory)
            end
        end
        
        -- Load Drops module and get SellItems remote (THIS IS THE KEY FIX!)
        -- Game uses ReplicatedStorage.Shared.Drops.SellItems:InvokeServer(items) to sell
        if not DropsModule then
            local drops = shared:FindFirstChild('Drops')
            if drops then
                DropsModule = safeRequire(drops)
                -- Get the SellItems RemoteFunction from Drops script
                SellItemsRemote = drops:FindFirstChild('SellItems')
            end
        end
        
        -- Load Profile module (ReplicatedStorage.Shared.Profile)
        if not ProfileModule then
            local profile = shared:FindFirstChild('Profile')
            if profile then
                ProfileModule = safeRequire(profile)
            end
        end
        
        -- Load Gear module (ReplicatedStorage.Shared.Gear) for perk system
        if not GearModule then
            local gear = shared:FindFirstChild('Gear')
            if gear then
                GearModule = safeRequire(gear)
                -- Load GearPerks submodule for perk data
                local gearPerks = gear:FindFirstChild('GearPerks')
                if gearPerks then
                    GearPerksModule = safeRequire(gearPerks)
                end
            end
        end
    end)
    
    return ItemsModule ~= nil and SellItemsRemote ~= nil
end

-- ============================================================================
-- PLAYER DATA ACCESS
-- ============================================================================

local function getPlayer()
    return Players.LocalPlayer
end

local function getPlayerProfile()
    local player = getPlayer()
    if not player then return nil end
    
    -- Use Profile module if available
    if ProfileModule and ProfileModule.GetProfile then
        local ok, profile = pcall(function()
            return ProfileModule:GetProfile(player)
        end)
        if ok and profile then
            return profile
        end
    end
    
    -- Fallback: Look in Profiles folder
    local profiles = ReplicatedStorage:FindFirstChild('Profiles')
    if profiles then
        return profiles:FindFirstChild(player.Name)
    end
    
    return nil
end

local function getInventoryFolder()
    local profile = getPlayerProfile()
    if not profile then return nil end
    
    local inventory = profile:FindFirstChild('Inventory')
    if not inventory then return nil end
    
    return inventory:FindFirstChild('Items')
end

local function getCosmeticsFolder()
    local profile = getPlayerProfile()
    if not profile then return nil end
    
    local inventory = profile:FindFirstChild('Inventory')
    if not inventory then return nil end
    
    return inventory:FindFirstChild('Cosmetics')
end

local function getPlayerEquips()
    local player = getPlayer()
    if not player then return nil end
    
    -- Use Profile module if available
    if ProfileModule and ProfileModule.GetPlayerEquips then
        local ok, equips = pcall(function()
            return ProfileModule:GetPlayerEquips(player)
        end)
        if ok and equips then
            return equips
        end
    end
    
    return nil
end

local function getEquippedItems()
    local equipped = {}
    local equips = getPlayerEquips()
    
    if equips then
        -- Check all equip slots
        for _, slot in ipairs(equips:GetChildren()) do
            local equippedItem = slot:FindFirstChildOfClass('Folder')
            if equippedItem then
                equipped[equippedItem] = true
            end
        end
    end
    
    return equipped
end

local function getFavoritedItems()
    local favorites = {}
    local profile = getPlayerProfile()
    if not profile then return favorites end
    
    -- Check for Locked folder on items (items with "Locked" child are protected)
    local inventory = profile:FindFirstChild('Inventory')
    if inventory then
        local items = inventory:FindFirstChild('Items')
        if items then
            for _, item in ipairs(items:GetChildren()) do
                if item:FindFirstChild('Locked') then
                    favorites[item] = true
                end
            end
        end
    end
    
    return favorites
end

-- ============================================================================
-- ITEM ANALYSIS
-- ============================================================================

local function getItemDefinitions()
    local defs = {}
    if not ItemsModule then
        loadModules()
    end
    if not ItemsModule then return defs end
    
    for name, data in pairs(ItemsModule) do
        if type(data) == 'table' and data.Type then
            -- Include sellable item types (Weapon, Armor, Rune)
            local itemType = data.Type
            if itemType == 'Weapon' or itemType == 'Armor' or itemType == 'Rune' then
                defs[name] = {
                    Name = name,
                    Type = itemType,
                    Rarity = data.Rarity or 1,
                    Level = data.Level or 1,
                }
            end
        end
    end
    
    return defs
end

local function getItemRarity(item, definitions)
    -- Use InventoryModule.GetItemTier if available (matches game logic)
    if InventoryModule and InventoryModule.GetItemTier then
        local ok, tier = pcall(function()
            return InventoryModule:GetItemTier(item)
        end)
        if ok and tier then
            return tier
        end
    end
    
    -- Fallback: Calculate tier based on game logic from decompiled Inventory
    local def = definitions and definitions[item.Name]
    if def then
        local itemType = def.Type
        if itemType == 'Weapon' or itemType == 'Armor' or itemType == 'Rune' then
            local rarity = def.Rarity or 1
            
            -- Check UpgradeLimit for rarity calculation (from game logic)
            local upgradeLimit = item:FindFirstChild('UpgradeLimit')
            if upgradeLimit and not def.Rarity then
                local tier = math.floor(upgradeLimit.Value / 2 - 1)
                rarity = math.max(0, tier) + 1
            end
            
            return math.floor(rarity)
        end
    end
    
    -- Check for UpgradeLimit directly on item
    local upgradeLimit = item:FindFirstChild('UpgradeLimit')
    if upgradeLimit then
        local tier = math.floor(upgradeLimit.Value / 2 - 1)
        return math.max(1, tier + 1)
    end
    
    return 1 -- Default to Common
end

local function getItemLevel(item)
    local levelValue = item:FindFirstChild('Level')
    if levelValue then
        return levelValue.Value or 1
    end
    
    -- Check item definition for base level
    if ItemsModule and ItemsModule[item.Name] then
        return ItemsModule[item.Name].Level or 1
    end
    
    return 1
end

local function getItemEmpower(item)
    local empowerValue = item:FindFirstChild('Empower')
    if empowerValue then
        return empowerValue.Value or 0
    end
    return 0
end

local function getItemScore(item)
    -- Calculate item "score" for keeping best items
    -- Higher score = better item (matches game logic for finding best weapons)
    local score = 0
    
    -- Base score from level + empower (matches game's FindBestFitWeapons logic)
    local level = getItemLevel(item)
    local empower = getItemEmpower(item)
    score = score + ((level + empower) * 10)
    
    -- Bonus from upgrades
    local upgrade = item:FindFirstChild('Upgrade')
    if upgrade then
        score = score + (upgrade.Value * 50)
    end
    
    -- Bonus from upgrade limit (indicates quality/tier)
    local upgradeLimit = item:FindFirstChild('UpgradeLimit')
    if upgradeLimit then
        score = score + (upgradeLimit.Value * 5)
    end
    
    return score
end

local function isItemLocked(item)
    -- Check if item has Locked child (from game logic: ItemIsLocked)
    return item:FindFirstChild('Locked') ~= nil
end

local function isItemUpgraded(item)
    -- Check if item has been upgraded (upgraded items can't be traded/sold easily)
    local upgrade = item:FindFirstChild('Upgrade')
    if upgrade and upgrade.Value > 0 then
        return true
    end
    return false
end

local function isItemCapped(item)
    -- Check if UpgradeLimit is 0 (capped items can't be traded)
    local upgradeLimit = item:FindFirstChild('UpgradeLimit')
    if upgradeLimit and upgradeLimit.Value == 0 then
        return true
    end
    return false
end

-- ============================================================================
-- PERK ANALYSIS FUNCTIONS
-- ============================================================================

--- Get all perks from an item (matches game's GetItemPerks logic)
--- @param item Instance The item to get perks from
--- @return table Array of {perkName, perkValue} for each perk slot (1-3)
local function getItemPerks(item)
    local perks = {}
    
    -- Use GearModule if available (matches game logic)
    if GearModule and GearModule.GetItemPerks then
        local ok, result = pcall(function()
            return GearModule:GetItemPerks(item)
        end)
        if ok and result then
            for i = 1, 3 do
                local perkData = result[i]
                if perkData and perkData[1] then
                    perks[i] = { name = perkData[1], value = perkData[2] }
                end
            end
            return perks
        end
    end
    
    -- Fallback: Read perks directly from item
    for i = 1, 3 do
        local perkVal = item:FindFirstChild("Perk" .. tostring(i))
        if perkVal then
            local perkName = perkVal.Value
            local perkValue = nil
            local valueChild = perkVal:FindFirstChild("PerkValue")
            if valueChild then
                perkValue = valueChild.Value
            end
            perks[i] = { name = perkName, value = perkValue }
        end
    end
    
    return perks
end

--- Get perk grade for a specific perk on an item
--- Uses game's GetPerkScore logic: calculates grade based on roll quality
--- @param itemName string The item's name (for looking up stat ranges)
--- @param perkName string The perk name
--- @param perkValue number The rolled perk value
--- @return string Grade ("S+", "S", "A", "B", "C") or nil if no value
local function getPerkGrade(itemName, perkName, perkValue)
    if not perkValue then
        return nil -- No value means no grade (boolean perks)
    end
    
    -- Use GearModule.GetPerkScore if available (matches game logic exactly)
    if GearModule and GearModule.GetPerkScore then
        local ok, grade = pcall(function()
            return GearModule:GetPerkScore(itemName, perkName, perkValue)
        end)
        if ok and grade then
            return grade
        end
    end
    
    -- Fallback: Get perk data and calculate grade manually
    local perkData = nil
    if GearModule and GearModule.GetPerkData then
        local ok, data = pcall(function()
            return GearModule:GetPerkData(perkName)
        end)
        if ok then
            perkData = data
        end
    elseif GearPerksModule and GearPerksModule[perkName] then
        perkData = GearPerksModule[perkName]
    end
    
    if not perkData then
        return "C" -- Unknown perk, assume worst grade
    end
    
    -- Get item type to find correct stat range
    local statRange = nil
    if ItemsModule and ItemsModule[itemName] then
        local itemDef = ItemsModule[itemName]
        local rangeKey = string.format("%sStatRange", itemDef.Type or "")
        statRange = perkData[rangeKey] or perkData.StatRange
    else
        statRange = perkData.StatRange
    end
    
    if not statRange then
        return "C" -- No stat range means we can't calculate
    end
    
    local minVal = statRange[1]
    local maxVal = statRange[2]
    local negativeActive = perkData.NegativeActive
    
    -- Normalize values for comparison
    local roundedMin = math.round(minVal * 100)
    local roundedMax = math.round(maxVal * 100)
    local roundedValue = math.round(perkValue * 100)
    
    -- Handle negative perks
    if roundedValue < 0 and negativeActive then
        roundedValue = -roundedValue
    end
    
    -- Check for S+ (max value)
    if roundedValue >= roundedMax then
        return "S+"
    end
    
    -- Check for S (near-max)
    local rangeSize = roundedMax - roundedMin
    local isLargeRange = rangeSize >= 15
    if isLargeRange then
        if roundedValue >= roundedMax - 2 then
            return "S"
        end
    else
        if roundedValue >= roundedMax - 1 then
            return "S"
        end
    end
    
    -- Calculate percentage for remaining grades
    local threshold = isLargeRange and (roundedMax - 2) or (roundedMax - 1)
    local ratio = (roundedValue - roundedMin) / (threshold - roundedMin)
    
    if ratio >= 0.8 then
        return "A"
    elseif ratio >= 0.5 then
        return "B"
    else
        return "C"
    end
end

--- Get the best perk grade from all perks on an item
--- @param item Instance The item to analyze
--- @return string Best grade found, or "C" if no perks
local function getBestPerkGrade(item)
    local perks = getItemPerks(item)
    local bestGrade = "C"
    local bestValue = 1 -- C = 1
    
    for _, perkInfo in pairs(perks) do
        if perkInfo and perkInfo.name and perkInfo.value then
            local grade = getPerkGrade(item.Name, perkInfo.name, perkInfo.value)
            if grade then
                local gradeValue = getPerkGradeValue(grade)
                if gradeValue > bestValue then
                    bestValue = gradeValue
                    bestGrade = grade
                end
            end
        end
    end
    
    return bestGrade
end

--- Check if item meets minimum perk grade requirement
--- @param item Instance The item to check
--- @param minGrade string Minimum grade to keep ("S+", "S", "A", "B", "C")
--- @return boolean True if item has at least one perk meeting or exceeding minGrade
local function meetsPerkRequirement(item, minGrade)
    local bestGrade = getBestPerkGrade(item)
    local bestValue = getPerkGradeValue(bestGrade)
    local minValue = getPerkGradeValue(minGrade)
    
    return bestValue >= minValue
end

local function shouldSellItem(item, itemRarity, equippedItems, favoritedItems)
    -- =========================================================================
    -- MYTHIC PROTECTION: Never sell Mythic items (rarity 6)
    -- Mythic items are meant to be traded, not sold/deleted
    -- =========================================================================
    if itemRarity >= 6 then
        return false
    end
    
    -- Never sell equipped items
    if getConfig('excludeEquipped') and equippedItems[item] then
        return false
    end
    
    -- Never sell locked/favorited items (uses game's Locked system)
    if getConfig('excludeFavorites') and (favoritedItems[item] or isItemLocked(item)) then
        return false
    end
    
    -- Never sell pets
    if getConfig('excludePets') then
        if ItemsModule and ItemsModule[item.Name] then
            local itemDef = ItemsModule[item.Name]
            if itemDef.Type == 'Pet' then
                return false
            end
        end
    end
    
    -- Don't sell upgraded items (they can't be traded anyway)
    if isItemUpgraded(item) then
        return false
    end
    
    -- Don't sell capped items (UpgradeLimit = 0)
    if isItemCapped(item) then
        return false
    end
    
    -- =========================================================================
    -- LEGENDARY PERK FILTER: Sell Legendary items with bad perks
    -- If enabled, checks if Legendary item meets minimum perk grade requirement
    -- =========================================================================
    if itemRarity == 5 and getConfig('sellLegendaryIfNotPerk') then
        local minGrade = getConfig('legendaryMinPerkGrade') or "S"
        
        -- If item doesn't meet perk requirement, mark for sale
        if not meetsPerkRequirement(item, minGrade) then
            -- Still apply level filters
            local itemLevel = getItemLevel(item)
            local itemEmpower = getItemEmpower(item)
            local effectiveLevel = itemLevel + itemEmpower
            
            local maxLevel = getConfig('MaxLevelToSell') or 0
            if maxLevel > 0 and effectiveLevel > maxLevel then
                return false
            end
            
            local minLevel = getConfig('MinLevelToKeep') or 0
            if minLevel > 0 and effectiveLevel >= minLevel then
                return false
            end
            
            return true -- Sell Legendary with bad perks
        end
        
        return false -- Keep Legendary with good perks
    end
    
    -- Check rarity threshold
    local threshold = getConfig('sellThreshold')
    local thresholdIndex = getRarityIndex(threshold)
    
    -- Sell if item rarity is BELOW threshold
    if itemRarity < thresholdIndex then
        -- Check level filters
        local itemLevel = getItemLevel(item)
        local itemEmpower = getItemEmpower(item)
        local effectiveLevel = itemLevel + itemEmpower
        
        -- If MaxLevelToSell is set, only sell items at or below that level
        local maxLevel = getConfig('MaxLevelToSell') or 0
        if maxLevel > 0 and effectiveLevel > maxLevel then
            return false
        end
        
        -- If MinLevelToKeep is set, don't sell items at or above that level
        local minLevel = getConfig('MinLevelToKeep') or 0
        if minLevel > 0 and effectiveLevel >= minLevel then
            return false
        end
        
        return true
    end
    
    return false
end

-- ============================================================================
-- ITEM COLLECTION & FILTERING
-- ============================================================================

local function getItemsToSell()
    local toSell = {}
    
    local itemsFolder = getInventoryFolder()
    if not itemsFolder then return toSell end
    
    local definitions = getItemDefinitions()
    local equippedItems = getEquippedItems()
    local favoritedItems = getFavoritedItems()
    
    -- Group items by name for "keep best" logic
    local itemsByName = {}
    
    -- Protected iteration to handle items that may become nil
    local success, err = pcall(function()
        for _, item in ipairs(itemsFolder:GetChildren()) do
            -- Check if item is valid before processing
            if item and item.Parent then
                -- Must be equipment (has Level or Upgrade attributes)
                local isEquipment = item:FindFirstChild('Level') or 
                                   item:FindFirstChild('Upgrade') or 
                                   item:FindFirstChild('UpgradeLimit')
                
                if isEquipment then
                    local rarity = getItemRarity(item, definitions)
                    
                    if shouldSellItem(item, rarity, equippedItems, favoritedItems) then
                        -- Group by item name for "keep best" filtering
                        if not itemsByName[item.Name] then
                            itemsByName[item.Name] = {}
                        end
                        table.insert(itemsByName[item.Name], {
                            instance = item,
                            rarity = rarity,
                            score = getItemScore(item),
                        })
                    end
                end
            end
        end
    end)
    
    if not success then
        warn('[AutoSell] Error scanning items:', err)
        return toSell
    end
    
    -- Apply "keep best" logic
    local keepCount = getConfig('keepBestCount') or 1
    
    for itemName, items in pairs(itemsByName) do
        -- Sort by score (highest first)
        table.sort(items, function(a, b)
            return a.score > b.score
        end)
        
        -- Keep the best X items, sell the rest
        for i = keepCount + 1, #items do
            -- Only add if item still exists
            local itemInstance = items[i].instance
            if itemInstance and itemInstance.Parent then
                table.insert(toSell, itemInstance)
            end
        end
    end
    
    return toSell
end

-- ============================================================================
-- ANTI-DETECTION HELPERS
-- ============================================================================

--- Add random variance to a value
--- @param value number Base value
--- @param variance number Variance percentage (0.0 to 1.0)
--- @return number Value with random variance applied
local function addVariance(value, variance)
    local range = value * variance
    return value + (math.random() * 2 - 1) * range
end

--- Get randomized sell delay with variance
--- @return number Randomized delay between sells
local function getRandomizedSellDelay()
    local baseDelay = getConfig('sellDelay') or 0.5
    local minDelay = AntiDetection.minSellDelay
    local maxDelay = AntiDetection.maxSellDelay
    
    -- Clamp base delay to reasonable range
    baseDelay = math.clamp(baseDelay, minDelay, maxDelay)
    
    -- Add random variance
    if AntiDetection.jitterEnabled then
        baseDelay = addVariance(baseDelay, AntiDetection.sellBatchVariance)
        -- Re-clamp after variance
        baseDelay = math.clamp(baseDelay, minDelay, maxDelay)
    end
    
    return baseDelay
end

--- Check if we should do a micro-pause (anti-detection)
--- @return boolean, number Whether to pause and pause duration
local function shouldMicroPause()
    if not AntiDetection.jitterEnabled then
        return false, 0
    end
    
    if math.random() < AntiDetection.microPauseChance then
        local pauseDuration = AntiDetection.microPauseMin + 
            math.random() * (AntiDetection.microPauseMax - AntiDetection.microPauseMin)
        return true, pauseDuration
    end
    
    return false, 0
end

-- ============================================================================
-- SELL EXECUTION
-- ============================================================================

local function executeSell()
    if not loadModules() then
        return 0, 0
    end
    
    local items = getItemsToSell()
    if #items == 0 then
        return 0, 0
    end
    
    local soldCount = 0
    local goldEarned = 0
    
    -- Use SellItems remote from Drops module (correct method!)
    -- Game accepts either single items or batches - we'll sell in small batches for anti-detection
    local batchSize = math.random(3, 6)  -- Random batch size for anti-detection
    local currentBatch = {}
    
    for i, item in ipairs(items) do
        -- Check if item still exists (could be destroyed/moved during iteration)
        if item and item.Parent then
            table.insert(currentBatch, item)
            
            -- Sell when batch is full or at end of items
            if #currentBatch >= batchSize or i == #items then
                -- Apply micro-pause chance (anti-detection)
                local doPause, pauseDuration = shouldMicroPause()
                if doPause then
                    safeWait(pauseDuration)
                end
                
                -- Sell the batch using correct remote
                local success, result = pcall(function()
                    return SellItemsRemote:InvokeServer(currentBatch)
                end)
                
                if success then
                    soldCount = soldCount + #currentBatch
                    if type(result) == 'number' then
                        goldEarned = goldEarned + result
                    end
                end
                
                -- Clear batch and get new random size
                currentBatch = {}
                batchSize = math.random(3, 6)
                
                -- Delay between batches (anti-detection)
                local delay = getRandomizedSellDelay()
                if delay > 0 then
                    safeWait(delay)
                end
            end
        end
    end
    
    return soldCount, goldEarned
end

-- ============================================================================
-- AUTO SELL LOOP
-- ============================================================================

local function runAutoSellLoop()
    while isRunning do
        -- Protected call to prevent crashes from stopping the loop
        local success, err = pcall(function()
            executeSell()
        end)
        
        if not success then
            warn('[AutoSell] Error in sell cycle:', err)
        end
        
        -- Wait for next cycle
        local interval = getConfig('sellInterval') or 30
        safeWait(interval)
    end
end

-- ============================================================================
-- INVENTORY SCANNER (periodic scanning replaces pickup listener)
-- ============================================================================

local scanConnection = nil
local lastScanTime = 0

--- Scan inventory and sell items matching criteria
--- Called periodically based on scanInterval setting
local function scanAndSellItems()
    if not isRunning then return 0, 0 end
    if not loadModules() then return 0, 0 end
    
    local items = getItemsToSell()
    if #items == 0 then return 0, 0 end
    
    local soldCount = 0
    local goldEarned = 0
    
    -- Sell in small batches with anti-detection
    local batchSize = math.random(3, 6)
    local currentBatch = {}
    
    for i, item in ipairs(items) do
        if item and item.Parent then
            table.insert(currentBatch, item)
            
            if #currentBatch >= batchSize or i == #items then
                -- Apply micro-pause chance (anti-detection)
                local doPause, pauseDuration = shouldMicroPause()
                if doPause then
                    safeWait(pauseDuration)
                end
                
                -- Sell the batch
                local success, result = pcall(function()
                    return SellItemsRemote:InvokeServer(currentBatch)
                end)
                
                if success then
                    soldCount = soldCount + #currentBatch
                    if type(result) == 'number' then
                        goldEarned = goldEarned + result
                    end
                end
                
                currentBatch = {}
                batchSize = math.random(3, 6)
                
                local delay = getRandomizedSellDelay()
                if delay > 0 then
                    safeWait(delay)
                end
            end
        end
    end
    
    return soldCount, goldEarned
end

--- Start the inventory scanner loop
local function startInventoryScanner()
    if scanConnection then return end -- Already running
    
    scanConnection = true -- Mark as running
    
    task.spawn(function()
        while isRunning and scanConnection do
            local scanInterval = getConfig('scanInterval') or 15
            local currentTime = os.clock()
            
            -- Check if enough time has passed since last scan
            if currentTime - lastScanTime >= scanInterval then
                lastScanTime = currentTime
                
                -- Protected call to prevent crashes
                local success, err = pcall(function()
                    scanAndSellItems()
                end)
                
                if not success then
                    warn('[AutoSell] Error in inventory scan:', err)
                end
            end
            
            -- Short sleep between checks
            safeWait(1)
        end
        
        scanConnection = nil
    end)
end

--- Stop the inventory scanner
local function stopInventoryScanner()
    scanConnection = nil
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function AutoSellAPI.enable()
    if isRunning then return end
    
    if not loadModules() then
        warn('[AutoSell] Required modules not available - Items:', ItemsModule ~= nil, 'SellItems:', SellItemsRemote ~= nil)
        return
    end
    
    isRunning = true
    setConfig('enabled', true)
    
    -- Start inventory scanner (replaces pickup listener)
    startInventoryScanner()
    
    -- Start auto-sell loop
    task.spawn(runAutoSellLoop)
end

function AutoSellAPI.disable()
    if not isRunning then return end
    
    isRunning = false
    setConfig('enabled', false)
    
    -- Stop inventory scanner
    stopInventoryScanner()
end

function AutoSellAPI.toggle()
    if isRunning then
        AutoSellAPI.disable()
    else
        AutoSellAPI.enable()
    end
    return isRunning
end

function AutoSellAPI.isEnabled()
    return isRunning
end

function AutoSellAPI.sellNow()
    if not loadModules() then
        return 0, 0
    end
    return executeSell()
end

function AutoSellAPI.getItemsToSell()
    return getItemsToSell()
end

function AutoSellAPI.preview()
    local items = getItemsToSell()
    local names = {}
    for _, item in ipairs(items) do
        table.insert(names, item.Name)
    end
    return names, #items
end

function AutoSellAPI.setThreshold(rarity)
    if RARITY_MAP[rarity] then
        setConfig('sellThreshold', rarity)
    end
end

function AutoSellAPI.setKeepBest(count)
    if type(count) == 'number' and count >= 0 then
        setConfig('keepBestCount', math.floor(count))
    end
end

function AutoSellAPI.setInterval(seconds)
    if type(seconds) == 'number' and seconds > 0 then
        setConfig('sellInterval', seconds)
    end
end

function AutoSellAPI.setDelay(seconds)
    if type(seconds) == 'number' and seconds >= 0 then
        setConfig('sellDelay', seconds)
    end
end

function AutoSellAPI.setScanInterval(seconds)
    if type(seconds) == 'number' and seconds >= 5 then
        setConfig('scanInterval', math.floor(seconds))
    end
end

function AutoSellAPI.setConfirmLegendaryPlus(enabled)
    setConfig('confirmLegendaryPlus', enabled == true)
end

function AutoSellAPI.setExcludeEquipped(enabled)
    setConfig('excludeEquipped', enabled == true)
end

function AutoSellAPI.setExcludeFavorites(enabled)
    setConfig('excludeFavorites', enabled == true)
end

function AutoSellAPI.setExcludePets(enabled)
    setConfig('excludePets', enabled == true)
end

function AutoSellAPI.setMaxLevel(level)
    if type(level) == 'number' and level >= 0 then
        setConfig('MaxLevelToSell', math.floor(level))
    end
end

function AutoSellAPI.setMinLevel(level)
    if type(level) == 'number' and level >= 0 then
        setConfig('MinLevelToKeep', math.floor(level))
    end
end

-- ============================================================================
-- LEGENDARY PERK FILTER API
-- ============================================================================

--- Enable/disable selling Legendary items with bad perks
--- @param enabled boolean True to enable Legendary perk filtering
function AutoSellAPI.setSellLegendaryIfNotPerk(enabled)
    setConfig('sellLegendaryIfNotPerk', enabled == true)
end

--- Set minimum perk grade to KEEP for Legendary items
--- Items with best perk below this grade will be sold
--- @param grade string Minimum grade: "S+", "S", "A", "B", or "C"
function AutoSellAPI.setLegendaryMinPerkGrade(grade)
    if PERK_GRADE_VALUE[grade] then
        setConfig('legendaryMinPerkGrade', grade)
    end
end

--- Get perk information for an item
--- @param item Instance The item to analyze
--- @return table Perk info with grades
function AutoSellAPI.getItemPerkInfo(item)
    loadModules() -- Ensure modules are loaded
    
    local perks = getItemPerks(item)
    local result = {}
    
    for i, perkInfo in pairs(perks) do
        if perkInfo and perkInfo.name then
            local grade = nil
            if perkInfo.value then
                grade = getPerkGrade(item.Name, perkInfo.name, perkInfo.value)
            end
            result[i] = {
                name = perkInfo.name,
                value = perkInfo.value,
                grade = grade,
            }
        end
    end
    
    result.bestGrade = getBestPerkGrade(item)
    return result
end

--- Get available perk grades for UI slider
--- @return table Array of grade names from best to worst
function AutoSellAPI.getPerkGrades()
    return { "S+", "S", "A", "B", "C" }
end

--- Preview Legendary items that would be sold with current perk settings
--- @return table, number Array of item names and count
function AutoSellAPI.previewLegendaryPerkSells()
    loadModules()
    
    local toSell = {}
    local itemsFolder = getInventoryFolder()
    if not itemsFolder then return toSell, 0 end
    
    local definitions = getItemDefinitions()
    local equippedItems = getEquippedItems()
    local favoritedItems = getFavoritedItems()
    local minGrade = getConfig('legendaryMinPerkGrade') or "S"
    
    for _, item in ipairs(itemsFolder:GetChildren()) do
        local isEquipment = item:FindFirstChild('Level') or 
                           item:FindFirstChild('Upgrade') or 
                           item:FindFirstChild('UpgradeLimit')
        
        if isEquipment then
            local rarity = getItemRarity(item, definitions)
            
            -- Only check Legendary items
            if rarity == 5 then
                -- Skip protected items
                if not equippedItems[item] and 
                   not favoritedItems[item] and 
                   not isItemLocked(item) and
                   not isItemUpgraded(item) and
                   not isItemCapped(item) then
                    
                    local bestGrade = getBestPerkGrade(item)
                    if not meetsPerkRequirement(item, minGrade) then
                        table.insert(toSell, {
                            name = item.Name,
                            bestGrade = bestGrade,
                            minRequired = minGrade,
                        })
                    end
                end
            end
        end
    end
    
    return toSell, #toSell
end

function AutoSellAPI.getStatus()
    return {
        running = isRunning,
        threshold = getConfig('sellThreshold'),
        keepBest = getConfig('keepBestCount'),
        interval = getConfig('sellInterval'),
        delay = getConfig('sellDelay'),
        scanInterval = getConfig('scanInterval'),
        confirmLegendaryPlus = getConfig('confirmLegendaryPlus'),
        excludeEquipped = getConfig('excludeEquipped'),
        excludeFavorites = getConfig('excludeFavorites'),
        excludePets = getConfig('excludePets'),
        maxLevelToSell = getConfig('MaxLevelToSell'),
        minLevelToKeep = getConfig('MinLevelToKeep'),
        -- Legendary perk filter settings
        sellLegendaryIfNotPerk = getConfig('sellLegendaryIfNotPerk'),
        legendaryMinPerkGrade = getConfig('legendaryMinPerkGrade'),
        pendingItems = #getItemsToSell(),
        -- Anti-detection settings
        antiDetection = {
            jitterEnabled = AntiDetection.jitterEnabled,
            minSellDelay = AntiDetection.minSellDelay,
            maxSellDelay = AntiDetection.maxSellDelay,
            microPauseChance = AntiDetection.microPauseChance,
        },
        -- Module status
        modules = {
            Items = ItemsModule ~= nil,
            Inventory = InventoryModule ~= nil,
            Drops = DropsModule ~= nil,
            SellItems = SellItemsRemote ~= nil,
            Profile = ProfileModule ~= nil,
            Gear = GearModule ~= nil,
        },
    }
end

-- ============================================================================
-- ANTI-DETECTION API
-- ============================================================================

--- Configure anti-detection settings
--- @param settings table Table with anti-detection options
function AutoSellAPI.setAntiDetection(settings)
    if type(settings) ~= 'table' then return end
    
    if settings.jitterEnabled ~= nil then
        AntiDetection.jitterEnabled = settings.jitterEnabled == true
    end
    if type(settings.minSellDelay) == 'number' then
        AntiDetection.minSellDelay = math.max(0.1, settings.minSellDelay)
    end
    if type(settings.maxSellDelay) == 'number' then
        AntiDetection.maxSellDelay = math.max(AntiDetection.minSellDelay, settings.maxSellDelay)
    end
    if type(settings.microPauseChance) == 'number' then
        AntiDetection.microPauseChance = math.clamp(settings.microPauseChance, 0, 0.5)
    end
    if type(settings.sellBatchVariance) == 'number' then
        AntiDetection.sellBatchVariance = math.clamp(settings.sellBatchVariance, 0, 0.5)
    end
end

--- Get current anti-detection configuration
--- @return table Current anti-detection settings
function AutoSellAPI.getAntiDetection()
    return {
        jitterEnabled = AntiDetection.jitterEnabled,
        minSellDelay = AntiDetection.minSellDelay,
        maxSellDelay = AntiDetection.maxSellDelay,
        sellBatchVariance = AntiDetection.sellBatchVariance,
        microPauseChance = AntiDetection.microPauseChance,
        microPauseMin = AntiDetection.microPauseMin,
        microPauseMax = AntiDetection.microPauseMax,
    }
end

-- ============================================================================
-- GLOBAL EXPORT
-- ============================================================================

_G.AutoSellAPI = AutoSellAPI
_G.x8s4v = AutoSellAPI  -- Obfuscated global key
getgenv().AutoSellAPI = AutoSellAPI

return AutoSellAPI
