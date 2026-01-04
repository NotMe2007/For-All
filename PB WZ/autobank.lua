-- ============================================================================
-- Bank API - Item Storage Management System
-- ============================================================================
-- https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/Bank.lua
-- Provides interface for depositing/withdrawing items from bank storage
-- Based on decompiled ReplicatedStorage.Shared.Bank module
--
-- API USAGE:
-- • BankAPI.getItems()              - Get all bank items and slot count
-- • BankAPI.deposit(item, count)    - Deposit item to bank
-- • BankAPI.withdraw(item, count)   - Withdraw item from bank
-- • BankAPI.hasExtraSlots()         - Check if player has extra bank slots pass
-- • BankAPI.purchaseExtraSlots()    - Prompt purchase of extra bank slots
-- • BankAPI.getSlotInfo()           - Get current/max slot information
-- • BankAPI.isInBank(item)          - Check if item is in bank
--
-- AUTO-MANAGEMENT:
-- • BankAPI.autoDepositAll()        - Deposit all non-equipped items to bank
-- • BankAPI.autoManageInventory()   - Auto deposit + sell bad items if needed
-- • BankAPI.sellBadItem()           - Sell one bad item (below A grade)
-- • BankAPI.freeInventorySlot()     - Free one slot (deposit or sell)
-- • BankAPI.enableAutoManagement()  - Enable automatic inventory management
-- • BankAPI.disableAutoManagement() - Disable automatic inventory management
--
-- SLOT CALCULATIONS:
-- • Base: 50 slots
-- • VIP: +50 slots
-- • Extra Bank Slots Pass: +100 slots
-- • Loyalty Rewards: +20 slots
--
-- PERK GRADE SYSTEM (for selling):
-- • S+ = Perfect roll (max value) - KEEP
-- • S  = Near-perfect roll - KEEP
-- • A  = Good roll (80%+) - KEEP
-- • B  = Decent roll (50%+) - SELL if needed
-- • C  = Poor roll (below 50%) - SELL first
--
-- ANTI-CHEAT COMPLIANCE:
-- See Tests/anticheat.lua for full documentation of detection systems.
--
-- Key protections implemented:
-- • Uses game's official Bank module remotes (TransferToBank, WithdrawFromBank)
-- • All remote calls go through safeRequire'd modules, not raw access
-- • No position manipulation or teleportation involved
-- • LOW RISK: Banking operations are not monitored by combat anti-cheat
-- ============================================================================

-- Services
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local MarketplaceService = game:GetService('MarketplaceService')
local RunService = game:GetService('RunService')

-- Global environment
local _genv = getgenv()

-- ============================================================================
-- CONFIGURATION FLAGS
-- ============================================================================

if _genv.AutoBankEnabled == nil then _genv.AutoBankEnabled = false end
if _genv.AutoBankSellBelowGrade == nil then _genv.AutoBankSellBelowGrade = "A" end
if _genv.AutoBankKeepEquipped == nil then _genv.AutoBankKeepEquipped = true end
if _genv.AutoBankKeepLocked == nil then _genv.AutoBankKeepLocked = true end
if _genv.AutoBankInventoryThreshold == nil then _genv.AutoBankInventoryThreshold = 0.9 end -- 90% full triggers

-- ============================================================================
-- GAMEPASS IDS
-- ============================================================================

local EXTRA_BANK_SLOTS_PASS = {
    DevID = 75170705,
    LiveID = 74987904
}

-- ============================================================================
-- PERK GRADE VALUES (higher = better)
-- ============================================================================

