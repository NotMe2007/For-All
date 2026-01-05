-- ============================================================================
-- Auto Farm - Complete Farming Automation System
-- ============================================================================
-- Combines: NoClip/Flying, Mob Detection, Auto-Attack, and Utility Features
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/Autofarm.lua"))()
--
-- API USAGE:
-- • _G.x4k7p.enable()           - Enable auto farm
-- • _G.x4k7p.disable()          - Disable auto farm
-- • _G.x4k7p.toggle()           - Toggle auto farm
-- • _G.x4k7p.setClass(name)     - Set current class
-- • _G.x4k7p.status()           - Print current status
-- • _G.x4k7p.getStats()         - Get session statistics
-- • _G.x4k7p.setSpeed(speed)    - Adjust movement speed
-- • _G.x4k7p.setHeight(height)  - Adjust hover height
-- • _G.x4k7p.detectTower()      - Check current dungeon
-- • _G.x4k7p.setWorldEvents(on) - Enable/disable world events
-- • _G.x4k7p.isWorldEventActive() - Check if in world event
-- • _G.autoFarm (alias)         - Same as _G.x4k7p
--
-- FEATURES:
-- • Intelligent mob targeting and prioritization
-- • Smooth flying movement with cluster avoidance
-- • Dungeon-specific automation (Prison, Atlantis, Crabby, etc.)
-- • World Events integration (auto-teleport and kill boss)
-- • Auto-dodge integration for safety
-- • Human-like movement patterns with variance
-- • Session statistics tracking
--
-- PERFORMANCE:
-- • Optimized mob scanning with distance checks
-- • Efficient movement calculations with throttling
-- • Configurable update intervals
-- • Physics update batching
--
-- SECURITY:
-- • Protected API calls with pcall wrapping
-- • Safe service access
-- • Player-owned mob filtering
-- • Anti-detection movement variance
-- • Variable speed patterns
--
-- ANTI-CHEAT COMPLIANCE:
-- See Tests/anticheat.lua for full documentation of detection systems.
--
-- Key protections implemented:
-- • Humanoid state management (updateMovementAnimation) prevents falling animation
--   detection - uses HumanoidStateType.Jumping for upward movement and Running
--   for horizontal movement to mask flying behavior
-- • Movement variance (18%) and speed variance (12%) prevent pattern detection
-- • Wobble effects simulate human imprecision in movement
-- • Micro-pauses add random delays to appear more natural
-- • TeleportAntiCheat bypass: Uses smooth flying movement instead of teleports
-- • Safe remote usage through game modules, not raw remotes
-- ============================================================================

-- Service caching for performance
local Players = game:GetService('Players')
local Workspace = game:GetService('Workspace')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local VirtualUser = game:GetService('VirtualUser')

-- ============================================================================
-- ANTI-DETECTION CONFIGURATION
-- ============================================================================
-- These settings help make movement patterns appear more human-like
local AntiDetection = {
    -- Movement variance (0-1, 0.18 = 18% random deviation)
    movementVariance = 0.18,
    
    -- Speed variance (randomize speed by this percentage)
    speedVariance = 0.12,
    
    -- Occasional micro-pauses during movement
    pauseChance = 0.015,           -- 1.5% chance per tick to pause
    pauseDurationMin = 0.08,       -- Minimum pause duration
    pauseDurationMax = 0.25,       -- Maximum pause duration
    
    -- Direction wobble (slight random direction changes)
    wobbleChance = 0.08,           -- 8% chance per tick
    wobbleAngle = 0.15,            -- Max wobble angle in radians (~8.5 degrees)
    
    -- Speed ramping (gradual speed changes instead of instant)
    useSpeedRamp = true,
    speedRampFactor = 0.85,        -- How fast to ramp (0-1, higher = faster)
    
    -- Altitude jitter (small random vertical adjustments)
    altitudeJitter = 0.4,          -- Studs of random altitude variation
}

-- ============================================================================
-- SESSION STATISTICS
-- ============================================================================
local SessionStats = {
    startTime = os.clock(),
    mobsTargeted = 0,
    distanceTraveled = 0,
    retreatCount = 0,
    dungeonRuns = 0,
    lastPosition = nil,
}

-- Configuration via getgenv
local _genv = getgenv()
if _genv.AutoFarmEnabled == nil then
    _genv.AutoFarmEnabled = false
end
if _genv.AutoFarmClass == nil then
    _genv.AutoFarmClass = 'Mage'  -- Default class
end
if _genv.AutoDodgePauseFarm == nil then
    _genv.AutoDodgePauseFarm = false
end
if _genv.AutoFarmWorldEvents == nil then
    _genv.AutoFarmWorldEvents = false
end
if _genv.AutoFarmPetAura == nil then
    _genv.AutoFarmPetAura = false
end

-- Pet Aura integration
local PetAuraAPI = nil
local isPetAuraLoaded = false

-- World Events integration
local WorldEventsAPI = nil
local isWorldEventsLoaded = false
local worldEventActive = false
local worldEventLastCheck = 0
local worldEventCooldown = 0  -- Cooldown after completing an event

-- Prison Tower integration
local PrisonTowerAPI = nil
local isPrisonTowerLoaded = false
local prisonStartPending = false
local prisonStartAttempts = 0
local prisonStartInProgress = false

-- Atlantis Tower integration
local AtlantisTowerAPI = nil
local isAtlantisTowerLoaded = false
local atlantisStartPending = false
local atlantisStartAttempts = 0
local atlantisStartInProgress = false

-- Crabby Crusade integration
local CrabbyCrusadeAPI = nil
local isCrabbyCrusadeLoaded = false
local crabbyStartPending = false
local crabbyStartAttempts = 0
local crabbyStartInProgress = false

-- Scarecrow Defense integration
local ScarecrowDefenseAPI = nil
local isScarecrowDefenseLoaded = false

-- Dire Problem integration
local DireProblemAPI = nil
local isDireProblemLoaded = false
local direProblemActive = false

-- Kingslayer integration
local KingslayerAPI = nil
local isKingslayerLoaded = false
local kingslayerActive = false

-- Gravetower integration
local GravetowerAPI = nil
local isGravetowerLoaded = false
local gravetowerActive = false

-- ============================================================================
-- MELEE CLASS DETECTION & AUTO-ADJUSTMENT
-- ============================================================================
-- Melee classes need different farming positions to be effective
-- They should be directly above mobs (behindDistance = 0) and closer to ground
local MeleeClasses = {
    Swordmaster = true,
    Defender = true,
    DualWielder = true,
    Guardian = true,
    Paladin = true,
    Berserker = true,
    Dragoon = true,
    Demon = true,
    Necromancer = true,
    Assassin = true,
    Warlord = true,
    Leviathan = true,
}

-- Optimal settings for melee farming
local MeleeSettings = {
    hoverHeight = 3,           -- Lower to the ground for melee range
    behindDistance = 0,        -- Directly above mob, not behind
    groundClearance = 2,       -- Minimal clearance
    outsidePadding = 0,        -- No extra padding
}

-- Optimal settings for ranged farming (defaults)
local RangedSettings = {
    hoverHeight = 7,           -- Higher up for safety
    behindDistance = 14,       -- Behind the mob
    groundClearance = 4,       -- More clearance
    outsidePadding = 6,        -- Extra padding
}

-- Track last detected class to avoid spam
local lastDetectedClass = nil
local lastClassCheckTime = 0

--- Check if current class is melee and adjust settings
--- @return boolean: True if current class is melee
local function checkAndAdjustForMelee()
    -- Only check every 2 seconds to avoid spam
    local now = os.clock()
    if now - lastClassCheckTime < 2 then
        return MeleeClasses[lastDetectedClass] or false
    end
    lastClassCheckTime = now
    
    -- Get current class from player GUI or getgenv
    local currentClass = _genv.AutoFarmClass
    
    -- Try to detect from player GUI if not set
    pcall(function()
        local plr = Players.LocalPlayer
        if plr then
            local playerGui = plr:FindFirstChild('PlayerGui')
            if playerGui then
                local profile = playerGui:FindFirstChild('Profile')
                if profile then
                    local classVal = profile:FindFirstChild('Class')
                    if classVal and classVal.Value then
                        currentClass = classVal.Value
                        _genv.AutoFarmClass = currentClass
                    end
                end
            end
        end
    end)
    
    -- Only adjust if class changed
    if currentClass == lastDetectedClass then
        return MeleeClasses[currentClass] or false
    end
    
    lastDetectedClass = currentClass
    
    if MeleeClasses[currentClass] then
        -- Apply melee settings
        _genv.AutoFarmHoverHeight = MeleeSettings.hoverHeight
        _genv.AutoFarmBehindDistance = MeleeSettings.behindDistance
        _genv.AutoFarmGroundClearance = MeleeSettings.groundClearance
        _genv.AutoFarmOutsidePadding = MeleeSettings.outsidePadding
        return true
    else
        -- Apply ranged settings
        _genv.AutoFarmHoverHeight = RangedSettings.hoverHeight
        _genv.AutoFarmBehindDistance = RangedSettings.behindDistance
        _genv.AutoFarmGroundClearance = RangedSettings.groundClearance
        _genv.AutoFarmOutsidePadding = RangedSettings.outsidePadding
        return false
    end
end

-- Movement/positioning tuning
if _genv.AutoFarmHoverHeight == nil then _genv.AutoFarmHoverHeight = 7 end           -- target hover height above ground/target
if _genv.AutoFarmBehindDistance == nil then _genv.AutoFarmBehindDistance = 14 end    -- distance to stay behind target (slightly closer)
if _genv.AutoFarmMaxSpeed == nil then _genv.AutoFarmMaxSpeed = 60 end                -- horizontal speed cap
if _genv.AutoFarmVerticalSpeed == nil then _genv.AutoFarmVerticalSpeed = 35 end      -- vertical speed cap
if _genv.AutoFarmGroundClearance == nil then _genv.AutoFarmGroundClearance = 4 end   -- extra clearance above ground
if _genv.AutoFarmSwitchTargetDistance == nil then _genv.AutoFarmSwitchTargetDistance = 100 end -- drop/retarget beyond this
if _genv.AutoFarmSmoothing == nil then _genv.AutoFarmSmoothing = 0.25 end            -- 0..1 smoothing for target position
-- Avoidance/cluster settings
if _genv.AutoFarmOutsidePadding == nil then _genv.AutoFarmOutsidePadding = 6 end    -- extra outward padding beyond behind distance (closer)
if _genv.AutoFarmAvoidRadius == nil then _genv.AutoFarmAvoidRadius = 9 end           -- radius to avoid other mobs (horizontal)
if _genv.AutoFarmAvoidStrength == nil then _genv.AutoFarmAvoidStrength = 45 end      -- repulsion strength
if _genv.AutoFarmNearbyClusterRadius == nil then _genv.AutoFarmNearbyClusterRadius = 40 end -- cluster radius around target

