-- World Events API
-- https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/WorldEvents.lua
-- Wrapper for game's World Events functionality
-- 
-- Features:
--   - Track active world events
--   - Teleport to events
--   - Event start/finish signals
--   - Guild points tracking
--   - Event timers and status
--
-- ANTI-CHEAT COMPLIANCE:
-- See Tests/anticheat.lua for full documentation of detection systems.
--
-- Key protections implemented:
-- • Uses game's official WorldEvents and Teleport modules
-- • Teleportation goes through game's Teleport module (server-validated)
-- • Event joining uses proper game remotes
-- • LOW RISK: Event participation is legitimate game feature
-- • TeleportAntiCheat: Game's Teleport module handles position validation

local WorldEventsAPI = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Local Player
local LocalPlayer = Players.LocalPlayer

-- Modules (loaded on init)
local WorldEventsModule = nil
local TeleportModule = nil
local ProfileModule = nil

-- State
local initialized = false
local eventData = {}
local activeEvents = {}

-- Callbacks
local onEventStartCallbacks = {}
local onEventFinishCallbacks = {}
local onIntermissionCallbacks = {}

-- Event connections
local eventStartedConnection = nil
local eventFinishedConnection = nil
local intermissionConnection = nil

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Load required modules
local function loadModules()
    if initialized then return true end
    
    local success = pcall(function()
        WorldEventsModule = require(ReplicatedStorage.Shared.WorldEvents)
        TeleportModule = require(ReplicatedStorage.Shared.Teleport)
        ProfileModule = require(ReplicatedStorage.Shared.Profile)
    end)
    
    if success and WorldEventsModule then
        initialized = true
    else
        warn("[WorldEventsAPI] Failed to load modules")
    end
    
    return initialized
end

-- Setup event listeners
local function setupEventListeners()
    if not loadModules() then return end
    
    -- Event started signal
    pcall(function()
        local signal = WorldEventsModule:GetEventStartedSignal()
        if signal then
            eventStartedConnection = signal:Connect(function(eventName, eventModel)
                activeEvents[eventName] = {
                    name = eventName,
                    model = eventModel,
                    startTime = os.time(),
                    status = "active"
                }
                
                for _, callback in pairs(onEventStartCallbacks) do
                    pcall(callback, eventName, eventModel)
                end
            end)
        end
    end)
    
    -- Event finished signal
    pcall(function()
        local signal = WorldEventsModule:GetEventFinishedSignal()
        if signal then
            eventFinishedConnection = signal:Connect(function(eventName)
                activeEvents[eventName] = nil
                
                for _, callback in pairs(onEventFinishCallbacks) do
                    pcall(callback, eventName)
                end
            end)
        end
    end)
    
    -- Intermission signal
    pcall(function()
        local signal = WorldEventsModule:GetIntermissionSignal()
        if signal then
            intermissionConnection = signal:Connect(function(eventName, eventModel, isNotification)
                if not activeEvents[eventName] then
                    activeEvents[eventName] = {
                        name = eventName,
                        model = eventModel,
                        intermissionStart = os.time(),
                        status = "intermission"
                    }
                end
                
                for _, callback in pairs(onIntermissionCallbacks) do
                    pcall(callback, eventName, eventModel, isNotification)
                end
            end)
        end
    end)
end

-- Initialize the API
function WorldEventsAPI:Init()
    if not loadModules() then return false end
    setupEventListeners()
    return initialized
end

-- ============================================================================
-- EVENT INFO
-- ============================================================================

-- Get all event names
function WorldEventsAPI:GetEventNames()
    if not loadModules() then return {} end
    
    local success, names = pcall(function()
        return WorldEventsModule:GetEventNames()
    end)
    
    return success and names or {}
end

-- Get event data by name
function WorldEventsAPI:GetEventData(eventName)
    if not loadModules() then return nil end
    return WorldEventsModule:GetEventData(eventName)
end