local PERK_GRADE_VALUE = {
    ["S+"] = 5,
    ["S"] = 4,
    ["A"] = 3,
    ["B"] = 2,
    ["C"] = 1,
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

local function safeRequire(mod)
    if not mod then return nil end
    local ok, res = pcall(require, mod)
    return ok and res or nil
end

local function isDevUniverse()
    local teleportModule = ReplicatedStorage:FindFirstChild('Shared')
    if teleportModule then
        teleportModule = teleportModule:FindFirstChild('Teleport')
        if teleportModule then
            local Teleport = safeRequire(teleportModule)
            if Teleport and Teleport.IsDevUniverse then
                local ok, result = pcall(function()
                    return Teleport:IsDevUniverse()
                end)
                if ok then return result end
            end
        end
    end
    return false
end

-- ============================================================================
-- MODULE CACHING
-- ============================================================================

local BankModule = nil
local ProfileModule = nil
local ItemsModule = nil
local InventoryModule = nil
local GearModule = nil
local GearPerksModule = nil
local DropsModule = nil
local SellItemsRemote = nil

-- Remote references
local GetBankItemsRemote = nil
local TransferToBankRemote = nil
local WithdrawFromBankRemote = nil
local OwnsExtraBankSlotsRemote = nil
local BankUpdatedSignal = nil

-- ============================================================================
-- MODULE LOADING
-- ============================================================================

local function loadModules()
    pcall(function()
        local shared = ReplicatedStorage:FindFirstChild('Shared')
        if not shared then return end
        
        -- Load Bank module
        if not BankModule then
            local bank = shared:FindFirstChild('Bank')
            if bank then
                BankModule = safeRequire(bank)
                -- Get remotes
                GetBankItemsRemote = bank:FindFirstChild('GetBankItems')
                TransferToBankRemote = bank:FindFirstChild('TransferToBank')
                WithdrawFromBankRemote = bank:FindFirstChild('WithdrawFromBank')
                OwnsExtraBankSlotsRemote = bank:FindFirstChild('OwnsExtraBankSlots')
                BankUpdatedSignal = bank:FindFirstChild('BankUpdated')
            end
        end
        
        -- Load Profile module
        if not ProfileModule then
            local profile = shared:FindFirstChild('Profile')
            if profile then
                ProfileModule = safeRequire(profile)
            end
        end
        
        -- Load Items module
        if not ItemsModule then
            local items = shared:FindFirstChild('Items')
            if items then
                ItemsModule = safeRequire(items)
            end
        end
        
        -- Load Inventory module
        if not InventoryModule then
            local inventory = shared:FindFirstChild('Inventory')
            if inventory then
                InventoryModule = safeRequire(inventory)
            end
        end
        
        -- Load Gear module for perk analysis
        if not GearModule then
            local gear = shared:FindFirstChild('Gear')
            if gear then
                GearModule = safeRequire(gear)
                local gearPerks = gear:FindFirstChild('GearPerks')
                if gearPerks then
                    GearPerksModule = safeRequire(gearPerks)
                end
            end
        end
        
        -- Load Drops module for selling
        if not DropsModule then
            local drops = shared:FindFirstChild('Drops')
            if drops then
                DropsModule = safeRequire(drops)
                SellItemsRemote = drops:FindFirstChild('SellItems')
            end
        end
    end)
    
    return BankModule ~= nil or GetBankItemsRemote ~= nil
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
    
    if ProfileModule and ProfileModule.GetProfile then
        local ok, profile = pcall(function()
            return ProfileModule:GetProfile(player)
        end)
        if ok and profile then
            return profile
        end
    end
    
    return nil
end

local function getPlayerEquips()
    local player = getPlayer()
    if not player then return nil end
    
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
        for _, slot in ipairs(equips:GetChildren()) do
            local equippedItem = slot:FindFirstChildOfClass('Folder')
            if equippedItem then
                equipped[equippedItem] = true
            end
        end
    end
    
    return equipped
end

local function getInventoryFolder()
    local profile = getPlayerProfile()
    if not profile then return nil end
    
    local inventory = profile:FindFirstChild('Inventory')
    if not inventory then return nil end
    
    return inventory:FindFirstChild('Items')
end

local function getInventoryInfo()
    local itemsFolder = getInventoryFolder()
    if not itemsFolder then return { count = 0, max = 100, percent = 0 } end
    
    local count = #itemsFolder:GetChildren()
    local max = 100 -- Default inventory size
    
    -- Try to get actual max from InventoryModule
    if InventoryModule and InventoryModule.GetMaxInventorySize then
        local ok, size = pcall(function()
            return InventoryModule:GetMaxInventorySize(getPlayer())
        end)
        if ok and size then max = size end
    end
    
    return {
        count = count,
        max = max,
        percent = count / max,
        available = max - count,
        isFull = count >= max
    }
end

-- ============================================================================
-- PERK ANALYSIS (for selling decisions)
-- ============================================================================

local function getItemPerks(item)
    local perks = {}
    
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
    
    -- Fallback: read perks directly
    for i = 1, 3 do
        local perkVal = item:FindFirstChild("Perk" .. tostring(i))
        if perkVal then
            local perkValue = nil
            local valueChild = perkVal:FindFirstChild("PerkValue")
            if valueChild then
                perkValue = valueChild.Value
            end
            perks[i] = { name = perkVal.Value, value = perkValue }
        end
    end
    
    return perks
end

local function getPerkGrade(itemName, perkName, perkValue)
    if not perkValue then return nil end
    
    if GearModule and GearModule.GetPerkScore then
        local ok, grade = pcall(function()
            return GearModule:GetPerkScore(itemName, perkName, perkValue)
        end)
        if ok and grade then return grade end
    end
    
    -- Fallback: estimate based on value ranges
    local perkData = nil
    if GearPerksModule and GearPerksModule[perkName] then
        perkData = GearPerksModule[perkName]
    end
    
    if not perkData or not perkData.StatRange then
        return "C"
    end
    
    local minVal = perkData.StatRange[1]
    local maxVal = perkData.StatRange[2]
    local roundedValue = math.round(perkValue * 100)
    local roundedMax = math.round(maxVal * 100)
    local roundedMin = math.round(minVal * 100)
    
    if roundedValue >= roundedMax then return "S+" end
    if roundedValue >= roundedMax - 2 then return "S" end
    
    local ratio = (roundedValue - roundedMin) / (roundedMax - roundedMin)
    if ratio >= 0.8 then return "A" end
    if ratio >= 0.5 then return "B" end
    return "C"
end

local function getBestPerkGrade(item)
    local perks = getItemPerks(item)
    local bestGrade = "C"
    local bestValue = 1
    
    for _, perkInfo in pairs(perks) do
        if perkInfo and perkInfo.name and perkInfo.value then
            local grade = getPerkGrade(item.Name, perkInfo.name, perkInfo.value)
            if grade then
                local gradeValue = PERK_GRADE_VALUE[grade] or 0
                if gradeValue > bestValue then
                    bestValue = gradeValue
                    bestGrade = grade
                end
            end
        end
    end
    
    return bestGrade, bestValue
end

-- ============================================================================
-- ITEM ANALYSIS
-- ============================================================================

local function isItemEquipped(item, equippedItems)
    return equippedItems and equippedItems[item]
end

local function isItemLocked(item)
    return item:FindFirstChild('Locked') ~= nil
end

local function isItemUpgraded(item)
    local upgrade = item:FindFirstChild('Upgrade')
    return upgrade and upgrade.Value > 0
end

local function getItemRarity(item)
    if InventoryModule and InventoryModule.GetItemTier then
        local ok, tier = pcall(function()
            return InventoryModule:GetItemTier(item)
        end)
        if ok and tier then return tier end
    end
    
    local upgradeLimit = item:FindFirstChild('UpgradeLimit')
    if upgradeLimit then
        local tier = math.floor(upgradeLimit.Value / 2 - 1)
        return math.max(1, tier + 1)
    end
    
    return 1
end

local function getItemLevel(item)
    local levelValue = item:FindFirstChild('Level')
    if levelValue then return levelValue.Value or 1 end
    return 1
end

local function getItemEmpower(item)
    local empowerValue = item:FindFirstChild('Empower')
    if empowerValue then return empowerValue.Value or 0 end
    return 0
end

local function getItemScore(item)
    local score = 0
    local level = getItemLevel(item)
    local empower = getItemEmpower(item)
    score = score + ((level + empower) * 10)
    
    local upgrade = item:FindFirstChild('Upgrade')
    if upgrade then score = score + (upgrade.Value * 50) end
    
    local upgradeLimit = item:FindFirstChild('UpgradeLimit')
    if upgradeLimit then score = score + (upgradeLimit.Value * 5) end
    
    return score
end

local function isItemBankable(item)
    if not item then return false end
    
    -- Check if item has Unbankable flag
    if ItemsModule and ItemsModule[item.Name] then
        if ItemsModule[item.Name].Unbankable then
            return false
        end
    end
    
    return true
end

local function isItemSellable(item, equippedItems)
    if not item then return false end
    
    -- Never sell equipped items
    if _genv.AutoBankKeepEquipped and isItemEquipped(item, equippedItems) then
        return false
    end
    
    -- Never sell locked items
    if _genv.AutoBankKeepLocked and isItemLocked(item) then
        return false
    end
    
    -- Never sell Mythic (rarity 6)
    local rarity = getItemRarity(item)
    if rarity >= 6 then
        return false
    end
    
    -- Don't sell upgraded items
    if isItemUpgraded(item) then
        return false
    end
    
    -- Check item type - only sell equipment
    local isEquipment = item:FindFirstChild('Level') or 
                       item:FindFirstChild('Upgrade') or 
                       item:FindFirstChild('UpgradeLimit')
    
    if not isEquipment then
        return false
    end
    
    -- Check if it's a pet
    if ItemsModule and ItemsModule[item.Name] then
        local itemDef = ItemsModule[item.Name]
        if itemDef.Type == 'Pet' then
            return false
        end
    end
    
    return true
end

-- ============================================================================
-- BANK API
-- ============================================================================

local BankAPI = {}

-- State
local cachedBankItems = nil
local cachedExtraSlots = 0
local lastUpdate = 0
local autoManageEnabled = false
local autoManageConnection = nil
local inventoryFullConnection = nil

-- ============================================================================
-- BANK ITEMS
-- ============================================================================

function BankAPI.getItems()
    if not loadModules() then
        return nil, 0
    end
    
    if GetBankItemsRemote then
        local success, result = pcall(function()
            return GetBankItemsRemote:InvokeServer()
        end)
        
        if success and result then
            cachedBankItems = result[1]
            cachedExtraSlots = result[2] or 0
            lastUpdate = os.clock()
            return result[1], result[2]
        end
    end
    
    if BankModule and BankModule.GetBankItems then
        local ok, items, extra = pcall(function()
            return BankModule:GetBankItems(getPlayer())
        end)
        if ok then
            cachedBankItems = items
            cachedExtraSlots = extra or 0
            lastUpdate = os.clock()
            return items, extra
        end
    end
    
    return cachedBankItems, cachedExtraSlots
end

function BankAPI.getCachedItems()
    return cachedBankItems, cachedExtraSlots
end

function BankAPI.getSlotInfo()
    local items, extraSlots = BankAPI.getItems()
    
    local currentUsed = 0
    if items and items:IsA('Folder') then
        currentUsed = #items:GetChildren()
    end
    
    local baseSlots = 50
    local totalSlots = baseSlots + (extraSlots or 0)
    
    return {
        current = currentUsed,
        max = totalSlots,
        available = totalSlots - currentUsed,
        base = baseSlots,
        extra = extraSlots or 0,
        isFull = currentUsed >= totalSlots,
    }
end

-- ============================================================================
-- DEPOSIT / WITHDRAW
-- ============================================================================

function BankAPI.deposit(item, count)
    if not item then return false end
    count = count or 1
    
    if not loadModules() then return false end
    if not isItemBankable(item) then return false end
    
    if TransferToBankRemote then
        local success = pcall(function()
            TransferToBankRemote:FireServer(item, count)
        end)
        return success
    end
    
    if BankModule and BankModule.TransferToBank then
        local ok = pcall(function()
            BankModule:TransferToBank(getPlayer(), item, count)
        end)
        return ok
    end
    
    return false
end

function BankAPI.withdraw(item, count)
    if not item then return false end
    count = count or 1
    
    if not loadModules() then return false end
    
    if WithdrawFromBankRemote then
        local success = pcall(function()
            WithdrawFromBankRemote:FireServer(item, count)
        end)
        return success
    end
    
    if BankModule and BankModule.WithdrawFromBank then
        local ok = pcall(function()
            BankModule:WithdrawFromBank(getPlayer(), item, count)
        end)
        return ok
    end
    
    return false
end

-- ============================================================================
-- AUTO DEPOSIT ALL NON-EQUIPPED ITEMS
-- ============================================================================

function BankAPI.autoDepositAll()
    if not loadModules() then return 0 end
    
    local bankInfo = BankAPI.getSlotInfo()
    if bankInfo.isFull then
        return 0
    end
    
    local itemsFolder = getInventoryFolder()
    if not itemsFolder then return 0 end
    
    local equippedItems = getEquippedItems()
    local depositedCount = 0
    
    for _, item in ipairs(itemsFolder:GetChildren()) do
        -- Skip if bank is now full
        if bankInfo.available <= depositedCount then
            break
        end
        
        -- Check all skip conditions
        local shouldSkip = false
        
        -- Skip equipped items
        if _genv.AutoBankKeepEquipped and isItemEquipped(item, equippedItems) then
            shouldSkip = true
        end
        
        -- Skip locked items
        if not shouldSkip and _genv.AutoBankKeepLocked and isItemLocked(item) then
            shouldSkip = true
        end
        
        -- Skip unbankable items
        if not shouldSkip and not isItemBankable(item) then
            shouldSkip = true
        end
        
        -- Deposit if not skipped
        if not shouldSkip then
            if BankAPI.deposit(item) then
                depositedCount = depositedCount + 1
                safeWait(0.15) -- Small delay between deposits
            end
        end
    end
    
    return depositedCount
end

-- ============================================================================
-- SELL BAD ITEMS (Below grade threshold)
-- ============================================================================

--- Get list of sellable items sorted by quality (worst first)
function BankAPI.getSellableItems()
    if not loadModules() then return {} end
    
    local itemsFolder = getInventoryFolder()
    if not itemsFolder then return {} end
    
    local equippedItems = getEquippedItems()
    local minGrade = _genv.AutoBankSellBelowGrade or "A"
    local minGradeValue = PERK_GRADE_VALUE[minGrade] or 3
    
    local sellable = {}
    
    for _, item in ipairs(itemsFolder:GetChildren()) do
        if isItemSellable(item, equippedItems) then
            local bestGrade, gradeValue = getBestPerkGrade(item)
            
            -- Only include items below the minimum grade threshold
            if gradeValue < minGradeValue then
                table.insert(sellable, {
                    item = item,
                    grade = bestGrade,
                    gradeValue = gradeValue,
                    rarity = getItemRarity(item),
                    score = getItemScore(item),
                })
            end
        end
    end
    
    -- Sort: lowest grade first, then lowest rarity, then lowest score
    table.sort(sellable, function(a, b)
        if a.gradeValue ~= b.gradeValue then
            return a.gradeValue < b.gradeValue
        end
        if a.rarity ~= b.rarity then
            return a.rarity < b.rarity
        end
        return a.score < b.score
    end)
    
    return sellable
end

--- Sell one bad item (returns true if sold, false if nothing to sell)
function BankAPI.sellBadItem()
    if not loadModules() or not SellItemsRemote then
        return false
    end
    
    local sellable = BankAPI.getSellableItems()
    if #sellable == 0 then
        return false
    end
    
    local itemToSell = sellable[1].item
    if not itemToSell or not itemToSell.Parent then
        return false
    end
    
    local success = pcall(function()
        SellItemsRemote:InvokeServer({itemToSell})
    end)
    
    return success
end

--- Sell multiple bad items
function BankAPI.sellBadItems(count)
    count = count or 1
    local soldCount = 0
    
    for i = 1, count do
        if BankAPI.sellBadItem() then
            soldCount = soldCount + 1
            safeWait(0.3) -- Delay between sells
        else
            break -- No more to sell
        end
    end
    
    return soldCount
end

-- ============================================================================
-- FREE INVENTORY SLOT (deposit or sell)
-- ============================================================================

--- Free one inventory slot by depositing to bank or selling
function BankAPI.freeInventorySlot()
    -- First try to deposit to bank
    local bankInfo = BankAPI.getSlotInfo()
    
    if not bankInfo.isFull then
        -- Find one item to deposit
        local itemsFolder = getInventoryFolder()
        if itemsFolder then
            local equippedItems = getEquippedItems()
            
            for _, item in ipairs(itemsFolder:GetChildren()) do
                if not isItemEquipped(item, equippedItems) and
                   not isItemLocked(item) and
                   isItemBankable(item) then
                    if BankAPI.deposit(item) then
                        return true, "deposited"
                    end
                end
            end
        end
    end
    
    -- Bank is full or couldn't deposit, try selling
    if BankAPI.sellBadItem() then
        return true, "sold"
    end
    
    return false, "failed"
end

--- Free multiple inventory slots
function BankAPI.freeInventorySlots(count)
    count = count or 1
    local freedCount = 0
    local actions = { deposited = 0, sold = 0 }
    
    for i = 1, count do
        local success, action = BankAPI.freeInventorySlot()
        if success then
            freedCount = freedCount + 1
            if action then actions[action] = (actions[action] or 0) + 1 end
            safeWait(0.2)
        else
            break
        end
    end
    
    return freedCount, actions
end

-- ============================================================================
-- AUTO MANAGEMENT (when inventory gets full)
-- ============================================================================

function BankAPI.autoManageInventory()
    local invInfo = getInventoryInfo()
    local threshold = _genv.AutoBankInventoryThreshold or 0.9
    
    if invInfo.percent < threshold then
        return -- Not full enough to manage
    end
    
    -- First, deposit all possible items
    local deposited = BankAPI.autoDepositAll()
    
    -- Check if still full
    invInfo = getInventoryInfo()
    if invInfo.isFull then
        -- Sell bad items to make space
        local toFree = math.min(5, invInfo.count) -- Free up to 5 slots
        BankAPI.sellBadItems(toFree)
    end
end

function BankAPI.enableAutoManagement()
    if autoManageEnabled then return end
    autoManageEnabled = true
    
    -- Run periodic check
    task.spawn(function()
        while autoManageEnabled do
            pcall(BankAPI.autoManageInventory)
            safeWait(10) -- Check every 10 seconds
        end
    end)
end

function BankAPI.disableAutoManagement()
    autoManageEnabled = false
end

function BankAPI.isAutoManagementEnabled()
    return autoManageEnabled
end

-- ============================================================================
-- BANK STATUS
-- ============================================================================

function BankAPI.isInBank(item)
    if not item then return false end
    
    if BankModule and BankModule.IsInBank then
        local ok, result = pcall(function()
            return BankModule:IsInBank(getPlayer(), item)
        end)
        if ok then return result end
    end
    
    local profile = getPlayerProfile()
    if profile then
        local bank = profile:FindFirstChild('Bank')
        if bank then
            local bankItems = bank:FindFirstChild('Items')
            if bankItems then
                return bankItems:IsAncestorOf(item)
            end
        end
    end
    
    return false
end

function BankAPI.hasExtraSlots()
    if not loadModules() then return false end
    
    if OwnsExtraBankSlotsRemote then
        local success, result = pcall(function()
            return OwnsExtraBankSlotsRemote:InvokeServer()
        end)
        if success then return result end
    end
    
    if BankModule and BankModule.HasExtraBankSlots then
        local ok, result = pcall(function()
            return BankModule:HasExtraBankSlots(getPlayer())
        end)
        if ok then return result end
    end
    
    return false
end

function BankAPI.purchaseExtraSlots()
    local player = getPlayer()
    if not player then return end
    
    local passId = isDevUniverse() and EXTRA_BANK_SLOTS_PASS.DevID or EXTRA_BANK_SLOTS_PASS.LiveID
    
    pcall(function()
        MarketplaceService:PromptGamePassPurchase(player, passId)
    end)
end

-- ============================================================================
-- BANK SIGNALS
-- ============================================================================

function BankAPI.getUpdatedSignal()
    if BankUpdatedSignal then
        return BankUpdatedSignal.OnClientEvent
    end
    return nil
end

function BankAPI.onUpdated(callback)
    local signal = BankAPI.getUpdatedSignal()
    if signal then
        return signal:Connect(callback)
    end
    return nil
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

function BankAPI.getItemCount()
    local items = BankAPI.getItems()
    if items and items:IsA('Folder') then
        return #items:GetChildren()
    end
    return 0
end

function BankAPI.isFull()
    local info = BankAPI.getSlotInfo()
    return info.available <= 0
end

function BankAPI.getItemsAsTable()
    local items = BankAPI.getItems()
    if items and items:IsA('Folder') then
        return items:GetChildren()
    end
    return {}
end

function BankAPI.findItem(itemName)
    local items = BankAPI.getItems()
    if items and items:IsA('Folder') then
        return items:FindFirstChild(itemName)
    end
    return nil
end

function BankAPI.findItems(filter)
    if not filter then return {} end
    
    local result = {}
    local items = BankAPI.getItemsAsTable()
    
    for _, item in ipairs(items) do
        local itemDef = ItemsModule and ItemsModule[item.Name]
        if filter(item, itemDef) then
            table.insert(result, item)
        end
    end
    
    return result
end

-- ============================================================================
-- STATUS
-- ============================================================================

function BankAPI.getStatus()
    local bankInfo = BankAPI.getSlotInfo()
    local invInfo = getInventoryInfo()
    local sellable = BankAPI.getSellableItems()
    
    return {
        bank = {
            itemCount = bankInfo.current,
            maxSlots = bankInfo.max,
            availableSlots = bankInfo.available,
            isFull = bankInfo.isFull,
            hasExtraSlots = BankAPI.hasExtraSlots(),
        },
        inventory = {
            itemCount = invInfo.count,
            maxSlots = invInfo.max,
            percent = invInfo.percent,
            isFull = invInfo.isFull,
        },
        sellableCount = #sellable,
        autoManagementEnabled = autoManageEnabled,
        lastUpdate = lastUpdate,
    }
end

-- ============================================================================
-- GLOBAL EXPORT
-- ============================================================================

_G.BankAPI = BankAPI
getgenv().BankAPI = BankAPI

return BankAPI
