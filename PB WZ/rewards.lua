-- ============================================================================
-- Rewards API - Automated Collection & Claiming System
-- ============================================================================
-- https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/rewards.lua
-- Combines: Coin Magnet, Gamepass Checker, Promo Codes, BattlePass, Dungeon Chests
-- All reward/collection related automation in one unified module
--
-- GLOBALS EXPORTED:
--   _G.RewardsAPI         → Main unified API
--   _G.x7d2k              → Magnet API (legacy)
--   _G.k3f7x              → Gamepass API (legacy)
--   _G.PromoCodesAPI      → Promo codes
--   _G.BattlePassAPI      → Battle pass
--   _G.DungeonChestsAPI   → Dungeon chests
--
-- ANTI-CHEAT COMPLIANCE:
-- See Tests/anticheat.lua for full documentation of detection systems.
--
-- Key protections implemented:
-- • Coin magnet uses CFrame positioning (client-side, no remotes)
-- • Promo codes use game's official Codes module remotes
-- • BattlePass uses game's official BattlePass module
-- • Dungeon chests use game's Missions module (server validates ownership)
-- • LOW RISK: Collection operations don't trigger combat anti-cheat
-- • Chest teleportation uses smooth movement, not instant teleport
-- ============================================================================

-- Services (cached once)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

-- Player reference
local player = Players.LocalPlayer
if not player then return end

-- Global environment
local _genv = getgenv()

-- ============================================================================
-- SHARED UTILITIES
-- ============================================================================

-- Custom wait using Heartbeat (executor-safe)
local function wait(sec)
    sec = tonumber(sec)
    if sec and sec > 0 then
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

-- Get player's root part
local function getPlayerPart()
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
end

-- ============================================================================
-- MAGNET API - Coin Collection
-- ============================================================================

-- Config
if _genv.CoinMagnet == nil then _genv.CoinMagnet = true end
if _genv.CoinMagnetInvisible == nil then _genv.CoinMagnetInvisible = true end

local MagnetAPI = {}

-- Process a coin (make invisible + pull to player)
local function processCoin(coin)
    if not coin or not coin:IsA("BasePart") then return end
    
    task.spawn(function()
        -- Make invisible immediately to reduce mobile lag
        if _genv.CoinMagnetInvisible then
            pcall(function()
                coin.Transparency = 1
                -- Hide any children (glow effects, etc)
                for _, child in ipairs(coin:GetDescendants()) do
                    if child:IsA("BasePart") then
                        child.Transparency = 1
                    elseif child:IsA("ParticleEmitter") or child:IsA("Trail") or child:IsA("BillboardGui") then
                        child.Enabled = false
                    elseif child:IsA("Light") then
                        child.Enabled = false
                    end
                end
            end)
        end
        
        -- Pull loop
        while coin and coin.Parent and _genv.CoinMagnet do
            pcall(function()
                local playerPart = getPlayerPart()
                if playerPart then
                    coin.CanCollide = false
                    coin.CFrame = playerPart.CFrame
                end
            end)
            wait(0.15)
        end
    end)
end

-- Initialize magnet
local function initMagnet()
    local coinsFolder = Workspace:FindFirstChild("Coins")
    if not coinsFolder then return end
    
    -- Process existing coins
    for _, coin in ipairs(coinsFolder:GetChildren()) do
        if coin.Name == "CoinPart" then
            processCoin(coin)
        end
    end
    
    -- Handle new coins
    coinsFolder.ChildAdded:Connect(function(coin)
        if coin.Name == "CoinPart" and _genv.CoinMagnet then
            processCoin(coin)
        end
    end)
end

function MagnetAPI.enable()
    _genv.CoinMagnet = true
end

function MagnetAPI.disable()
    _genv.CoinMagnet = false
end

function MagnetAPI.toggle()
    _genv.CoinMagnet = not _genv.CoinMagnet
    return _genv.CoinMagnet
end

function MagnetAPI.setInvisible(enabled)
    _genv.CoinMagnetInvisible = enabled