-- Custom wait using Heartbeat
-- Uses task.wait for efficiency when available
local function wait(sec)
    sec = tonumber(sec)
    if sec and sec > 0 then
        -- Use task.wait if available (more efficient)
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
-- ANTI-DETECTION UTILITY FUNCTIONS
-- ============================================================================

--- Add random variance to a value
--- @param value number: Base value
--- @param variance number: Variance percentage (0-1), uses AntiDetection.movementVariance if nil
--- @return number: Value with random variance applied
local function addVariance(value, variance)
    variance = variance or AntiDetection.movementVariance
    local delta = value * variance
    return value + (math.random() * 2 - 1) * delta
end

--- Add variance to a Vector3
--- @param vec Vector3: Base vector
--- @param variance number: Variance percentage
--- @return Vector3: Vector with random variance applied to each component
local function addVectorVariance(vec, variance)
    variance = variance or AntiDetection.movementVariance
    return Vector3.new(
        addVariance(vec.X, variance),
        addVariance(vec.Y, variance * 0.5), -- Less vertical variance
        addVariance(vec.Z, variance)
    )
end

--- Apply direction wobble (small random angle change)
--- @param direction Vector3: Unit direction vector
--- @return Vector3: Wobbled direction
local function applyWobble(direction)
    if math.random() > AntiDetection.wobbleChance then
        return direction
    end
    
    local wobbleAngle = (math.random() * 2 - 1) * AntiDetection.wobbleAngle
    local cosA = math.cos(wobbleAngle)
    local sinA = math.sin(wobbleAngle)
    
    -- Rotate in XZ plane (yaw wobble)
    return Vector3.new(
        direction.X * cosA - direction.Z * sinA,
        direction.Y,
        direction.X * sinA + direction.Z * cosA
    ).Unit
end

--- Get speed with variance applied
--- @param baseSpeed number: Base movement speed
--- @return number: Speed with random variance
local function getVariedSpeed(baseSpeed)
    return addVariance(baseSpeed, AntiDetection.speedVariance)
end

--- Check if we should do a micro-pause
--- @return boolean, number: Should pause, pause duration
local function shouldMicroPause()
    if math.random() < AntiDetection.pauseChance then
        local duration = AntiDetection.pauseDurationMin + 
            math.random() * (AntiDetection.pauseDurationMax - AntiDetection.pauseDurationMin)
        return true, duration
    end
    return false, 0
end

--- Update distance traveled statistic
--- @param currentPos Vector3: Current position
local function updateDistanceTraveled(currentPos)
    if SessionStats.lastPosition then
        local delta = (currentPos - SessionStats.lastPosition).Magnitude
        if delta < 100 then -- Ignore teleports
            SessionStats.distanceTraveled = SessionStats.distanceTraveled + delta
        end
    end
    SessionStats.lastPosition = currentPos
end

-- Get player
local plr = Players.LocalPlayer
if not plr then
    return
end

-- Detect if player is in Atlantis Tower
-- Atlantis Tower has NextFloorTeleporter
local function isInAtlantisTower()
    local inAtlantis = false
    pcall(function()
        local missionObjects = Workspace:FindFirstChild('MissionObjects')
        if missionObjects then
            -- Atlantis Tower: has NextFloorTeleporter
            if missionObjects:FindFirstChild('NextFloorTeleporter') then
                inAtlantis = true
            end
        end
    end)
    return inAtlantis
end

-- Detect if player is in Prison Tower
-- Prison Tower has MissionStart but NOT NextFloorTeleporter
local function isInPrisonTower()
    local inPrison = false
    pcall(function()
        local missionObjects = Workspace:FindFirstChild('MissionObjects')
        if missionObjects then
            -- Prison Tower: has MissionStart + WaveStartGate, but NO NextFloorTeleporter
            if missionObjects:FindFirstChild('MissionStart') and 
               missionObjects:FindFirstChild('WaveStartGate') and
               not missionObjects:FindFirstChild('NextFloorTeleporter') then
                inPrison = true
            end
        end
    end)
    return inPrison
end

-- Detect if player is in Crabby Crusade
-- Crabby Crusade has Checkpoints and Cabbages
local function isInCrabbyCrusade()
    local inCrabby = false
    pcall(function()
        local missionObjects = Workspace:FindFirstChild('MissionObjects')
        if missionObjects then
            -- Crabby Crusade: has Checkpoints and Cabbages folders
            if missionObjects:FindFirstChild('Checkpoints') and 
               missionObjects:FindFirstChild('Cabbages') then
                inCrabby = true
            end
        end
    end)
    return inCrabby
end

-- Detect if player is in Scarecrow Defense
-- Heuristic: MissionStart exists, but no NextFloorTeleporter/WaveStartGate/Cabbages
local function isInScarecrowDefense()
    local inScarecrow = false
    pcall(function()
        local missionObjects = Workspace:FindFirstChild('MissionObjects')
        if missionObjects then
            if missionObjects:FindFirstChild('MissionStart') and
               not missionObjects:FindFirstChild('NextFloorTeleporter') and
               not missionObjects:FindFirstChild('WaveStartGate') and
               not missionObjects:FindFirstChild('Cabbages') then
                inScarecrow = true
            end
        end
    end)
    return inScarecrow
end

-- Detect if player is in Dire Problem dungeon
local function isInDireProblem()
    local inDire = false
    pcall(function()
        -- Prefer PlaceAPI if available
        local placeApi = getgenv().x5n3d or _G.x5n3d
        if placeApi and placeApi.getCurrent then
            local cur = placeApi.getCurrent()
            if cur and cur.isDungeon and cur.name and string.find(cur.name, 'Dire Problem') then
                inDire = true
                return
            end
        end
        -- Fallback heuristic: presence of BossIntroTrigger and BridgeTrigger
        local missionObjects = Workspace:FindFirstChild('MissionObjects')
        local foliage = Workspace:FindFirstChild('Foliage')
        if missionObjects and missionObjects:FindFirstChild('BossIntroTrigger') and missionObjects:FindFirstChild('BridgeTrigger') and foliage then
            inDire = true
        end
    end)
    return inDire
end

-- Detect if player is in Kingslayer dungeon
local function isInKingslayer()
    local inKingslayer = false
    pcall(function()
        -- Prefer PlaceAPI if available
        local placeApi = getgenv().x5n3d or _G.x5n3d
        if placeApi and placeApi.getCurrent then
            local cur = placeApi.getCurrent()
            if cur and cur.isDungeon and cur.name and string.find(cur.name, 'Kingslayer') then
                inKingslayer = true
                return
            end
        end
        -- Fallback heuristic: presence of Cage1Marker and Cage2Marker
        local cage1 = Workspace:FindFirstChild('Cage1Marker')
        local cage2 = Workspace:FindFirstChild('Cage2Marker')
        if cage1 and cage2 and cage1:FindFirstChild('Collider') and cage2:FindFirstChild('Collider') then
            inKingslayer = true
        end
    end)
    return inKingslayer
end

-- Detect if player is in Gravetower dungeon
local function isInGravetower()
    local inGravetower = false
    pcall(function()
        -- Prefer PlaceAPI if available
        local placeApi = getgenv().x5n3d or _G.x5n3d
        if placeApi and placeApi.getCurrent then
            local cur = placeApi.getCurrent()
            if cur and cur.isDungeon and cur.name and string.find(cur.name, 'Gravetower') then
                inGravetower = true
                return
            end
        end
        -- Fallback heuristic: presence of Gravetower-specific elements
        -- Check for SpiritHorse mobs (unique to Gravetower)
        local mobs = Workspace:FindFirstChild('Mobs')
        if mobs then
            for _, mob in ipairs(mobs:GetChildren()) do
                if string.find(mob.Name, 'SpiritHorse') then
                    inGravetower = true
                    return
                end
            end
        end
    end)
    return inGravetower
end

-- Load Prison Tower automation script
local function loadPrisonTower()
    if not isPrisonTowerLoaded then
        pcall(function()
            PrisonTowerAPI = loadstring(game:HttpGet('https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/PrisonTower.lua'))()
            isPrisonTowerLoaded = true
        end)
    end
    return PrisonTowerAPI
end

-- Load Atlantis Tower automation script
local function loadAtlantisTower()
    if not isAtlantisTowerLoaded then
        pcall(function()
            AtlantisTowerAPI = loadstring(game:HttpGet('https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/AtlantisTower.lua'))()
            isAtlantisTowerLoaded = true
        end)
    end
    return AtlantisTowerAPI
end

-- Load Crabby Crusade automation script
local function loadCrabbyCrusade()
    if not isCrabbyCrusadeLoaded then
        pcall(function()
            CrabbyCrusadeAPI = loadstring(game:HttpGet('https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/CrabbyCrusade.lua'))()
            isCrabbyCrusadeLoaded = true
        end)
    end
    return CrabbyCrusadeAPI
end

-- Load Scarecrow Defense automation script
local function loadScarecrowDefense()
    if not isScarecrowDefenseLoaded then
        pcall(function()
            ScarecrowDefenseAPI = loadstring(game:HttpGet('https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/ScarecrowDefense.lua'))()
            isScarecrowDefenseLoaded = true
        end)
    end
    return ScarecrowDefenseAPI
end

-- Load Dire Problem automation script
local function loadDireProblem()
    if not isDireProblemLoaded then
        -- Prefer local/global API if already loaded
        DireProblemAPI = _G.DireProblemAPI or getgenv().DireProblemAPI
        if DireProblemAPI then
            isDireProblemLoaded = true
            return DireProblemAPI
        end
        pcall(function()
            -- Fallback: load from repository path (obfuscated version)
            DireProblemAPI = loadstring(game:HttpGet('https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/DireProblem.lua'))()
            isDireProblemLoaded = true
        end)
    end
    return DireProblemAPI
end

-- Load Kingslayer automation script
local function loadKingslayer()
    if not isKingslayerLoaded then
        -- Prefer local/global API if already loaded
        KingslayerAPI = _G.KingslayerAPI or getgenv().KingslayerAPI
        if KingslayerAPI then
            isKingslayerLoaded = true
            return KingslayerAPI
        end
        pcall(function()
            -- Fallback: load from repository path (obfuscated version)
            KingslayerAPI = loadstring(game:HttpGet('https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/Kingslayer.lua'))()
            isKingslayerLoaded = true
        end)
    end
    return KingslayerAPI