-- Get all events with data
function WorldEventsAPI:GetAllEvents()
    local events = {}
    local names = self:GetEventNames()
    
    for _, name in ipairs(names) do
        local data = self:GetEventData(name)
        if data then
            events[name] = {
                Name = name,
                Level = data.Level or 0,
                Radius = data.Radius or 0,
                TimeLimit = data.TimeLimit or 0,
                XP = data.XP or 0,
                TeleportRequiresVisit = data.TeleportRequiresVisit or false
            }
        end
    end
    
    return events
end

-- Check if any event is active
function WorldEventsAPI:IsAnyEventActive()
    if not loadModules() then return false end
    return WorldEventsModule:EventActive()
end

-- Get active events folder
function WorldEventsAPI:GetActiveEventsFolder()
    if not loadModules() then return nil end
    return WorldEventsModule.ActiveEvents
end

-- Get active event by name
function WorldEventsAPI:GetActiveEvent(eventName)
    if not loadModules() then return nil end
    return WorldEventsModule:GetActiveFolder(eventName)
end

-- Get list of currently active events
function WorldEventsAPI:GetActiveEvents()
    local events = {}
    
    pcall(function()
        local activeFolder = self:GetActiveEventsFolder()
        if activeFolder then
            for _, event in pairs(activeFolder:GetChildren()) do
                if event:IsA("Folder") then
                    local eventInfo = {
                        Name = event.Name,
                        Started = event:FindFirstChild("Started") and event.Started.Value or false,
                        Level = event:FindFirstChild("Level") and event.Level.Value or 0,
                        Position = event:FindFirstChild("EventPosition") and event.EventPosition.Value or nil,
                        IntermissionTimer = event:FindFirstChild("IntermissionTimer") and event.IntermissionTimer.Value or 0
                    }
                    
                    -- Calculate time remaining
                    if not eventInfo.Started and eventInfo.IntermissionTimer > 0 then
                        local intermissionTime = WorldEventsModule.INTERMISSION_TIME or 300
                        local elapsed = os.time() - eventInfo.IntermissionTimer
                        eventInfo.TimeUntilStart = math.max(0, intermissionTime - elapsed)
                        eventInfo.Status = "intermission"
                    else
                        eventInfo.Status = eventInfo.Started and "active" or "unknown"
                    end
                    
                    table.insert(events, eventInfo)
                end
            end
        end
    end)
    
    return events
end

-- ============================================================================
-- TELEPORT
-- ============================================================================

-- Check if can teleport to event
function WorldEventsAPI:CanTeleportToEvent(eventName, player)
    if not loadModules() then return false end
    player = player or LocalPlayer
    return WorldEventsModule:CanTeleportToEvent(player, eventName)
end

-- Teleport to event
function WorldEventsAPI:TeleportToEvent(eventName)
    if not loadModules() then return false end
    
    if not self:CanTeleportToEvent(eventName) then
        warn("[WorldEventsAPI] Cannot teleport to event:", eventName)
        return false
    end
    
    pcall(function()
        WorldEventsModule:TeleportToEvent(LocalPlayer, eventName)
    end)
    
    return true
end

-- Get events you can teleport to
function WorldEventsAPI:GetTeleportableEvents()
    local events = {}
    local activeEvents = self:GetActiveEvents()
    
    for _, event in ipairs(activeEvents) do
        if self:CanTeleportToEvent(event.Name) then
            table.insert(events, event)
        end
    end
    
    return events
end

-- ============================================================================
-- GUILD POINTS
-- ============================================================================

-- Check if can award guild points for event
function WorldEventsAPI:CanAwardGuildPoints(eventName, player)
    if not loadModules() then return false end
    player = player or LocalPlayer
    
    local success, result = pcall(function()
        return WorldEventsModule:CanAwardGuildPoints(player, eventName)
    end)
    
    return success and result or false
end

-- Get guild points progress for current world
function WorldEventsAPI:GetGuildPointsProgress(player)
    if not loadModules() then return 0, 0 end
    player = player or LocalPlayer
    
    local success, completed, total = pcall(function()
        return WorldEventsModule:GetGuildPointsForWorld(player)
    end)
    
    if success then
        return completed, total
    end
    return 0, 0
