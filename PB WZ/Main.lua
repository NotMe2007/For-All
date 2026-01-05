-- ============================================================================
-- ZenX GUI - Kill Aura + Magnet Controller + Auto Farm
-- ============================================================================
-- Modern dark theme with neon accents, smooth animations, and sleek design
-- Loads the Kill Aura API and Magnet API
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/Main.lua"))()
--
-- SECURITY FEATURES:
-- • Protected calls (pcall) for all critical operations
-- • Randomized variable names to prevent detection
-- • World Zero game validation before execution
-- • Safe API loading with fallback mechanisms
--
-- PERFORMANCE OPTIMIZATIONS:
-- • Efficient service caching
-- • Optimized polling intervals
-- • Lazy loading of API modules
-- • Memory-efficient GUI rendering
-- ============================================================================

-- ============================================================================
-- WAIT FOR GAME TO FULLY LOAD
-- ============================================================================
if not game:IsLoaded() then
    game.Loaded:Wait()
end
task.wait(2) -- Extra delay for all services to initialize

-- ============================================================================
-- GUI VERSION (Easy to modify)
local GUI_VERSION = 'V-b.0.7.T'
-- ============================================================================
-- TELEPORT PERSISTENCE (Only runs after server hops, not on other games)
-- ============================================================================
pcall(function()
    -- Only set up for World Zero (GameId: 985731078)
    if game.GameId ~= 985731078 then return end
    
    local LOADSTRING_URL = "https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/Main.lua"
    -- Wait for game to fully load before running the script
    local LOADSTRING_CODE = [[
        if not game:IsLoaded() then game.Loaded:Wait() end
        task.wait(2)
        loadstring(game:HttpGet("]] .. LOADSTRING_URL .. [["))()
    ]]
    
    -- Use queue_on_teleport - this queues the script to run ONLY after a teleport
    -- It does NOT run on game launch, only when teleporting between servers
    if queue_on_teleport then
        queue_on_teleport(LOADSTRING_CODE)
    elseif syn and syn.queue_on_teleport then
        syn.queue_on_teleport(LOADSTRING_CODE)
    elseif fluxus and fluxus.queue_on_teleport then
        fluxus.queue_on_teleport(LOADSTRING_CODE)
    end
end)

-- ============================================================================
-- ANTI-DETECTION PATCH (Run FIRST)
-- ============================================================================
-- For full anti-cheat documentation, see Tests/anticheat.lua
-- This section disables client-side detection mechanisms that could flag the GUI
--
-- Key patches applied:
-- • MedalClipper.TriggerClip - Disabled (prevents detection clip triggering)
-- • Promise module - Destroyed (prevents async detection callbacks)
-- • debug.traceback - Blocked (prevents stack trace analysis for detection)
-- • Client.Streaming - Optional disable (DISABLE_CLIENT_STREAMING flag)
--
-- See anticheat.lua for server-side detection systems (Combat module, etc.)
-- ============================================================================

-- Performance/config flags
-- Set to true ONLY if you explicitly want to disable client streaming.
-- Disabling streaming can dramatically increase visible instances and hurt FPS.
local DISABLE_CLIENT_STREAMING = false

local success = pcall(function()
    local ReplicatedStorage = game:GetService('ReplicatedStorage')
    
    -- Disable MedalClipper
    pcall(function()
        local util = ReplicatedStorage:FindFirstChild('Util')
        if util then
            local medalClipper = util:FindFirstChild('MedalClipper')
            if medalClipper then
                if medalClipper:FindFirstChild('TriggerClip') then
                    medalClipper.TriggerClip:Destroy()
                end
                pcall(function()
                    local mockModule = require(medalClipper)
                    if mockModule and mockModule.TriggerClip then
                        mockModule.TriggerClip = function() end
                    end
                end)
            end
        end
    end)
    
    -- Disable entire Promise module
    pcall(function()
        local util = ReplicatedStorage:FindFirstChild('Util')
        if util then
            local promiseUtil = util:FindFirstChild('Promise')
            if promiseUtil then
                for _, child in ipairs(promiseUtil:GetChildren()) do
                    pcall(function() child:Destroy() end)
                end
                promiseUtil:Destroy()
            end
        end
    end)
    
    -- Preserve Client.Streaming by default to avoid loading excessive content
    -- Destroying Streaming can cause huge FRM Visible counts and FPS drops.
    if DISABLE_CLIENT_STREAMING then
        pcall(function()
            local client = ReplicatedStorage:FindFirstChild('Client')
            if client then
                local streaming = client:FindFirstChild('Streaming')
                if streaming then
                    streaming:Destroy()
                end
            end
        end)
    end
end)

-- Block debug.traceback from being used in detection
pcall(function()
    local originalTraceback = debug.traceback
    debug.traceback = function()
        return ""
    end
end)

-- ============================================================================
-- WORLD ZERO GAME VALIDATION
-- ============================================================================

local WORLD_ZERO_GAME_ID = 985731078  -- World Zero Experience ID (Updated)

-- Validate game environment before execution
if game.GameId ~= WORLD_ZERO_GAME_ID then
    return warn("[ZenX] ⚠️ Security: This script only works in World Zero! Current GameId: " .. tostring(game.GameId))
end

-- Verify required services are available
local requiredServices = {"Players", "RunService", "UserInputService", "TweenService"}
for _, serviceName in ipairs(requiredServices) do
    local success, service = pcall(function() return game:GetService(serviceName) end)
    if not success or not service then
        return warn("[ZenX] ⚠️ Security: Required service '" .. serviceName .. "' is not available!")
    end
end

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')
local TweenService = game:GetService('TweenService')
local TeleportService = game:GetService('TeleportService')
local HttpService = game:GetService('HttpService')
local _genv = getgenv()

-- ============================================================================
-- SETTINGS API - Skip Cutscenes and other game settings
-- ============================================================================

local SettingsAPI = {}

local SettingsModule = nil
local SetSkipCutscenesRemote = nil

local function ensureSettingsRemotes()
    if SettingsModule then return true end
    
    local shared = game:GetService('ReplicatedStorage'):FindFirstChild("Shared")
    if shared then
        SettingsModule = shared:FindFirstChild("Settings")
    end
    
    if SettingsModule then
        SetSkipCutscenesRemote = SettingsModule:FindFirstChild("SetSkipCutscenes")
        return true
    end
    return false
end

function SettingsAPI:EnableSkipCutscenes()
    if not ensureSettingsRemotes() then return false end
    
    local success = false
    pcall(function()
        if SetSkipCutscenesRemote then
            SetSkipCutscenesRemote:FireServer(true)
            success = true
        end
    end)
    
    return success
end

function SettingsAPI:DisableSkipCutscenes()
    if not ensureSettingsRemotes() then return false end
    
    local success = false
    pcall(function()
        if SetSkipCutscenesRemote then
            SetSkipCutscenesRemote:FireServer(false)
            success = true
        end
    end)
    
    return success
end

function SettingsAPI:IsSkipCutscenesEnabled()
    if not ensureSettingsRemotes() then return false end
    
    local player = Players.LocalPlayer
    if not player then return false end
    
    local enabled = false
    pcall(function()
        local Settings = require(SettingsModule)
        if Settings and Settings.GetSkipCutscene then
            enabled = Settings:GetSkipCutscene(player)
        end
    end)
    
    return enabled
end

function SettingsAPI:AutoEnableSkipCutscenes()
    task.spawn(function()
        task.wait(2)
        if not self:IsSkipCutscenesEnabled() then
            self:EnableSkipCutscenes()
        end
    end)
end

-- Expose to global
_G.SettingsAPI = SettingsAPI
_genv.SettingsAPI = SettingsAPI

-- ============================================================================
-- ZENX FILE SYSTEM - Centralized folder management
-- ============================================================================

local ZENX_FOLDER = "ZenX WZ"
local DEBUG_WEBHOOK_URL = "https://discord.com/api/webhooks/1455512026297405553/BfDwZ_JAggrumBWHZAIupS5K1Bx8jCWSuEjMj_H2D-SNpneVFKfP7TRVkTzaeWbtfwji"
local DEBUG_FILE = ZENX_FOLDER .. "/debug.log"
local debugLineCount = 0
local MAX_DEBUG_LINES_BEFORE_WEBHOOK = 100

-- Create ZenX folder if it doesn't exist
local function ensureZenXFolder()
    if not isfolder then return false end
    
    local success = pcall(function()
        if not isfolder(ZENX_FOLDER) then
            makefolder(ZENX_FOLDER)
        end
    end)
    
    return success
end

-- Get full path for a file in ZenX folder
local function getZenXPath(filename)
    return ZENX_FOLDER .. "/" .. filename
end

-- Initialize folder on load
ensureZenXFolder()

-- ============================================================================
-- ZENX DEBUG SYSTEM - Logging with webhook support
-- ============================================================================

local ZenXDebug = {}
ZenXDebug.enabled = true
ZenXDebug.logs = {}