end

-- Load Gravetower automation script
local function loadGravetower()
    if not isGravetowerLoaded then
        -- Prefer local/global API if already loaded
        GravetowerAPI = _G.GravetowerAPI or getgenv().GravetowerAPI
        if GravetowerAPI then
            isGravetowerLoaded = true
            return GravetowerAPI
        end
        pcall(function()
            -- Fallback: load from repository path (obfuscated version)
            GravetowerAPI = loadstring(game:HttpGet('https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/Gravetower.lua'))()
            isGravetowerLoaded = true
        end)
    end
    return GravetowerAPI
end

-- Load Pet Aura API
local function loadPetAura()
    if not isPetAuraLoaded then
        -- Prefer local/global API if already loaded
        PetAuraAPI = _G.x8p3q or _G.PetAuraAPI or getgenv().x8p3q
        if PetAuraAPI then
            isPetAuraLoaded = true
            return PetAuraAPI
        end
        pcall(function()
            -- Fallback: load from repository path
            PetAuraAPI = loadstring(game:HttpGet('https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/petaura.lua'))()
            isPetAuraLoaded = true
        end)
    end
    return PetAuraAPI
end

-- Load World Events API
local function loadWorldEvents()
    if not isWorldEventsLoaded then
        -- Prefer local/global API if already loaded
        WorldEventsAPI = _G.WorldEventsAPI or getgenv().WorldEventsAPI
        if WorldEventsAPI then
            isWorldEventsLoaded = true
            return WorldEventsAPI
        end
        pcall(function()
            -- Fallback: load from repository path
            WorldEventsAPI = loadstring(game:HttpGet('https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/WorldEvents.lua'))()
            if WorldEventsAPI then
                WorldEventsAPI:Init()
                isWorldEventsLoaded = true
            end
        end)
    end
    return WorldEventsAPI
end

-- Check if world event is active and can teleport
local function checkForWorldEvent()
    if not _genv.AutoFarmWorldEvents then return nil end
    if worldEventCooldown > os.clock() then return nil end
    
    local api = loadWorldEvents()
    if not api then return nil end
    
    -- Check if any event is active
    pcall(function()
        api:Init()  -- Ensure initialized
    end)
    
    local success, events = pcall(function()
        return api:GetActiveEvents()
    end)
    
    if not success or not events or #events == 0 then return nil end
    
    -- Find first teleportable event that has started
    for _, event in ipairs(events) do
        if event.Status == "active" and event.Started then
            local canTP = false
            pcall(function()
                canTP = api:CanTeleportToEvent(event.Name)
            end)
            if canTP then
                return event
            end
        end
    end
    
    return nil
end

-- Teleport to world event and wait for completion
local function handleWorldEvent(event)
    if not event or not WorldEventsAPI then return false end
    
    worldEventActive = true
    
    -- Teleport to event
    local teleported = false
    pcall(function()
        teleported = WorldEventsAPI:TeleportToEvent(event.Name)
    end)
    
    if not teleported then
        worldEventActive = false
        return false
    end
    
    -- Wait for teleport to complete
    wait(3)
    
    -- Track when event ends
    local eventEnded = false
    local eventConnection = nil
    
    pcall(function()
        WorldEventsAPI:OnEventFinish(function(eventName)
            if eventName == event.Name then
                eventEnded = true
            end
        end)
    end)
    
    -- Wait for event to end (max 10 minutes)
    local maxWait = os.clock() + 600
    while not eventEnded and os.clock() < maxWait do
        -- Check if event is still active
        local stillActive = false
        pcall(function()
            local activeEvents = WorldEventsAPI:GetActiveEvents()
            for _, e in ipairs(activeEvents) do
                if e.Name == event.Name and e.Started then
                    stillActive = true
                    break
                end
            end
        end)
        
        if not stillActive then
            eventEnded = true
        end
        
        wait(2)
    end
    
    worldEventActive = false
    worldEventCooldown = os.clock() + 30  -- 30 second cooldown before checking again
    
    return true
end

-- Trigger floor transitions in towers
local function existDoor()
    if Workspace and Workspace:FindFirstChild('Map') then
        for _, a in ipairs(Workspace.Map:GetChildren()) do
            -- Touch the BoundingBox to trigger floor transition
            if a:FindFirstChild('BoundingBox') then 
                local _, hrp = getPlayerParts()
                if hrp then
                    -- Extra safety: only trigger if no mobs nearby (avoid mid-wave)
                    local mobsContainer = Workspace:FindFirstChild('Mobs')
                    local nearbyMobs = 0
                    if mobsContainer then
                        for _, m in ipairs(mobsContainer:GetChildren()) do
                            local col = m:FindFirstChild('Collider')
                            local hp = m:FindFirstChild('HealthProperties')
                            local h = hp and hp:FindFirstChild('Health')
                            if col and h and h.Value > 0 then
                                if (col.Position - hrp.Position).Magnitude <= 60 then
                                    nearbyMobs = nearbyMobs + 1
                                end
                            end
                        end
                    end
                    if nearbyMobs > 0 then
                        return
                    end
                    firetouchinterest(hrp, a.BoundingBox, 0)
                    wait(.25)
                    firetouchinterest(hrp, a.BoundingBox, 1)
                end
            end
            
            -- Clean up visual obstacles
            pcall(function()
                if a:FindFirstChild('Model') then a.Model:Destroy() end
                if a:FindFirstChild('Tiles') then a.Tiles:Destroy() end
                if a:FindFirstChild('Gate') then a.Gate:Destroy() end
            end)
        end
    end
end

-- Ensure AutoDodge is disabled (used for dungeons with no player damage)
local function ensureAutoDodgeDisabled()
    pcall(function()
        local autoDodge = _G.AutoDodgeAPI or _G.x6p9t or getgenv().x6p9t
        local enabledFlag = (getgenv() and getgenv().AutoDodgeEnabled) or false
        local isEnabled = false
        if autoDodge and autoDodge.config then
            isEnabled = (autoDodge.config.enabled == true)
        else
            isEnabled = enabledFlag
        end
        if autoDodge and isEnabled and autoDodge.disable then
            autoDodge.disable()
        end
        if getgenv() then
            getgenv().AutoDodgeEnabled = false
        end
    end)
end

-- Get player components (character, HRP, etc)
local function getPlayerParts()
    if not plr.Character then
        return nil, nil, nil
    end
    
    local character = plr.Character
    local hrp = character:FindFirstChild('HumanoidRootPart')
    local collider = character:FindFirstChild('Collider') or character:FindFirstChild('UpperTorso')
    
    return character, hrp, collider
end

-- NoClip/Flying implementation
local function noClip()
    pcall(function()
        local character, hrp, collider = getPlayerParts()
        if not character or not hrp or not collider then return end
        
        -- Disable Freefall/FallingDown states to prevent falling animation
        -- This is what the game itself does (see anticheat.lua section 3)
        local humanoid = character:FindFirstChild('Humanoid')
        if humanoid then
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
        end
        
        -- Create BodyVelocity for flying
        if not hrp:FindFirstChild('BodyVelocity') then
            local bv = Instance.new('BodyVelocity')
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.P = 9000
            bv.Parent = hrp
        end

        -- Keep character upright and allow facing target
        if not hrp:FindFirstChild('BodyGyro') then
            local bg = Instance.new('BodyGyro')
            bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
            bg.P = 1e5
            bg.D = 500
            bg.CFrame = hrp.CFrame
            bg.Parent = hrp
        end
        
        -- Disable collision
        hrp.CanCollide = false
        collider.CanCollide = false
    end)
end

-- Update humanoid state to avoid falling animation detection
-- Uses Jump when moving up, Running when moving horizontally
-- ALWAYS sets a safe state when airborne - never allows Freefall
-- See Tests/anticheat.lua section 3 & 7 for detection details
local lastAnimationState = nil
local lastStateChangeTime = 0
local function updateMovementAnimation(velocity)
    pcall(function()
        local character = plr.Character
        if not character then return end
        
        local humanoid = character:FindFirstChild('Humanoid')
        if not humanoid then return end
        local hrp = character:FindFirstChild('HumanoidRootPart')
        if not hrp then return end
        
        -- Check if we're off the ground (flying)
        local isAirborne = false
        local rayResult = Workspace:Raycast(hrp.Position, Vector3.new(0, -10, 0))
        if not rayResult then
            isAirborne = true
        end
        
        local verticalVel = velocity.Y
        local horizontalVel = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
        
        -- Determine which animation to use based on movement direction
        local newState = nil
        
        if verticalVel > 5 then
            -- Moving upward - use Jumping state
            newState = Enum.HumanoidStateType.Jumping
        elseif horizontalVel > 3 then
            -- Moving horizontally - use Running state
            newState = Enum.HumanoidStateType.Running
        elseif verticalVel < -5 then
            -- Moving down - use Jumping to avoid freefall detection
            newState = Enum.HumanoidStateType.Jumping
        elseif isAirborne then
            -- Hovering/idle in air - MUST set a safe state, never allow Freefall
            -- Alternate between Jumping and Running to look more natural
            local now = os.clock()
            if now - lastStateChangeTime > 0.5 then
                newState = Enum.HumanoidStateType.Jumping
                lastStateChangeTime = now
            else
                newState = lastAnimationState or Enum.HumanoidStateType.Jumping
            end
        end
        
        -- Force state change when airborne, or when state changed
        if newState and (isAirborne or newState ~= lastAnimationState) then
            -- Also ensure Freefall is disabled (belt and suspenders)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            humanoid:ChangeState(newState)
            lastAnimationState = newState
        end
    end)
end

-- Continuous animation enforcement loop (failsafe)
-- Runs every 0.3 seconds to ensure we NEVER stay in Freefall when autofarm is enabled
-- This is a belt-and-suspenders approach alongside updateMovementAnimation
spawn(function()
    while true do
        wait(0.3)
        if _genv.AutoFarmEnabled then
            pcall(function()
                local character = plr.Character
                if not character then return end
                
                local humanoid = character:FindFirstChild('Humanoid')
                if not humanoid then return end
                local hrp = character:FindFirstChild('HumanoidRootPart')
                if not hrp then return end
                
                -- Check if we're airborne
                local rayResult = Workspace:Raycast(hrp.Position, Vector3.new(0, -10, 0))
                if not rayResult then
                    -- We're in the air - ensure safe state
                    -- Always disable Freefall states
                    humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
                    humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                    
                    -- Check current state
                    local currentState = humanoid:GetState()
                    if currentState == Enum.HumanoidStateType.Freefall 
                       or currentState == Enum.HumanoidStateType.FallingDown then
                        -- Force to Jumping state
                        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                    end
                end
            end)
        end
    end
end)