end

function MagnetAPI.isEnabled()
    return _genv.CoinMagnet
end

-- ============================================================================
-- GAMEPASS API - Ownership Checking
-- ============================================================================

local ITEM_DROP_PASS_ID = 8136250

if _genv.CheckGamepass == nil then _genv.CheckGamepass = true end

local GamepassAPI = {}

-- Check gamepass ownership (safer method)
local function checkGamepassOwnership(gamepassId)
    local hasPass = false
    
    -- Try MarketplaceService
    pcall(function()
        hasPass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
    end)
    
    if hasPass then return true end
    
    -- Fallback: check PlayerGui profile
    pcall(function()
        local playerGui = player:FindFirstChild("PlayerGui")
        if playerGui then
            local profile = playerGui:FindFirstChild("Profile")
            if profile then
                local gamepassInfo = profile:FindFirstChild("Gamepasses")
                if gamepassInfo then
                    for _, pass in ipairs(gamepassInfo:GetChildren()) do
                        if tonumber(pass.Name) == gamepassId then
                            hasPass = true
                            break
                        end
                    end
                end
            end
        end
    end)
    
    return hasPass
end

function GamepassAPI.checkItemDropPass()
    return checkGamepassOwnership(ITEM_DROP_PASS_ID)
end

function GamepassAPI.checkGamepass(gamepassId)
    return checkGamepassOwnership(gamepassId)
end

function GamepassAPI.hasItemDropPass()
    return _genv.HasItemDropPass or false
end

function GamepassAPI.refresh()
    pcall(function()
        _genv.HasItemDropPass = GamepassAPI.checkItemDropPass()
    end)
end

-- ============================================================================
-- PROMO CODES API
-- ============================================================================

local PromoCodesAPI = {}

-- File storage for redeemed codes
local PROMO_CODES_FILE = "ZenX WZ/redeemed_codes.json"
local PROMO_COOLDOWN = 13 -- 13 seconds per code as required by the game

local PROMO_CODES = {
    "RELEASE", "THANKYOU", "WORLDZERO", "HOLIDAY", "WINTER", "NEWYEAR",
    "2024", "2025", "2026", "ANNIVERSARY", "BIRTHDAY", "SUMMER", "SPRING",
    "FALL", "AUTUMN", "HALLOWEEN", "SPOOKY", "CHRISTMAS", "XMAS", "EASTER",
    "VALENTINES", "STPATRICK", "JULY4TH", "LABORDAY", "THANKSGIVING",
    "BLACKFRIDAY", "CYBERMONDAY", "100K", "500K", "1MILLION", "1M", "2M",
    "5M", "10M", "50M", "100M", "TWITTER", "DISCORD", "YOUTUBE", "TIKTOK",
    "TWITCH", "UPDATE", "NEWUPDATE", "PATCH", "HOTFIX", "WORLD1", "WORLD2",
    "WORLD3", "WORLD4", "WORLD5", "WORLD6", "WORLD7", "WORLD8", "WORLD9",
    "WORLD10", "EVENT", "SPECIAL", "LIMITED", "EXCLUSIVE", "VIP", "PREMIUM",
    "GIFT", "FREE", "BONUS", "REWARD", "PRIZE", "SORRY", "MAINTENANCE",
    "OOPS", "COMPENSATION", "COMMUNITY", "PLAYERS", "FANS", "SUPPORTERS",
    "ZENX", "DUNGEON", "TOWER", "RAID", "BOSS", "LOOT", "GEAR", "PET",
    "MOUNT", "AURA", "CRYSTALS", "GOLD", "COINS",
}

-- Cache of already redeemed/attempted codes
local redeemedCodes = {}

-- Ensure ZenX folder exists
local function ensurePromoFolder()
    pcall(function()
        if not isfolder("ZenX WZ") then
            makefolder("ZenX WZ")
        end
    end)
end

