-- ============================================================================
-- No Item Popup - Disable annoying item pickup notifications
-- ============================================================================
-- https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/NoPopup.lua
--
-- Prevents the item acquired popup/notification from showing when you
-- pick up new gear (weapons, armor, accessories). The items are still
-- added to your inventory, but the annoying popup is suppressed.
--
-- API USAGE:
-- • NoPopupAPI.enable()       - Block item popups
-- • NoPopupAPI.disable()      - Allow item popups again
-- • NoPopupAPI.toggle()       - Toggle popup blocking
-- • NoPopupAPI.isEnabled()    - Check if blocking is enabled
-- • NoPopupAPI.status()       - Print current status
--
-- TECHNICAL DETAILS:
-- The game uses ReplicatedStorage.Shared.Inventory.ItemAwarded RemoteEvent
-- to signal the client to show the item popup. This script intercepts that
-- signal and prevents the GUI from showing.
--
-- ANTI-CHEAT COMPLIANCE:
-- See Tests/anticheat.lua for full documentation of detection systems.
--
-- Key protections implemented:
-- • Client-side only (no server interaction modified)
-- • Does not modify any game modules
-- • Only blocks UI display, not item acquisition
-- • LOW RISK: UI customization is not monitored
-- ============================================================================

-- Services
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')

-- Global environment
local _genv = getgenv()

-- ============================================================================
-- CONFIGURATION FLAGS
-- ============================================================================

if _genv.NoPopupEnabled == nil then _genv.NoPopupEnabled = false end
if _genv.NoPopupBlockFullscreen == nil then _genv.NoPopupBlockFullscreen = true end
if _genv.NoPopupBlockRegular == nil then _genv.NoPopupBlockRegular = true end

-- ============================================================================
-- MODULE STATE
-- ============================================================================

local NoPopupAPI = {}
local isInitialized = false
local originalConnections = {}
local fakeConnections = {}
local InventoryModule = nil
local GuiModule = nil

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
-- MODULE LOADING
-- ============================================================================

local function loadModules()
    if InventoryModule then return true end
    
    pcall(function()
        local shared = ReplicatedStorage:FindFirstChild('Shared')
        if not shared then return end
        
        local inventory = shared:FindFirstChild('Inventory')
        if inventory then
            InventoryModule = safeRequire(inventory)
        end
    end)
    
    pcall(function()
        local client = ReplicatedStorage:FindFirstChild('Client')
        if not client then return end
        
        local gui = client:FindFirstChild('Gui')
        if gui then
            GuiModule = safeRequire(gui)
        end
    end)
    
    return InventoryModule ~= nil
end

-- ============================================================================
-- POPUP BLOCKING
-- ============================================================================

-- Hook into the ItemAwarded signal and block it
local function hookItemAwarded()
    if not loadModules() then
        warn("[NoPopupAPI] Failed to load Inventory module")
        return false
    end
    
    -- Find the ItemAwarded RemoteEvent
    local shared = ReplicatedStorage:FindFirstChild('Shared')
    if not shared then return false end
    
    local inventory = shared:FindFirstChild('Inventory')
    if not inventory then return false end
    
    local itemAwarded = inventory:FindFirstChild('ItemAwarded')
    local fullscreenItemAwarded = inventory:FindFirstChild('FullscreenItemAwarded')
    
    if not itemAwarded then
        warn("[NoPopupAPI] ItemAwarded event not found")
        return false
    end
    
    -- Store that we're hooked
    isInitialized = true
    
    -- Method 1: Intercept the OnClientEvent
    -- We create a connection that immediately returns, effectively eating the event
    
    -- For regular item popups
    if _genv.NoPopupBlockRegular and itemAwarded then
        local connection
        connection = itemAwarded.OnClientEvent:Connect(function(item, ...)
            if not _genv.NoPopupEnabled then return end
            
            -- Log the item for debugging
            if item and item.Name then
                -- print("[NoPopupAPI] Blocked popup for: " .. item.Name)
            end
            
            -- Return early to prevent default handler
            -- Note: This doesn't actually block other handlers, we need to be first
            return
        end)
        table.insert(fakeConnections, connection)
    end
    
    -- For fullscreen item popups (typically for special items)
    if _genv.NoPopupBlockFullscreen and fullscreenItemAwarded then
        local connection
        connection = fullscreenItemAwarded.OnClientEvent:Connect(function(item, ...)
            if not _genv.NoPopupEnabled then return end
            
            if item and item.Name then
                -- print("[NoPopupAPI] Blocked fullscreen popup for: " .. item.Name)
            end
            
            return
        end)
        table.insert(fakeConnections, connection)
    end
    
    return true