-- Check if the BOSSTreeEnt boss is invincible (cage/pillars present)
-- When cage or pillars are up, players must destroy them first
--- @return boolean: True if boss is invincible and should be skipped
local function isTreeEntInvincible()
    local result = false
    pcall(function()
        -- Check for TreeEntCage (the shield/cage around the boss)
        local cage = Workspace:FindFirstChild('TreeEntCage')
        if cage then
            result = true
            return
        end
        
        -- Also check for pillars - boss spawns Pillar1, Pillar2, Pillar3 when invincible
        local pillar1 = Workspace:FindFirstChild('Pillar1')
        local pillar2 = Workspace:FindFirstChild('Pillar2')
        local pillar3 = Workspace:FindFirstChild('Pillar3')
        
        if pillar1 or pillar2 or pillar3 then
            result = true
            return
        end
    end)
    return result
end

-- Check if a mob is a familiar/summon and should be skipped
--- @param mob Instance: The mob to check
--- @return boolean: True if mob is a familiar (should skip)
local function isFamiliar(mob)
    if not mob then return true end
    
    -- Check for common familiar indicators
    local mobName = mob.Name
    if not mobName then return true end
    
    -- Skip if mob has "Familiar" in the name
    if string.find(mobName, "Familiar") then
        return true
    end
    
    -- Skip if mob has "Summon" in the name
    if string.find(mobName, "Summon") then
        return true
    end
    
    -- Skip if mob has "Pet" in the name
    if string.find(mobName, "Pet") then
        return true
    end
    
    -- Skip Spirit-related summons (Necromancer/Summoner) but NOT SpiritHorse or other game mobs
    -- Only skip exact matches like "Spirit", "Spirit1", "Spirit2" etc. (summoned spirits)
    if mobName == "Spirit" or string.match(mobName, "^Spirit%d*$") then
        return true
    end
    if mobName == "Soul" or string.match(mobName, "^Soul%d*$") then
        return true
    end
    if mobName == "Skeleton" or string.match(mobName, "^Skeleton%d*$") then
        return true
    end
    
    -- Check if mob has an Owner property (player-owned familiar)
    local hasOwner = false
    pcall(function()
        if mob:FindFirstChild("Owner") or mob:FindFirstChild("PlayerOwner") then
            hasOwner = true
        end
    end)
    
    return hasOwner
end

-- Check if a mob is owned by another player (not us)
--- @param mob Instance: The mob to check
--- @return boolean: True if owned by another player
local function isOwnedByOtherPlayer(mob)
    if not plr then return false end
    
    local isOtherOwned = false
    pcall(function()
        local mobProps = mob:FindFirstChild('MobProperties')
        if mobProps then
            local ownerVal = mobProps:FindFirstChild('Owner')
            if ownerVal and ownerVal.Value then
                -- Has an owner - check if it's not us
                if ownerVal.Value ~= plr then
                    isOtherOwned = true
                end
            end
        end
    end)
    
    return isOtherOwned
end