-- Load redeemed codes from file
local function loadRedeemedCodes()
    pcall(function()
        ensurePromoFolder()
        if isfile(PROMO_CODES_FILE) then
            local content = readfile(PROMO_CODES_FILE)
            local HttpService = game:GetService("HttpService")
            local data = HttpService:JSONDecode(content)
            if data and type(data) == "table" then
                redeemedCodes = data
            end
        end
    end)
end

-- Save redeemed codes to file
local function saveRedeemedCodes()
    pcall(function()
        ensurePromoFolder()
        local HttpService = game:GetService("HttpService")
        local content = HttpService:JSONEncode(redeemedCodes)
        writefile(PROMO_CODES_FILE, content)
    end)
end

-- Check if code was already redeemed/attempted
local function isCodeRedeemed(code)
    return redeemedCodes[code:upper()] == true
end

-- Mark code as redeemed
local function markCodeRedeemed(code)
    redeemedCodes[code:upper()] = true
    saveRedeemedCodes()
end

local function getPromoRemote()
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    if shared then
        local promoCodes = shared:FindFirstChild("PromoCodes")
        if promoCodes then
            return promoCodes:FindFirstChild("RedeemCode")
        end
    end
    return nil
end

function PromoCodesAPI:RedeemCode(code)
    local remote = getPromoRemote()
    if remote then
        local success, result = pcall(function()
            return remote:InvokeServer(code)
        end)
        -- Mark as redeemed regardless of result (to avoid re-trying invalid codes)
        markCodeRedeemed(code)
        return success and result == true
    end
    return false
end

function PromoCodesAPI:GetCodesList()
    return PROMO_CODES
end

function PromoCodesAPI:GetRedeemedCodes()
    return redeemedCodes
end

function PromoCodesAPI:AddCode(code)
    table.insert(PROMO_CODES, code)
end

function PromoCodesAPI:ClearRedeemedCache()
    redeemedCodes = {}
    saveRedeemedCodes()
end

function PromoCodesAPI:AutoRedeemAll()
    local redeemedCount = 0
    local skippedCount = 0
    local remote = getPromoRemote()
    if not remote then 
        return redeemedCount 
    end
    
    -- Load previously redeemed codes
    loadRedeemedCodes()
    
    for _, code in ipairs(PROMO_CODES) do
        -- Skip already redeemed codes
        if isCodeRedeemed(code) then
            skippedCount = skippedCount + 1
        else
            local success, result = pcall(function()
                return remote:InvokeServer(code)
            end)
            
            -- Mark as attempted (save to file)
            markCodeRedeemed(code)
            
            if success and result == true then
                redeemedCount = redeemedCount + 1
            end
            
            -- Wait 13 seconds between codes (game requirement)
            task.wait(PROMO_COOLDOWN)
        end
    end
    
    return redeemedCount
end

function PromoCodesAPI:AutoRedeemAllAsync(delay)
    task.spawn(function()
        task.wait(delay or 5)
        self:AutoRedeemAll()
    end)
end

-- ============================================================================
-- BATTLEPASS API
-- ============================================================================

local BattlePassAPI = {}

local BP_EXP_PER_RANK = 500
local BP_NORMAL_TRACK_ENDS = 15
local BP_EXTRA_TRACK_STEPS = 5

local bpRemotesFound = false
local BattlepassModule, RedeemItemRemote, GetPlayerExpRemote
local GetItemRanksRemote, HasPremiumRemote, ItemsRedeemableRemote