-- Send debug logs to webhook
local function sendDebugWebhook()
    if not ZenXDebug.enabled then return end
    if #ZenXDebug.logs == 0 then return end
    
    local success = pcall(function()
        local player = Players.LocalPlayer
        local playerName = player and player.Name or "Unknown"
        local userId = player and player.UserId or 0
        
        -- Build log content (last 100 lines)
        local logContent = table.concat(ZenXDebug.logs, "\n")
        
        -- Truncate if too long for Discord embed
        if #logContent > 3900 then
            logContent = "...[truncated]...\n" .. string.sub(logContent, -3800)
        end
        
        local webhookData = {
            username = "ZenX Debug",
            embeds = {{
                title = "🔧 ZenX Debug Log",
                description = "```\n" .. logContent .. "\n```",
                color = 3447003,
                fields = {
                    { name = "Player", value = playerName, inline = true },
                    { name = "UserID", value = tostring(userId), inline = true },
                    { name = "Lines", value = tostring(#ZenXDebug.logs), inline = true },
                },
                footer = { text = "ZenX WZ Debug System" },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }}
        }
        
        local jsonBody = HttpService:JSONEncode(webhookData)
        
        -- Use request/http_request/syn.request depending on executor
        if request then
            request({
                Url = DEBUG_WEBHOOK_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = jsonBody
            })
        elseif http_request then
            http_request({
                Url = DEBUG_WEBHOOK_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = jsonBody
            })
        elseif syn and syn.request then
            syn.request({
                Url = DEBUG_WEBHOOK_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = jsonBody
            })
        end
        
        -- Clear logs after sending
        ZenXDebug.logs = {}
        debugLineCount = 0
    end)
end

-- Write to debug file and check for webhook
local function writeDebugToFile()
    if not writefile then return end
    
    pcall(function()
        ensureZenXFolder()
        local content = table.concat(ZenXDebug.logs, "\n")
        writefile(DEBUG_FILE, content)
    end)
end

-- Main debug log function
function ZenXDebug.log(category, message)
    if not ZenXDebug.enabled then return end
    
    local timestamp = os.date("%H:%M:%S")
    local logLine = string.format("[%s] [%s] %s", timestamp, category, tostring(message))
    
    table.insert(ZenXDebug.logs, logLine)
    debugLineCount = debugLineCount + 1
    
    -- Write to file
    writeDebugToFile()
    
    -- Send webhook every 100 lines
    if debugLineCount >= MAX_DEBUG_LINES_BEFORE_WEBHOOK then
        sendDebugWebhook()
    end
end

-- Convenience methods
function ZenXDebug.info(message) ZenXDebug.log("INFO", message) end
function ZenXDebug.warn(message) ZenXDebug.log("WARN", message) end
function ZenXDebug.error(message) ZenXDebug.log("ERROR", message) end
function ZenXDebug.success(message) ZenXDebug.log("SUCCESS", message) end

-- Force send webhook (for critical events)
function ZenXDebug.flush()
    if #ZenXDebug.logs > 0 then
        sendDebugWebhook()
    end
end

-- Export globally
_G.ZenXDebug = ZenXDebug
_G.ZenXFolder = ZENX_FOLDER
_G.getZenXPath = getZenXPath
_G.ensureZenXFolder = ensureZenXFolder

-- Log script start
ZenXDebug.info("ZenX WZ Script Started")
ZenXDebug.info("Player: " .. (Players.LocalPlayer and Players.LocalPlayer.Name or "Unknown"))

-- ============================================================================
-- AUTO-ENABLE SKIP CUTSCENES SETTING
-- ============================================================================
-- PLACE DETECTION API (Load early so other APIs can use it)
-- ============================================================================
pcall(function()
    -- URL placeholder - add your placeids.lua URL here
    local PLACEIDS_URL = "" -- TODO: Add URL like "https://raw.githubusercontent.com/.../placeids.lua"
    
    if PLACEIDS_URL ~= "" then
        local placeSuccess = pcall(function()
            local script = game:HttpGet(PLACEIDS_URL)
            local placeFunc = loadstring(script)
            if placeFunc then placeFunc() end
        end)
        
        if placeSuccess and _G.x5n3d then
            _G.PlaceAPI = _G.x5n3d
            _genv.PlaceAPI = _G.x5n3d
            ZenXDebug.info("PlaceAPI loaded successfully")
            
            local current = _G.PlaceAPI.getCurrent()
            if current then
                ZenXDebug.info("Current location: " .. (current.name or "Unknown") .. " (" .. current.type .. ")")
            end
        end
    end
end)

-- ============================================================================
-- AUTO-ENABLE SKIP CUTSCENES (via API)
-- ============================================================================
pcall(function()
    local settingsSuccess = pcall(function()
        local script = game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/rewards.lua")
        local settingsFunc = loadstring(script)
        if settingsFunc then settingsFunc() end
    end)
    
    if settingsSuccess and _G.SettingsAPI then
        _G.SettingsAPI:AutoEnableSkipCutscenes()
    end
end)

-- ============================================================================
-- UNIFIED REWARDS API (Magnet, Promo Codes, BattlePass, Dungeon Chests)
-- ============================================================================
pcall(function()
    local rewardsSuccess = pcall(function()
        local script = game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/rewards.lua")
        local rewardsFunc = loadstring(script)
        if rewardsFunc then rewardsFunc() end
    end)
    
    if rewardsSuccess and _G.RewardsAPI then
        ZenXDebug.info("RewardsAPI loaded successfully")
        
        -- Auto-enable coin magnet (already enabled by default)
        if _G.RewardsAPI.Magnet then
            _G.RewardsAPI.Magnet.enable()
            _G.RewardsAPI.Magnet.setInvisible(true) -- Hide coins to reduce mobile lag
            ZenXDebug.info("Coin Magnet enabled (invisible mode)")
        end
        
        -- Auto-enable physical chest collection (Tower/World chests)
        if _G.ChestCollectionAPI or _G.RewardsAPI.ChestCollection then
            local chestAPI = _G.ChestCollectionAPI or _G.RewardsAPI.ChestCollection
            chestAPI.enable()
            ZenXDebug.info("Chest Collection enabled (auto-teleport chests)")
        end
        
        -- Auto-enable dungeon chest claiming
        if _G.DungeonChestsAPI then
            _G.DungeonChestsAPI:AutoEnable()
            ZenXDebug.info("Dungeon Chests auto-claim enabled")
        end
        
        -- Auto-redeem promo codes in background (13s cooldown, 5s initial delay)
        -- Codes are saved to file so they won't be re-tried
        if _G.PromoCodesAPI then
            _G.PromoCodesAPI:AutoRedeemAllAsync(5) -- 5s delay before starting
            ZenXDebug.info("Promo Codes auto-redeem started (skips already-tried codes)")
        end
        
        -- Auto-claim battle pass rewards in background
        if _G.BattlePassAPI then
            _G.BattlePassAPI:AutoClaimAllAsync(8) -- 8s delay
            ZenXDebug.info("BattlePass auto-claim started")
        end
    else
        ZenXDebug.warn("RewardsAPI failed to load, trying individual APIs...")
        
        -- Fallback: try loading individual APIs
        pcall(function()
            local chestsScript = game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/rewards.lua")
            local chestsFunc = loadstring(chestsScript)
            if chestsFunc then chestsFunc() end
            if _G.DungeonChestsAPI then _G.DungeonChestsAPI:AutoEnable() end
        end)
        
        pcall(function()
            local promoScript = game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/rewards.lua")
            local promoFunc = loadstring(promoScript)
            if promoFunc then promoFunc() end
            if _G.PromoCodesAPI then _G.PromoCodesAPI:AutoRedeemAllAsync(13, 5) end
        end)
        
        pcall(function()
            local bpScript = game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/rewards.lua")
            local bpFunc = loadstring(bpScript)
            if bpFunc then bpFunc() end
            if _G.BattlePassAPI then _G.BattlePassAPI:AutoClaimAllAsync(8) end
        end)
    end
end)

-- ============================================================================
-- AUTO-ENABLE SETTINGS (Skip Cutscenes)
-- ============================================================================
pcall(function()
    if _G.SettingsAPI then
        _G.SettingsAPI:AutoEnableSkipCutscenes()
        ZenXDebug.info("Skip Cutscenes auto-enabled")
    end
end)

-- ============================================================================
-- LOAD PERFORMANCE MODE API
-- ============================================================================
pcall(function()
    local perfSuccess = pcall(function()
        local script = game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/rewards.lua")
        local perfFunc = loadstring(script)
        if perfFunc then perfFunc() end
    end)
end)

-- Performance mode wrapper functions (use API if available, fallback to inline)
local function enablePerformanceMode()
    if _G.PerformanceAPI then
        _G.PerformanceAPI:Enable()
    end
end

local function disablePerformanceMode()
    if _G.PerformanceAPI then
        _G.PerformanceAPI:Disable()
    end
end


-- ============================================================================
-- RANDOMIZED NAMING (Anti-Detection)
-- ============================================================================

local function generateRandomName(prefix)
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    local length = math.random(8, 12)
    local result = prefix or ''
    for i = 1, length do
        local rand = math.random(1, #chars)
        result = result .. chars:sub(rand, rand)
    end
    return result
end

-- Generate unique names for this session
local GUI_NAME = generateRandomName('Gui_')
local MAIN_FRAME_NAME = generateRandomName('Frame_')
local TITLE_BAR_NAME = generateRandomName('Title_')
local CONTENT_NAME = generateRandomName('Content_')
local BTN1_NAME = generateRandomName('Btn_')
local BTN2_NAME = generateRandomName('Btn_')

-- Developer mode check (multiple IDs)
local DEVELOPER_IDS = { 3777669667, 2634942179, 1603011852, 10193983575 }
local function isDev(userId)
    for _, id in ipairs(DEVELOPER_IDS) do
        if userId == id then
            return true
        end
    end
    return false
end
local isDeveloper = Players.LocalPlayer and isDev(Players.LocalPlayer.UserId)

--============================================================================
-- KEY VERIFICATION SYSTEM
--============================================================================
-- Simple check: If verified_key.json exists in executor workspace, user is verified.
-- The Junkie loader creates this file after successful key verification.

local KEY_FILE_PATH = "verified_key.json"

-- Check if verified key file exists
local function isKeyVerified()
    -- Already verified this session
    if _G.ZenX_SessionVerified == true then
        return true
    end
    
    -- Check if file exists in executor workspace
    if isfile and isfile(KEY_FILE_PATH) then
        _G.ZenX_SessionVerified = true
        return true
    end
    
    -- Fallback: check readfile
    if readfile then
        local success, content = pcall(function()
            return readfile(KEY_FILE_PATH)
        end)
        if success and content and content ~= "" then
            _G.ZenX_SessionVerified = true
            return true
        end
    end
    
    return false
end

-- Run key verification (skip for developers)
if not isDeveloper then
    if not isKeyVerified() then
        warn("[ZenX] ⚠️ No valid key found!")
        warn("[ZenX] Please run this command first to get a key:")
        warn('loadstring(game:HttpGet("https://api.junkie-development.de/api/v1/luascripts/public/ef2cd821474d60882ccc855716ff1a11c1bcfa0b77cbdffaf96f6a7aa8ffd5a2/download"))()')
        return
    end
end

--============================================================================
-- JUNKIE PROTECTED CONFIGURATION (Legacy/Fallback)
--============================================================================
-- Note: Key verification now handled above
-- Users can still use the loader directly if preferred:
-- loadstring(game:HttpGet("https://api.junkie-development.de/api/v1/luascripts/public/ef2cd821474d60882ccc855716ff1a11c1bcfa0b77cbdffaf96f6a7aa8ffd5a2/download"))()

-- Manual configuration (only needed WITHOUT GUI SDK) 
-- JunkieProtected.API_KEY = "4d00b6fc-8691-4808-9f7b-cd726de7b7c1"
-- JunkieProtected.PROVIDER = "ZenX"
-- JunkieProtected.SERVICE_ID = "WZ"

-- Randomized global keys
local KILL_AURA_KEY = generateRandomName('k')
local MAGNET_KEY = generateRandomName('m')
local AUTOFARM_KEY = generateRandomName('a')
local CHEST_KEY = generateRandomName('c')
local PLACE_KEY = generateRandomName('p')
local AUTODODGE_KEY = generateRandomName('d')
local INFTOWER_KEY = generateRandomName('t')
local AUTOFARM_SETTINGS_KEY = generateRandomName('s')
local KILLAURA_SETTINGS_KEY = generateRandomName('ks')
local AUTOSELL_SETTINGS_KEY = generateRandomName('as')

-- State persistence file
local STATE_FILE_PATH = "ZenX WZ/zenx_state.json"

-- ============================================================================
-- LOAD PLACE DETECTION API
-- ============================================================================

local PlaceAPI = nil

local function loadPlaceAPI()
    -- Try to load from _G if already loaded
    if _G[PLACE_KEY] then
        PlaceAPI = _G[PLACE_KEY]
        updateLocation()
        return true
    end
    if _G.x5n3d then
        PlaceAPI = _G.x5n3d
        _G[PLACE_KEY] = PlaceAPI
        updateLocation()
        return true
    end
    if _G.PlaceAPI then
        PlaceAPI = _G.PlaceAPI
        _G[PLACE_KEY] = PlaceAPI
        updateLocation()
        return true
    end
    
    -- Otherwise, try to load from GitHub via loadstring
    -- URL placeholder - add your placeids.lua URL here
    local PLACEIDS_URL = "" -- TODO: Add URL like "https://raw.githubusercontent.com/.../placeids.lua"
    
    if PLACEIDS_URL ~= "" then
        pcall(function()
            local script = game:HttpGet(PLACEIDS_URL)
            local placeFunc = loadstring(script)
            if placeFunc then
                placeFunc()
                if _G.x5n3d then
                    PlaceAPI = _G.x5n3d
                    _G[PLACE_KEY] = PlaceAPI
                    _G.PlaceAPI = PlaceAPI
                    updateLocation()
                    return true
                end
            end
        end)
    end
    
    return PlaceAPI ~= nil
end

-- Attempt late-load of PlaceAPI if it wasn't available initially
local function checkAndLoadPlaceAPI()
    if PlaceAPI == nil and _G.x5n3d then
        PlaceAPI = _G.x5n3d
        updateLocation()
    end
end

-- ============================================================================
-- PLACEID AND LOCATION DETECTION
-- ============================================================================

local PLACE_ID = game.PlaceId
local currentLocation = nil

local function updateLocation()
    if PlaceAPI then
        currentLocation = PlaceAPI.getCurrent()
    end
end

local function isDungeon()
    if currentLocation then
        return currentLocation.isDungeon
    end
    return false
end

local function isWorldOrTower()
    if currentLocation then
        return currentLocation.isLobby or currentLocation.isTower
    end
    return true -- Default to enabled
end

-- ============================================================================
-- LOAD KILL AURA API
-- ============================================================================

local KillAuraAPI = nil

local function loadKillAura()
    -- Try to load from _G if already loaded
    if _G[KILL_AURA_KEY] then
        KillAuraAPI = _G[KILL_AURA_KEY]
        return true
    end
    if _G.x9m1n then
        KillAuraAPI = _G.x9m1n
        _G[KILL_AURA_KEY] = KillAuraAPI
        return true
    end
    
    -- Otherwise, try to load from GitHub via loadstring
    pcall(function()
        local script = game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/killaura.lua")
        local killAuraFunc = loadstring(script)
        if killAuraFunc then
            killAuraFunc()
            if _G.x9m1n then
                KillAuraAPI = _G.x9m1n
                _G[KILL_AURA_KEY] = KillAuraAPI
                return true
            end
        end
    end)
    
    return KillAuraAPI ~= nil
end

-- ============================================================================
-- LOAD MAGNET API
-- ============================================================================

local MagnetAPI = nil

local function loadMagnet()
    -- Try to load from _G if already loaded
    if _G[MAGNET_KEY] then
        MagnetAPI = _G[MAGNET_KEY]
        return true
    end
    if _G.x7d2k then
        MagnetAPI = _G.x7d2k
        _G[MAGNET_KEY] = MagnetAPI
        return true
    end
    
    -- Otherwise, try to load from GitHub via loadstring
    pcall(function()
        local script = game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/rewards.lua")
        local magnetFunc = loadstring(script)
        if magnetFunc then
            magnetFunc()
            if _G.x7d2k then
                MagnetAPI = _G.x7d2k
                _G[MAGNET_KEY] = MagnetAPI
                return true
            end
        end
    end)
    
    return MagnetAPI ~= nil
end

-- ============================================================================
-- LOAD AUTO FARM API
-- ============================================================================

local AutoFarmAPI = nil

local function loadAutoFarm()
    -- Try to load from _G if already loaded
    if _G[AUTOFARM_KEY] then
        AutoFarmAPI = _G[AUTOFARM_KEY]
        return true
    end
    if _G.x4k7p then
        AutoFarmAPI = _G.x4k7p
        _G[AUTOFARM_KEY] = AutoFarmAPI
        return true
    end
    
    -- Otherwise, try to load from GitHub via loadstring
    pcall(function()
        local script = game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/Autofarm.lua")
        local autoFarmFunc = loadstring(script)
        if autoFarmFunc then
            autoFarmFunc()
            if _G.x4k7p then
                AutoFarmAPI = _G.x4k7p
                _G[AUTOFARM_KEY] = AutoFarmAPI
                return true
            end
        end
    end)
    
    return AutoFarmAPI ~= nil
end

-- ============================================================================
-- LOAD AUTO FARM SETTINGS API
-- ============================================================================

local AutoFarmSettingsAPI = nil

local function loadAutoFarmSettings()
    -- Try to load from _G if already loaded
    if _G[AUTOFARM_SETTINGS_KEY] then
        AutoFarmSettingsAPI = _G[AUTOFARM_SETTINGS_KEY]
        return true
    end
    if _G.AutoFarmSettingsAPI then
        AutoFarmSettingsAPI = _G.AutoFarmSettingsAPI
        _G[AUTOFARM_SETTINGS_KEY] = AutoFarmSettingsAPI
        return true
    end
    
    -- Otherwise, try to load from GitHub via loadstring
    pcall(function()
        local script = game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/autofarmsettingsapi.lua")
        local settingsFunc = loadstring(script)
        if settingsFunc then
            settingsFunc()
            if _G.AutoFarmSettingsAPI then
                AutoFarmSettingsAPI = _G.AutoFarmSettingsAPI
                _G[AUTOFARM_SETTINGS_KEY] = AutoFarmSettingsAPI
                return true
            end
        end
    end)
    
    return AutoFarmSettingsAPI ~= nil
end

-- ============================================================================
-- LOAD KILL AURA SETTINGS API
-- ============================================================================

local KillAuraSettingsAPI = nil

local function loadKillAuraSettings()
    -- Try to load from _G if already loaded
    if _G[KILLAURA_SETTINGS_KEY] then
        KillAuraSettingsAPI = _G[KILLAURA_SETTINGS_KEY]
        return true
    end
    if _G.KillAuraSettingsAPI then
        KillAuraSettingsAPI = _G.KillAuraSettingsAPI
        _G[KILLAURA_SETTINGS_KEY] = KillAuraSettingsAPI
        return true
    end
    
    -- Otherwise, try to load from GitHub via loadstring (obfuscated version)
    pcall(function()
        local script = game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/killaurasettingsapi.lua")
        local settingsFunc = loadstring(script)
        if settingsFunc then
            settingsFunc()
            if _G.KillAuraSettingsAPI then
                KillAuraSettingsAPI = _G.KillAuraSettingsAPI
                _G[KILLAURA_SETTINGS_KEY] = KillAuraSettingsAPI
                return true
            end
        end
    end)
    
    return KillAuraSettingsAPI ~= nil
end

-- ============================================================================
-- LOAD AUTO SELL SETTINGS API
-- ============================================================================

local AutoSellSettingsAPI = nil

local function loadAutoSellSettings()
    -- Try to load from _G if already loaded
    if _G[AUTOSELL_SETTINGS_KEY] then
        AutoSellSettingsAPI = _G[AUTOSELL_SETTINGS_KEY]
        return true
    end
    if _G.AutoSellSettingsAPI then
        AutoSellSettingsAPI = _G.AutoSellSettingsAPI
        _G[AUTOSELL_SETTINGS_KEY] = AutoSellSettingsAPI
        return true
    end
    
    -- Load from local autosellsettings.lua (non-obfuscated version)
    pcall(function()
        local script = game:HttpGet("https://raw.githubusercontent.com/NotMe2007/WZ/main/Tests/autosellsettings.lua")
        local settingsFunc = loadstring(script)
        if settingsFunc then
            settingsFunc()
            if _G.AutoSellSettingsAPI then
                AutoSellSettingsAPI = _G.AutoSellSettingsAPI
                _G[AUTOSELL_SETTINGS_KEY] = AutoSellSettingsAPI
                return true
            end
        end
    end)
    
    return AutoSellSettingsAPI ~= nil
end

-- ============================================================================
-- LOAD AUTO SELL API
-- ============================================================================

local AUTOSELL_KEY = generateRandomName('sell')
local AutoSellAPI = nil

local function loadAutoSell()
    -- Try to load from _G if already loaded
    if _G[AUTOSELL_KEY] then
        AutoSellAPI = _G[AUTOSELL_KEY]
        return true
    end
    if _G.AutoSellAPI then
        AutoSellAPI = _G.AutoSellAPI
        _G[AUTOSELL_KEY] = AutoSellAPI
        return true
    end
    if _G.x8s4v then
        AutoSellAPI = _G.x8s4v
        _G[AUTOSELL_KEY] = AutoSellAPI
        return true
    end
    
    -- Otherwise, try to load from GitHub via loadstring
    pcall(function()
        local script = game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/autosell.lua")
        local sellFunc = loadstring(script)
        if sellFunc then
            sellFunc()
            if _G.AutoSellAPI then
                AutoSellAPI = _G.AutoSellAPI
                _G[AUTOSELL_KEY] = AutoSellAPI
                return true
            end
        end
    end)
    
    return AutoSellAPI ~= nil
end

-- ============================================================================
-- LOAD AUTO BANK API
-- ============================================================================

local AUTOBANK_KEY = generateRandomName('bank')
local AutoBankAPI = nil

local function loadAutoBank()
    -- Try to load from _G if already loaded
    if _G[AUTOBANK_KEY] then
        AutoBankAPI = _G[AUTOBANK_KEY]
        return true
    end
    if _G.BankAPI then
        AutoBankAPI = _G.BankAPI
        _G[AUTOBANK_KEY] = AutoBankAPI
        return true
    end
    if _G.AutoBankAPI then
        AutoBankAPI = _G.AutoBankAPI
        _G[AUTOBANK_KEY] = AutoBankAPI
        return true
    end
    
    -- Otherwise, try to load from GitHub via loadstring
    pcall(function()
        local script = game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/autobank.lua")
        local bankFunc = loadstring(script)
        if bankFunc then
            bankFunc()
            if _G.BankAPI then
                AutoBankAPI = _G.BankAPI
                _G[AUTOBANK_KEY] = AutoBankAPI
                return true
            end
        end
    end)
    
    return AutoBankAPI ~= nil
end

-- ============================================================================
-- LOAD NO POPUP API
-- ============================================================================

local NOPOPUP_KEY = generateRandomName('nopopup')
local NoPopupAPI = nil

local function loadNoPopup()
    -- Try to load from _G if already loaded
    if _G[NOPOPUP_KEY] then
        NoPopupAPI = _G[NOPOPUP_KEY]
        return true
    end
    if _G.NoPopupAPI then
        NoPopupAPI = _G.NoPopupAPI
        _G[NOPOPUP_KEY] = NoPopupAPI
        return true
    end
    
    -- Otherwise, try to load from GitHub via loadstring
    pcall(function()
        local script = game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/NoPopup.lua")
        local popupFunc = loadstring(script)
        if popupFunc then
            popupFunc()
            if _G.NoPopupAPI then
                NoPopupAPI = _G.NoPopupAPI
                _G[NOPOPUP_KEY] = NoPopupAPI
                return true
            end
        end
    end)
    
    return NoPopupAPI ~= nil
end

-- ============================================================================
-- LOAD CHEST COLLECTOR API
-- ============================================================================

local ChestAPI = nil

local function loadChestCollector()
    -- Try to load from _G if already loaded
    if _G[CHEST_KEY] then
        ChestAPI = _G[CHEST_KEY]
        return true
    end
    if _G.x2m8q then
        ChestAPI = _G.x2m8q
        _G[CHEST_KEY] = ChestAPI
        return true
    end
    
    -- Otherwise, try to load from GitHub via loadstring
    pcall(function()
        local script = game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/rewards.lua")
        local chestFunc = loadstring(script)
        if chestFunc then
            chestFunc()
            if _G.x2m8q then
                ChestAPI = _G.x2m8q
                _G[CHEST_KEY] = ChestAPI
                return true
            end
        end
    end)
    
    return ChestAPI ~= nil
end

-- ============================================================================
-- LOAD AUTO DODGE API
-- ============================================================================

local AutoDodgeAPI = nil

local function loadAutoDodge()
    -- Try to load from _G if already loaded
    if _G[AUTODODGE_KEY] then
        AutoDodgeAPI = _G[AUTODODGE_KEY]
        return true
    end
    if _G.x6p9t then
        AutoDodgeAPI = _G.x6p9t
        _G[AUTODODGE_KEY] = AutoDodgeAPI
        return true
    end
    
    -- Otherwise, try to load from GitHub via loadstring
    pcall(function()
        local script = game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/AutoDoge.lua")
        local dodgeFunc = loadstring(script)
        if dodgeFunc then
            dodgeFunc()
            if _G.x6p9t then
                AutoDodgeAPI = _G.x6p9t
                _G[AUTODODGE_KEY] = AutoDodgeAPI
                return true
            end
        end
    end)
    
    return AutoDodgeAPI ~= nil
end

-- ============================================================================
-- AUTO DODGE STABILIZER (Fixes post-dodge flying + lag spikes)
-- ============================================================================

local AutoDodgeStabilizer = {}
do
    local heartbeatConn
    local lastDodgeAt = 0
    local lastGroundY = nil
    local stepGate = 0

    local function getGroundY(hrp)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Blacklist
        params.FilterDescendantsInstances = {hrp}
        local origin = hrp.Position
        local result = workspace:Raycast(origin, Vector3.new(0, -80, 0), params)
        if result then
            return result.Position.Y
        end
        return nil
    end

    local function cameraFailsafe(humanoid)
        local cam = workspace.CurrentCamera
        if cam then
            if cam.CameraType ~= Enum.CameraType.Custom then
                cam.CameraType = Enum.CameraType.Custom
            end
            if cam.CameraSubject ~= humanoid then
                cam.CameraSubject = humanoid
            end
        end
    end

    function AutoDodgeStabilizer.start()
        if heartbeatConn then return end
        heartbeatConn = game:GetService("RunService").Heartbeat:Connect(function(dt)
            stepGate = stepGate + dt
            if stepGate < 1/30 then return end
            stepGate = 0

            local plr = game:GetService("Players").LocalPlayer
            if not plr or not plr.Character then return end
            local char = plr.Character
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum then return end

            cameraFailsafe(hum)

            local v = hrp.AssemblyLinearVelocity
            local speed = v.Magnitude
            if speed > 80 then
                lastDodgeAt = time()
            end

            if math.abs(v.Y) < 10 then
                local gy = getGroundY(hrp)
                if gy then
                    lastGroundY = gy
                end
            end

            if lastDodgeAt > 0 and (time() - lastDodgeAt) >= 0.25 then
                hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                hrp.RotVelocity = Vector3.new(0, 0, 0)
                if lastGroundY and (hrp.Position.Y - lastGroundY) > 6 then
                    hrp.CFrame = CFrame.new(Vector3.new(hrp.Position.X, lastGroundY + 3, hrp.Position.Z), hrp.CFrame.LookVector + hrp.Position)
                end
                lastDodgeAt = 0
            end
        end)
    end

    function AutoDodgeStabilizer.stop()
        if heartbeatConn then
            heartbeatConn:Disconnect()
            heartbeatConn = nil
        end
        lastDodgeAt = 0
        lastGroundY = nil
    end
end

-- If AutoDodgeAPI is present, wrap its enable/disable to include stabilizer
local function patchAutoDodge()
    if not AutoDodgeAPI then return end
    local originalEnable = AutoDodgeAPI.enable
    local originalDisable = AutoDodgeAPI.disable

    if type(originalEnable) == "function" then
        AutoDodgeAPI.enable = function(...)
            local ok, err = pcall(originalEnable, ...)
            if not ok then warn("[ZenX] AutoDodge enable error:", err) end
            AutoDodgeStabilizer.start()
        end
    end

    if type(originalDisable) == "function" then
        AutoDodgeAPI.disable = function(...)
            AutoDodgeStabilizer.stop()
            local ok, err = pcall(originalDisable, ...)
            if not ok then warn("[ZenX] AutoDodge disable error:", err) end
        end
    end
end

-- ============================================================================
-- LOAD KINGSLAYER API
-- ============================================================================

local KingslayerAPI = nil

local function loadKingslayerAPI()
    -- Try to get from global if already loaded
    if _G.KingslayerAPI then
        KingslayerAPI = _G.KingslayerAPI
        return true
    end
    if getgenv().KingslayerAPI then
        KingslayerAPI = getgenv().KingslayerAPI
        return true
    end
    return KingslayerAPI ~= nil
end

-- ============================================================================
-- LOAD TEMPLE OF RUIN API
-- ============================================================================

local TempleofRuinAPI = nil

local function loadTempleofRuinAPI()
    -- Try to get from global if already loaded
    if _G.TempleofRuinAPI then
        TempleofRuinAPI = _G.TempleofRuinAPI
        return true
    end
    if getgenv().TempleofRuinAPI then
        TempleofRuinAPI = getgenv().TempleofRuinAPI
        return true
    end
    return TempleofRuinAPI ~= nil
end

-- ============================================================================
-- LOAD INFINITE TOWER API
-- ============================================================================

local InfTowerAPI = nil

local function loadInfTower()
    -- Try to load from _G if already loaded
    if _G[INFTOWER_KEY] then
        InfTowerAPI = _G[INFTOWER_KEY]
        return true
    end
    if _G.InfTowerAPI then
        InfTowerAPI = _G.InfTowerAPI
        _G[INFTOWER_KEY] = InfTowerAPI
        return true
    end
    
    -- Otherwise, try to load from GitHub via loadstring
    pcall(function()
        local script = game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/InfTower.lua")
        local infTowerFunc = loadstring(script)
        if infTowerFunc then
            infTowerFunc()
            if _G.InfTowerAPI then
                InfTowerAPI = _G.InfTowerAPI
                _G[INFTOWER_KEY] = InfTowerAPI
                return true
            end
        end
    end)
    
    return InfTowerAPI ~= nil
end

-- ============================================================================
-- LOAD KLAUS DUNGEON MAP SCRIPT
-- ============================================================================

local KlausDungeonLoaded = false

local function loadKlausDungeon()
    if KlausDungeonLoaded then return true end
    
    -- Klaus Dungeon Place ID
    local KLAUS_DUNGEON_PLACE_ID = 4526768588 -- Klaus Dungeon
    
    if game.PlaceId == KLAUS_DUNGEON_PLACE_ID then
        pcall(function()
            local script = game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/KlausDugoen.lua")
            local klausFunc = loadstring(script)
            if klausFunc then
                klausFunc()
                KlausDungeonLoaded = true
            end
        end)
    end
    
    return KlausDungeonLoaded
end

-- ============================================================================
-- LOAD KINGSLAYER DUNGEON MAP SCRIPT
-- ============================================================================

local KingslayerDungeonLoaded = false

local function loadKingslayerDungeon()
    if KingslayerDungeonLoaded then return true end
    
    -- Kingslayer Dungeon Place ID
    local KINGSLAYER_DUNGEON_PLACE_ID = 4310478830 -- Kingslayer (1-4)
    
    if game.PlaceId == KINGSLAYER_DUNGEON_PLACE_ID then
        pcall(function()
            local script = game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/Kingslayer.lua")
            local kingslayerFunc = loadstring(script)
            if kingslayerFunc then
                kingslayerFunc()
                KingslayerDungeonLoaded = true
            end
        end)
    end
    
    return KingslayerDungeonLoaded
end

-- ============================================================================
-- LOAD TEMPLE OF RUIN DUNGEON MAP SCRIPT
-- ============================================================================

local TempleofRuinDungeonLoaded = false

local function loadTempleofRuinDungeon()
    if TempleofRuinDungeonLoaded then return true end
    
    -- Temple of Ruin Dungeon Place ID
    local TEMPLEOFRUIN_DUNGEON_PLACE_ID = 3885726701 -- Temple of Ruin (2-1)
    
    if game.PlaceId == TEMPLEOFRUIN_DUNGEON_PLACE_ID then
        pcall(function()
            local script = game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/TempleofRuin.lua")
            local templeofruinFunc = loadstring(script)
            if templeofruinFunc then
                templeofruinFunc()
                TempleofRuinDungeonLoaded = true
            end
        end)
    end
    
    return TempleofRuinDungeonLoaded
end

-- ============================================================================
-- COLOR SCHEME (Vape v4 Style)
-- ============================================================================

local Colors = {
    bg_primary = Color3.fromRGB(15, 15, 15),      -- Almost black
    bg_secondary = Color3.fromRGB(25, 25, 25),    -- Slightly lighter
    accent_main = Color3.fromRGB(0, 255, 100),    -- Neon green
    accent_primary = Color3.fromRGB(0, 255, 100), -- Neon green (alias)
    accent_secondary = Color3.fromRGB(0, 200, 255), -- Neon cyan
    accent_danger = Color3.fromRGB(255, 50, 50),  -- Neon red
    text_primary = Color3.fromRGB(255, 255, 255), -- White
    text_secondary = Color3.fromRGB(150, 150, 150), -- Gray
    border = Color3.fromRGB(40, 40, 40),          -- Dark gray border
}

-- ============================================================================
-- TWEEN ANIMATION HELPER
-- ============================================================================

local function tweenColor(obj, newColor, duration)
    local tweenInfo = TweenInfo.new(
        duration or 0.3,
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.InOut
    )
    local tween = TweenService:Create(obj, tweenInfo, { BackgroundColor3 = newColor })
    tween:Play()
    return tween
end

-- ============================================================================
-- CREATE VAPE V4 STYLE GUI
-- ============================================================================

local function createVapeGUI()
    local plr = Players.LocalPlayer
    if not plr then return end

    local playerGui = plr:FindFirstChild('PlayerGui')
    if not playerGui then return end

    -- Create ScreenGui container
    local screenGui = Instance.new('ScreenGui')
    screenGui.Name = GUI_NAME
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui

    -- ========================================================================
    -- MAIN WINDOW FRAME
    -- ========================================================================

    local frameHeight = isDeveloper and 400 or 255  -- Reduced height for smaller buttons
    local mainFrame = Instance.new('Frame')
    mainFrame.Name = MAIN_FRAME_NAME
    mainFrame.Size = UDim2.new(0, 220, 0, frameHeight)  -- Reduced width from 250 to 220
    mainFrame.Position = UDim2.new(0.5, -110, 0, 20)
    mainFrame.BackgroundColor3 = Colors.bg_primary
    mainFrame.BorderColor3 = Colors.border
    mainFrame.BorderSizePixel = 2
    mainFrame.Active = true -- allow input capture
    pcall(function() mainFrame.Draggable = true end) -- legacy draggable fallback
    mainFrame.Parent = screenGui

    -- Add corner radius effect with UICorner
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame

    -- ========================================================================
    -- TITLE BAR
    -- ========================================================================

    local titleBar = Instance.new('Frame')
    titleBar.Name = TITLE_BAR_NAME
    titleBar.Size = UDim2.new(1, 0, 0, 30)  -- Reduced from 35 to 30
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundColor3 = Colors.bg_secondary
    titleBar.BorderColor3 = Colors.border
    titleBar.BorderSizePixel = 0
    titleBar.Active = true
    titleBar.Parent = mainFrame

    local titleCorner = Instance.new('UICorner')
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = titleBar

    -- Title Text
    local titleLabel = Instance.new('TextLabel')
    titleLabel.Name = 'Title'
    titleLabel.Size = UDim2.new(0.5, 0, 1, 0)
    titleLabel.Position = UDim2.new(0, 10, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Colors.accent_main
    titleLabel.TextSize = 14  -- Reduced from 16
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = 'ZenX'
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar
    
    -- Version label (right side of title)
    local versionLabel = Instance.new('TextLabel')
    versionLabel.Name = 'Version'
    versionLabel.Size = UDim2.new(0.5, -10, 1, 0)
    versionLabel.Position = UDim2.new(0.5, 0, 0, 0)
    versionLabel.BackgroundTransparency = 1
    versionLabel.TextColor3 = Colors.accent_secondary
    versionLabel.TextSize = 11  -- Reduced from 12
    versionLabel.Font = Enum.Font.GothamBold
    versionLabel.Text = GUI_VERSION
    versionLabel.TextXAlignment = Enum.TextXAlignment.Right
    versionLabel.Parent = titleBar

    -- ========================================================================
    -- DRAGGING (TitleBar drag moves MainFrame)
    -- ========================================================================

    local dragging = false
    local dragStart
    local startPos

    -- Helper to check if any settings overlay is currently visible
    local function isSettingsOverlayVisible()
        local result = false
        pcall(function()
            if _G.KillAuraSettingsAPI and _G.KillAuraSettingsAPI.isVisible and _G.KillAuraSettingsAPI.isVisible() then
                result = true
            end
            if _G.AutoFarmSettingsAPI and _G.AutoFarmSettingsAPI.isVisible and _G.AutoFarmSettingsAPI.isVisible() then
                result = true
            end
            if _G.AutoSellSettingsAPI and _G.AutoSellSettingsAPI.isVisible and _G.AutoSellSettingsAPI.isVisible() then
                result = true
            end
        end)
        return result
    end

    titleBar.InputBegan:Connect(function(input)
        -- Don't start dragging if a settings overlay is visible
        if isSettingsOverlayVisible() then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- ========================================================================
    -- CONTENT AREA
    -- ========================================================================

    local contentArea = Instance.new('Frame')
    contentArea.Name = CONTENT_NAME
    contentArea.Size = UDim2.new(1, 0, 1, -30)  -- Adjusted for smaller title bar
    contentArea.Position = UDim2.new(0, 0, 0, 30)  -- Adjusted for smaller title bar
    contentArea.BackgroundTransparency = 1
    contentArea.Parent = mainFrame

    -- Forward declarations for overlay toggle functions (defined later)
    local toggleDodgeSettingsOverlay
    local toggleBankSettingsOverlay
    local setNoPopupState  -- Forward declaration for No Popup helper

    -- ========================================================================
    -- AUTO FARM BUTTON + SETTINGS GEAR
    -- ========================================================================

    local autoFarmButton = Instance.new('TextButton')
    autoFarmButton.Name = BTN1_NAME
    autoFarmButton.Size = UDim2.new(1, -53, 0, 40)  -- Smaller button (height 40)
    autoFarmButton.Position = UDim2.new(0, 10, 0, 8)
    autoFarmButton.BackgroundColor3 = Colors.accent_danger
    autoFarmButton.BorderColor3 = Colors.border
    autoFarmButton.BorderSizePixel = 1
    autoFarmButton.TextColor3 = Colors.text_primary
    autoFarmButton.TextSize = 13
    autoFarmButton.Font = Enum.Font.GothamBold
    autoFarmButton.Text = '🚀 AUTO FARM'
    autoFarmButton.Parent = contentArea

    local autoFarmCorner = Instance.new('UICorner')
    autoFarmCorner.CornerRadius = UDim.new(0, 6)
    autoFarmCorner.Parent = autoFarmButton

    -- ========================================================================
    -- AUTO FARM SETTINGS BUTTON (⚙️)
    -- ========================================================================

    local autoFarmSettingsBtn = Instance.new('TextButton')
    autoFarmSettingsBtn.Name = generateRandomName('SettingsBtn_')
    autoFarmSettingsBtn.Size = UDim2.new(0, 33, 0, 40)  -- 5% smaller (33 instead of 35)
    autoFarmSettingsBtn.Position = UDim2.new(1, -43, 0, 8)  -- Right side of content area
    autoFarmSettingsBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)  -- Blue color
    autoFarmSettingsBtn.BorderColor3 = Colors.border
    autoFarmSettingsBtn.BorderSizePixel = 1
    autoFarmSettingsBtn.TextColor3 = Colors.text_primary
    autoFarmSettingsBtn.TextSize = 15
    autoFarmSettingsBtn.Font = Enum.Font.GothamBold
    autoFarmSettingsBtn.Text = '⚙️'
    autoFarmSettingsBtn.Parent = contentArea

    local settingsBtnCorner = Instance.new('UICorner')
    settingsBtnCorner.CornerRadius = UDim.new(0, 6)
    settingsBtnCorner.Parent = autoFarmSettingsBtn

    -- ========================================================================
    -- AUTO FARM SETTINGS OVERLAY
    -- ========================================================================

    -- Create settings overlay on mainFrame
    local settingsOverlay = Instance.new('Frame')
    settingsOverlay.Name = 'AutoFarmSettingsOverlay'
    settingsOverlay.Size = UDim2.new(1, 0, 1, 0)
    settingsOverlay.Position = UDim2.new(0, 0, 0, 0)
    settingsOverlay.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    settingsOverlay.BackgroundTransparency = 0
    settingsOverlay.BorderSizePixel = 0
    settingsOverlay.Visible = false
    settingsOverlay.Active = true
    settingsOverlay.ZIndex = 10
    settingsOverlay.Parent = mainFrame

    -- Block clicks from passing through the overlay
    settingsOverlay.InputBegan:Connect(function(input)
        -- Consume input to prevent click-through
    end)
    settingsOverlay.InputEnded:Connect(function(input)
        -- Consume input to prevent click-through
    end)

    local overlayCorner = Instance.new('UICorner')
    overlayCorner.CornerRadius = UDim.new(0, 8)
    overlayCorner.Parent = settingsOverlay

    -- Settings Header
    local settingsHeader = Instance.new('Frame')
    settingsHeader.Name = 'Header'
    settingsHeader.Size = UDim2.new(1, 0, 0, 35)
    settingsHeader.Position = UDim2.new(0, 0, 0, 0)
    settingsHeader.BackgroundColor3 = Colors.bg_secondary
    settingsHeader.BorderSizePixel = 0
    settingsHeader.Active = true
    settingsHeader.ZIndex = 11
    settingsHeader.Parent = settingsOverlay

    -- Block clicks from passing through header
    settingsHeader.InputBegan:Connect(function(input) end)

    local headerCorner = Instance.new('UICorner')
    headerCorner.CornerRadius = UDim.new(0, 8)
    headerCorner.Parent = settingsHeader

    local settingsTitle = Instance.new('TextLabel')
    settingsTitle.Name = 'Title'
    settingsTitle.Size = UDim2.new(1, -40, 1, 0)
    settingsTitle.Position = UDim2.new(0, 10, 0, 0)
    settingsTitle.BackgroundTransparency = 1
    settingsTitle.TextColor3 = Colors.accent_secondary
    settingsTitle.TextSize = 14
    settingsTitle.Font = Enum.Font.GothamBold
    settingsTitle.Text = '⚙️ Farm Settings'
    settingsTitle.TextXAlignment = Enum.TextXAlignment.Left
    settingsTitle.ZIndex = 12
    settingsTitle.Parent = settingsHeader

    local closeSettingsBtn = Instance.new('TextButton')
    closeSettingsBtn.Name = 'Close'
    closeSettingsBtn.Size = UDim2.new(0, 30, 0, 30)
    closeSettingsBtn.Position = UDim2.new(1, -32, 0, 2)
    closeSettingsBtn.BackgroundColor3 = Colors.accent_danger
    closeSettingsBtn.BorderSizePixel = 0
    closeSettingsBtn.TextColor3 = Colors.text_primary
    closeSettingsBtn.TextSize = 14
    closeSettingsBtn.Font = Enum.Font.GothamBold
    closeSettingsBtn.Text = 'X'
    closeSettingsBtn.ZIndex = 12
    closeSettingsBtn.Parent = settingsHeader

    local closeBtnCorner = Instance.new('UICorner')
    closeBtnCorner.CornerRadius = UDim.new(0, 6)
    closeBtnCorner.Parent = closeSettingsBtn

    -- Settings Content (ScrollingFrame to fit all controls)
    local settingsContent = Instance.new('ScrollingFrame')
    settingsContent.Name = 'Content'
    settingsContent.Size = UDim2.new(1, 0, 1, -35)
    settingsContent.Position = UDim2.new(0, 0, 0, 35)
    settingsContent.BackgroundTransparency = 1
    settingsContent.Active = true
    settingsContent.ZIndex = 11
    settingsContent.ScrollBarThickness = 4
    settingsContent.ScrollBarImageColor3 = Color3.fromRGB(0, 200, 255)
    settingsContent.CanvasSize = UDim2.new(0, 0, 0, 320)  -- Height for all controls
    settingsContent.ScrollingDirection = Enum.ScrollingDirection.Y
    settingsContent.BorderSizePixel = 0
    settingsContent.Parent = settingsOverlay

    -- Block clicks from passing through content area
    settingsContent.InputBegan:Connect(function(input) end)

    -- ========================================================================
    -- FARM MODE TOGGLE (Above / Below)
    -- ========================================================================

    local farmMode = "above"  -- Default mode
    local farmHeight = 7      -- Default height (0.5 increments)
    local farmBehind = 14     -- Default behind distance (0.2 increments)
    
    -- Initialize genv with default values
    if not _genv.AutoFarmHoverHeight then
        _genv.AutoFarmHoverHeight = 7
    end
    if not _genv.AutoFarmBehindDistance then
        _genv.AutoFarmBehindDistance = 14
    end

    local modeLabel = Instance.new('TextLabel')
    modeLabel.Name = 'ModeLabel'
    modeLabel.Size = UDim2.new(1, -20, 0, 18)
    modeLabel.Position = UDim2.new(0, 10, 0, 10)
    modeLabel.BackgroundTransparency = 1
    modeLabel.TextColor3 = Colors.text_primary
    modeLabel.TextSize = 12
    modeLabel.Font = Enum.Font.GothamBold
    modeLabel.Text = 'Farm Position'
    modeLabel.TextXAlignment = Enum.TextXAlignment.Left
    modeLabel.ZIndex = 12
    modeLabel.Parent = settingsContent

    local aboveBtn = Instance.new('TextButton')
    aboveBtn.Name = 'AboveBtn'
    aboveBtn.Size = UDim2.new(0.46, 0, 0, 26)
    aboveBtn.Position = UDim2.new(0, 10, 0, 32)
    aboveBtn.BackgroundColor3 = Colors.accent_main  -- Active by default
    aboveBtn.BorderSizePixel = 0
    aboveBtn.TextColor3 = Colors.text_primary
    aboveBtn.TextSize = 11
    aboveBtn.Font = Enum.Font.GothamBold
    aboveBtn.Text = '⬆️ Farm Above'
    aboveBtn.ZIndex = 12
    aboveBtn.Parent = settingsContent

    local aboveBtnCorner = Instance.new('UICorner')
    aboveBtnCorner.CornerRadius = UDim.new(0, 6)
    aboveBtnCorner.Parent = aboveBtn

    local belowBtn = Instance.new('TextButton')
    belowBtn.Name = 'BelowBtn'
    belowBtn.Size = UDim2.new(0.46, 0, 0, 26)
    belowBtn.Position = UDim2.new(0.52, 0, 0, 32)
    belowBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)  -- Inactive
    belowBtn.BorderSizePixel = 0
    belowBtn.TextColor3 = Colors.text_primary
    belowBtn.TextSize = 11
    belowBtn.Font = Enum.Font.GothamBold
    belowBtn.Text = '⬇️ Farm Below'
    belowBtn.ZIndex = 12
    belowBtn.Parent = settingsContent

    local belowBtnCorner = Instance.new('UICorner')
    belowBtnCorner.CornerRadius = UDim.new(0, 6)
    belowBtnCorner.Parent = belowBtn

    -- ========================================================================
    -- FARM HEIGHT SLIDER
    -- ========================================================================

    local heightLabel = Instance.new('TextLabel')
    heightLabel.Name = 'HeightLabel'
    heightLabel.Size = UDim2.new(0.6, 0, 0, 20)
    heightLabel.Position = UDim2.new(0, 10, 0, 68)
    heightLabel.BackgroundTransparency = 1
    heightLabel.TextColor3 = Colors.text_primary
    heightLabel.TextSize = 12
    heightLabel.Font = Enum.Font.GothamBold
    heightLabel.Text = 'Farm Height'
    heightLabel.TextXAlignment = Enum.TextXAlignment.Left
    heightLabel.ZIndex = 12
    heightLabel.Parent = settingsContent

    local heightValueLabel = Instance.new('TextLabel')
    heightValueLabel.Name = 'HeightValue'
    heightValueLabel.Size = UDim2.new(0.3, 0, 0, 20)
    heightValueLabel.Position = UDim2.new(0.65, 0, 0, 68)
    heightValueLabel.BackgroundTransparency = 1
    heightValueLabel.TextColor3 = Colors.accent_secondary
    heightValueLabel.TextSize = 12
    heightValueLabel.Font = Enum.Font.GothamBold
    heightValueLabel.Text = tostring(farmHeight)
    heightValueLabel.TextXAlignment = Enum.TextXAlignment.Right
    heightValueLabel.ZIndex = 12
    heightValueLabel.Parent = settingsContent

    local heightSliderBg = Instance.new('Frame')
    heightSliderBg.Name = 'HeightSliderBg'
    heightSliderBg.Size = UDim2.new(1, -20, 0, 16)
    heightSliderBg.Position = UDim2.new(0, 10, 0, 90)
    heightSliderBg.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    heightSliderBg.BorderSizePixel = 0
    heightSliderBg.Active = true
    heightSliderBg.ZIndex = 12
    heightSliderBg.Parent = settingsContent

    local heightBgCorner = Instance.new('UICorner')
    heightBgCorner.CornerRadius = UDim.new(0, 8)
    heightBgCorner.Parent = heightSliderBg

    local heightSliderFill = Instance.new('Frame')
    heightSliderFill.Name = 'Fill'
    heightSliderFill.Size = UDim2.new((farmHeight - 0.5) / 19.5, 0, 1, 0)  -- 0.5 to 20 range
    heightSliderFill.Position = UDim2.new(0, 0, 0, 0)
    heightSliderFill.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    heightSliderFill.BorderSizePixel = 0
    heightSliderFill.ZIndex = 12
    heightSliderFill.Parent = heightSliderBg

    local heightFillCorner = Instance.new('UICorner')
    heightFillCorner.CornerRadius = UDim.new(0, 8)
    heightFillCorner.Parent = heightSliderFill

    local heightKnob = Instance.new('Frame')
    heightKnob.Name = 'Knob'
    heightKnob.Size = UDim2.new(0, 20, 0, 20)
    heightKnob.Position = UDim2.new((farmHeight - 0.5) / 19.5, -10, 0.5, -10)
    heightKnob.BackgroundColor3 = Colors.text_primary
    heightKnob.BorderSizePixel = 0
    heightKnob.Active = true
    heightKnob.ZIndex = 13
    heightKnob.Parent = heightSliderBg

    local heightKnobCorner = Instance.new('UICorner')
    heightKnobCorner.CornerRadius = UDim.new(1, 0)
    heightKnobCorner.Parent = heightKnob

    -- ========================================================================
    -- FARM BEHIND SLIDER
    -- ========================================================================

    local behindLabel = Instance.new('TextLabel')
    behindLabel.Name = 'BehindLabel'
    behindLabel.Size = UDim2.new(0.6, 0, 0, 20)
    behindLabel.Position = UDim2.new(0, 10, 0, 116)
    behindLabel.BackgroundTransparency = 1
    behindLabel.TextColor3 = Colors.text_primary
    behindLabel.TextSize = 12
    behindLabel.Font = Enum.Font.GothamBold
    behindLabel.Text = 'Farm Behind'
    behindLabel.TextXAlignment = Enum.TextXAlignment.Left
    behindLabel.ZIndex = 12
    behindLabel.Parent = settingsContent

    local behindValueLabel = Instance.new('TextLabel')
    behindValueLabel.Name = 'BehindValue'
    behindValueLabel.Size = UDim2.new(0.3, 0, 0, 20)
    behindValueLabel.Position = UDim2.new(0.65, 0, 0, 116)
    behindValueLabel.BackgroundTransparency = 1
    behindValueLabel.TextColor3 = Colors.accent_secondary
    behindValueLabel.TextSize = 12
    behindValueLabel.Font = Enum.Font.GothamBold
    behindValueLabel.Text = tostring(farmBehind)
    behindValueLabel.TextXAlignment = Enum.TextXAlignment.Right
    behindValueLabel.ZIndex = 12
    behindValueLabel.Parent = settingsContent

    local behindSliderBg = Instance.new('Frame')
    behindSliderBg.Name = 'BehindSliderBg'
    behindSliderBg.Size = UDim2.new(1, -20, 0, 16)
    behindSliderBg.Position = UDim2.new(0, 10, 0, 138)
    behindSliderBg.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    behindSliderBg.BorderSizePixel = 0
    behindSliderBg.Active = true
    behindSliderBg.ZIndex = 12
    behindSliderBg.Parent = settingsContent

    local behindBgCorner = Instance.new('UICorner')
    behindBgCorner.CornerRadius = UDim.new(0, 8)
    behindBgCorner.Parent = behindSliderBg

    local behindSliderFill = Instance.new('Frame')
    behindSliderFill.Name = 'Fill'
    behindSliderFill.Size = UDim2.new((farmBehind - 0.2) / 29.8, 0, 1, 0)  -- 0.2 to 30 range
    behindSliderFill.Position = UDim2.new(0, 0, 0, 0)
    behindSliderFill.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    behindSliderFill.BorderSizePixel = 0
    behindSliderFill.ZIndex = 12
    behindSliderFill.Parent = behindSliderBg

    local behindFillCorner = Instance.new('UICorner')
    behindFillCorner.CornerRadius = UDim.new(0, 8)
    behindFillCorner.Parent = behindSliderFill

    local behindKnob = Instance.new('Frame')
    behindKnob.Name = 'Knob'
    behindKnob.Size = UDim2.new(0, 20, 0, 20)
    behindKnob.Position = UDim2.new((farmBehind - 0.2) / 29.8, -10, 0.5, -10)
    behindKnob.BackgroundColor3 = Colors.text_primary
    behindKnob.BorderSizePixel = 0
    behindKnob.Active = true
    behindKnob.ZIndex = 13
    behindKnob.Parent = behindSliderBg

    local behindKnobCorner = Instance.new('UICorner')
    behindKnobCorner.CornerRadius = UDim.new(1, 0)
    behindKnobCorner.Parent = behindKnob

    -- ========================================================================
    -- SAVE SETTINGS BUTTON (moved up since dodge settings are now on Page 2)
    -- ========================================================================

    -- Dodge settings are now on Page 2 - removed from this overlay
    local autoDodgeEnabled = true  -- Default enabled (stored for compatibility, managed on Page 2)

    local saveSettingsBtn = Instance.new('TextButton')
    saveSettingsBtn.Name = 'SaveSettingsBtn'
    saveSettingsBtn.Size = UDim2.new(1, -20, 0, 35)
    saveSettingsBtn.Position = UDim2.new(0, 10, 0, 170)  -- Moved up since dodge controls removed
    saveSettingsBtn.BackgroundColor3 = Colors.accent_main
    saveSettingsBtn.BorderSizePixel = 0
    saveSettingsBtn.TextColor3 = Colors.bg_primary
    saveSettingsBtn.TextSize = 12
    saveSettingsBtn.Font = Enum.Font.GothamBold
    saveSettingsBtn.Text = '💾 Save Settings'
    saveSettingsBtn.ZIndex = 12
    saveSettingsBtn.Parent = settingsContent

    local saveBtnCorner = Instance.new('UICorner')
    saveBtnCorner.CornerRadius = UDim.new(0, 6)
    saveBtnCorner.Parent = saveSettingsBtn

    -- Update settings content canvas size (reduced since dodge controls moved)
    settingsContent.CanvasSize = UDim2.new(0, 0, 0, 220)

    -- ========================================================================
    -- SETTINGS LOGIC & FUNCTIONS
    -- ========================================================================

    local SETTINGS_FILE = "ZenX WZ/zenx_autofarm_settings.json"
    local settingsVisible = false

    -- Apply settings to AutoFarm
    local function applyFarmSettings()
        if farmMode == "below" then
            -- When farming below, use negative height and disable ground clearance
            _genv.AutoFarmHoverHeight = -math.abs(farmHeight)
            _genv.AutoFarmGroundClearance = 0  -- Disable clearance when below

        else
            -- When farming above, use positive height with ground clearance
            _genv.AutoFarmHoverHeight = math.abs(farmHeight)
            _genv.AutoFarmGroundClearance = 4  -- Normal clearance when above
        end
        _genv.AutoFarmBehindDistance = farmBehind
    end

    -- Update mode button colors
    local function updateModeButtons()
        if farmMode == "above" then
            tweenColor(aboveBtn, Colors.accent_main, 0.15)
            tweenColor(belowBtn, Color3.fromRGB(35, 35, 35), 0.15)
        else
            tweenColor(aboveBtn, Color3.fromRGB(35, 35, 35), 0.15)
            tweenColor(belowBtn, Colors.accent_main, 0.15)
        end
        applyFarmSettings()
    end

    -- Mode button clicks
    aboveBtn.MouseButton1Click:Connect(function()
        farmMode = "above"
        updateModeButtons()
    end)

    belowBtn.MouseButton1Click:Connect(function()
        farmMode = "below"
        updateModeButtons()
    end)

    -- Height slider logic
    local heightDragging = false

    local function updateHeightSlider(inputPos)
        local sliderAbsPos = heightSliderBg.AbsolutePosition
        local sliderAbsSize = heightSliderBg.AbsoluteSize
        local relativeX = math.clamp((inputPos.X - sliderAbsPos.X) / sliderAbsSize.X, 0, 1)
        
        local rawValue = 0.5 + (relativeX * 19.5)  -- 0.5 to 20 range
        local snappedValue = math.floor(rawValue / 0.5 + 0.5) * 0.5  -- Snap to 0.5 increments
        snappedValue = math.clamp(snappedValue, 0.5, 20)
        snappedValue = math.floor(snappedValue * 10 + 0.5) / 10  -- Round to 1 decimal
        
        farmHeight = snappedValue
        
        local percentage = (snappedValue - 0.5) / 19.5
        heightSliderFill.Size = UDim2.new(math.clamp(percentage, 0, 1), 0, 1, 0)
        heightKnob.Position = UDim2.new(math.clamp(percentage, 0, 1), -10, 0.5, -10)
        heightValueLabel.Text = tostring(snappedValue)
        
        applyFarmSettings()
    end

    heightSliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            heightDragging = true
            updateHeightSlider(input.Position)
        end
    end)

    heightKnob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            heightDragging = true
        end
    end)

    -- Behind slider logic
    local behindDragging = false

    local function updateBehindSlider(inputPos)
        local sliderAbsPos = behindSliderBg.AbsolutePosition
        local sliderAbsSize = behindSliderBg.AbsoluteSize
        local relativeX = math.clamp((inputPos.X - sliderAbsPos.X) / sliderAbsSize.X, 0, 1)
        
        local rawValue = 0.2 + (relativeX * 29.8)  -- 0.2 to 30 range
        local snappedValue = math.floor(rawValue / 0.2 + 0.5) * 0.2  -- Snap to 0.2 increments
        snappedValue = math.clamp(snappedValue, 0.2, 30)
        snappedValue = math.floor(snappedValue * 10 + 0.5) / 10  -- Round to 1 decimal
        
        farmBehind = snappedValue
        
        local percentage = (snappedValue - 0.2) / 29.8
        behindSliderFill.Size = UDim2.new(math.clamp(percentage, 0, 1), 0, 1, 0)
        behindKnob.Position = UDim2.new(math.clamp(percentage, 0, 1), -10, 0.5, -10)
        behindValueLabel.Text = tostring(snappedValue)
        
        applyFarmSettings()
    end

    behindSliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            behindDragging = true
            updateBehindSlider(input.Position)
        end
    end)

    behindKnob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            behindDragging = true
        end
    end)

    -- Global input tracking for sliders (tween slider moved to Page 2)
    UserInputService.InputChanged:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            if heightDragging then
                updateHeightSlider(input.Position)
            elseif behindDragging then
                updateBehindSlider(input.Position)
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            heightDragging = false
            behindDragging = false
        end
    end)

    -- Save settings function
    local function saveSettings()
        if not writefile then
            warn("[ZenX] writefile not available - cannot save settings")
            if _G.ZenXDebug then _G.ZenXDebug.warn("writefile not available - cannot save settings") end
            return false
        end
        
        -- Ensure folder exists before saving
        ensureZenXFolder()
        
        local settingsData = {
            farmMode = farmMode,
            farmHeight = farmHeight,
            farmBehind = farmBehind,
            -- Note: autoDodgeEnabled and tweenSpeed now saved on Page 2
        }
        
        local success, err = pcall(function()
            local jsonStr = HttpService:JSONEncode(settingsData)
            writefile(SETTINGS_FILE, jsonStr)
        end)
        
        if success then
            if _G.ZenXDebug then _G.ZenXDebug.success("AutoFarm settings saved successfully") end
        else
            if _G.ZenXDebug then _G.ZenXDebug.error("Failed to save settings: " .. tostring(err)) end
        end
        
        return success
    end

    -- Load settings function
    local function loadSavedSettings()
        if not readfile or not isfile then
            if _G.ZenXDebug then _G.ZenXDebug.warn("readfile/isfile not available - cannot load settings") end
            return false
        end
        
        local success = pcall(function()
            if isfile(SETTINGS_FILE) then
                local content = readfile(SETTINGS_FILE)
                if content and content ~= "" then
                    local decoded = HttpService:JSONDecode(content)
                    if decoded then
                        if decoded.farmMode then farmMode = decoded.farmMode end
                        if decoded.farmHeight then farmHeight = tonumber(decoded.farmHeight) or 7 end
                        if decoded.farmBehind then farmBehind = tonumber(decoded.farmBehind) or 14 end
                        -- Legacy: load autoDodgeEnabled if present
                        if decoded.autoDodgeEnabled ~= nil then autoDodgeEnabled = decoded.autoDodgeEnabled end
                        
                        -- Apply settings to genv for AutoFarm
                        applyFarmSettings()
                        
                        -- Update UI to match loaded settings
                        updateModeButtons()
                        
                        local heightPercentage = (farmHeight - 0.5) / 19.5
                        heightSliderFill.Size = UDim2.new(math.clamp(heightPercentage, 0, 1), 0, 1, 0)
                        heightKnob.Position = UDim2.new(math.clamp(heightPercentage, 0, 1), -10, 0.5, -10)
                        heightValueLabel.Text = tostring(farmHeight)
                        
                        local behindPercentage = (farmBehind - 0.2) / 29.8
                        behindSliderFill.Size = UDim2.new(math.clamp(behindPercentage, 0, 1), 0, 1, 0)
                        behindKnob.Position = UDim2.new(math.clamp(behindPercentage, 0, 1), -10, 0.5, -10)
                        behindValueLabel.Text = tostring(farmBehind)
                        
                        if _G.ZenXDebug then _G.ZenXDebug.success("AutoFarm settings loaded successfully") end
                    end
                end
            else
                if _G.ZenXDebug then _G.ZenXDebug.info("No saved settings file found, using defaults") end
            end
        end)
        
        return success
    end

    -- Save button click
    saveSettingsBtn.MouseButton1Click:Connect(function()
        local success = saveSettings()
        if success then
            saveSettingsBtn.Text = '✅ Saved!'
            tweenColor(saveSettingsBtn, Color3.fromRGB(0, 200, 80), 0.1)
            task.delay(1, function()
                if saveSettingsBtn and saveSettingsBtn.Parent then
                    saveSettingsBtn.Text = '💾 Save Settings'
                    tweenColor(saveSettingsBtn, Colors.accent_main, 0.2)
                end
            end)
        else
            saveSettingsBtn.Text = '❌ Failed!'
            tweenColor(saveSettingsBtn, Colors.accent_danger, 0.1)
            task.delay(1, function()
                if saveSettingsBtn and saveSettingsBtn.Parent then
                    saveSettingsBtn.Text = '💾 Save Settings'
                    tweenColor(saveSettingsBtn, Colors.accent_main, 0.2)
                end
            end)
        end
    end)

    -- Save button hover effects
    saveSettingsBtn.MouseEnter:Connect(function()
        tweenColor(saveSettingsBtn, Color3.fromRGB(0, 200, 80), 0.1)
    end)

    saveSettingsBtn.MouseLeave:Connect(function()
        tweenColor(saveSettingsBtn, Colors.accent_main, 0.1)
    end)

    -- Toggle settings overlay
    local function toggleSettingsOverlay()
        settingsVisible = not settingsVisible
        if settingsVisible then
            -- Hide the main content area (buttons) to prevent click-through
            contentArea.Visible = false
            settingsOverlay.Visible = true
            settingsOverlay.BackgroundTransparency = 1
            local tween = TweenService:Create(settingsOverlay, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0})
            tween:Play()
        else
            local tween = TweenService:Create(settingsOverlay, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
            tween:Play()
            tween.Completed:Connect(function()
                settingsOverlay.Visible = false
                -- Show the main content area again
                contentArea.Visible = true
            end)
        end
    end

    -- Settings button click
    autoFarmSettingsBtn.MouseButton1Click:Connect(function()
        toggleSettingsOverlay()
    end)

    -- Close button click
    closeSettingsBtn.MouseButton1Click:Connect(function()
        settingsVisible = true  -- Set to true so toggle will close it
        toggleSettingsOverlay()
    end)

    -- Settings button hover effects
    autoFarmSettingsBtn.MouseEnter:Connect(function()
        tweenColor(autoFarmSettingsBtn, Color3.fromRGB(0, 180, 255), 0.1)
    end)

    autoFarmSettingsBtn.MouseLeave:Connect(function()
        tweenColor(autoFarmSettingsBtn, Color3.fromRGB(0, 150, 255), 0.1)
    end)

    -- Load saved settings on GUI creation
    task.defer(function()
        loadSavedSettings()
    end)

    -- ========================================================================
    -- KILL AURA BUTTON
    -- ========================================================================

    local killAuraButton = Instance.new('TextButton')
    killAuraButton.Name = BTN2_NAME
    killAuraButton.Size = UDim2.new(1, -53, 0, 40)  -- Smaller button (height 40)
    killAuraButton.Position = UDim2.new(0, 10, 0, 52)  -- Adjusted position
    killAuraButton.BackgroundColor3 = Colors.accent_danger
    killAuraButton.BorderColor3 = Colors.border
    killAuraButton.BorderSizePixel = 1
    killAuraButton.TextColor3 = Colors.text_primary
    killAuraButton.TextSize = 13
    killAuraButton.Font = Enum.Font.GothamBold
    killAuraButton.Text = '⚔ KILL AURA'
    killAuraButton.Parent = contentArea

    local killAuraCorner = Instance.new('UICorner')
    killAuraCorner.CornerRadius = UDim.new(0, 6)
    killAuraCorner.Parent = killAuraButton

    -- ========================================================================
    -- KILL AURA SETTINGS BUTTON (⚠️)
    -- ========================================================================

    local killAuraSettingsBtn = Instance.new('TextButton')
    killAuraSettingsBtn.Name = generateRandomName('KASettingsBtn_')
    killAuraSettingsBtn.Size = UDim2.new(0, 33, 0, 40)  -- 5% smaller
    killAuraSettingsBtn.Position = UDim2.new(1, -43, 0, 52)  -- Adjusted position
    killAuraSettingsBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 0)  -- Yellow warning color
    killAuraSettingsBtn.BorderColor3 = Colors.border
    killAuraSettingsBtn.BorderSizePixel = 1
    killAuraSettingsBtn.TextColor3 = Colors.bg_primary
    killAuraSettingsBtn.TextSize = 15
    killAuraSettingsBtn.Font = Enum.Font.GothamBold
    killAuraSettingsBtn.Text = '⚠️'
    killAuraSettingsBtn.Parent = contentArea

    local kaSettingsBtnCorner = Instance.new('UICorner')
    kaSettingsBtnCorner.CornerRadius = UDim.new(0, 6)
    kaSettingsBtnCorner.Parent = killAuraSettingsBtn

    -- Kill Aura Settings button click handler
    -- Note: KillAuraSettingsAPI.toggle() now auto-creates its own overlay
    killAuraSettingsBtn.MouseButton1Click:Connect(function()
        -- Load Kill Aura Settings API if not loaded
        if not KillAuraSettingsAPI then
            loadKillAuraSettings()
        end
        
        if KillAuraSettingsAPI then
            KillAuraSettingsAPI.toggle(mainFrame)
        end
    end)

    -- Kill Aura Settings button hover effects
    killAuraSettingsBtn.MouseEnter:Connect(function()
        tweenColor(killAuraSettingsBtn, Color3.fromRGB(255, 220, 50), 0.1)
    end)

    killAuraSettingsBtn.MouseLeave:Connect(function()
        tweenColor(killAuraSettingsBtn, Color3.fromRGB(255, 200, 0), 0.1)
    end)

    -- ========================================================================
    -- AUTO SELL BUTTON + SETTINGS GEAR (For All Users)
    -- ========================================================================

    local autoSellButton = Instance.new('TextButton')
    autoSellButton.Name = generateRandomName('AutoSellBtn_')
    autoSellButton.Size = UDim2.new(1, -53, 0, 40)  -- Smaller button (height 40)
    autoSellButton.Position = UDim2.new(0, 10, 0, 96)  -- Adjusted position
    autoSellButton.BackgroundColor3 = Colors.accent_danger
    autoSellButton.BorderColor3 = Colors.border
    autoSellButton.BorderSizePixel = 1
    autoSellButton.TextColor3 = Colors.text_primary
    autoSellButton.TextSize = 13
    autoSellButton.Font = Enum.Font.GothamBold
    autoSellButton.Text = '💲 AUTO SELL'
    autoSellButton.Parent = contentArea

    local autoSellCorner = Instance.new('UICorner')
    autoSellCorner.CornerRadius = UDim.new(0, 6)
    autoSellCorner.Parent = autoSellButton

    -- Auto Sell Settings Button (⚙️)
    local autoSellSettingsBtn = Instance.new('TextButton')
    autoSellSettingsBtn.Name = generateRandomName('AutoSellSettingsBtn_')
    autoSellSettingsBtn.Size = UDim2.new(0, 33, 0, 40)  -- 5% smaller
    autoSellSettingsBtn.Position = UDim2.new(1, -43, 0, 96)  -- Adjusted position
    autoSellSettingsBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)  -- Blue color
    autoSellSettingsBtn.BorderColor3 = Colors.border
    autoSellSettingsBtn.BorderSizePixel = 1
    autoSellSettingsBtn.TextColor3 = Colors.text_primary
    autoSellSettingsBtn.TextSize = 15
    autoSellSettingsBtn.Font = Enum.Font.GothamBold
    autoSellSettingsBtn.Text = '⚙️'
    autoSellSettingsBtn.Parent = contentArea

    local autoSellSettingsCorner = Instance.new('UICorner')
    autoSellSettingsCorner.CornerRadius = UDim.new(0, 6)
    autoSellSettingsCorner.Parent = autoSellSettingsBtn

    -- Auto Sell state (stored in _genv for cross-scope access)
    _genv.autoSellEnabled = _genv.autoSellEnabled or false

    -- Auto Sell button click
    autoSellButton.MouseButton1Click:Connect(function()
        _genv.autoSellEnabled = not _genv.autoSellEnabled
        if _genv.autoSellEnabled then
            tweenColor(autoSellButton, Colors.accent_main, 0.2)
            -- Load and enable Auto Sell API
            if not AutoSellAPI then
                loadAutoSell()
            end
            if AutoSellAPI then
                AutoSellAPI.enable()
            end
        else
            tweenColor(autoSellButton, Colors.accent_danger, 0.2)
            -- Disable Auto Sell API
            if AutoSellAPI then
                AutoSellAPI.disable()
            end
        end
    end)

    -- Auto Sell button hover effects
    autoSellButton.MouseEnter:Connect(function()
        if _genv.autoSellEnabled then
            tweenColor(autoSellButton, Color3.fromRGB(0, 200, 80), 0.15)
        else
            tweenColor(autoSellButton, Color3.fromRGB(220, 30, 30), 0.15)
        end
    end)

    autoSellButton.MouseLeave:Connect(function()
        if _genv.autoSellEnabled then
            tweenColor(autoSellButton, Colors.accent_main, 0.15)
        else
            tweenColor(autoSellButton, Colors.accent_danger, 0.15)
        end
    end)

    -- Auto Sell settings button hover effects
    autoSellSettingsBtn.MouseEnter:Connect(function()
        tweenColor(autoSellSettingsBtn, Color3.fromRGB(0, 180, 255), 0.1)
    end)

    autoSellSettingsBtn.MouseLeave:Connect(function()
        tweenColor(autoSellSettingsBtn, Color3.fromRGB(0, 150, 255), 0.1)
    end)

    -- Auto Sell settings button click (placeholder for settings overlay)
    autoSellSettingsBtn.MouseButton1Click:Connect(function()
        -- Load Auto Sell Settings API if not loaded
        if not AutoSellSettingsAPI then
            loadAutoSellSettings()
        end
        
        if AutoSellSettingsAPI then
            -- Enable No Popup when opening Auto Sell settings (safe call)
            pcall(function()
                if setNoPopupState then setNoPopupState(true) end
            end)
            AutoSellSettingsAPI.toggle(mainFrame)
            -- Disable No Popup when closed (check after toggle)
            task.defer(function()
                task.wait(0.1)
                pcall(function()
                    if AutoSellSettingsAPI.isVisible and not AutoSellSettingsAPI.isVisible() then
                        if setNoPopupState then setNoPopupState(false) end
                    end
                end)
            end)
        end
    end)

    -- ========================================================================
    -- SAVE STATE BUTTON + DELETE SAVE BUTTON
    -- ========================================================================

    local saveStateButton = Instance.new('TextButton')
    saveStateButton.Name = generateRandomName('SaveStateBtn_')
    saveStateButton.Size = UDim2.new(0.5, -15, 0, 32)  -- Smaller
    saveStateButton.Position = UDim2.new(0, 10, 0, 172)  -- Always below More button
    saveStateButton.BackgroundColor3 = Color3.fromRGB(100, 100, 180)
    saveStateButton.BorderColor3 = Colors.border
    saveStateButton.BorderSizePixel = 1
    saveStateButton.TextColor3 = Colors.text_primary
    saveStateButton.TextSize = 10
    saveStateButton.Font = Enum.Font.GothamBold
    saveStateButton.Text = '💾 SAVE'
    saveStateButton.Parent = contentArea

    local saveStateCorner = Instance.new('UICorner')
    saveStateCorner.CornerRadius = UDim.new(0, 6)
    saveStateCorner.Parent = saveStateButton

    -- Delete Save Button
    local deleteStateButton = Instance.new('TextButton')
    deleteStateButton.Name = generateRandomName('DeleteStateBtn_')
    deleteStateButton.Size = UDim2.new(0.5, -15, 0, 32)  -- Smaller
    deleteStateButton.Position = UDim2.new(0.5, 5, 0, 172)  -- Same Y as Save
    deleteStateButton.BackgroundColor3 = Color3.fromRGB(180, 80, 80)
    deleteStateButton.BorderColor3 = Colors.border
    deleteStateButton.BorderSizePixel = 1
    deleteStateButton.TextColor3 = Colors.text_primary
    deleteStateButton.TextSize = 10
    deleteStateButton.Font = Enum.Font.GothamBold
    deleteStateButton.Text = '🗑️ DELETE'
    deleteStateButton.Parent = contentArea

    local deleteStateCorner = Instance.new('UICorner')
    deleteStateCorner.CornerRadius = UDim.new(0, 6)
    deleteStateCorner.Parent = deleteStateButton

    -- Save state function (uses _genv for cross-scope access)
    local function saveCurrentState()
        if not writefile then 
            if _G.ZenXDebug then _G.ZenXDebug.warn("writefile not available - cannot save state") end
            return false 
        end
        
        -- Ensure folder exists before saving
        ensureZenXFolder()
        
        local state = {
            autoFarmEnabled = _genv.autoFarmEnabled or false,
            killAuraEnabled = _genv.killAuraEnabled or false,
            autoSellEnabled = _genv.autoSellEnabled or false,
            savedAt = os.time(),
        }
        
        local success = pcall(function()
            local jsonStr = HttpService:JSONEncode(state)
            writefile(STATE_FILE_PATH, jsonStr)
        end)
        
        if success then
            if _G.ZenXDebug then _G.ZenXDebug.success("State saved successfully") end
        else
            if _G.ZenXDebug then _G.ZenXDebug.error("Failed to save state") end
        end
        
        return success
    end

    -- Load state function (called on startup)
    local function loadSavedState()
        if not readfile or not isfile then return nil end
        
        local state = nil
        pcall(function()
            if isfile(STATE_FILE_PATH) then
                local content = readfile(STATE_FILE_PATH)
                if content and content ~= "" then
                    state = HttpService:JSONDecode(content)
                    if _G.ZenXDebug then _G.ZenXDebug.success("State loaded successfully") end
                end
            else
                if _G.ZenXDebug then _G.ZenXDebug.info("No saved state file found") end
            end
        end)
        
        return state
    end

    -- Apply saved state (uses _genv for cross-scope access)
    local function applySavedState()
        local state = loadSavedState()
        if not state then return end
        
        -- Apply Auto Farm state
        if state.autoFarmEnabled then
            _genv.autoFarmEnabled = true
            tweenColor(autoFarmButton, Colors.accent_main, 0.2)
            if AutoFarmAPI then
                AutoFarmAPI.enable()
            end
            if KingslayerAPI and game.PlaceId == 4310478830 then
                KingslayerAPI.enable()
            end
            -- Enable Temple of Ruin if we're in Temple of Ruin dungeon
            if TempleofRuinAPI and game.PlaceId == 3885726701 then
                TempleofRuinAPI.enable()
            end
            enablePerformanceMode()
            if AutoDodgeAPI and autoDodgeEnabled then
                AutoDodgeAPI.enable()
            end
        end
        
        -- Apply Kill Aura state
        if state.killAuraEnabled then
            _genv.killAuraEnabled = true
            tweenColor(killAuraButton, Colors.accent_main, 0.2)
            if KillAuraAPI then
                KillAuraAPI.start()
            end
        end
        
        -- Apply Auto Sell state
        if state.autoSellEnabled then
            _genv.autoSellEnabled = true
            tweenColor(autoSellButton, Colors.accent_main, 0.2)
            if not AutoSellAPI then
                loadAutoSell()
            end
            if AutoSellAPI then
                AutoSellAPI.enable()
            end
        end
    end

    -- Save State button click
    saveStateButton.MouseButton1Click:Connect(function()
        local success = saveCurrentState()
        if success then
            saveStateButton.Text = '✅ SAVED!'
            tweenColor(saveStateButton, Color3.fromRGB(0, 200, 80), 0.1)
            task.delay(1.5, function()
                if saveStateButton and saveStateButton.Parent then
                    saveStateButton.Text = '💾 SAVE'
                    tweenColor(saveStateButton, Color3.fromRGB(100, 100, 180), 0.2)
                end
            end)
        else
            saveStateButton.Text = '❌ FAILED!'
            tweenColor(saveStateButton, Colors.accent_danger, 0.1)
            task.delay(1.5, function()
                if saveStateButton and saveStateButton.Parent then
                    saveStateButton.Text = '💾 SAVE'
                    tweenColor(saveStateButton, Color3.fromRGB(100, 100, 180), 0.2)
                end
            end)
        end
    end)

    -- Save State button hover effects
    saveStateButton.MouseEnter:Connect(function()
        tweenColor(saveStateButton, Color3.fromRGB(120, 120, 200), 0.1)
    end)

    saveStateButton.MouseLeave:Connect(function()
        tweenColor(saveStateButton, Color3.fromRGB(100, 100, 180), 0.1)
    end)

    -- Delete State function
    local function deleteCurrentState()
        if not delfile and not (writefile and isfile) then return false end
        
        local success = pcall(function()
            if delfile then
                delfile(STATE_FILE_PATH)
            elseif isfile and isfile(STATE_FILE_PATH) then
                writefile(STATE_FILE_PATH, "")
            end
        end)
        
        if success then
            if _G.ZenXDebug then _G.ZenXDebug.success("State deleted successfully") end
        else
            if _G.ZenXDebug then _G.ZenXDebug.error("Failed to delete state") end
        end
        
        return success
    end

    -- Delete State button click
    deleteStateButton.MouseButton1Click:Connect(function()
        local success = deleteCurrentState()
        if success then
            deleteStateButton.Text = '✅ DELETED!'
            tweenColor(deleteStateButton, Color3.fromRGB(0, 200, 80), 0.1)
            task.delay(1.5, function()
                if deleteStateButton and deleteStateButton.Parent then
                    deleteStateButton.Text = '🗑️ DELETE'
                    tweenColor(deleteStateButton, Color3.fromRGB(180, 80, 80), 0.2)
                end
            end)
        else
            deleteStateButton.Text = '❌ FAILED!'
            tweenColor(deleteStateButton, Colors.accent_danger, 0.1)
            task.delay(1.5, function()
                if deleteStateButton and deleteStateButton.Parent then
                    deleteStateButton.Text = '🗑️ DELETE'
                    tweenColor(deleteStateButton, Color3.fromRGB(180, 80, 80), 0.2)
                end
            end)
        end
    end)

    -- Delete State button hover effects
    deleteStateButton.MouseEnter:Connect(function()
        tweenColor(deleteStateButton, Color3.fromRGB(200, 100, 100), 0.1)
    end)

    deleteStateButton.MouseLeave:Connect(function()
        tweenColor(deleteStateButton, Color3.fromRGB(180, 80, 80), 0.1)
    end)

    -- ========================================================================
    -- PAGINATION BUTTONS (⏮️ ⏭️) - Navigate between Page 1 and Page 2
    -- ========================================================================

    local currentPage = 1  -- 1 = Main page, 2 = AutoDodge/AutoBank page

    -- Page 2 Content Area (hidden by default)
    local page2Content = Instance.new('Frame')
    page2Content.Name = 'Page2Content'
    page2Content.Size = UDim2.new(1, 0, 1, -30)  -- Adjusted for smaller title bar
    page2Content.Position = UDim2.new(0, 0, 0, 30)  -- Adjusted for smaller title bar
    page2Content.BackgroundTransparency = 1
    page2Content.Active = true  -- Capture input to prevent drag-through
    page2Content.Visible = false
    page2Content.Parent = mainFrame

    -- Block input from propagating to mainFrame when on Page 2
    page2Content.InputBegan:Connect(function(input)
        -- Consume the input to prevent dragging
    end)

    -- Previous Page Button (⏮️)
    local prevPageBtn = Instance.new('TextButton')
    prevPageBtn.Name = generateRandomName('PrevPageBtn_')
    prevPageBtn.Size = UDim2.new(1, -20, 0, 28)  -- Full width like More button
    prevPageBtn.Position = UDim2.new(0, 10, 0, 140)  -- Same as More button position
    prevPageBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 140)
    prevPageBtn.BorderColor3 = Colors.border
    prevPageBtn.BorderSizePixel = 1
    prevPageBtn.TextColor3 = Colors.text_primary
    prevPageBtn.TextSize = 13
    prevPageBtn.Font = Enum.Font.GothamBold
    prevPageBtn.Text = '⏮️ Back'
    prevPageBtn.Visible = true  -- Visible when on Page 2
    prevPageBtn.Parent = page2Content

    local prevPageCorner = Instance.new('UICorner')
    prevPageCorner.CornerRadius = UDim.new(0, 6)
    prevPageCorner.Parent = prevPageBtn

    -- Next Page Button (⏭️) - On Page 1
    local nextPageBtn = Instance.new('TextButton')
    nextPageBtn.Name = generateRandomName('NextPageBtn_')
    nextPageBtn.Size = UDim2.new(1, -20, 0, 28)  -- Smaller
    nextPageBtn.Position = UDim2.new(0, 10, 0, 140)  -- Adjusted position
    nextPageBtn.BackgroundColor3 = Color3.fromRGB(80, 140, 80)
    nextPageBtn.BorderColor3 = Colors.border
    nextPageBtn.BorderSizePixel = 1
    nextPageBtn.TextColor3 = Colors.text_primary
    nextPageBtn.TextSize = 13
    nextPageBtn.Font = Enum.Font.GothamBold
    nextPageBtn.Text = 'More ⏭️'
    nextPageBtn.Parent = contentArea

    local nextPageCorner = Instance.new('UICorner')
    nextPageCorner.CornerRadius = UDim.new(0, 6)
    nextPageCorner.Parent = nextPageBtn

    -- ========================================================================
    -- PAGE 2: AUTO DODGE BUTTON + SETTINGS
    -- ========================================================================

    local autoDodgeButton = Instance.new('TextButton')
    autoDodgeButton.Name = generateRandomName('AutoDodgeBtn_')
    autoDodgeButton.Size = UDim2.new(1, -53, 0, 40)  -- Smaller button
    autoDodgeButton.Position = UDim2.new(0, 10, 0, 8)
    autoDodgeButton.BackgroundColor3 = Colors.accent_danger
    autoDodgeButton.BorderColor3 = Colors.border
    autoDodgeButton.BorderSizePixel = 1
    autoDodgeButton.TextColor3 = Colors.text_primary
    autoDodgeButton.TextSize = 13
    autoDodgeButton.Font = Enum.Font.GothamBold
    autoDodgeButton.Text = '🛡️ AUTO DODGE'
    autoDodgeButton.Parent = page2Content

    local autoDodgeCorner = Instance.new('UICorner')
    autoDodgeCorner.CornerRadius = UDim.new(0, 6)
    autoDodgeCorner.Parent = autoDodgeButton

    -- Auto Dodge Settings Button (⚙️)
    local autoDodgeSettingsBtn = Instance.new('TextButton')
    autoDodgeSettingsBtn.Name = generateRandomName('AutoDodgeSettingsBtn_')
    autoDodgeSettingsBtn.Size = UDim2.new(0, 33, 0, 40)  -- 5% smaller
    autoDodgeSettingsBtn.Position = UDim2.new(1, -43, 0, 8)
    autoDodgeSettingsBtn.BackgroundColor3 = Color3.fromRGB(255, 150, 0)  -- Orange color
    autoDodgeSettingsBtn.BorderColor3 = Colors.border
    autoDodgeSettingsBtn.BorderSizePixel = 1
    autoDodgeSettingsBtn.TextColor3 = Colors.text_primary
    autoDodgeSettingsBtn.TextSize = 15
    autoDodgeSettingsBtn.Font = Enum.Font.GothamBold
    autoDodgeSettingsBtn.Text = '⚙️'
    autoDodgeSettingsBtn.Parent = page2Content

    local autoDodgeSettingsCorner = Instance.new('UICorner')
    autoDodgeSettingsCorner.CornerRadius = UDim.new(0, 6)
    autoDodgeSettingsCorner.Parent = autoDodgeSettingsBtn

    -- Auto Dodge state
    _genv.autoDodgeEnabled = _genv.autoDodgeEnabled or false

    -- Auto Dodge button click
    autoDodgeButton.MouseButton1Click:Connect(function()
        _genv.autoDodgeEnabled = not _genv.autoDodgeEnabled
        autoDodgeEnabled = _genv.autoDodgeEnabled  -- Keep local in sync
        if _genv.autoDodgeEnabled then
            tweenColor(autoDodgeButton, Colors.accent_main, 0.2)
            if not AutoDodgeAPI then
                loadAutoDodge()
            end
            if AutoDodgeAPI then
                AutoDodgeAPI.enable()
            end
        else
            tweenColor(autoDodgeButton, Colors.accent_danger, 0.2)
            if AutoDodgeAPI then
                AutoDodgeAPI.disable()
            end
        end
    end)

    -- Auto Dodge button hover effects
    autoDodgeButton.MouseEnter:Connect(function()
        if _genv.autoDodgeEnabled then
            tweenColor(autoDodgeButton, Color3.fromRGB(0, 200, 80), 0.15)
        else
            tweenColor(autoDodgeButton, Color3.fromRGB(220, 30, 30), 0.15)
        end
    end)

    autoDodgeButton.MouseLeave:Connect(function()
        if _genv.autoDodgeEnabled then
            tweenColor(autoDodgeButton, Colors.accent_main, 0.15)
        else
            tweenColor(autoDodgeButton, Colors.accent_danger, 0.15)
        end
    end)

    -- Auto Dodge settings button hover effects
    autoDodgeSettingsBtn.MouseEnter:Connect(function()
        tweenColor(autoDodgeSettingsBtn, Color3.fromRGB(255, 180, 50), 0.1)
    end)

    autoDodgeSettingsBtn.MouseLeave:Connect(function()
        tweenColor(autoDodgeSettingsBtn, Color3.fromRGB(255, 150, 0), 0.1)
    end)

    -- Auto Dodge settings button click (opens dodge speed overlay)
    autoDodgeSettingsBtn.MouseButton1Click:Connect(function()
        toggleDodgeSettingsOverlay()
    end)

    -- ========================================================================
    -- PAGE 2: AUTO BANK BUTTON + SETTINGS
    -- ========================================================================

    local autoBankButton = Instance.new('TextButton')
    autoBankButton.Name = generateRandomName('AutoBankBtn_')
    autoBankButton.Size = UDim2.new(1, -53, 0, 40)  -- Smaller button
    autoBankButton.Position = UDim2.new(0, 10, 0, 52)  -- Adjusted position
    autoBankButton.BackgroundColor3 = Colors.accent_danger
    autoBankButton.BorderColor3 = Colors.border
    autoBankButton.BorderSizePixel = 1
    autoBankButton.TextColor3 = Colors.text_primary
    autoBankButton.TextSize = 13
    autoBankButton.Font = Enum.Font.GothamBold
    autoBankButton.Text = '🏦 AUTO BANK'
    autoBankButton.Parent = page2Content

    local autoBankCorner = Instance.new('UICorner')
    autoBankCorner.CornerRadius = UDim.new(0, 6)
    autoBankCorner.Parent = autoBankButton

    -- Auto Bank Settings Button (⚙️)
    local autoBankSettingsBtn = Instance.new('TextButton')
    autoBankSettingsBtn.Name = generateRandomName('AutoBankSettingsBtn_')
    autoBankSettingsBtn.Size = UDim2.new(0, 33, 0, 40)  -- 5% smaller
    autoBankSettingsBtn.Position = UDim2.new(1, -43, 0, 52)  -- Adjusted position
    autoBankSettingsBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)  -- Blue color
    autoBankSettingsBtn.BorderColor3 = Colors.border
    autoBankSettingsBtn.BorderSizePixel = 1
    autoBankSettingsBtn.TextColor3 = Colors.text_primary
    autoBankSettingsBtn.TextSize = 15
    autoBankSettingsBtn.Font = Enum.Font.GothamBold
    autoBankSettingsBtn.Text = '⚙️'
    autoBankSettingsBtn.Parent = page2Content

    local autoBankSettingsCorner = Instance.new('UICorner')
    autoBankSettingsCorner.CornerRadius = UDim.new(0, 6)
    autoBankSettingsCorner.Parent = autoBankSettingsBtn

    -- Auto Bank state
    _genv.autoBankEnabled = _genv.autoBankEnabled or false

    -- Auto Bank button click
    autoBankButton.MouseButton1Click:Connect(function()
        _genv.autoBankEnabled = not _genv.autoBankEnabled
        if _genv.autoBankEnabled then
            tweenColor(autoBankButton, Colors.accent_main, 0.2)
            if not AutoBankAPI then
                loadAutoBank()
            end
            if AutoBankAPI then
                AutoBankAPI.enableAutoManagement()
                _genv.AutoBankEnabled = true
            end
        else
            tweenColor(autoBankButton, Colors.accent_danger, 0.2)
            if AutoBankAPI then
                AutoBankAPI.disableAutoManagement()
                _genv.AutoBankEnabled = false
            end
        end
    end)

    -- Auto Bank button hover effects
    autoBankButton.MouseEnter:Connect(function()
        if _genv.autoBankEnabled then
            tweenColor(autoBankButton, Color3.fromRGB(0, 200, 80), 0.15)
        else
            tweenColor(autoBankButton, Color3.fromRGB(220, 30, 30), 0.15)
        end
    end)

    autoBankButton.MouseLeave:Connect(function()
        if _genv.autoBankEnabled then
            tweenColor(autoBankButton, Colors.accent_main, 0.15)
        else
            tweenColor(autoBankButton, Colors.accent_danger, 0.15)
        end
    end)

    -- Auto Bank settings button hover effects
    autoBankSettingsBtn.MouseEnter:Connect(function()
        tweenColor(autoBankSettingsBtn, Color3.fromRGB(0, 180, 255), 0.1)
    end)

    autoBankSettingsBtn.MouseLeave:Connect(function()
        tweenColor(autoBankSettingsBtn, Color3.fromRGB(0, 150, 255), 0.1)
    end)

    -- Auto Bank settings button click (opens bank settings overlay)
    autoBankSettingsBtn.MouseButton1Click:Connect(function()
        toggleBankSettingsOverlay()
    end)

    -- ========================================================================
    -- PAGE 2: SAVE/DELETE BUTTONS (Mirror Page 1)
    -- ========================================================================

    local page2SaveBtn = Instance.new('TextButton')
    page2SaveBtn.Name = generateRandomName('Page2SaveBtn_')
    page2SaveBtn.Size = UDim2.new(0.5, -15, 0, 32)  -- Same size as Page 1
    page2SaveBtn.Position = UDim2.new(0, 10, 0, 172)  -- Same Y position as Page 1
    page2SaveBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 180)
    page2SaveBtn.BorderColor3 = Colors.border
    page2SaveBtn.BorderSizePixel = 1
    page2SaveBtn.TextColor3 = Colors.text_primary
    page2SaveBtn.TextSize = 10
    page2SaveBtn.Font = Enum.Font.GothamBold
    page2SaveBtn.Text = '💾 SAVE'
    page2SaveBtn.Parent = page2Content

    local page2SaveCorner = Instance.new('UICorner')
    page2SaveCorner.CornerRadius = UDim.new(0, 6)
    page2SaveCorner.Parent = page2SaveBtn

    local page2DeleteBtn = Instance.new('TextButton')
    page2DeleteBtn.Name = generateRandomName('Page2DeleteBtn_')
    page2DeleteBtn.Size = UDim2.new(0.5, -15, 0, 32)  -- Same size as Page 1
    page2DeleteBtn.Position = UDim2.new(0.5, 5, 0, 172)  -- Same Y position as Page 1
    page2DeleteBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 80)
    page2DeleteBtn.BorderColor3 = Colors.border
    page2DeleteBtn.BorderSizePixel = 1
    page2DeleteBtn.TextColor3 = Colors.text_primary
    page2DeleteBtn.TextSize = 10
    page2DeleteBtn.Font = Enum.Font.GothamBold
    page2DeleteBtn.Text = '🗑️ DELETE'
    page2DeleteBtn.Parent = page2Content

    local page2DeleteCorner = Instance.new('UICorner')
    page2DeleteCorner.CornerRadius = UDim.new(0, 6)
    page2DeleteCorner.Parent = page2DeleteBtn

    -- Page 2 Save button click - uses same function as Page 1
    page2SaveBtn.MouseButton1Click:Connect(function()
        local success = saveCurrentState()
        if success then
            page2SaveBtn.Text = '✅ SAVED!'
            tweenColor(page2SaveBtn, Color3.fromRGB(0, 200, 80), 0.1)
            task.delay(1.5, function()
                if page2SaveBtn and page2SaveBtn.Parent then
                    page2SaveBtn.Text = '💾 SAVE'
                    tweenColor(page2SaveBtn, Color3.fromRGB(100, 100, 180), 0.2)
                end
            end)
        else
            page2SaveBtn.Text = '❌ FAILED!'
            tweenColor(page2SaveBtn, Colors.accent_danger, 0.1)
            task.delay(1.5, function()
                if page2SaveBtn and page2SaveBtn.Parent then
                    page2SaveBtn.Text = '💾 SAVE'
                    tweenColor(page2SaveBtn, Color3.fromRGB(100, 100, 180), 0.2)
                end
            end)
        end
    end)

    -- Page 2 Save button hover effects
    page2SaveBtn.MouseEnter:Connect(function()
        tweenColor(page2SaveBtn, Color3.fromRGB(120, 120, 200), 0.1)
    end)

    page2SaveBtn.MouseLeave:Connect(function()
        tweenColor(page2SaveBtn, Color3.fromRGB(100, 100, 180), 0.1)
    end)

    -- Page 2 Delete button click - uses same function as Page 1
    page2DeleteBtn.MouseButton1Click:Connect(function()
        local success = deleteCurrentState()
        if success then
            page2DeleteBtn.Text = '✅ DELETED!'
            tweenColor(page2DeleteBtn, Color3.fromRGB(0, 200, 80), 0.1)
            task.delay(1.5, function()
                if page2DeleteBtn and page2DeleteBtn.Parent then
                    page2DeleteBtn.Text = '🗑️ DELETE'
                    tweenColor(page2DeleteBtn, Color3.fromRGB(180, 80, 80), 0.2)
                end
            end)
        else
            page2DeleteBtn.Text = '❌ FAILED!'
            tweenColor(page2DeleteBtn, Colors.accent_danger, 0.1)
            task.delay(1.5, function()
                if page2DeleteBtn and page2DeleteBtn.Parent then
                    page2DeleteBtn.Text = '🗑️ DELETE'
                    tweenColor(page2DeleteBtn, Color3.fromRGB(180, 80, 80), 0.2)
                end
            end)
        end
    end)

    -- Page 2 Delete button hover effects
    page2DeleteBtn.MouseEnter:Connect(function()
        tweenColor(page2DeleteBtn, Color3.fromRGB(200, 100, 100), 0.1)
    end)

    page2DeleteBtn.MouseLeave:Connect(function()
        tweenColor(page2DeleteBtn, Color3.fromRGB(180, 80, 80), 0.1)
    end)

    -- ========================================================================
    -- NO POPUP AUTO-MANAGEMENT (enabled when settings overlays open)
    -- ========================================================================
    
    -- Helper function to enable/disable No Popup when settings overlays are opened/closed
    setNoPopupState = function(enabled)
        loadNoPopup()
        if NoPopupAPI then
            if enabled then
                NoPopupAPI.enable()
            else
                NoPopupAPI.disable()
            end
        else
            getgenv().NoPopupEnabled = enabled
        end
    end

    -- ========================================================================
    -- PAGINATION LOGIC
    -- ========================================================================

    local function switchToPage(pageNum)
        currentPage = pageNum
        if pageNum == 1 then
            contentArea.Visible = true
            page2Content.Visible = false
        else
            contentArea.Visible = false
            page2Content.Visible = true
            prevPageBtn.Visible = true
        end
    end

    -- Next page button click
    nextPageBtn.MouseButton1Click:Connect(function()
        switchToPage(2)
    end)

    nextPageBtn.MouseEnter:Connect(function()
        tweenColor(nextPageBtn, Color3.fromRGB(100, 160, 100), 0.1)
    end)

    nextPageBtn.MouseLeave:Connect(function()
        tweenColor(nextPageBtn, Color3.fromRGB(80, 140, 80), 0.1)
    end)

    -- Previous page button click
    prevPageBtn.MouseButton1Click:Connect(function()
        switchToPage(1)
    end)

    prevPageBtn.MouseEnter:Connect(function()
        tweenColor(prevPageBtn, Color3.fromRGB(100, 100, 160), 0.1)
    end)

    prevPageBtn.MouseLeave:Connect(function()
        tweenColor(prevPageBtn, Color3.fromRGB(80, 80, 140), 0.1)
    end)

    -- ========================================================================
    -- AUTO DODGE SETTINGS OVERLAY
    -- ========================================================================

    local dodgeSettingsVisible = false
    
    -- Create dodge settings overlay on mainFrame
    local dodgeSettingsOverlay = Instance.new('Frame')
    dodgeSettingsOverlay.Name = 'AutoDodgeSettingsOverlay'
    dodgeSettingsOverlay.Size = UDim2.new(1, 0, 1, 0)
    dodgeSettingsOverlay.Position = UDim2.new(0, 0, 0, 0)
    dodgeSettingsOverlay.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    dodgeSettingsOverlay.BackgroundTransparency = 0
    dodgeSettingsOverlay.BorderSizePixel = 0
    dodgeSettingsOverlay.Visible = false
    dodgeSettingsOverlay.Active = true
    dodgeSettingsOverlay.ZIndex = 10
    dodgeSettingsOverlay.Parent = mainFrame

    dodgeSettingsOverlay.InputBegan:Connect(function(input) end)
    dodgeSettingsOverlay.InputEnded:Connect(function(input) end)

    local dodgeOverlayCorner = Instance.new('UICorner')
    dodgeOverlayCorner.CornerRadius = UDim.new(0, 8)
    dodgeOverlayCorner.Parent = dodgeSettingsOverlay

    -- Dodge Settings Header
    local dodgeSettingsHeader = Instance.new('Frame')
    dodgeSettingsHeader.Name = 'Header'
    dodgeSettingsHeader.Size = UDim2.new(1, 0, 0, 35)
    dodgeSettingsHeader.Position = UDim2.new(0, 0, 0, 0)
    dodgeSettingsHeader.BackgroundColor3 = Colors.bg_secondary
    dodgeSettingsHeader.BorderSizePixel = 0
    dodgeSettingsHeader.Active = true
    dodgeSettingsHeader.ZIndex = 11
    dodgeSettingsHeader.Parent = dodgeSettingsOverlay

    dodgeSettingsHeader.InputBegan:Connect(function(input) end)

    local dodgeHeaderCorner = Instance.new('UICorner')
    dodgeHeaderCorner.CornerRadius = UDim.new(0, 8)
    dodgeHeaderCorner.Parent = dodgeSettingsHeader

    local dodgeSettingsTitle = Instance.new('TextLabel')
    dodgeSettingsTitle.Name = 'Title'
    dodgeSettingsTitle.Size = UDim2.new(1, -40, 1, 0)
    dodgeSettingsTitle.Position = UDim2.new(0, 10, 0, 0)
    dodgeSettingsTitle.BackgroundTransparency = 1
    dodgeSettingsTitle.TextColor3 = Color3.fromRGB(255, 150, 0)
    dodgeSettingsTitle.TextSize = 14
    dodgeSettingsTitle.Font = Enum.Font.GothamBold
    dodgeSettingsTitle.Text = '🛡️ Dodge Settings'
    dodgeSettingsTitle.TextXAlignment = Enum.TextXAlignment.Left
    dodgeSettingsTitle.ZIndex = 12
    dodgeSettingsTitle.Parent = dodgeSettingsHeader

    local closeDodgeSettingsBtn = Instance.new('TextButton')
    closeDodgeSettingsBtn.Name = 'Close'
    closeDodgeSettingsBtn.Size = UDim2.new(0, 30, 0, 30)
    closeDodgeSettingsBtn.Position = UDim2.new(1, -32, 0, 2)
    closeDodgeSettingsBtn.BackgroundColor3 = Colors.accent_danger
    closeDodgeSettingsBtn.BorderSizePixel = 0
    closeDodgeSettingsBtn.TextColor3 = Colors.text_primary
    closeDodgeSettingsBtn.TextSize = 14
    closeDodgeSettingsBtn.Font = Enum.Font.GothamBold
    closeDodgeSettingsBtn.Text = 'X'
    closeDodgeSettingsBtn.ZIndex = 12
    closeDodgeSettingsBtn.Parent = dodgeSettingsHeader

    local closeDodgeBtnCorner = Instance.new('UICorner')
    closeDodgeBtnCorner.CornerRadius = UDim.new(0, 6)
    closeDodgeBtnCorner.Parent = closeDodgeSettingsBtn

    -- Dodge Settings Content
    local dodgeSettingsContent = Instance.new('ScrollingFrame')
    dodgeSettingsContent.Name = 'Content'
    dodgeSettingsContent.Size = UDim2.new(1, 0, 1, -35)
    dodgeSettingsContent.Position = UDim2.new(0, 0, 0, 35)
    dodgeSettingsContent.BackgroundTransparency = 1
    dodgeSettingsContent.Active = true
    dodgeSettingsContent.ZIndex = 11
    dodgeSettingsContent.ScrollBarThickness = 4
    dodgeSettingsContent.ScrollBarImageColor3 = Color3.fromRGB(255, 150, 0)
    dodgeSettingsContent.CanvasSize = UDim2.new(0, 0, 0, 240)
    dodgeSettingsContent.ScrollingDirection = Enum.ScrollingDirection.Y
    dodgeSettingsContent.BorderSizePixel = 0
    dodgeSettingsContent.Parent = dodgeSettingsOverlay

    dodgeSettingsContent.InputBegan:Connect(function(input) end)

    -- Initialize dodge settings from genv or defaults
    local dodgeTweenSpeed = _genv.AutoDodgeTweenSpeed or 0.12
    local dodgeDetectionRadius = _genv.AutoDodgeDetectionRadius or 180
    local dodgeSkipGround = _genv.AutoDodgeSkipGround ~= false

    -- TWEEN SPEED SLIDER
    local tweenSpeedLabel = Instance.new('TextLabel')
    tweenSpeedLabel.Name = 'TweenSpeedLabel'
    tweenSpeedLabel.Size = UDim2.new(0.6, 0, 0, 20)
    tweenSpeedLabel.Position = UDim2.new(0, 10, 0, 10)
    tweenSpeedLabel.BackgroundTransparency = 1
    tweenSpeedLabel.TextColor3 = Colors.text_primary
    tweenSpeedLabel.TextSize = 12
    tweenSpeedLabel.Font = Enum.Font.GothamBold
    tweenSpeedLabel.Text = 'Dodge Speed'
    tweenSpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
    tweenSpeedLabel.ZIndex = 12
    tweenSpeedLabel.Parent = dodgeSettingsContent

    local tweenSpeedValue = Instance.new('TextLabel')
    tweenSpeedValue.Name = 'TweenSpeedValue'
    tweenSpeedValue.Size = UDim2.new(0.3, 0, 0, 20)
    tweenSpeedValue.Position = UDim2.new(0.65, 0, 0, 10)
    tweenSpeedValue.BackgroundTransparency = 1
    tweenSpeedValue.TextColor3 = Color3.fromRGB(255, 150, 0)
    tweenSpeedValue.TextSize = 12
    tweenSpeedValue.Font = Enum.Font.GothamBold
    tweenSpeedValue.Text = string.format("%.2fs", dodgeTweenSpeed)
    tweenSpeedValue.TextXAlignment = Enum.TextXAlignment.Right
    tweenSpeedValue.ZIndex = 12
    tweenSpeedValue.Parent = dodgeSettingsContent

    local tweenSpeedSliderBg = Instance.new('Frame')
    tweenSpeedSliderBg.Name = 'TweenSpeedSliderBg'
    tweenSpeedSliderBg.Size = UDim2.new(1, -20, 0, 16)
    tweenSpeedSliderBg.Position = UDim2.new(0, 10, 0, 32)
    tweenSpeedSliderBg.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    tweenSpeedSliderBg.BorderSizePixel = 0
    tweenSpeedSliderBg.Active = true
    tweenSpeedSliderBg.ZIndex = 12
    tweenSpeedSliderBg.Parent = dodgeSettingsContent

    local tweenSpeedBgCorner = Instance.new('UICorner')
    tweenSpeedBgCorner.CornerRadius = UDim.new(0, 8)
    tweenSpeedBgCorner.Parent = tweenSpeedSliderBg

    local tweenSpeedFill = Instance.new('Frame')
    tweenSpeedFill.Name = 'Fill'
    tweenSpeedFill.Size = UDim2.new((dodgeTweenSpeed - 0.05) / 0.45, 0, 1, 0)  -- 0.05 to 0.5 range
    tweenSpeedFill.Position = UDim2.new(0, 0, 0, 0)
    tweenSpeedFill.BackgroundColor3 = Color3.fromRGB(255, 150, 0)
    tweenSpeedFill.BorderSizePixel = 0
    tweenSpeedFill.ZIndex = 13
    tweenSpeedFill.Parent = tweenSpeedSliderBg

    local tweenSpeedFillCorner = Instance.new('UICorner')
    tweenSpeedFillCorner.CornerRadius = UDim.new(0, 8)
    tweenSpeedFillCorner.Parent = tweenSpeedFill

    local function updateTweenSpeedSlider(input)
        local sliderX = tweenSpeedSliderBg.AbsolutePosition.X
        local sliderWidth = tweenSpeedSliderBg.AbsoluteSize.X
        local mouseX = input.Position.X
        local percent = math.clamp((mouseX - sliderX) / sliderWidth, 0, 1)
        dodgeTweenSpeed = 0.05 + percent * 0.45  -- 0.05 to 0.5
        dodgeTweenSpeed = math.floor(dodgeTweenSpeed * 100 + 0.5) / 100
        tweenSpeedValue.Text = string.format("%.2fs", dodgeTweenSpeed)
        TweenService:Create(tweenSpeedFill, TweenInfo.new(0.1), {Size = UDim2.new(percent, 0, 1, 0)}):Play()
        _genv.AutoDodgeTweenSpeed = dodgeTweenSpeed
        if AutoDodgeAPI and AutoDodgeAPI.config then
            AutoDodgeAPI.config.tweenDuration = dodgeTweenSpeed
        end
    end

    local tweenSpeedDragging = false
    tweenSpeedSliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            tweenSpeedDragging = true
            updateTweenSpeedSlider(input)
        end
    end)
    tweenSpeedSliderBg.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            tweenSpeedDragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if tweenSpeedDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateTweenSpeedSlider(input)
        end
    end)

    -- DETECTION RADIUS SLIDER
    local radiusLabel = Instance.new('TextLabel')
    radiusLabel.Name = 'RadiusLabel'
    radiusLabel.Size = UDim2.new(0.6, 0, 0, 20)
    radiusLabel.Position = UDim2.new(0, 10, 0, 60)
    radiusLabel.BackgroundTransparency = 1
    radiusLabel.TextColor3 = Colors.text_primary
    radiusLabel.TextSize = 12
    radiusLabel.Font = Enum.Font.GothamBold
    radiusLabel.Text = 'Detection Radius'
    radiusLabel.TextXAlignment = Enum.TextXAlignment.Left
    radiusLabel.ZIndex = 12
    radiusLabel.Parent = dodgeSettingsContent

    local radiusValue = Instance.new('TextLabel')
    radiusValue.Name = 'RadiusValue'
    radiusValue.Size = UDim2.new(0.3, 0, 0, 20)
    radiusValue.Position = UDim2.new(0.65, 0, 0, 60)
    radiusValue.BackgroundTransparency = 1
    radiusValue.TextColor3 = Color3.fromRGB(255, 150, 0)
    radiusValue.TextSize = 12
    radiusValue.Font = Enum.Font.GothamBold
    radiusValue.Text = tostring(dodgeDetectionRadius)
    radiusValue.TextXAlignment = Enum.TextXAlignment.Right
    radiusValue.ZIndex = 12
    radiusValue.Parent = dodgeSettingsContent

    local radiusSliderBg = Instance.new('Frame')
    radiusSliderBg.Name = 'RadiusSliderBg'
    radiusSliderBg.Size = UDim2.new(1, -20, 0, 16)
    radiusSliderBg.Position = UDim2.new(0, 10, 0, 82)
    radiusSliderBg.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    radiusSliderBg.BorderSizePixel = 0
    radiusSliderBg.Active = true
    radiusSliderBg.ZIndex = 12
    radiusSliderBg.Parent = dodgeSettingsContent

    local radiusBgCorner = Instance.new('UICorner')
    radiusBgCorner.CornerRadius = UDim.new(0, 8)
    radiusBgCorner.Parent = radiusSliderBg

    local radiusFill = Instance.new('Frame')
    radiusFill.Name = 'Fill'
    radiusFill.Size = UDim2.new((dodgeDetectionRadius - 50) / 200, 0, 1, 0)  -- 50 to 250 range
    radiusFill.Position = UDim2.new(0, 0, 0, 0)
    radiusFill.BackgroundColor3 = Color3.fromRGB(255, 150, 0)
    radiusFill.BorderSizePixel = 0
    radiusFill.ZIndex = 13
    radiusFill.Parent = radiusSliderBg

    local radiusFillCorner = Instance.new('UICorner')
    radiusFillCorner.CornerRadius = UDim.new(0, 8)
    radiusFillCorner.Parent = radiusFill

    local function updateRadiusSlider(input)
        local sliderX = radiusSliderBg.AbsolutePosition.X
        local sliderWidth = radiusSliderBg.AbsoluteSize.X
        local mouseX = input.Position.X
        local percent = math.clamp((mouseX - sliderX) / sliderWidth, 0, 1)
        dodgeDetectionRadius = math.floor(50 + percent * 200)  -- 50 to 250
        radiusValue.Text = tostring(dodgeDetectionRadius)
        TweenService:Create(radiusFill, TweenInfo.new(0.1), {Size = UDim2.new(percent, 0, 1, 0)}):Play()
        _genv.AutoDodgeDetectionRadius = dodgeDetectionRadius
        if AutoDodgeAPI and AutoDodgeAPI.config then
            AutoDodgeAPI.config.detectionRadius = dodgeDetectionRadius
        end
    end

    local radiusDragging = false
    radiusSliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            radiusDragging = true
            updateRadiusSlider(input)
        end
    end)
    radiusSliderBg.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            radiusDragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if radiusDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateRadiusSlider(input)
        end
    end)

    -- SKIP GROUND ATTACKS TOGGLE
    local skipGroundLabel = Instance.new('TextLabel')
    skipGroundLabel.Name = 'SkipGroundLabel'
    skipGroundLabel.Size = UDim2.new(0.7, 0, 0, 28)
    skipGroundLabel.Position = UDim2.new(0, 10, 0, 115)
    skipGroundLabel.BackgroundTransparency = 1
    skipGroundLabel.TextColor3 = Colors.text_primary
    skipGroundLabel.TextSize = 12
    skipGroundLabel.Font = Enum.Font.GothamBold
    skipGroundLabel.Text = 'Skip Ground Attacks (Flying)'
    skipGroundLabel.TextXAlignment = Enum.TextXAlignment.Left
    skipGroundLabel.ZIndex = 12
    skipGroundLabel.Parent = dodgeSettingsContent

    local skipGroundToggle = Instance.new('TextButton')
    skipGroundToggle.Name = 'SkipGroundToggle'
    skipGroundToggle.Size = UDim2.new(0, 50, 0, 26)
    skipGroundToggle.Position = UDim2.new(1, -60, 0, 116)
    skipGroundToggle.BackgroundColor3 = dodgeSkipGround and Colors.accent_main or Color3.fromRGB(80, 80, 80)
    skipGroundToggle.BorderSizePixel = 0
    skipGroundToggle.TextColor3 = Colors.text_primary
    skipGroundToggle.TextSize = 10
    skipGroundToggle.Font = Enum.Font.GothamBold
    skipGroundToggle.Text = dodgeSkipGround and 'ON' or 'OFF'
    skipGroundToggle.ZIndex = 12
    skipGroundToggle.Parent = dodgeSettingsContent

    local skipGroundToggleCorner = Instance.new('UICorner')
    skipGroundToggleCorner.CornerRadius = UDim.new(0, 6)
    skipGroundToggleCorner.Parent = skipGroundToggle

    skipGroundToggle.MouseButton1Click:Connect(function()
        dodgeSkipGround = not dodgeSkipGround
        skipGroundToggle.Text = dodgeSkipGround and 'ON' or 'OFF'
        tweenColor(skipGroundToggle, dodgeSkipGround and Colors.accent_main or Color3.fromRGB(80, 80, 80), 0.2)
        _genv.AutoDodgeSkipGround = dodgeSkipGround
        if AutoDodgeAPI and AutoDodgeAPI.config then
            AutoDodgeAPI.config.skipGroundAttacksWhenFlying = dodgeSkipGround
        end
    end)

    -- PAUSE FARM WHEN DODGING TOGGLE
    local pauseFarmLabel = Instance.new('TextLabel')
    pauseFarmLabel.Name = 'PauseFarmLabel'
    pauseFarmLabel.Size = UDim2.new(0.7, 0, 0, 28)
    pauseFarmLabel.Position = UDim2.new(0, 10, 0, 155)
    pauseFarmLabel.BackgroundTransparency = 1
    pauseFarmLabel.TextColor3 = Colors.text_primary
    pauseFarmLabel.TextSize = 12
    pauseFarmLabel.Font = Enum.Font.GothamBold
    pauseFarmLabel.Text = 'Pause Farm When Dodging'
    pauseFarmLabel.TextXAlignment = Enum.TextXAlignment.Left
    pauseFarmLabel.ZIndex = 12
    pauseFarmLabel.Parent = dodgeSettingsContent

    local pauseFarmOnDodge = _genv.AutoDodgePauseFarm or false
    local pauseFarmToggle = Instance.new('TextButton')
    pauseFarmToggle.Name = 'PauseFarmToggle'
    pauseFarmToggle.Size = UDim2.new(0, 50, 0, 26)
    pauseFarmToggle.Position = UDim2.new(1, -60, 0, 156)
    pauseFarmToggle.BackgroundColor3 = pauseFarmOnDodge and Colors.accent_main or Color3.fromRGB(80, 80, 80)
    pauseFarmToggle.BorderSizePixel = 0
    pauseFarmToggle.TextColor3 = Colors.text_primary
    pauseFarmToggle.TextSize = 10
    pauseFarmToggle.Font = Enum.Font.GothamBold
    pauseFarmToggle.Text = pauseFarmOnDodge and 'ON' or 'OFF'
    pauseFarmToggle.ZIndex = 12
    pauseFarmToggle.Parent = dodgeSettingsContent

    local pauseFarmToggleCorner = Instance.new('UICorner')
    pauseFarmToggleCorner.CornerRadius = UDim.new(0, 6)
    pauseFarmToggleCorner.Parent = pauseFarmToggle

    pauseFarmToggle.MouseButton1Click:Connect(function()
        pauseFarmOnDodge = not pauseFarmOnDodge
        pauseFarmToggle.Text = pauseFarmOnDodge and 'ON' or 'OFF'
        tweenColor(pauseFarmToggle, pauseFarmOnDodge and Colors.accent_main or Color3.fromRGB(80, 80, 80), 0.2)
        _genv.AutoDodgePauseFarm = pauseFarmOnDodge
    end)

    -- Toggle dodge settings overlay function
    toggleDodgeSettingsOverlay = function()
        dodgeSettingsVisible = not dodgeSettingsVisible
        if dodgeSettingsVisible then
            setNoPopupState(true)  -- Enable No Popup when opening settings
            page2Content.Visible = false
            dodgeSettingsOverlay.Visible = true
            dodgeSettingsOverlay.BackgroundTransparency = 1
            local tween = TweenService:Create(dodgeSettingsOverlay, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0})
            tween:Play()
        else
            setNoPopupState(false)  -- Disable No Popup when closing settings
            local tween = TweenService:Create(dodgeSettingsOverlay, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
            tween:Play()
            tween.Completed:Connect(function()
                dodgeSettingsOverlay.Visible = false
                -- Restore correct page based on currentPage
                if currentPage == 2 then
                    page2Content.Visible = true
                else
                    contentArea.Visible = true
                end
            end)
        end
    end

    closeDodgeSettingsBtn.MouseButton1Click:Connect(function()
        dodgeSettingsVisible = true
        toggleDodgeSettingsOverlay()
    end)

    -- ========================================================================
    -- AUTO BANK SETTINGS OVERLAY
    -- ========================================================================

    local bankSettingsVisible = false
    
    -- Create bank settings overlay on mainFrame
    local bankSettingsOverlay = Instance.new('Frame')
    bankSettingsOverlay.Name = 'AutoBankSettingsOverlay'
    bankSettingsOverlay.Size = UDim2.new(1, 0, 1, 0)
    bankSettingsOverlay.Position = UDim2.new(0, 0, 0, 0)
    bankSettingsOverlay.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    bankSettingsOverlay.BackgroundTransparency = 0
    bankSettingsOverlay.BorderSizePixel = 0
    bankSettingsOverlay.Visible = false
    bankSettingsOverlay.Active = true
    bankSettingsOverlay.ZIndex = 10
    bankSettingsOverlay.Parent = mainFrame

    bankSettingsOverlay.InputBegan:Connect(function(input) end)
    bankSettingsOverlay.InputEnded:Connect(function(input) end)

    local bankOverlayCorner = Instance.new('UICorner')
    bankOverlayCorner.CornerRadius = UDim.new(0, 8)
    bankOverlayCorner.Parent = bankSettingsOverlay

    -- Bank Settings Header
    local bankSettingsHeader = Instance.new('Frame')
    bankSettingsHeader.Name = 'Header'
    bankSettingsHeader.Size = UDim2.new(1, 0, 0, 35)
    bankSettingsHeader.Position = UDim2.new(0, 0, 0, 0)
    bankSettingsHeader.BackgroundColor3 = Colors.bg_secondary
    bankSettingsHeader.BorderSizePixel = 0
    bankSettingsHeader.Active = true
    bankSettingsHeader.ZIndex = 11
    bankSettingsHeader.Parent = bankSettingsOverlay

    bankSettingsHeader.InputBegan:Connect(function(input) end)

    local bankHeaderCorner = Instance.new('UICorner')
    bankHeaderCorner.CornerRadius = UDim.new(0, 8)
    bankHeaderCorner.Parent = bankSettingsHeader

    local bankSettingsTitle = Instance.new('TextLabel')
    bankSettingsTitle.Name = 'Title'
    bankSettingsTitle.Size = UDim2.new(1, -40, 1, 0)
    bankSettingsTitle.Position = UDim2.new(0, 10, 0, 0)
    bankSettingsTitle.BackgroundTransparency = 1
    bankSettingsTitle.TextColor3 = Color3.fromRGB(0, 150, 255)
    bankSettingsTitle.TextSize = 14
    bankSettingsTitle.Font = Enum.Font.GothamBold
    bankSettingsTitle.Text = '🏦 Bank Settings'
    bankSettingsTitle.TextXAlignment = Enum.TextXAlignment.Left
    bankSettingsTitle.ZIndex = 12
    bankSettingsTitle.Parent = bankSettingsHeader

    local closeBankSettingsBtn = Instance.new('TextButton')
    closeBankSettingsBtn.Name = 'Close'
    closeBankSettingsBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBankSettingsBtn.Position = UDim2.new(1, -32, 0, 2)
    closeBankSettingsBtn.BackgroundColor3 = Colors.accent_danger
    closeBankSettingsBtn.BorderSizePixel = 0
    closeBankSettingsBtn.TextColor3 = Colors.text_primary
    closeBankSettingsBtn.TextSize = 14
    closeBankSettingsBtn.Font = Enum.Font.GothamBold
    closeBankSettingsBtn.Text = 'X'
    closeBankSettingsBtn.ZIndex = 12
    closeBankSettingsBtn.Parent = bankSettingsHeader

    local closeBankBtnCorner = Instance.new('UICorner')
    closeBankBtnCorner.CornerRadius = UDim.new(0, 6)
    closeBankBtnCorner.Parent = closeBankSettingsBtn

    -- Bank Settings Content
    local bankSettingsContent = Instance.new('ScrollingFrame')
    bankSettingsContent.Name = 'Content'
    bankSettingsContent.Size = UDim2.new(1, 0, 1, -35)
    bankSettingsContent.Position = UDim2.new(0, 0, 0, 35)
    bankSettingsContent.BackgroundTransparency = 1
    bankSettingsContent.Active = true
    bankSettingsContent.ZIndex = 11
    bankSettingsContent.ScrollBarThickness = 4
    bankSettingsContent.ScrollBarImageColor3 = Color3.fromRGB(0, 150, 255)
    bankSettingsContent.CanvasSize = UDim2.new(0, 0, 0, 240)
    bankSettingsContent.ScrollingDirection = Enum.ScrollingDirection.Y
    bankSettingsContent.BorderSizePixel = 0
    bankSettingsContent.Parent = bankSettingsOverlay

    bankSettingsContent.InputBegan:Connect(function(input) end)

    -- Initialize bank settings from genv or defaults
    local sellBelowGrade = _genv.AutoBankSellBelowGrade or "A"
    local depositEquipped = _genv.AutoBankKeepEquipped == false  -- OFF by default (keep equipped)
    local depositLocked = _genv.AutoBankKeepLocked == false  -- OFF by default (keep locked)
    local inventoryThreshold = _genv.AutoBankInventoryThreshold or 0.9

    -- SELL BELOW GRADE SELECTOR
    local gradeLabel = Instance.new('TextLabel')
    gradeLabel.Name = 'GradeLabel'
    gradeLabel.Size = UDim2.new(0.5, -5, 0, 20)
    gradeLabel.Position = UDim2.new(0, 10, 0, 10)
    gradeLabel.BackgroundTransparency = 1
    gradeLabel.TextColor3 = Colors.text_primary
    gradeLabel.TextSize = 11
    gradeLabel.Font = Enum.Font.GothamBold
    gradeLabel.Text = 'Sell Bank Items'
    gradeLabel.TextXAlignment = Enum.TextXAlignment.Left
    gradeLabel.ZIndex = 12
    gradeLabel.Parent = bankSettingsContent

    local grades = {"C", "B", "A", "S", "S+"}
    local gradeIndex = 3  -- Default to A
    for i, g in ipairs(grades) do
        if g == sellBelowGrade then gradeIndex = i break end
    end

    -- Grade selector buttons positioned on same row as label, right-aligned
    local gradePrevBtn = Instance.new('TextButton')
    gradePrevBtn.Name = 'GradePrev'
    gradePrevBtn.Size = UDim2.new(0, 22, 0, 22)
    gradePrevBtn.Position = UDim2.new(0.5, -5, 0, 8)
    gradePrevBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    gradePrevBtn.BorderSizePixel = 0
    gradePrevBtn.TextColor3 = Colors.text_primary
    gradePrevBtn.TextSize = 12
    gradePrevBtn.Font = Enum.Font.GothamBold
    gradePrevBtn.Text = '<'
    gradePrevBtn.ZIndex = 12
    gradePrevBtn.Parent = bankSettingsContent

    local gradePrevCorner = Instance.new('UICorner')
    gradePrevCorner.CornerRadius = UDim.new(0, 4)
    gradePrevCorner.Parent = gradePrevBtn

    local gradeValueLabel = Instance.new('TextLabel')
    gradeValueLabel.Name = 'GradeValue'
    gradeValueLabel.Size = UDim2.new(0, 70, 0, 22)
    gradeValueLabel.Position = UDim2.new(0.5, 20, 0, 8)
    gradeValueLabel.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    gradeValueLabel.BackgroundTransparency = 0
    gradeValueLabel.TextColor3 = Colors.text_primary
    gradeValueLabel.TextSize = 10
    gradeValueLabel.Font = Enum.Font.GothamBold
    gradeValueLabel.Text = sellBelowGrade .. ' & Below'
    gradeValueLabel.ZIndex = 12
    gradeValueLabel.Parent = bankSettingsContent

    local gradeValueCorner = Instance.new('UICorner')
    gradeValueCorner.CornerRadius = UDim.new(0, 4)
    gradeValueCorner.Parent = gradeValueLabel

    local gradeNextBtn = Instance.new('TextButton')
    gradeNextBtn.Name = 'GradeNext'
    gradeNextBtn.Size = UDim2.new(0, 22, 0, 22)
    gradeNextBtn.Position = UDim2.new(0.5, 93, 0, 8)
    gradeNextBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    gradeNextBtn.BorderSizePixel = 0
    gradeNextBtn.TextColor3 = Colors.text_primary
    gradeNextBtn.TextSize = 12
    gradeNextBtn.Font = Enum.Font.GothamBold
    gradeNextBtn.Text = '>'
    gradeNextBtn.ZIndex = 12
    gradeNextBtn.Parent = bankSettingsContent

    local gradeNextCorner = Instance.new('UICorner')
    gradeNextCorner.CornerRadius = UDim.new(0, 4)
    gradeNextCorner.Parent = gradeNextBtn

    local function updateGradeDisplay()
        sellBelowGrade = grades[gradeIndex]
        gradeValueLabel.Text = sellBelowGrade .. ' & Below'
        _genv.AutoBankSellBelowGrade = sellBelowGrade
    end

    gradePrevBtn.MouseButton1Click:Connect(function()
        gradeIndex = math.max(1, gradeIndex - 1)
        updateGradeDisplay()
    end)

    gradeNextBtn.MouseButton1Click:Connect(function()
        gradeIndex = math.min(#grades, gradeIndex + 1)
        updateGradeDisplay()
    end)

    -- INVENTORY THRESHOLD SLIDER
    local thresholdLabel = Instance.new('TextLabel')
    thresholdLabel.Name = 'ThresholdLabel'
    thresholdLabel.Size = UDim2.new(0.6, 0, 0, 18)
    thresholdLabel.Position = UDim2.new(0, 10, 0, 38)
    thresholdLabel.BackgroundTransparency = 1
    thresholdLabel.TextColor3 = Colors.text_primary
    thresholdLabel.TextSize = 11
    thresholdLabel.Font = Enum.Font.GothamBold
    thresholdLabel.Text = 'Auto-Manage Threshold'
    thresholdLabel.TextXAlignment = Enum.TextXAlignment.Left
    thresholdLabel.ZIndex = 12
    thresholdLabel.Parent = bankSettingsContent

    local thresholdValue = Instance.new('TextLabel')
    thresholdValue.Name = 'ThresholdValue'
    thresholdValue.Size = UDim2.new(0.3, -10, 0, 18)
    thresholdValue.Position = UDim2.new(0.7, 0, 0, 38)
    thresholdValue.BackgroundTransparency = 1
    thresholdValue.TextColor3 = Color3.fromRGB(0, 150, 255)
    thresholdValue.TextSize = 11
    thresholdValue.Font = Enum.Font.GothamBold
    thresholdValue.Text = string.format("%d%%", inventoryThreshold * 100)
    thresholdValue.TextXAlignment = Enum.TextXAlignment.Right
    thresholdValue.ZIndex = 12
    thresholdValue.Parent = bankSettingsContent

    local thresholdSliderBg = Instance.new('Frame')
    thresholdSliderBg.Name = 'ThresholdSliderBg'
    thresholdSliderBg.Size = UDim2.new(1, -20, 0, 14)
    thresholdSliderBg.Position = UDim2.new(0, 10, 0, 58)
    thresholdSliderBg.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    thresholdSliderBg.BorderSizePixel = 0
    thresholdSliderBg.Active = true
    thresholdSliderBg.ZIndex = 12
    thresholdSliderBg.Parent = bankSettingsContent

    local thresholdBgCorner = Instance.new('UICorner')
    thresholdBgCorner.CornerRadius = UDim.new(0, 8)
    thresholdBgCorner.Parent = thresholdSliderBg

    local thresholdFill = Instance.new('Frame')
    thresholdFill.Name = 'Fill'
    thresholdFill.Size = UDim2.new((inventoryThreshold - 0.5) / 0.5, 0, 1, 0)  -- 0.5 to 1.0 range (50% to 100%)
    thresholdFill.Position = UDim2.new(0, 0, 0, 0)
    thresholdFill.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    thresholdFill.BorderSizePixel = 0
    thresholdFill.ZIndex = 13
    thresholdFill.Parent = thresholdSliderBg

    local thresholdFillCorner = Instance.new('UICorner')
    thresholdFillCorner.CornerRadius = UDim.new(0, 8)
    thresholdFillCorner.Parent = thresholdFill

    local function updateThresholdSlider(input)
        local sliderX = thresholdSliderBg.AbsolutePosition.X
        local sliderWidth = thresholdSliderBg.AbsoluteSize.X
        local mouseX = input.Position.X
        local percent = math.clamp((mouseX - sliderX) / sliderWidth, 0, 1)
        inventoryThreshold = 0.5 + percent * 0.5  -- 0.5 to 1.0
        inventoryThreshold = math.floor(inventoryThreshold * 100 + 0.5) / 100
        thresholdValue.Text = string.format("%d%%", inventoryThreshold * 100)
        TweenService:Create(thresholdFill, TweenInfo.new(0.1), {Size = UDim2.new(percent, 0, 1, 0)}):Play()
        _genv.AutoBankInventoryThreshold = inventoryThreshold
    end

    local thresholdDragging = false
    thresholdSliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            thresholdDragging = true
            updateThresholdSlider(input)
        end
    end)
    thresholdSliderBg.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            thresholdDragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if thresholdDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateThresholdSlider(input)
        end
    end)

    -- DEPOSIT EQUIPPED TOGGLE
    local depositEquippedLabel = Instance.new('TextLabel')
    depositEquippedLabel.Name = 'DepositEquippedLabel'
    depositEquippedLabel.Size = UDim2.new(0.7, 0, 0, 24)
    depositEquippedLabel.Position = UDim2.new(0, 10, 0, 82)
    depositEquippedLabel.BackgroundTransparency = 1
    depositEquippedLabel.TextColor3 = Colors.text_primary
    depositEquippedLabel.TextSize = 11
    depositEquippedLabel.Font = Enum.Font.GothamBold
    depositEquippedLabel.Text = 'Deposit Equipped Items'
    depositEquippedLabel.TextXAlignment = Enum.TextXAlignment.Left
    depositEquippedLabel.ZIndex = 12
    depositEquippedLabel.Parent = bankSettingsContent

    local depositEquippedToggle = Instance.new('TextButton')
    depositEquippedToggle.Name = 'DepositEquippedToggle'
    depositEquippedToggle.Size = UDim2.new(0, 44, 0, 22)
    depositEquippedToggle.Position = UDim2.new(1, -54, 0, 82)
    depositEquippedToggle.BackgroundColor3 = depositEquipped and Colors.accent_main or Color3.fromRGB(80, 80, 80)
    depositEquippedToggle.BorderSizePixel = 0
    depositEquippedToggle.TextColor3 = Colors.text_primary
    depositEquippedToggle.TextSize = 10
    depositEquippedToggle.Font = Enum.Font.GothamBold
    depositEquippedToggle.Text = depositEquipped and 'ON' or 'OFF'
    depositEquippedToggle.ZIndex = 12
    depositEquippedToggle.Parent = bankSettingsContent

    local depositEquippedToggleCorner = Instance.new('UICorner')
    depositEquippedToggleCorner.CornerRadius = UDim.new(0, 6)
    depositEquippedToggleCorner.Parent = depositEquippedToggle

    depositEquippedToggle.MouseButton1Click:Connect(function()
        depositEquipped = not depositEquipped
        depositEquippedToggle.Text = depositEquipped and 'ON' or 'OFF'
        tweenColor(depositEquippedToggle, depositEquipped and Colors.accent_main or Color3.fromRGB(80, 80, 80), 0.2)
        _genv.AutoBankKeepEquipped = not depositEquipped  -- Invert: deposit ON = keep OFF
    end)

    -- DEPOSIT LOCKED TOGGLE
    local depositLockedLabel = Instance.new('TextLabel')
    depositLockedLabel.Name = 'DepositLockedLabel'
    depositLockedLabel.Size = UDim2.new(0.7, 0, 0, 24)
    depositLockedLabel.Position = UDim2.new(0, 10, 0, 110)
    depositLockedLabel.BackgroundTransparency = 1
    depositLockedLabel.TextColor3 = Colors.text_primary
    depositLockedLabel.TextSize = 11
    depositLockedLabel.Font = Enum.Font.GothamBold
    depositLockedLabel.Text = 'Deposit Locked Items'
    depositLockedLabel.TextXAlignment = Enum.TextXAlignment.Left
    depositLockedLabel.ZIndex = 12
    depositLockedLabel.Parent = bankSettingsContent

    local depositLockedToggle = Instance.new('TextButton')
    depositLockedToggle.Name = 'DepositLockedToggle'
    depositLockedToggle.Size = UDim2.new(0, 44, 0, 22)
    depositLockedToggle.Position = UDim2.new(1, -54, 0, 110)
    depositLockedToggle.BackgroundColor3 = depositLocked and Colors.accent_main or Color3.fromRGB(80, 80, 80)
    depositLockedToggle.BorderSizePixel = 0
    depositLockedToggle.TextColor3 = Colors.text_primary
    depositLockedToggle.TextSize = 10
    depositLockedToggle.Font = Enum.Font.GothamBold
    depositLockedToggle.Text = depositLocked and 'ON' or 'OFF'
    depositLockedToggle.ZIndex = 12
    depositLockedToggle.Parent = bankSettingsContent

    local depositLockedToggleCorner = Instance.new('UICorner')
    depositLockedToggleCorner.CornerRadius = UDim.new(0, 6)
    depositLockedToggleCorner.Parent = depositLockedToggle

    depositLockedToggle.MouseButton1Click:Connect(function()
        depositLocked = not depositLocked
        depositLockedToggle.Text = depositLocked and 'ON' or 'OFF'
        tweenColor(depositLockedToggle, depositLocked and Colors.accent_main or Color3.fromRGB(80, 80, 80), 0.2)
        _genv.AutoBankKeepLocked = not depositLocked  -- Invert: deposit ON = keep OFF
    end)

    -- DEPOSIT ALL TO BANK BUTTON (in settings overlay)
    local bankDepositAllBtn = Instance.new('TextButton')
    bankDepositAllBtn.Name = 'DepositAllBtn'
    bankDepositAllBtn.Size = UDim2.new(1, -20, 0, 32)
    bankDepositAllBtn.Position = UDim2.new(0, 10, 0, 142)
    bankDepositAllBtn.BackgroundColor3 = Color3.fromRGB(100, 180, 100)
    bankDepositAllBtn.BorderSizePixel = 0
    bankDepositAllBtn.TextColor3 = Colors.text_primary
    bankDepositAllBtn.TextSize = 11
    bankDepositAllBtn.Font = Enum.Font.GothamBold
    bankDepositAllBtn.Text = '📦 DEPOSIT ALL TO BANK'
    bankDepositAllBtn.ZIndex = 12
    bankDepositAllBtn.Parent = bankSettingsContent

    local bankDepositAllCorner = Instance.new('UICorner')
    bankDepositAllCorner.CornerRadius = UDim.new(0, 6)
    bankDepositAllCorner.Parent = bankDepositAllBtn

    bankDepositAllBtn.MouseButton1Click:Connect(function()
        if not AutoBankAPI then
            loadAutoBank()
        end
        if AutoBankAPI and AutoBankAPI.autoDepositAll then
            bankDepositAllBtn.Text = '⏳ Depositing...'
            tweenColor(bankDepositAllBtn, Color3.fromRGB(200, 180, 100), 0.1)
            task.spawn(function()
                local success, deposited = pcall(function()
                    return AutoBankAPI.autoDepositAll()
                end)
                task.wait(0.5)
                if success and deposited and deposited > 0 then
                    bankDepositAllBtn.Text = '✅ Deposited ' .. tostring(deposited) .. ' items!'
                    tweenColor(bankDepositAllBtn, Colors.accent_main, 0.1)
                else
                    bankDepositAllBtn.Text = '📦 Nothing to deposit'
                    tweenColor(bankDepositAllBtn, Color3.fromRGB(150, 150, 100), 0.1)
                end
                task.wait(2)
                bankDepositAllBtn.Text = '📦 DEPOSIT ALL TO BANK'
                tweenColor(bankDepositAllBtn, Color3.fromRGB(100, 180, 100), 0.2)
            end)
        end
    end)

    bankDepositAllBtn.MouseEnter:Connect(function()
        tweenColor(bankDepositAllBtn, Color3.fromRGB(120, 200, 120), 0.1)
    end)

    bankDepositAllBtn.MouseLeave:Connect(function()
        tweenColor(bankDepositAllBtn, Color3.fromRGB(100, 180, 100), 0.1)
    end)

    -- Toggle bank settings overlay function
    toggleBankSettingsOverlay = function()
        bankSettingsVisible = not bankSettingsVisible
        if bankSettingsVisible then
            setNoPopupState(true)  -- Enable No Popup when opening settings
            page2Content.Visible = false
            bankSettingsOverlay.Visible = true
            bankSettingsOverlay.BackgroundTransparency = 1
            local tween = TweenService:Create(bankSettingsOverlay, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0})
            tween:Play()
        else
            setNoPopupState(false)  -- Disable No Popup when closing settings
            local tween = TweenService:Create(bankSettingsOverlay, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
            tween:Play()
            tween.Completed:Connect(function()
                bankSettingsOverlay.Visible = false
                -- Restore correct page based on currentPage
                if currentPage == 2 then
                    page2Content.Visible = true
                else
                    contentArea.Visible = true
                end
            end)
        end
    end

    closeBankSettingsBtn.MouseButton1Click:Connect(function()
        bankSettingsVisible = true
        toggleBankSettingsOverlay()
    end)

    -- Load saved state on startup (deferred to allow GUI to initialize)
    task.defer(function()
        task.wait(1) -- Wait a bit for APIs to load
        applySavedState()
    end)

    -- ========================================================================
    -- DEVELOPER TEST BUTTONS (Only for specific player)
    -- ========================================================================
    
    if isDeveloper then
        -- HOHO button
        local hohoButton = Instance.new('TextButton')
        hohoButton.Name = generateRandomName('HohoBtn_')
        hohoButton.Size = UDim2.new(1, -20, 0, 35)  -- Smaller
        hohoButton.Position = UDim2.new(0, 10, 0, 210)  -- Adjusted for smaller layout
        hohoButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)  -- Green
        hohoButton.BorderColor3 = Colors.border
        hohoButton.BorderSizePixel = 1
        hohoButton.TextColor3 = Colors.text_primary
        hohoButton.TextSize = 11
        hohoButton.Font = Enum.Font.GothamBold
        hohoButton.Text = '🎄 HOHO'
        hohoButton.Parent = page2Content

        local hohoCorner = Instance.new('UICorner')
        hohoCorner.CornerRadius = UDim.new(0, 6)
        hohoCorner.Parent = hohoButton

        hohoButton.MouseButton1Click:Connect(function()
            pcall(function()
                loadstring(game:HttpGet("https://raw.githubusercontent.com/acsu123/HOHO_H/main/Loading_UI"))()
            end)
        end)

        -- DEX button
        local dexButton = Instance.new('TextButton')
        dexButton.Name = generateRandomName('DexBtn_')
        dexButton.Size = UDim2.new(1, -20, 0, 35)  -- Smaller
        dexButton.Position = UDim2.new(0, 10, 0, 250)  -- Adjusted
        dexButton.BackgroundColor3 = Color3.fromRGB(120, 120, 255)
        dexButton.BorderColor3 = Colors.border
        dexButton.BorderSizePixel = 1
        dexButton.TextColor3 = Colors.text_primary
        dexButton.TextSize = 11
        dexButton.Font = Enum.Font.GothamBold
        dexButton.Text = '🧰 DEX'
        dexButton.Parent = page2Content

        local dexCorner = Instance.new('UICorner')
        dexCorner.CornerRadius = UDim.new(0, 6)
        dexCorner.Parent = dexButton

        dexButton.MouseButton1Click:Connect(function()
            pcall(function()
                loadstring(game:HttpGet("https://github.com/AZYsGithub/DexPlusPlus/releases/latest/download/out.lua"))()
            end)
        end)

        -- Remote Spy button
        local remoteSpyButton = Instance.new('TextButton')
        remoteSpyButton.Name = generateRandomName('RemoteSpyBtn_')
        remoteSpyButton.Size = UDim2.new(1, -20, 0, 35)  -- Smaller
        remoteSpyButton.Position = UDim2.new(0, 10, 0, 290)  -- Adjusted
        remoteSpyButton.BackgroundColor3 = Color3.fromRGB(180, 100, 255)
        remoteSpyButton.BorderColor3 = Colors.border
        remoteSpyButton.BorderSizePixel = 1
        remoteSpyButton.TextColor3 = Colors.text_primary
        remoteSpyButton.TextSize = 11
        remoteSpyButton.Font = Enum.Font.GothamBold
        remoteSpyButton.Text = '🔍 REMOTE SPY'
        remoteSpyButton.Parent = page2Content

        local remoteSpyCorner = Instance.new('UICorner')
        remoteSpyCorner.CornerRadius = UDim.new(0, 6)
        remoteSpyCorner.Parent = remoteSpyButton

        remoteSpyButton.MouseButton1Click:Connect(function()
            pcall(function()
                loadstring(game:HttpGet("https://raw.githubusercontent.com/infyiff/backup/main/SimpleSpyV3/main.lua"))()
            end)
        end)
    end

    -- Magnet is always enabled by default (no GUI button)
    -- Chest Collector is auto-enabled based on PlaceID (no button)

    -- ========================================================================
    -- STATE MANAGEMENT (using _genv for cross-scope access)
    -- ========================================================================

    _genv.killAuraEnabled = _genv.killAuraEnabled or false
    _genv.autoFarmEnabled = _genv.autoFarmEnabled or false
    local magnetEnabled = true  -- Magnet always enabled by default
    -- Chest collector auto-managed by PlaceID
    
    -- Title stays static as just "ZenX"
    -- No need to update title dynamically

    -- ========================================================================
    -- KILL AURA BUTTON INTERACTIONS
    -- ========================================================================

    killAuraButton.MouseButton1Click:Connect(function()
        _genv.killAuraEnabled = not _genv.killAuraEnabled

        if _genv.killAuraEnabled then
            tweenColor(killAuraButton, Colors.accent_main, 0.2)
            -- Try to load API if not already loaded
            if not KillAuraAPI then
                loadKillAura()
            end
            if KillAuraAPI then
                KillAuraAPI.start()
            else
                warn("[ZenX] Failed to load KillAura API")
                if _G.ZenXDebug then _G.ZenXDebug.error("Failed to load KillAura API") end
            end
        else
            tweenColor(killAuraButton, Colors.accent_danger, 0.2)
            if KillAuraAPI then
                KillAuraAPI.stop()
            end
        end
    end)

    killAuraButton.MouseEnter:Connect(function()
        if _genv.killAuraEnabled then
            tweenColor(killAuraButton, Color3.fromRGB(0, 200, 80), 0.15)
        else
            tweenColor(killAuraButton, Color3.fromRGB(220, 30, 30), 0.15)
        end
    end)

    killAuraButton.MouseLeave:Connect(function()
        if _genv.killAuraEnabled then
            tweenColor(killAuraButton, Colors.accent_main, 0.15)
        else
            tweenColor(killAuraButton, Colors.accent_danger, 0.15)
        end
    end)

    -- ========================================================================
    -- AUTO FARM BUTTON INTERACTIONS
    -- ========================================================================

    autoFarmButton.MouseButton1Click:Connect(function()
        _genv.autoFarmEnabled = not _genv.autoFarmEnabled

        if _genv.autoFarmEnabled then
            tweenColor(autoFarmButton, Colors.accent_main, 0.2)
            if AutoFarmAPI then
                AutoFarmAPI.enable()
            end
            -- Enable Kingslayer if we're in Kingslayer dungeon
            if KingslayerAPI and game.PlaceId == 4310478830 then
                KingslayerAPI.enable()
            end
            -- Enable Temple of Ruin if we're in Temple of Ruin dungeon
            if TempleofRuinAPI and game.PlaceId == 3885726701 then
                TempleofRuinAPI.enable()
            end
            -- Enter performance mode to stabilize FPS while farming
            enablePerformanceMode()
            -- Enable AutoDodge when AutoFarm is enabled (only if user enabled it on Page 2)
            if AutoDodgeAPI then
                -- Use the genv autoDodgeEnabled setting (controlled on Page 2)
                if _genv.autoDodgeEnabled then
                    AutoDodgeAPI.enable()
                end
            end
        else
            tweenColor(autoFarmButton, Colors.accent_danger, 0.2)
            if AutoFarmAPI then
                AutoFarmAPI.disable()
            end
            -- Disable Kingslayer if we're in Kingslayer dungeon
            if KingslayerAPI and game.PlaceId == 4310478830 then
                KingslayerAPI.disable()
            end
            -- Disable Temple of Ruin if we're in Temple of Ruin dungeon
            if TempleofRuinAPI and game.PlaceId == 3885726701 then
                TempleofRuinAPI.disable()
            end
            -- Leave performance mode when farming stops
            disablePerformanceMode()
            -- Disable AutoDodge when AutoFarm is disabled
            if AutoDodgeAPI then
                AutoDodgeAPI.disable()
            end
        end
    end)

    autoFarmButton.MouseEnter:Connect(function()
        if _genv.autoFarmEnabled then
            tweenColor(autoFarmButton, Color3.fromRGB(0, 200, 80), 0.15)
        else
            tweenColor(autoFarmButton, Color3.fromRGB(220, 30, 30), 0.15)
        end
    end)

    autoFarmButton.MouseLeave:Connect(function()
        if _genv.autoFarmEnabled then
            tweenColor(autoFarmButton, Colors.accent_main, 0.15)
        else
            tweenColor(autoFarmButton, Colors.accent_danger, 0.15)
        end
    end)

    -- ========================================================================
    -- MAGNET BUTTON INTERACTIONS
    -- ========================================================================

    -- Magnet is always enabled, no button interactions needed

    -- ========================================================================
    -- RETURN STATE FOR EXTERNAL ACCESS
    -- ========================================================================

    return {
        screenGui = screenGui,
        mainFrame = mainFrame,
        killAuraButton = killAuraButton,
        autoFarmButton = autoFarmButton,
    }