-- Find all alive mobs (excluding player's familiar)
local function getMobs()
    local mobs = {}
    local positions = {}
    
    -- Get player's familiar if they have one
    local familiar = nil
    pcall(function()
        if plr.Character then
            local props = plr.Character:FindFirstChild('Properties')
            if props then
                local famVal = props:FindFirstChild('Familiar')
                if famVal and famVal.Value then
                    familiar = famVal.Value
                end
            end
        end
    end)
    
    pcall(function()
        if Workspace:FindFirstChild('Mobs') then
            for _, mob in ipairs(Workspace.Mobs:GetChildren()) do
                local skip = false
                
                -- Skip familiars/summons (player-owned creatures)
                if isFamiliar(mob) then
                    skip = true
                end

                -- Skip mobs owned by other players
                if not skip and isOwnedByOtherPlayer(mob) then
                    skip = true
                end
                
                -- Skip BOSSTreeEnt boss when invincible (cage/pillars are up)
                -- Must destroy cage/pillars first to break the shield
                if not skip and mob and (mob.Name == 'BOSSTreeEnt' or mob.Name == 'CorruptedGreaterTree') and isTreeEntInvincible() then
                    skip = true
                end
                
                -- Skip Dire Problem boss unless explicitly enabled
                if not skip and mob and mob.Name == 'BOSSDireBoarwolf' then
                    local allowBoss = false
                    pcall(function()
                        local g = getgenv()
                        if g and g.DireProblemBossTarget == true then
                            allowBoss = true
                        end
                    end)
                    if not allowBoss then
                        skip = true
                    end
                end
                
                if not skip and mob == familiar then
                    skip = true
                end
                
                if not skip and mob:FindFirstChild('Collider') and mob:FindFirstChild('HealthProperties') then
                    local health = mob.HealthProperties:FindFirstChild('Health')
                    if health and health.Value > 0 then
                        table.insert(mobs, mob)
                        local character, hrp = getPlayerParts()
                        if hrp then
                            table.insert(positions, hrp.Position)
                        end
                    end
                end
            end
        end
    end)
    
    -- Also check for TreeEnt pillars directly in workspace (not in Mobs folder)
    -- These need to be destroyed to break the boss's invincibility
    pcall(function()
        local pillarNames = {'Pillar1', 'Pillar2', 'Pillar3'}
        for _, pillarName in ipairs(pillarNames) do
            local pillar = Workspace:FindFirstChild(pillarName)
            if pillar then
                local collider = pillar:FindFirstChild('Collider')
                if collider then
                    local health = pillar:FindFirstChild('HealthProperties')
                    if health and health:FindFirstChild('Health') then
                        local healthVal = health.Health
                        if healthVal and healthVal.Value and healthVal.Value > 0 then
                            table.insert(mobs, pillar)
                            local character, hrp = getPlayerParts()
                            if hrp then
                                table.insert(positions, hrp.Position)
                            end
                        end
                    end
                end
            end
        end
    end)
    
    return mobs, positions
end

-- Move object to specific position using smooth tweening
local tweenSpeed = 76  -- Base value (will be varied for anti-detection)
local currentSpeed = tweenSpeed  -- Ramped speed for smooth acceleration

local function moveTo(obj, x, y, z)
    pcall(function()
        local character, hrp = getPlayerParts()
        if not hrp or not obj then return end
        
        local targetCFrame
        if x and y and z then
            targetCFrame = obj.CFrame * CFrame.new(x, y, z)
        else
            targetCFrame = obj.CFrame
        end
        
        -- Calculate distance and time needed
        local distance = (targetCFrame.Position - hrp.Position).Magnitude
        
        -- Don't tween if already very close
        if distance < 5 then
            hrp.CFrame = targetCFrame
            return
        end
        
        -- Smooth interpolation using BodyVelocity
        local bv = hrp:FindFirstChild('BodyVelocity')
        if bv then
            local direction = (targetCFrame.Position - hrp.Position).Unit
            local moveVel = direction * tweenSpeed
            bv.Velocity = moveVel
            
            -- Update animation to avoid falling detection
            updateMovementAnimation(moveVel)
        end
    end)
end

-- Tween to a target position and wait until arrival (blocking)
local function tweenToPosition(targetPos, speed)
    speed = speed or tweenSpeed
    local character, hrp = getPlayerParts()
    if not character or not hrp then return false end
    
    -- Ensure noClip is active for movement
    noClip()
    
    local maxTime = 10 -- timeout after 10 seconds
    local startTime = os.clock()
    
    while true do
        character, hrp = getPlayerParts()
        if not character or not hrp then return false end
        
        local bv = hrp:FindFirstChild('BodyVelocity')
        if not bv then
            noClip()
            bv = hrp:FindFirstChild('BodyVelocity')
            if not bv then return false end
        end
        
        local toTarget = targetPos - hrp.Position
        local distance = toTarget.Magnitude
        
        -- Arrived or timeout
        if distance < 5 then
            bv.Velocity = Vector3.new(0, 0, 0)
            return true
        end
        
        if os.clock() - startTime > maxTime then
            bv.Velocity = Vector3.new(0, 0, 0)
            return false
        end
        
        -- Keep moving toward target
        local direction = toTarget.Unit
        local moveVel = direction * speed
        bv.Velocity = moveVel
        
        -- Update animation to avoid falling detection
        updateMovementAnimation(moveVel)
        
        wait(0.1)
    end
end

-- Tween + touch helper for tower parts (handles both BasePart and Model)
local function touchWithMove(part)
    local character, hrp = getPlayerParts()
    if not character or not hrp or not part then
        return false
    end
    
    -- Find the actual BasePart to use
    local targetPart = part
    if part:IsA('Model') then
        targetPart = part:FindFirstChild('Collider') or part:FindFirstChildWhichIsA('BasePart') or part.PrimaryPart
    end
    
    if not targetPart or not targetPart:IsA('BasePart') then
        return false
    end

    -- Tween to slightly above the part
    local targetPos = targetPart.Position + Vector3.new(0, 3, 0)
    tweenToPosition(targetPos, tweenSpeed)
    
    -- Now teleport exactly to part and touch
    character, hrp = getPlayerParts()
    if hrp then
        hrp.CFrame = targetPart.CFrame
        wait(0.1)
        
        -- Check for TouchInterest on both the target part and original part
        local touchInterest = targetPart:FindFirstChild('TouchInterest') or part:FindFirstChild('TouchInterest')
        if touchInterest then
            local touchTarget = touchInterest.Parent
            firetouchinterest(hrp, touchTarget, 0)
            wait(0.1)
            firetouchinterest(hrp, touchTarget, 1)
        end
    end

    return true
end

-- Local fallback start for Prison Tower using tweened movement
local function prisonLocalStart()
    local missionObjects = Workspace:FindFirstChild('MissionObjects')
    if not missionObjects then return false end

    -- Step 1: Tween to MissionStart.Collider and touch it
    local missionStart = missionObjects:FindFirstChild('MissionStart')
    if missionStart then
        local collider = missionStart:FindFirstChild('Collider')
        if collider then
            touchWithMove(collider)
        else
            touchWithMove(missionStart)
        end
    end
    
    -- Wait 3 seconds for mission to start
    wait(3)

    -- Step 2: Tween to MinibossSpawn to trigger mob spawning
    local minibossSpawn = missionObjects:FindFirstChild('MinibossSpawn')
    if minibossSpawn then
        touchWithMove(minibossSpawn)
    end

    return true
end

-- Local start for Atlantis Tower using tweened movement
local function atlantisLocalStart()
    local missionObjects = Workspace:FindFirstChild('MissionObjects')
    if not missionObjects then return false end

    -- Step 1: Tween to NextFloorTeleporter and touch it
    local nextTele = missionObjects:FindFirstChild('NextFloorTeleporter')
    if nextTele then
        touchWithMove(nextTele)
    end

    -- Wait 3 seconds for mission to start (same as Prison Tower)
    wait(3)

    -- Step 2: Tween to MinibossSpawn to trigger mob spawning
    local miniboss = missionObjects:FindFirstChild('MinibossSpawn')
    if miniboss then
        touchWithMove(miniboss)
    end

    return true
end

-- Local start for Crabby Crusade using tweened movement
local function crabbyLocalStart()
    local missionObjects = Workspace:FindFirstChild('MissionObjects')
    if not missionObjects then return false end

    -- Step 1: Tween to MissionStart.Collider and touch it
    local missionStart = missionObjects:FindFirstChild('MissionStart')
    if missionStart then
        local collider = missionStart:FindFirstChild('Collider')
        if collider then
            touchWithMove(collider)
        else
            touchWithMove(missionStart)
        end
    end

    -- Wait 3 seconds for mission to start
    wait(3)

    return true
end

-- Attack mobs with skills (using Kill Aura separately)
local function attackMobs()
    -- Attack is handled by Kill Aura module
    -- This function is a placeholder for future use
end

-- Get player health percentage
local function getHealthPercent()
    -- Prefer server-provided HealthProperties path in Workspace
    local percent = 100
    pcall(function()
        local chars = Workspace:FindFirstChild('Characters')
        if chars and plr and plr.Name then
            local myChar = chars:FindFirstChild(plr.Name)
            if myChar then
                local hpProps = myChar:FindFirstChild('HealthProperties')
                if hpProps then
                    local healthVal = hpProps:FindFirstChild('Health')
                    local maxHealthVal = hpProps:FindFirstChild('MaxHealth')
                    if healthVal and maxHealthVal and maxHealthVal.Value > 0 then
                        percent = (healthVal.Value / maxHealthVal.Value) * 100
                        return
                    end
                end
            end
        end
        -- Fallback to Humanoid if custom path not found
        local character = plr.Character
        if character then
            local humanoid = character:FindFirstChild('Humanoid')
            if humanoid and humanoid.MaxHealth > 0 then
                percent = (humanoid.Health / humanoid.MaxHealth) * 100
            end
        end
    end)
    return percent
end



-- Raycast helpers to find ground and enforce altitude
local _rayParams = RaycastParams.new()
_rayParams.FilterType = Enum.RaycastFilterType.Exclude
_rayParams.IgnoreWater = false

local function getGroundY(originPos, maxDrop)
    local character = plr.Character
    local ignore = {}
    if character then table.insert(ignore, character) end
    _rayParams.FilterDescendantsInstances = ignore
    local start = originPos + Vector3.new(0, 50, 0)
    local dir = Vector3.new(0, -(maxDrop or 600), 0)
    local result = Workspace:Raycast(start, dir, _rayParams)
    if result then return result.Position.Y end
    return nil
end

-- Simple target selection, state, and smoothing
local _state = {
    currentTarget = nil,
    smoothedTargetPos = nil,
    lastTargetChange = 0,
    lastTargetLost = 0,
}

local function isMobAlive(mob)
    if not mob then return false end
    local hpProps = mob:FindFirstChild('HealthProperties')
    local hp = hpProps and hpProps:FindFirstChild('Health')
    return hp and hp.Value and hp.Value > 0
end

local function pickTarget()
    local mobs = getMobs()
    local _, hrp = getPlayerParts()
    if not hrp or #mobs == 0 then return nil end
    local best, bestDist = nil, math.huge
    for _, mob in ipairs(mobs) do
        if isMobAlive(mob) and mob:FindFirstChild('Collider') then
            local d = (mob.Collider.Position - hrp.Position).Magnitude
            if d < bestDist then
                best = mob
                bestDist = d
            end
        end
    end
    return best
end

-- Fly towards mobs (attack handled by Kill Aura)
spawn(function()
    local retreating = false
    local lastDoorCheck = 0
    local lastTowerCheck = 0
    local prisonTowerActive = false
    local atlantisTowerActive = false
    local crabbyCrusadeActive = false
    local scarecrowDefenseActive = false
    local lastPhysicsUpdate = 0  -- Track physics update timing
    local lastVelocity = Vector3.new(0, 0, 0)  -- Track last velocity to avoid redundant updates
    
    while true do
        local loopStartTime = os.clock()
        
        -- Adaptive loop delay based on situation
        local waitTime = 0.1  -- default
        
        -- If we have a target, check distance and adjust wait time
        if _state.currentTarget and _genv.AutoFarmEnabled then
            local _, hrp = getPlayerParts()
            if hrp and _state.currentTarget:FindFirstChild('Collider') then
                local dist = (hrp.Position - _state.currentTarget.Collider.Position).Magnitude
                
                -- Far away (>80 studs): slow down significantly to reduce lag
                if dist > 80 then
                    waitTime = 0.4
                -- Medium distance (40-80): moderate slowdown
                elseif dist > 40 then
                    waitTime = 0.25
                -- Close (<40): normal speed
                else
                    waitTime = 0.1
                end
            end
        end
        
        wait(waitTime)
        
        if not _genv.AutoFarmEnabled then
            -- Disable Prison Tower if it was active
            if prisonTowerActive and PrisonTowerAPI then
                PrisonTowerAPI.disable()
                prisonTowerActive = false
            end
            -- Disable Atlantis Tower if it was active
            if atlantisTowerActive and AtlantisTowerAPI then
                AtlantisTowerAPI.disable()
                atlantisTowerActive = false
            end
            -- Disable Crabby Crusade if it was active
            if crabbyCrusadeActive and CrabbyCrusadeAPI then
                CrabbyCrusadeAPI.disable()
                crabbyCrusadeActive = false
            end
            -- Disable Scarecrow Defense if it was active
            if scarecrowDefenseActive and ScarecrowDefenseAPI then
                ScarecrowDefenseAPI.disable()
                scarecrowDefenseActive = false
            end
            -- Disable Dire Problem if it was active
            if direProblemActive and DireProblemAPI then
                DireProblemAPI.disable()
                direProblemActive = false
            end
            -- Disable Kingslayer if it was active
            if kingslayerActive and KingslayerAPI then
                KingslayerAPI.disable()
                kingslayerActive = false
            end
            -- Reset world event state
            if worldEventActive then
                worldEventActive = false
            end
            -- When disabled, clean up physics immediately
            pcall(function()
                local character, hrp = getPlayerParts()
                if character and hrp then
                    -- Stop BodyVelocity
                    local bv = hrp:FindFirstChild('BodyVelocity')
                    if bv then
                        bv.Velocity = Vector3.new(0, 0, 0)
                    end
                    
                    -- Re-enable collision
                    hrp.CanCollide = true
                    local collider = character:FindFirstChild('Collider') or character:FindFirstChild('UpperTorso')
                    if collider then
                        collider.CanCollide = true
                    end
                end
            end)
            retreating = false
            _state.currentTarget = nil
            _state.smoothedTargetPos = nil
            wait(1)
        else
            -- Skip entire loop iteration if any dungeon start sequence is running
            if prisonStartInProgress or atlantisStartInProgress or crabbyStartInProgress then
                wait(0.1)
            -- Skip if world event is active
            elseif worldEventActive then
                wait(0.5)
            else
            pcall(function()
                noClip()
                
                -- Check and adjust settings for melee vs ranged classes
                checkAndAdjustForMelee()
                
                -- Check for world events first (before dungeons)
                if _genv.AutoFarmWorldEvents and not worldEventActive then
                    local currentTime = os.clock()
                    -- Check every 10 seconds to avoid excessive checks
                    if currentTime - worldEventLastCheck >= 10 then
                        worldEventLastCheck = currentTime
                        local event = checkForWorldEvent()
                        if event then
                            spawn(function()
                                handleWorldEvent(event)
                            end)
                            return
                        end
                    end
                end
                
                -- Pause movement if AutoDodge is active
                if _genv.AutoDodgePauseFarm then
                    -- Stop all movement and let AutoDodge handle character movement
                    local character, hrp = getPlayerParts()
                    if hrp then
                        local bv = hrp:FindFirstChild('BodyVelocity')
                        if bv then
                            bv.Velocity = Vector3.new(0, 0, 0)
                            -- Still update animation to prevent Freefall
                            updateMovementAnimation(Vector3.new(0, 0, 0))
                        end
                        local bg = hrp:FindFirstChild('BodyGyro')
                        if bg then
                            bg.CFrame = hrp.CFrame  -- Keep current orientation
                        end
                    end
                    return
                end

                local healthPercent = getHealthPercent()

                -- Check if we need to retreat
                if healthPercent <= 36 and not retreating then
                    retreating = true
                    SessionStats.retreatCount = SessionStats.retreatCount + 1
                end
                -- If retreating, fly up and wait for HP to recover
                if retreating then
                    local character, hrp = getPlayerParts()
                    if hrp then
                        -- Fly to a safe, fixed altitude above ground
                        local groundY = getGroundY(hrp.Position, 800) or (hrp.Position.Y - 50)
                        local targetHeight = math.max(groundY + _genv.AutoFarmHoverHeight + 30, hrp.Position.Y + 25)
                        local targetPos = Vector3.new(hrp.Position.X, targetHeight, hrp.Position.Z)
                        local bv = hrp:FindFirstChild('BodyVelocity')
                        if bv then
                            local direction = (targetPos - hrp.Position).Unit
                            local distance = (targetPos - hrp.Position).Magnitude
                            
                            -- If we're high enough, stop moving
                            if distance < 5 then
                                bv.Velocity = Vector3.new(0, 0, 0)
                            else
                                -- Vertical rise primarily, minimal horizontal drift
                                local vSign = (targetPos.Y > hrp.Position.Y) and 1 or -1
                                local retreatVel = Vector3.new(0, _genv.AutoFarmVerticalSpeed * vSign, 0)
                                bv.Velocity = retreatVel
                                -- Update animation to avoid falling detection
                                updateMovementAnimation(retreatVel)
                            end
                        end
                        local bg = hrp:FindFirstChild('BodyGyro')
                        if bg then bg.CFrame = CFrame.new(hrp.Position) end
                    end
                    
                    -- Wait for HP to recover to 93%
                    if healthPercent >= 93 then
                        retreating = false
                    end
                    
                    return -- Skip mob targeting while retreating
                end
                
                -- Check tower state every 3 seconds
                local currentTime = os.clock()
                if currentTime - lastTowerCheck >= 3 then
                    -- Check dungeons in priority order
                    local inAtlantis = isInAtlantisTower()
                    local inCrabby = (not inAtlantis) and isInCrabbyCrusade()
                    local inDire = (not inAtlantis) and (not inCrabby) and isInDireProblem()
                    local inKingslayer = (not inAtlantis) and (not inCrabby) and (not inDire) and isInKingslayer()
                    local inGravetower = (not inAtlantis) and (not inCrabby) and (not inDire) and (not inKingslayer) and isInGravetower()
                    local inScarecrow = (not inAtlantis) and (not inCrabby) and (not inDire) and (not inKingslayer) and (not inGravetower) and isInScarecrowDefense()
                    local inPrison = (not inAtlantis) and (not inCrabby) and (not inDire) and (not inKingslayer) and (not inGravetower) and (not inScarecrow) and isInPrisonTower()

                    if inCrabby then
                        -- Disable other dungeons if they were active
                        if prisonTowerActive and PrisonTowerAPI then
                            PrisonTowerAPI.disable()
                            prisonTowerActive = false
                            prisonStartPending = false
                            prisonStartAttempts = 0
                        end
                        if atlantisTowerActive and AtlantisTowerAPI then
                            AtlantisTowerAPI.disable()
                            atlantisTowerActive = false
                            atlantisStartPending = false
                            atlantisStartAttempts = 0
                        end
                        if scarecrowDefenseActive and ScarecrowDefenseAPI then
                            ScarecrowDefenseAPI.disable()
                            scarecrowDefenseActive = false
                        end

                        -- Load and enable Crabby Crusade
                        if loadCrabbyCrusade() and not crabbyCrusadeActive then
                            CrabbyCrusadeAPI.enable()
                            crabbyCrusadeActive = true
                            crabbyStartPending = true
                            crabbyStartAttempts = 0
                        end

                        -- Run Crabby Crusade start sequence
                        if CrabbyCrusadeAPI and crabbyStartPending and not crabbyStartInProgress then
                            crabbyStartPending = false
                            crabbyStartAttempts = crabbyStartAttempts + 1
                            crabbyStartInProgress = true

                            spawn(function()
                                crabbyLocalStart()
                                crabbyStartInProgress = false
                            end)
                        end

                        -- Force-disable AutoDodge in Crabby Crusade (no incoming damage here)
                        ensureAutoDodgeDisabled()
                    elseif inAtlantis then
                        -- Disable other dungeons if they were active
                        if prisonTowerActive and PrisonTowerAPI then
                            PrisonTowerAPI.disable()
                            prisonTowerActive = false
                            prisonStartPending = false
                            prisonStartAttempts = 0
                        end
                        if crabbyCrusadeActive and CrabbyCrusadeAPI then
                            CrabbyCrusadeAPI.disable()
                            crabbyCrusadeActive = false
                            crabbyStartPending = false
                            crabbyStartAttempts = 0
                        end
                        if scarecrowDefenseActive and ScarecrowDefenseAPI then
                            ScarecrowDefenseAPI.disable()
                            scarecrowDefenseActive = false
                        end

                        -- Load and enable Atlantis Tower
                        if loadAtlantisTower() and not atlantisTowerActive then
                            AtlantisTowerAPI.enable()
                            atlantisTowerActive = true
                            atlantisStartPending = true
                            atlantisStartAttempts = 0
                        end

                        -- Run Atlantis start sequence
                        if AtlantisTowerAPI and atlantisStartPending and not atlantisStartInProgress then
                            atlantisStartPending = false
                            atlantisStartAttempts = atlantisStartAttempts + 1
                            atlantisStartInProgress = true

                            spawn(function()
                                atlantisLocalStart()
                                atlantisStartInProgress = false
                            end)
                        end
                    elseif inScarecrow then
                        -- Disable other dungeons if they were active
                        if prisonTowerActive and PrisonTowerAPI then
                            PrisonTowerAPI.disable()
                            prisonTowerActive = false
                            prisonStartPending = false
                            prisonStartAttempts = 0
                        end
                        if atlantisTowerActive and AtlantisTowerAPI then
                            AtlantisTowerAPI.disable()
                            atlantisTowerActive = false
                            atlantisStartPending = false
                            atlantisStartAttempts = 0
                        end
                        if crabbyCrusadeActive and CrabbyCrusadeAPI then
                            CrabbyCrusadeAPI.disable()
                            crabbyCrusadeActive = false
                            crabbyStartPending = false
                            crabbyStartAttempts = 0
                        end

                        -- Load and enable Scarecrow Defense (auto-start handles touching)
                        if loadScarecrowDefense() and not scarecrowDefenseActive then
                            ScarecrowDefenseAPI.enable()
                            scarecrowDefenseActive = true
                        end

                        -- Force-disable AutoDodge in Scarecrow Defense (no incoming damage here)
                        ensureAutoDodgeDisabled()

                    elseif inDire then
                        -- Disable other dungeons if they were active
                        if prisonTowerActive and PrisonTowerAPI then
                            PrisonTowerAPI.disable()
                            prisonTowerActive = false
                            prisonStartPending = false
                            prisonStartAttempts = 0
                        end
                        if atlantisTowerActive and AtlantisTowerAPI then
                            AtlantisTowerAPI.disable()
                            atlantisTowerActive = false
                            atlantisStartPending = false
                            atlantisStartAttempts = 0
                        end
                        if crabbyCrusadeActive and CrabbyCrusadeAPI then
                            CrabbyCrusadeAPI.disable()
                            crabbyCrusadeActive = false
                            crabbyStartPending = false
                            crabbyStartAttempts = 0
                        end
                        if scarecrowDefenseActive and ScarecrowDefenseAPI then
                            ScarecrowDefenseAPI.disable()
                            scarecrowDefenseActive = false
                        end
                        if kingslayerActive and KingslayerAPI then
                            KingslayerAPI.disable()
                            kingslayerActive = false
                        end

                        -- Load and enable Dire Problem
                        if loadDireProblem() and not direProblemActive then
                            DireProblemAPI.enable()
                            direProblemActive = true
                        end

                    elseif inKingslayer then
                        -- Disable other dungeons if they were active
                        if prisonTowerActive and PrisonTowerAPI then
                            PrisonTowerAPI.disable()
                            prisonTowerActive = false
                            prisonStartPending = false
                            prisonStartAttempts = 0
                        end
                        if atlantisTowerActive and AtlantisTowerAPI then
                            AtlantisTowerAPI.disable()
                            atlantisTowerActive = false
                            atlantisStartPending = false
                            atlantisStartAttempts = 0
                        end
                        if crabbyCrusadeActive and CrabbyCrusadeAPI then
                            CrabbyCrusadeAPI.disable()
                            crabbyCrusadeActive = false
                            crabbyStartPending = false
                            crabbyStartAttempts = 0
                        end
                        if scarecrowDefenseActive and ScarecrowDefenseAPI then
                            ScarecrowDefenseAPI.disable()
                            scarecrowDefenseActive = false
                        end
                        if direProblemActive and DireProblemAPI then
                            DireProblemAPI.disable()
                            direProblemActive = false
                        end

                        -- Load and enable Kingslayer
                        if loadKingslayer() and not kingslayerActive then
                            KingslayerAPI.enable()
                            kingslayerActive = true
                        end

                    elseif inGravetower then
                        -- Disable other dungeons if they were active
                        if prisonTowerActive and PrisonTowerAPI then
                            PrisonTowerAPI.disable()
                            prisonTowerActive = false
                            prisonStartPending = false
                            prisonStartAttempts = 0
                        end
                        if atlantisTowerActive and AtlantisTowerAPI then
                            AtlantisTowerAPI.disable()
                            atlantisTowerActive = false
                            atlantisStartPending = false
                            atlantisStartAttempts = 0
                        end
                        if crabbyCrusadeActive and CrabbyCrusadeAPI then
                            CrabbyCrusadeAPI.disable()
                            crabbyCrusadeActive = false
                            crabbyStartPending = false
                            crabbyStartAttempts = 0
                        end
                        if scarecrowDefenseActive and ScarecrowDefenseAPI then
                            ScarecrowDefenseAPI.disable()
                            scarecrowDefenseActive = false
                        end
                        if direProblemActive and DireProblemAPI then
                            DireProblemAPI.disable()
                            direProblemActive = false
                        end
                        if kingslayerActive and KingslayerAPI then
                            KingslayerAPI.disable()
                            kingslayerActive = false
                        end

                        -- Load and enable Gravetower
                        if loadGravetower() and not gravetowerActive then
                            GravetowerAPI.enable()
                            gravetowerActive = true
                        end

                    elseif inPrison then
                        -- Disable other dungeons if they were active
                        if atlantisTowerActive and AtlantisTowerAPI then
                            AtlantisTowerAPI.disable()
                            atlantisTowerActive = false
                            atlantisStartPending = false
                            atlantisStartAttempts = 0
                        end
                        if crabbyCrusadeActive and CrabbyCrusadeAPI then
                            CrabbyCrusadeAPI.disable()
                            crabbyCrusadeActive = false
                            crabbyStartPending = false
                            crabbyStartAttempts = 0
                        end
                        if scarecrowDefenseActive and ScarecrowDefenseAPI then
                            ScarecrowDefenseAPI.disable()
                            scarecrowDefenseActive = false
                        end

                        -- Load and enable Prison Tower
                        if loadPrisonTower() and not prisonTowerActive then
                            PrisonTowerAPI.enable()
                            prisonTowerActive = true
                            prisonStartPending = true
                            prisonStartAttempts = 0
                        end

                        -- Run Prison start sequence
                        if PrisonTowerAPI and prisonStartPending and not prisonStartInProgress then
                            prisonStartPending = false
                            prisonStartAttempts = prisonStartAttempts + 1
                            prisonStartInProgress = true

                            spawn(function()
                                prisonLocalStart()
                                prisonStartInProgress = false
                            end)
                        end
                    else
                        if prisonTowerActive and PrisonTowerAPI then
                            PrisonTowerAPI.disable()
                            prisonTowerActive = false
                            prisonStartPending = false
                            prisonStartAttempts = 0
                        end

                        if atlantisTowerActive and AtlantisTowerAPI then
                            AtlantisTowerAPI.disable()
                            atlantisTowerActive = false
                            atlantisStartPending = false
                            atlantisStartAttempts = 0
                        end

                        if crabbyCrusadeActive and CrabbyCrusadeAPI then
                            CrabbyCrusadeAPI.disable()
                            crabbyCrusadeActive = false
                            crabbyStartPending = false
                            crabbyStartAttempts = 0
                        end

                        if scarecrowDefenseActive and ScarecrowDefenseAPI then
                            ScarecrowDefenseAPI.disable()
                            scarecrowDefenseActive = false
                        end

                        if direProblemActive and DireProblemAPI then
                            DireProblemAPI.disable()
                            direProblemActive = false
                        end

                        if kingslayerActive and KingslayerAPI then
                            KingslayerAPI.disable()
                            kingslayerActive = false
                        end

                        if gravetowerActive and GravetowerAPI then
                            GravetowerAPI.disable()
                            gravetowerActive = false
                        end

                        if currentTime - lastDoorCheck >= 5 then
                            existDoor()
                            lastDoorCheck = currentTime
                        end
                    end

                    lastTowerCheck = currentTime
                end

                -- If in Dire Problem and boss has spawned, auto-enable boss targeting
                pcall(function()
                    if isInDireProblem() then
                        local mobs = Workspace:FindFirstChild('Mobs')
                        local boss = mobs and mobs:FindFirstChild('BOSSDireBoarwolf')
                        if boss and (getgenv().DireProblemBossTarget ~= true) then
                            local api = _G.DireProblemAPI or getgenv().DireProblemAPI
                            if api and api.enableBossTarget then
                                api.enableBossTarget()
                            else
                                getgenv().DireProblemBossTarget = true
                            end
                        end
                    end
                end)
                
                -- Normal farming behavior
                local character, hrp = getPlayerParts()
                if not hrp then return end

                -- Maintain/choose target with lock to reduce jitter
                local current = _state.currentTarget
                local needNew = false
                if not current or not isMobAlive(current) or not current:FindFirstChild('Collider') then
                    needNew = true
                else
                    local dist = (current.Collider.Position - hrp.Position).Magnitude
                    if dist > _genv.AutoFarmSwitchTargetDistance then
                        needNew = true
                    end
                end
                if needNew then
                    current = pickTarget()
                    _state.currentTarget = current
                    if current then
                        -- Track statistics
                        SessionStats.mobsTargeted = SessionStats.mobsTargeted + 1
                    else
                        _state.lastTargetLost = os.clock()
                    end
                    _state.lastTargetChange = os.clock()
                end

                if current and current:FindFirstChild('Collider') then
                    local col = current.Collider

                    -- Compute desired point: bias to mob's back and away from clusters
                    local mobs = getMobs()
                    local center = nil
                    local count = 0
                    for _, m in ipairs(mobs) do
                        if m ~= current and m:FindFirstChild('Collider') then
                            if (m.Collider.Position - col.Position).Magnitude <= _genv.AutoFarmNearbyClusterRadius then
                                if not center then center = Vector3.new(0, 0, 0) end
                                center = center + m.Collider.Position
                                count = count + 1
                            end
                        end
                    end
                    if count > 0 then center = center / count end

                    local behindDir = -(col.CFrame.LookVector) -- stay behind the mob's facing
                    if behindDir.Magnitude < 0.1 then
                        behindDir = Vector3.new(0, 0, -1)
                    end

                    local clusterBias = Vector3.new(0, 0, 0)
                    if center then
                        clusterBias = (col.Position - center)
                        if clusterBias.Magnitude > 0.1 then
                            clusterBias = clusterBias.Unit
                        else
                            clusterBias = Vector3.new(0, 0, 0)
                        end
                    end

                    -- Blend the "behind" offset with a small push away from clustered mobs
                    local blended = (behindDir * 1.35) + (clusterBias * 0.65)
                    if blended.Magnitude < 0.15 then
                        blended = behindDir
                    else
                        blended = blended.Unit
                    end

                    local baseGroundY = getGroundY(col.Position, 600) or col.Position.Y
                    local targetY
                    
                    -- Calculate targetY based on whether we're farming above or below
                    if _genv.AutoFarmHoverHeight >= 0 then
                        -- Farm Above: stay above ground with clearance
                        targetY = math.max(baseGroundY + _genv.AutoFarmHoverHeight + _genv.AutoFarmGroundClearance,
                                          col.Position.Y + _genv.AutoFarmHoverHeight)
                    else
                        -- Farm Below: go below ground (use absolute value of height)
                        -- Subtract extra 3 studs to account for head height above HumanoidRootPart
                        -- This ensures the head doesn't stick out above ground
                        targetY = baseGroundY + _genv.AutoFarmHoverHeight - 3
                    end
                    
                    local behind = math.max(8, _genv.AutoFarmBehindDistance) -- prevent getting too close
                    local desired = col.Position + blended * (behind + _genv.AutoFarmOutsidePadding)
                    desired = Vector3.new(desired.X, targetY, desired.Z)

                    -- Smooth the target to reduce micro-oscillation
                    if not _state.smoothedTargetPos then
                        _state.smoothedTargetPos = desired
                    else
                        _state.smoothedTargetPos = _state.smoothedTargetPos + (desired - _state.smoothedTargetPos) * _genv.AutoFarmSmoothing
                    end
                    local targetPos = _state.smoothedTargetPos

                    -- Move with separated horizontal/vertical components
                    local toTarget = targetPos - hrp.Position
                    local horizontal = Vector3.new(toTarget.X, 0, toTarget.Z)
                    local hDist = horizontal.Magnitude
                    local vDist = toTarget.Y
                    local hTol, vTol = 2.0, 1.5

                    -- Calculate velocity but only update physics if needed (throttle updates)
                    local timeSincePhysicsUpdate = os.clock() - lastPhysicsUpdate
                    local shouldUpdatePhysics = timeSincePhysicsUpdate >= 0.05  -- Max 20 updates/sec

                    local bv = hrp:FindFirstChild('BodyVelocity')
                    if bv and shouldUpdatePhysics then
                        local vel = Vector3.new(0, 0, 0)
                        local horizDir = nil
                        if hDist > hTol then
                            horizDir = horizontal.Unit
                        end

                        -- Obstacle avoidance: repulse from nearby non-target mobs around our current position
                        local repel = Vector3.new(0,0,0)
                        for _, m in ipairs(mobs) do
                            if m ~= current and m:FindFirstChild('Collider') then
                                local delta = hrp.Position - m.Collider.Position
                                local deltaH = Vector3.new(delta.X, 0, delta.Z)
                                local d = deltaH.Magnitude
                                if d > 0.01 and d < _genv.AutoFarmAvoidRadius then
                                    local strength = (_genv.AutoFarmAvoidRadius - d) / _genv.AutoFarmAvoidRadius
                                    repel = repel + (deltaH.Unit * (strength * _genv.AutoFarmAvoidStrength))
                                end
                            end
                        end

                        local finalH = Vector3.new(0,0,0)
                        if horizDir and repel.Magnitude > 0.1 then
                            finalH = (horizDir * _genv.AutoFarmMaxSpeed + repel)
                            -- limit final horizontal speed
                            local fhm = Vector3.new(finalH.X,0,finalH.Z).Magnitude
                            if fhm > _genv.AutoFarmMaxSpeed then
                                finalH = finalH.Unit * _genv.AutoFarmMaxSpeed
                            end
                        elseif horizDir then
                            finalH = horizDir * _genv.AutoFarmMaxSpeed
                        elseif repel.Magnitude > 0.1 then
                            finalH = repel
                        end

                        vel = vel + Vector3.new(finalH.X, 0, finalH.Z)
                        if math.abs(vDist) > vTol then
                            local vSign = (vDist > 0) and 1 or -1
                            vel = Vector3.new(vel.X, _genv.AutoFarmVerticalSpeed * vSign, vel.Z)
                        end
                        if vel.Magnitude < 1 then
                            vel = Vector3.new(0, 0, 0)
                        end
                        
                        -- Anti-detection: Apply variance to velocity
                        if vel.Magnitude > 1 then
                            -- Apply speed variance
                            local speedMult = 1 + (math.random() * 2 - 1) * AntiDetection.speedVariance
                            vel = vel * speedMult
                            
                            -- Apply direction wobble
                            if math.random() < AntiDetection.wobbleChance then
                                vel = applyWobble(vel.Unit) * vel.Magnitude
                            end
                            
                            -- Add small altitude jitter
                            local jitter = (math.random() * 2 - 1) * AntiDetection.altitudeJitter
                            vel = Vector3.new(vel.X, vel.Y + jitter, vel.Z)
                            
                            -- Micro-pause check
                            local doPause, pauseDur = shouldMicroPause()
                            if doPause then
                                vel = Vector3.new(0, 0, 0)
                                -- Will naturally resume next tick
                            end
                        end
                        
                        -- Speed ramping for smooth acceleration
                        if AntiDetection.useSpeedRamp then
                            local targetMag = vel.Magnitude
                            local currentMag = lastVelocity.Magnitude
                            local rampedMag = currentMag + (targetMag - currentMag) * AntiDetection.speedRampFactor
                            if vel.Magnitude > 0.1 then
                                vel = vel.Unit * rampedMag
                            end
                        end
                        
                        -- Only update if velocity changed significantly (reduce redundant updates)
                        local velocityDelta = (vel - lastVelocity).Magnitude
                        if velocityDelta > 2 or vel.Magnitude < 0.1 then
                            bv.Velocity = vel
                            lastVelocity = vel
                            lastPhysicsUpdate = os.clock()
                            
                            -- Update animation state to avoid falling detection
                            updateMovementAnimation(vel)
                            
                            -- Update distance traveled statistic
                            updateDistanceTraveled(hrp.Position)
                        end
                    end

                    -- Keep facing the target (yaw only)
                    local bg = hrp:FindFirstChild('BodyGyro')
                    if bg then
                        local lookAt = Vector3.new(col.Position.X, hrp.Position.Y, col.Position.Z)
                        bg.CFrame = CFrame.new(hrp.Position, lookAt)
                    end

                    -- Attack is handled by Kill Aura module
                else
                    -- No target available - hold position
                    local bv = hrp:FindFirstChild('BodyVelocity')
                    if bv then 
                        bv.Velocity = Vector3.new(0, 0, 0)
                        -- Still update animation to prevent Freefall when hovering with no target
                        updateMovementAnimation(Vector3.new(0, 0, 0))
                    end
                end
            end)
            end -- end of prisonStartInProgress else
        end
    end
end)

-- Utility: Remove damage numbers
if Workspace then
    Workspace.ChildAdded:Connect(function(v)
        if v and v.Name == 'DamageNumber' and _genv.AutoFarmEnabled then
            pcall(function() v:Destroy() end)
        end
    end)
end

-- Utility: Anti-AFK
if plr and plr.Idled then
    plr.Idled:Connect(function()
        if _genv.AutoFarmEnabled then
            pcall(function()
                local camera = Workspace.CurrentCamera
                VirtualUser:Button2Down(Vector2.new(0, 0), camera.CFrame)
                task.wait(1)
                VirtualUser:Button2Up(Vector2.new(0, 0), camera.CFrame)
            end)
        end
    end)
end

-- API for control
local AutoFarmAPI = {}

function AutoFarmAPI.enable()
    _genv.AutoFarmEnabled = true
    
    -- Remove world bounds (invisible walls) to allow free movement
    pcall(function()
        local worldBounds = Workspace:FindFirstChild('World_Bounds')
        if worldBounds then
            for _, child in ipairs(worldBounds:GetChildren()) do
                pcall(function() child:Destroy() end)
            end
        end
    end)
    
    -- Enable Pet Aura if configured
    if _genv.AutoFarmPetAura then
        pcall(function()
            local petAura = loadPetAura()
            if petAura and petAura.enable then
                petAura.enable()
            end
        end)
    end
    
    -- Prison Tower will auto-enable when detected
end

function AutoFarmAPI.disable()
    _genv.AutoFarmEnabled = false
    
    -- BUG FIX #2: Disable AutoDodge when AutoFarm is disabled to prevent spam dodging
    pcall(function()
        local autoDodge = _G.AutoDodgeAPI or _G.x6p9t or getgenv().x6p9t
        if autoDodge and autoDodge.config and autoDodge.config.enabled then
            autoDodge:DisableAutoDodge()
        end
        if getgenv() then
            getgenv().AutoDodgeEnabled = false
        end
    end)
    
    -- Disable Pet Aura if active
    if PetAuraAPI then
        pcall(function() PetAuraAPI.disable() end)
    end
    
    -- Disable Prison Tower if active
    if PrisonTowerAPI then
        pcall(function() PrisonTowerAPI.disable() end)
    end
    -- Disable Atlantis Tower if active
    if AtlantisTowerAPI then
        pcall(function() AtlantisTowerAPI.disable() end)
    end
    -- Disable Kingslayer if active
    if KingslayerAPI then
        pcall(function() KingslayerAPI.disable() end)
    end
    -- Disable Dire Problem if active
    if DireProblemAPI then
        pcall(function() DireProblemAPI.disable() end)
    end
    
    -- Wait a moment for the main loop to stop
    wait(0.2)
    
    -- Clean up physics to prevent stuck state
    pcall(function()
        local character, hrp = getPlayerParts()
        if not character or not hrp then return end
        
        -- Stop and remove BodyVelocity
        local bv = hrp:FindFirstChild('BodyVelocity')
        if bv then
            bv.Velocity = Vector3.new(0, 0, 0)
            wait(0.1)
            bv:Destroy()
        end
        local bg = hrp:FindFirstChild('BodyGyro')
        if bg then
            wait(0.05)
            bg:Destroy()
        end
        
        -- Remove any other physics constraints
        for _, desc in ipairs(character:GetDescendants()) do
            if desc:IsA('BodyVelocity') or desc:IsA('BodyGyro') or desc:IsA('BodyPosition') then
                desc:Destroy()
            end
        end
        
        -- Re-enable collision
        hrp.CanCollide = true
        local collider = character:FindFirstChild('Collider') or character:FindFirstChild('UpperTorso')
        if collider then
            collider.CanCollide = true
        end
        
        -- Reset velocity to zero
        hrp.Velocity = Vector3.new(0, 0, 0)
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        
        -- Reset humanoid state
        local humanoid = character:FindFirstChild('Humanoid')
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Landed)
            wait(0.1)
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end)
end