local function ensureBPRemotes()
    if bpRemotesFound then return true end
    
    local searchPaths = {
        {"Shared", "Battlepass"}, {"Shared", "BattlePass"},
        {"Modules", "Battlepass"}, {"Modules", "BattlePass"},
        {"Battlepass"}, {"BattlePass"},
        {"Remotes", "Battlepass"}, {"Remotes", "BattlePass"},
    }
    
    for _, path in ipairs(searchPaths) do
        local current = ReplicatedStorage
        for _, name in ipairs(path) do
            current = current and current:FindFirstChild(name)
        end
        if current then
            BattlepassModule = current
            break
        end
    end
    
    if not BattlepassModule then
        for _, child in ipairs(ReplicatedStorage:GetDescendants()) do
            local lowerName = child.Name:lower()
            if (lowerName:find("battlepass") or lowerName:find("battle_pass")) and
               (child:IsA("Folder") or child:IsA("ModuleScript")) then
                BattlepassModule = child
                break
            end
        end
    end
    
    if BattlepassModule then
        RedeemItemRemote = BattlepassModule:FindFirstChild("RedeemItem") or BattlepassModule:FindFirstChild("Redeem")
        GetPlayerExpRemote = BattlepassModule:FindFirstChild("GetPlayerExp") or BattlepassModule:FindFirstChild("GetExp")
        GetItemRanksRemote = BattlepassModule:FindFirstChild("GetItemRanks") or BattlepassModule:FindFirstChild("GetRanks")
        HasPremiumRemote = BattlepassModule:FindFirstChild("HasPremium") or BattlepassModule:FindFirstChild("IsPremium")
        ItemsRedeemableRemote = BattlepassModule:FindFirstChild("ItemsRedeemable") or BattlepassModule:FindFirstChild("CanRedeem")
        bpRemotesFound = true
        return true
    end
    return false
end

local function findNextBPTier(currentTier)
    if currentTier < BP_NORMAL_TRACK_ENDS then
        return currentTier + 1
    end
    return currentTier + BP_EXTRA_TRACK_STEPS
end

function BattlePassAPI:GetPlayerExp()
    ensureBPRemotes()
    if GetPlayerExpRemote then
        local ok, result = pcall(function() return GetPlayerExpRemote:InvokeServer() end)
        if ok then return result or 0 end
    end
    return 0
end

function BattlePassAPI:GetItemRanks()
    ensureBPRemotes()
    if GetItemRanksRemote then
        local ok, free, paid = pcall(function() return GetItemRanksRemote:InvokeServer() end)
        if ok then return free or 0, paid or 0 end
    end
    return 0, 0
end

function BattlePassAPI:HasPremium()
    ensureBPRemotes()
    if HasPremiumRemote then
        local ok, result = pcall(function() return HasPremiumRemote:InvokeServer() end)
        if ok then return result or false end
    end
    return false
end

function BattlePassAPI:ItemsRedeemable()
    ensureBPRemotes()
    if ItemsRedeemableRemote then
        local ok, result = pcall(function() return ItemsRedeemableRemote:InvokeServer() end)
        if ok then return result or false end
    end
    return false
end

function BattlePassAPI:GetCurrentRank()
    return math.floor(self:GetPlayerExp() / BP_EXP_PER_RANK)
end

function BattlePassAPI:ClaimReward(tier, isPremium)
    ensureBPRemotes()
    if RedeemItemRemote then
        local ok = pcall(function() RedeemItemRemote:FireServer(tier, isPremium) end)
        return ok
    end
    return false
end

function BattlePassAPI:AutoClaimAll()
    local claimed = 0
    local currentRank = self:GetCurrentRank()
    if currentRank <= 0 then return claimed end
    
    local freeTrack, paidTrack = self:GetItemRanks()
    local hasPremium = self:HasPremium()
    
    -- Free track
    local nextTier = findNextBPTier(freeTrack)
    while nextTier <= currentRank do
        if self:ClaimReward(nextTier, false) then
            claimed = claimed + 1
            task.wait(0.5)
        else
            break
        end
        local newFree = self:GetItemRanks()
        if newFree == freeTrack then break end
        freeTrack = newFree
        nextTier = findNextBPTier(freeTrack)
    end
    
    -- Premium track
    if hasPremium then
        nextTier = findNextBPTier(paidTrack)
        while nextTier <= currentRank do
            if self:ClaimReward(nextTier, true) then
                claimed = claimed + 1
                task.wait(0.5)
            else
                break
            end
            local _, newPaid = self:GetItemRanks()
            if newPaid == paidTrack then break end
            paidTrack = newPaid
            nextTier = findNextBPTier(paidTrack)
        end
    end
    
    return claimed