end

-- Get world event ID for tracking
function WorldEventsAPI:GetWorldEventID(eventName)
    if not loadModules() then return nil end
    
    local success, id = pcall(function()
        return WorldEventsModule:GetWorldEventID(eventName)
    end)
    
    return success and id or nil
end

-- ============================================================================
-- TIMERS
-- ============================================================================

-- Get intermission time constant
function WorldEventsAPI:GetIntermissionTime()
    if not loadModules() then return 300 end
    return WorldEventsModule.INTERMISSION_TIME or 300
end

-- Get notification time constant
function WorldEventsAPI:GetNotificationTime()
    if not loadModules() then return 60 end
    return WorldEventsModule.NOTIFICATION_TIME or 60
end

-- Calculate time until event starts
function WorldEventsAPI:GetTimeUntilStart(eventName)
    local activeEvents = self:GetActiveEvents()
    
    for _, event in ipairs(activeEvents) do
        if event.Name == eventName then
            return event.TimeUntilStart or 0
        end
    end
    
    return 0
end

-- ============================================================================
-- CALLBACKS
-- ============================================================================

-- Register callback for event start
function WorldEventsAPI:OnEventStart(callback)
    table.insert(onEventStartCallbacks, callback)
end

-- Register callback for event finish
function WorldEventsAPI:OnEventFinish(callback)
    table.insert(onEventFinishCallbacks, callback)
end

-- Register callback for intermission
function WorldEventsAPI:OnIntermission(callback)
    table.insert(onIntermissionCallbacks, callback)
end

-- ============================================================================
-- SIGNALS (raw)
-- ============================================================================

-- Get event started signal
function WorldEventsAPI:GetEventStartedSignal()
    if not loadModules() then return nil end
    return WorldEventsModule:GetEventStartedSignal()
end

-- Get event finished signal
function WorldEventsAPI:GetEventFinishedSignal()
    if not loadModules() then return nil end
    return WorldEventsModule:GetEventFinishedSignal()
end

-- Get intermission signal
function WorldEventsAPI:GetIntermissionSignal()
    if not loadModules() then return nil end
    return WorldEventsModule:GetIntermissionSignal()
end

-- ============================================================================
-- STATUS
-- ============================================================================

-- Get full status
function WorldEventsAPI:GetStatus()
    local activeEvents = self:GetActiveEvents()
    local completed, total = self:GetGuildPointsProgress()
    
    return {
        Initialized = initialized,
        AnyEventActive = self:IsAnyEventActive(),
        ActiveEventCount = #activeEvents,
        ActiveEvents = activeEvents,
        GuildPointsCompleted = completed,
        GuildPointsTotal = total,
        IntermissionTime = self:GetIntermissionTime(),
        NotificationTime = self:GetNotificationTime()
    }
end

-- Print status for debugging (disabled - anti-cheat detection)
function WorldEventsAPI:PrintStatus()
    -- Prints removed for anti-cheat
end

-- Print all events for debugging (disabled - anti-cheat detection)
function WorldEventsAPI:PrintAllEvents()
    -- Prints removed for anti-cheat
end

-- ============================================================================
-- CLEANUP
-- ============================================================================

-- Cleanup connections
function WorldEventsAPI:Cleanup()
    if eventStartedConnection then
        eventStartedConnection:Disconnect()
        eventStartedConnection = nil
    end
    
    if eventFinishedConnection then
        eventFinishedConnection:Disconnect()
        eventFinishedConnection = nil
    end
    
    if intermissionConnection then
        intermissionConnection:Disconnect()
        intermissionConnection = nil
    end
    
    onEventStartCallbacks = {}
    onEventFinishCallbacks = {}
    onIntermissionCallbacks = {}
end

-- ============================================================================
-- EXPOSE TO GLOBAL
-- ============================================================================

_G.WorldEventsAPI = WorldEventsAPI
getgenv().WorldEventsAPI = WorldEventsAPI

return WorldEventsAPI