function AutoFarmAPI.toggle()
    _genv.AutoFarmEnabled = not _genv.AutoFarmEnabled
end

function AutoFarmAPI.setClass(className)
    _genv.AutoFarmClass = className
end

-- Manual trigger for tower start sequence (for debugging)
function AutoFarmAPI.startTower()
    if isInAtlantisTower() then
        return atlantisLocalStart()
    elseif isInPrisonTower() then
        return prisonLocalStart()
    elseif isInKingslayer() then
        -- Kingslayer doesn't need a start sequence like towers
        return true
    end
    return false
end

-- Check which tower is detected
function AutoFarmAPI.detectTower()
    if isInAtlantisTower() then
        return "Atlantis"
    elseif isInPrisonTower() then
        return "Prison"
    elseif isInCrabbyCrusade() then
        return "Crabby"
    elseif isInScarecrowDefense() then
        return "Scarecrow"
    elseif isInDireProblem() then
        return "DireProblem"
    elseif isInKingslayer() then
        return "Kingslayer"
    elseif isInGravetower() then
        return "Gravetower"
    end
    return "None"
end

-- ============================================================================
-- NEW API METHODS
-- ============================================================================

--- Set movement speed
--- @param speed number: New movement speed (default 60)
function AutoFarmAPI.setSpeed(speed)
    _genv.AutoFarmMaxSpeed = speed or 60