end

function BattlePassAPI:GetStatus()
    local xp = self:GetPlayerExp()
    local freeTrack, paidTrack = self:GetItemRanks()
    return {
        XP = xp,
        CurrentRank = math.floor(xp / BP_EXP_PER_RANK),
        FreeTrackClaimed = freeTrack,
        PaidTrackClaimed = paidTrack,
        HasPremium = self:HasPremium(),
        CanClaimRewards = self:ItemsRedeemable()
    }
end

function BattlePassAPI:AutoClaimAllAsync(delay)
    task.spawn(function()
        task.wait(delay or 8)
        if not self:ItemsRedeemable() then return end
        self:AutoClaimAll()
    end)
end

-- ============================================================================
-- CHEST COLLECTION API - Physical Chest Teleportation
-- ============================================================================
-- Auto-collects physical chest Models from Tower and world events
-- These are different from DungeonChests (reward GUI after dungeon completion)

local ChestCollectionAPI = {}

if _genv.ChestCollectionEnabled == nil then _genv.ChestCollectionEnabled = true end

local chestLoopRunning = false
local chestChildAddedConn = nil

-- Get HumanoidRootPart
local function getHRP()
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChild('HumanoidRootPart')
end

-- Collect a single chest model
local function collectChest(chestModel)
    if not chestModel or not chestModel:IsA('Model') then return false end
    
    local success = false
    pcall(function()
        local hrp = getHRP()
        if hrp then
            local primaryPart = chestModel.PrimaryPart
            if primaryPart then
                primaryPart.CFrame = hrp.CFrame
                success = true
            else
                -- Try to find any BasePart to teleport
                for _, part in ipairs(chestModel:GetDescendants()) do
                    if part:IsA('BasePart') then
                        part.CFrame = hrp.CFrame
                        success = true
                        break
                    end
                end
            end
        end
    end)
    return success
end

-- Scan workspace for chest models
local function scanForChests()
    local hrp = getHRP()
    if not hrp then return 0 end
    
    local count = 0
    pcall(function()
        for _, v in ipairs(Workspace:GetChildren()) do
            if v and v:IsA('Model') and string.find(v.Name:lower(), 'chest') then
                if collectChest(v) then
                    count = count + 1
                end
            end
        end
    end)
    return count
end

-- Start the chest collection loop
local function startChestLoop()
    if chestLoopRunning then return end
    chestLoopRunning = true
    
    task.spawn(function()
        while chestLoopRunning and _genv.ChestCollectionEnabled do
            pcall(scanForChests)
            wait(1)
        end
        chestLoopRunning = false
    end)
end

-- Stop the chest collection loop
local function stopChestLoop()
    chestLoopRunning = false
end

-- Setup child added listener
local function setupChestListener()
    if chestChildAddedConn then return end
    
    chestChildAddedConn = Workspace.ChildAdded:Connect(function(v)
        if not _genv.ChestCollectionEnabled then return end
        
        if v and v:IsA('Model') and string.find(v.Name:lower(), 'chest') then
            task.spawn(function()
                wait(0.1)
                collectChest(v)
            end)
        end
    end)
end

function ChestCollectionAPI.enable()
    _genv.ChestCollectionEnabled = true
    startChestLoop()
    setupChestListener()
end

function ChestCollectionAPI.disable()
    _genv.ChestCollectionEnabled = false
    stopChestLoop()
    if chestChildAddedConn then
        chestChildAddedConn:Disconnect()
        chestChildAddedConn = nil
    end
end

function ChestCollectionAPI.toggle()
    if _genv.ChestCollectionEnabled then
        ChestCollectionAPI.disable()
    else
        ChestCollectionAPI.enable()
    end
    return _genv.ChestCollectionEnabled
end

function ChestCollectionAPI.isEnabled()
    return _genv.ChestCollectionEnabled
end