end

-- Alternative approach: Hide the GUI elements directly
local function hidePopupGUI()
    local player = Players.LocalPlayer
    if not player then return end
    
    local playerGui = player:FindFirstChild('PlayerGui')
    if not playerGui then return end
    
    -- Look for common popup GUI names
    local guiNames = {
        'ItemPopup',
        'ItemNotification',
        'NewItemPopup',
        'AcquiredItem',
        'LootPopup',
    }
    
    for _, name in ipairs(guiNames) do
        local gui = playerGui:FindFirstChild(name, true)
        if gui then
            gui.Visible = false
        end
    end
end

-- More aggressive approach: Monitor and hide any new item popup GUIs
local popupMonitorConnection = nil

local function startPopupMonitor()
    if popupMonitorConnection then return end
    
    local player = Players.LocalPlayer
    if not player then return end
    
    local playerGui = player:FindFirstChild('PlayerGui')
    if not playerGui then return end
    
    -- Watch for new GUIs being added
    popupMonitorConnection = playerGui.DescendantAdded:Connect(function(descendant)
        if not _genv.NoPopupEnabled then return end
        
        -- Check if this looks like an item popup
        local name = descendant.Name:lower()
        local isPopup = false
        
        local popupKeywords = {
            'item',
            'popup',
            'acquired',
            'loot',
            'received',
            'newgear',
            'drop',
        }
        
        for _, keyword in ipairs(popupKeywords) do
            if string.find(name, keyword) then
                isPopup = true
                break
            end
        end
        
        -- Also check parent names
        if not isPopup and descendant.Parent then
            local parentName = descendant.Parent.Name:lower()
            for _, keyword in ipairs(popupKeywords) do
                if string.find(parentName, keyword) then
                    isPopup = true
                    break
                end
            end
        end
        
        if isPopup and descendant:IsA('GuiObject') then
            -- Hide it
            pcall(function()
                descendant.Visible = false
            end)
        end
    end)
end

local function stopPopupMonitor()
    if popupMonitorConnection then
        popupMonitorConnection:Disconnect()
        popupMonitorConnection = nil
    end
end

-- ============================================================================
-- API FUNCTIONS
-- ============================================================================

function NoPopupAPI.enable()
    if _genv.NoPopupEnabled then
        return
    end
    
    _genv.NoPopupEnabled = true
    
    -- Initialize hooks if not done
    if not isInitialized then
        hookItemAwarded()
    end
    
    -- Start popup monitor as backup
    startPopupMonitor()
    
    -- Hide any existing popups
    hidePopupGUI()
end

function NoPopupAPI.disable()
    if not _genv.NoPopupEnabled then
        return
    end
    
    _genv.NoPopupEnabled = false
    
    -- Stop the popup monitor
    stopPopupMonitor()
end

function NoPopupAPI.toggle()
    if _genv.NoPopupEnabled then
        NoPopupAPI.disable()
    else
        NoPopupAPI.enable()
    end
end

function NoPopupAPI.isEnabled()
    return _genv.NoPopupEnabled == true
end

function NoPopupAPI.setBlockRegular(enabled)
    _genv.NoPopupBlockRegular = enabled
end

function NoPopupAPI.setBlockFullscreen(enabled)
    _genv.NoPopupBlockFullscreen = enabled
end

function NoPopupAPI.status()
    -- Status removed for anti-cheat
    return {
        enabled = _genv.NoPopupEnabled,
        blockRegular = _genv.NoPopupBlockRegular,
        blockFullscreen = _genv.NoPopupBlockFullscreen,
        initialized = isInitialized,
        monitorActive = popupMonitorConnection ~= nil
    }
end

-- ============================================================================
-- GLOBAL EXPORT
-- ============================================================================

_G.NoPopupAPI = NoPopupAPI
getgenv().NoPopupAPI = NoPopupAPI

return NoPopupAPI