end

--- Get current movement speed
--- @return number: Current movement speed
function AutoFarmAPI.getSpeed()
    return _genv.AutoFarmMaxSpeed
end

--- Set hover height
--- @param height number: Height above ground/target (negative = below ground)
function AutoFarmAPI.setHeight(height)
    _genv.AutoFarmHoverHeight = height or 7
end

--- Get current hover height
--- @return number: Current hover height
function AutoFarmAPI.getHeight()
    return _genv.AutoFarmHoverHeight
end

--- Get session statistics
--- @return table: Statistics table with mobsTargeted, distanceTraveled, retreatCount, sessionTime
function AutoFarmAPI.getStats()
    return {
        mobsTargeted = SessionStats.mobsTargeted,
        distanceTraveled = math.floor(SessionStats.distanceTraveled),
        retreatCount = SessionStats.retreatCount,
        dungeonRuns = SessionStats.dungeonRuns,
        sessionTime = math.floor(os.clock() - SessionStats.startTime),
        enabled = _genv.AutoFarmEnabled,
        currentClass = _genv.AutoFarmClass,
    }
end

--- Reset session statistics
function AutoFarmAPI.resetStats()
    SessionStats.startTime = os.clock()
    SessionStats.mobsTargeted = 0
    SessionStats.distanceTraveled = 0
    SessionStats.retreatCount = 0
    SessionStats.dungeonRuns = 0
    SessionStats.lastPosition = nil