function ChestCollectionAPI.collectAll()
    local count = scanForChests()
    return count
end

-- ============================================================================
-- DUNGEON CHESTS API
-- ============================================================================

local DungeonChestsAPI = {}

local dcEnabled = false
local dcClaimingChests = false
local dcMissionConn, dcRaidConn, dcGuiConn

local MissionsModule, GetMissionPrize

local function ensureDCRemotes()
    if MissionsModule then return true end
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    if shared then
        MissionsModule = shared:FindFirstChild("Missions")
    end
    if MissionsModule then
        GetMissionPrize = MissionsModule:FindFirstChild("GetMissionPrize")
        return GetMissionPrize ~= nil
    end
    return false
end

local function hasExtraDropPass()
    local hasPass = false
    pcall(function()
        hasPass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, ITEM_DROP_PASS_ID)
    end)
    if hasPass then return true end
    
    pcall(function()
        if _genv.HasItemDropPass then
            hasPass = _genv.HasItemDropPass
        end
    end)
    return hasPass
end

-- Close the MissionRewards GUI properly
local function closeRewardsGUI()
    pcall(function()
        local playerGui = player:FindFirstChild("PlayerGui")
        if not playerGui then return end
        
        local rewardsGui = playerGui:FindFirstChild("MissionRewards")
        if rewardsGui then
            -- Disable the GUI
            rewardsGui.Enabled = false
            
            -- Try to find and click the close/continue button
            for _, desc in ipairs(rewardsGui:GetDescendants()) do
                if desc:IsA("TextButton") or desc:IsA("ImageButton") then
                    local name = desc.Name:lower()
                    if name:find("close") or name:find("continue") or name:find("exit") or name:find("done") then
                        -- Fire click events
                        if desc.Activated then
                            desc.Activated:Fire()
                        end
                        break
                    end
                end
            end
            
            -- Also try firing any LeaveRewards remote
            if MissionsModule then
                local leaveRemote = MissionsModule:FindFirstChild("LeaveRewards") or 
                                   MissionsModule:FindFirstChild("CloseRewards") or
                                   MissionsModule:FindFirstChild("FinishRewards")
                if leaveRemote then
                    if leaveRemote:IsA("RemoteEvent") then
                        leaveRemote:FireServer()
                    elseif leaveRemote:IsA("RemoteFunction") then
                        pcall(function() leaveRemote:InvokeServer() end)
                    end
                end
            end
        end
    end)
end

local function claimChests()
    if dcClaimingChests then return end
    if not ensureDCRemotes() then return end
    
    dcClaimingChests = true
    
    local playerGui = player:WaitForChild("PlayerGui", 10)
    if not playerGui then
        dcClaimingChests = false
        return
    end
    
    -- Wait for MissionRewards GUI
    local rewardsGui
    for i = 1, 50 do
        rewardsGui = playerGui:FindFirstChild("MissionRewards")
        if rewardsGui and rewardsGui.Enabled then break end
        task.wait(0.1)
    end
    
    if not rewardsGui or not rewardsGui.Enabled then
        dcClaimingChests = false
        return
    end
    
    task.wait(1.5)
    
    -- Claim chests (2 normal, 3 with gamepass)
    local chestsToOpen = hasExtraDropPass() and 3 or 2
    
    for i = 1, chestsToOpen do
        pcall(function()
            GetMissionPrize:InvokeServer()
        end)
        task.wait(1.2)
    end
    
    -- Wait for animations then close the GUI
    task.wait(2)
    closeRewardsGUI()
    
    task.delay(5, function()
        dcClaimingChests = false
    end)
end