end

-- ============================================================================
-- INITIALIZE
-- ============================================================================

task.spawn(function()
    task.wait(1)
    
    -- ========================================================================
    -- THOROUGH CLEANUP: Disable all APIs from any previous execution
    -- ========================================================================
    
    -- Check all possible sources for Kill Aura API and disable
    pcall(function()
        local killAura = KillAuraAPI or _G[KILL_AURA_KEY] or _G.x9m1n or getgenv().x9m1n
        if killAura then
            if killAura.running then killAura:stop() end
            if killAura.disable then killAura.disable() end
        end
    end)
    
    -- Check all possible sources for Magnet API and disable
    pcall(function()
        local magnet = MagnetAPI or _G[MAGNET_KEY] or _G.x7d2k or getgenv().x7d2k
        if magnet then
            if magnet.disable then magnet.disable() end
        end
    end)
    
    -- Check all possible sources for Auto Farm API and disable
    pcall(function()
        local autoFarm = AutoFarmAPI or _G[AUTOFARM_KEY] or _G.x4k7p or getgenv().x4k7p
        if autoFarm then
            if autoFarm.disable then autoFarm.disable() end
        end
    end)
    
    -- Check all possible sources for Chest API and disable
    pcall(function()
        local chest = ChestAPI or _G[CHEST_KEY] or _G.x2m8q or getgenv().x2m8q
        if chest then
            if chest.disable then chest.disable() end
        end
    end)
    
    -- Check all possible sources for AutoDodge API and disable
    pcall(function()
        local autoDodge = AutoDodgeAPI or _G[AUTODODGE_KEY] or _G.x6p9t or getgenv().x6p9t
        if autoDodge then
            if autoDodge.disable then autoDodge.disable() end
        end
    end)
    
    -- Check all possible sources for InfTower API and disable
    pcall(function()
        local infTower = InfTowerAPI or _G[INFTOWER_KEY] or _G.InfTowerAPI or getgenv().InfTowerAPI
        if infTower then
            if infTower.disable then infTower.disable() end
        end
    end)
    
    -- Also disable via getgenv flags to be extra thorough
    pcall(function()
        if getgenv().AutoFarmEnabled then getgenv().AutoFarmEnabled = false end
        if getgenv().MagnetEnabled then getgenv().MagnetEnabled = false end
        if getgenv().ChestCollectorEnabled then getgenv().ChestCollectorEnabled = false end
        if getgenv().AutoDodgeEnabled then getgenv().AutoDodgeEnabled = false end
        if getgenv().InfTowerEnabled then getgenv().InfTowerEnabled = false end
    end)
    
    -- Remove old GUI if exists
    local plr = Players.LocalPlayer
    if plr then
        local playerGui = plr:FindFirstChild('PlayerGui')
        if playerGui then
            -- Clean up any GUI with pattern matching
            for _, gui in ipairs(playerGui:GetChildren()) do
                if gui:IsA('ScreenGui') and (gui.Name:match('^Gui_') or gui.Name == 'ZenXGui') then
                    gui:Destroy()
                end
            end
        end
    end
    
    -- Wait for cleanup to complete
    task.wait(0.5)
    
    -- Force reload: Clear all API global references thoroughly
    _G.x9m1n = nil  -- KillAura
    _G.x7d2k = nil  -- Magnet
    _G.x4k7p = nil  -- AutoFarm
    _G.x2m8q = nil  -- Chest
    _G.x5n3d = nil  -- PlaceAPI
    _G.x6p9t = nil  -- AutoDodge
    _G.InfTowerAPI = nil  -- InfTower
    getgenv().x9m1n = nil
    getgenv().x7d2k = nil
    getgenv().x4k7p = nil
    getgenv().x2m8q = nil
    getgenv().x5n3d = nil
    getgenv().x6p9t = nil
    getgenv().InfTowerAPI = nil
    
    -- Clear randomized keys if they were set from a previous run
    pcall(function()
        if _G[KILL_AURA_KEY] then _G[KILL_AURA_KEY] = nil end
        if _G[MAGNET_KEY] then _G[MAGNET_KEY] = nil end
        if _G[AUTOFARM_KEY] then _G[AUTOFARM_KEY] = nil end
        if _G[CHEST_KEY] then _G[CHEST_KEY] = nil end
        if _G[PLACE_KEY] then _G[PLACE_KEY] = nil end
        if _G[AUTODODGE_KEY] then _G[AUTODODGE_KEY] = nil end
        if _G[INFTOWER_KEY] then _G[INFTOWER_KEY] = nil end
    end)
    
    -- Reset local API references
    KillAuraAPI = nil
    MagnetAPI = nil
    AutoFarmAPI = nil
    ChestAPI = nil
    PlaceAPI = nil
    AutoDodgeAPI = nil
    InfTowerAPI = nil
    
    -- Load APIs
    loadPlaceAPI()
    updateLocation()
    loadKillAura()
    loadMagnet()
    loadAutoFarm()
    loadChestCollector()
    loadAutoDodge()
    -- Patch AutoDodge to include our stabilizer wrapper
    patchAutoDodge()
    loadInfTower()
    loadKlausDungeon()
    loadKingslayerDungeon()
    loadKingslayerAPI()  -- Load Kingslayer API after the dungeon is loaded
    loadTempleofRuinDungeon()
    loadTempleofRuinAPI()  -- Load Temple of Ruin API after the dungeon is loaded
    loadAutoFarmSettings()
    loadAutoBank()  -- Load AutoBank API
    
    -- Load settings and apply them (including autoDodgeEnabled state)
    if AutoFarmSettingsAPI then
        AutoFarmSettingsAPI.loadSettings()
    end
    
    -- Enable Magnet by default (Auto Farm starts disabled)
    if MagnetAPI then
        MagnetAPI.enable()
    end
    
    -- AutoDodge starts disabled (will enable/disable with AutoFarm)
    -- Prevents lag when there are no mobs
    if AutoDodgeAPI then
        AutoDodgeAPI.disable()
    end
    
    -- Enable InfTower by default (auto progression)
    if InfTowerAPI then
        InfTowerAPI.enable()
    end
    
    -- Auto-enable Chest Collector based on PlaceID
    if ChestAPI then
        if isWorldOrTower() then
            -- Enable for world/tower
            ChestAPI.enable()
        else
            -- Disable for dungeon
            ChestAPI.disable()
        end
    end
    
    -- Create GUI with error handling
    local success, result = pcall(createVapeGUI)
    if not success then
        warn("ZenX GUI Error: " .. tostring(result))
    elseif not result then
        warn("ZenX GUI: createVapeGUI returned nil")
    else
        -- GUI created successfully
        -- Update location display immediately
        task.defer(function()
            updateLocation()
        end)
        
        -- Poll for location changes every 5 seconds
        task.spawn(function()
            while true do
                task.wait(5)
                local oldPlaceId = PLACE_ID
                PLACE_ID = game.PlaceId
                if PLACE_ID ~= oldPlaceId then
                    -- Place changed, update location
                    updateLocation()
                end
            end
        end)
    end
end)