end

--- Set anti-detection configuration
--- @param key string: Configuration key (movementVariance, speedVariance, pauseChance, etc.)
--- @param value any: New value for the configuration
function AutoFarmAPI.setAntiDetection(key, value)
    if AntiDetection[key] ~= nil then
        AntiDetection[key] = value
    end
end

--- Get anti-detection configuration
--- @param key string: Optional specific key to get
--- @return any: Value or full table if no key specified
function AutoFarmAPI.getAntiDetection(key)
    if key then
        return AntiDetection[key]
    end
    return AntiDetection
end

--- Print current status to console (returns table instead - anti-cheat safe)
function AutoFarmAPI.status()
    local stats = AutoFarmAPI.getStats()
    local dungeon = AutoFarmAPI.detectTower()
    local isMeleeClass = MeleeClasses[_genv.AutoFarmClass] == true
    
    return {
        enabled = _genv.AutoFarmEnabled,
        class = _genv.AutoFarmClass,
        classType = isMeleeClass and 'MELEE' or 'RANGED',
        dungeon = dungeon,
        speed = _genv.AutoFarmMaxSpeed,
        height = _genv.AutoFarmHoverHeight,
        behindDistance = _genv.AutoFarmBehindDistance,
        worldEvents = _genv.AutoFarmWorldEvents,
        worldEventActive = worldEventActive,
        mobsTargeted = stats.mobsTargeted,
        distanceTraveled = stats.distanceTraveled,
        retreatCount = stats.retreatCount,
        sessionTime = stats.sessionTime,
        movementVariance = AntiDetection.movementVariance,
        speedVariance = AntiDetection.speedVariance
    }
end

--- Check if world event is currently being handled
--- @return boolean: True if world event is active
function AutoFarmAPI.isWorldEventActive()
    return worldEventActive
end

--- Enable/disable world events integration
--- @param enabled boolean: True to enable, false to disable
function AutoFarmAPI.setWorldEvents(enabled)
    _genv.AutoFarmWorldEvents = enabled == true
end

--- Check if currently enabled
--- @return boolean: True if auto farm is enabled
function AutoFarmAPI.isEnabled()
    return _genv.AutoFarmEnabled == true
end

--- Get current target mob (if any)
--- @return Instance|nil: Current target mob or nil
function AutoFarmAPI.getTarget()
    return _state.currentTarget
end

--- Check if current class is melee
--- @return boolean: True if current class is melee
function AutoFarmAPI.isMelee()
    local currentClass = _genv.AutoFarmClass
    return MeleeClasses[currentClass] == true
end

--- Get melee settings
--- @return table: MeleeSettings configuration
function AutoFarmAPI.getMeleeSettings()
    return MeleeSettings
end

--- Get ranged settings
--- @return table: RangedSettings configuration
function AutoFarmAPI.getRangedSettings()
    return RangedSettings
end

--- Force melee mode (overrides class detection)
function AutoFarmAPI.forceMeleeMode()
    _genv.AutoFarmHoverHeight = MeleeSettings.hoverHeight
    _genv.AutoFarmBehindDistance = MeleeSettings.behindDistance
    _genv.AutoFarmGroundClearance = MeleeSettings.groundClearance
    _genv.AutoFarmOutsidePadding = MeleeSettings.outsidePadding
end

--- Force ranged mode (overrides class detection)
function AutoFarmAPI.forceRangedMode()
    _genv.AutoFarmHoverHeight = RangedSettings.hoverHeight
    _genv.AutoFarmBehindDistance = RangedSettings.behindDistance
    _genv.AutoFarmGroundClearance = RangedSettings.groundClearance
    _genv.AutoFarmOutsidePadding = RangedSettings.outsidePadding
end

-- ============================================================================
-- GLOBAL EXPORTS
-- ============================================================================

_G.x4k7p = AutoFarmAPI
getgenv().x4k7p = AutoFarmAPI

-- Also expose with friendly names for easy access
_G.autoFarm = AutoFarmAPI
getgenv().autoFarm = AutoFarmAPI

-- ============================================================================
-- EXPORT
-- ============================================================================

return AutoFarmAPI