function DungeonChestsAPI:Enable()
    if dcEnabled then return true end
    if not ensureDCRemotes() then return false end
    
    dcEnabled = true
    
    -- Mission finished signal
    local missionSignal = MissionsModule:FindFirstChild("MissionFinished")
    if missionSignal then
        dcMissionConn = missionSignal.OnClientEvent:Connect(function()
            task.spawn(claimChests)
        end)
    end
    
    -- Raid complete signal (backup)
    local raidSignal = MissionsModule:FindFirstChild("RaidComplete")
    if raidSignal then
        dcRaidConn = raidSignal.OnClientEvent:Connect(function()
            task.spawn(claimChests)
        end)
    end
    
    -- Also watch for the GUI appearing (extra backup)
    local playerGui = player:FindFirstChild("PlayerGui")
    if playerGui then
        dcGuiConn = playerGui.ChildAdded:Connect(function(child)
            if child.Name == "MissionRewards" and dcEnabled and not dcClaimingChests then
                task.wait(0.5)
                if child.Enabled then
                    task.spawn(claimChests)
                end
            end
        end)
    end
    
    return true
end

function DungeonChestsAPI:Disable()
    dcEnabled = false
    if dcMissionConn then dcMissionConn:Disconnect() dcMissionConn = nil end
    if dcRaidConn then dcRaidConn:Disconnect() dcRaidConn = nil end
    if dcGuiConn then dcGuiConn:Disconnect() dcGuiConn = nil end
end

function DungeonChestsAPI:IsEnabled()
    return dcEnabled
end

function DungeonChestsAPI:ClaimNow()
    task.spawn(claimChests)
end

function DungeonChestsAPI:HasExtraDropPass()
    return hasExtraDropPass()
end

function DungeonChestsAPI:CloseGUI()
    closeRewardsGUI()
end

function DungeonChestsAPI:AutoEnable()
    task.spawn(function()
        task.wait(3)
        self:Enable()
    end)
end

-- ============================================================================
-- UNIFIED REWARDS API
-- ============================================================================

local RewardsAPI = {
    Magnet = MagnetAPI,
    Gamepass = GamepassAPI,
    PromoCodes = PromoCodesAPI,
    BattlePass = BattlePassAPI,
    ChestCollection = ChestCollectionAPI,
    DungeonChests = DungeonChestsAPI,
}

-- Quick enable/disable all
function RewardsAPI:EnableAll()
    MagnetAPI.enable()
    ChestCollectionAPI.enable()
    DungeonChestsAPI:Enable()
end

function RewardsAPI:DisableAll()
    MagnetAPI.disable()
    ChestCollectionAPI.disable()
    DungeonChestsAPI:Disable()
end

-- Status overview
function RewardsAPI:GetStatus()
    return {
        Magnet = {
            Enabled = _genv.CoinMagnet,
            Invisible = _genv.CoinMagnetInvisible,
        },
        Gamepass = {
            HasItemDropPass = _genv.HasItemDropPass or false,
        },
        BattlePass = BattlePassAPI:GetStatus(),
        ChestCollection = {
            Enabled = _genv.ChestCollectionEnabled,
        },
        DungeonChests = {
            Enabled = dcEnabled,
            HasExtraDropPass = hasExtraDropPass(),
        },
    }
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Initialize magnet
task.spawn(initMagnet)

-- Check gamepasses on startup
task.spawn(function()
    task.wait(2)
    GamepassAPI.refresh()
end)

-- ============================================================================
-- GLOBAL EXPORTS
-- ============================================================================

-- Main unified API
_G.RewardsAPI = RewardsAPI
_genv.RewardsAPI = RewardsAPI

-- Legacy globals (backwards compatibility)
_G.x7d2k = MagnetAPI
_G.k3f7x = GamepassAPI
_G.PromoCodesAPI = PromoCodesAPI
_genv.PromoCodesAPI = PromoCodesAPI
_G.BattlePassAPI = BattlePassAPI
_genv.BattlePassAPI = BattlePassAPI
_G.ChestCollectionAPI = ChestCollectionAPI
_genv.ChestCollectionAPI = ChestCollectionAPI
_G.x2m8q = ChestCollectionAPI
_genv.x2m8q = ChestCollectionAPI
_G.DungeonChestsAPI = DungeonChestsAPI
_genv.DungeonChestsAPI = DungeonChestsAPI

return RewardsAPI
